export const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL as string) ?? '';

// ── Token management ────────────────────────────────────────────────────────

const TOKEN_KEY = 'nfe_vigia_tokens';

interface StoredTokens {
  access: string;
  refresh: string;
  user?: any;
}

export function getStoredTokens(): StoredTokens | null {
  try {
    const raw = localStorage.getItem(TOKEN_KEY);
    if (raw) return JSON.parse(raw);
  } catch {}
  return null;
}

export function setStoredTokens(tokens: StoredTokens) {
  localStorage.setItem(TOKEN_KEY, JSON.stringify(tokens));
}

export function clearStoredTokens() {
  localStorage.removeItem(TOKEN_KEY);
}

export function getAccessToken(): string | null {
  return getStoredTokens()?.access ?? null;
}

// ── Refresh logic ───────────────────────────────────────────────────────────

let refreshPromise: Promise<string | null> | null = null;

async function refreshAccessToken(): Promise<string | null> {
  const tokens = getStoredTokens();
  if (!tokens?.refresh) return null;

  const res = await fetch(`${API_BASE_URL}/api/auth/refresh/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ refresh: tokens.refresh }),
  });

  if (!res.ok) {
    clearStoredTokens();
    return null;
  }

  const data = await res.json();
  if (data.access) {
    setStoredTokens({
      access: data.access,
      refresh: data.refresh || tokens.refresh,
      user: tokens.user,
    });
    return data.access;
  }
  clearStoredTokens();
  return null;
}

async function getValidToken(): Promise<string | null> {
  const tokens = getStoredTokens();
  if (!tokens?.access) return null;

  // Decode JWT to check expiration
  try {
    const payload = JSON.parse(atob(tokens.access.split('.')[1]));
    const now = Math.floor(Date.now() / 1000);
    if (now >= payload.exp - 60) {
      // Token expiring in less than 60 seconds, refresh it
      if (!refreshPromise) {
        refreshPromise = refreshAccessToken().finally(() => { refreshPromise = null; });
      }
      return refreshPromise;
    }
  } catch {
    // If we can't decode, just use the token as-is
  }

  return tokens.access;
}

// ── Main fetch helper ───────────────────────────────────────────────────────

/**
 * Makes an authenticated request to the Django backend.
 * Automatically manages JWT tokens (Bearer auth + auto-refresh on 401).
 */
export async function apiFetch(
  path: string,
  options: RequestInit = {},
): Promise<Response> {
  const token = await getValidToken();

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string> || {}),
  };

  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  const res = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers,
  });

  // Auto-refresh on 401
  if (res.status === 401 && token) {
    const newToken = await refreshAccessToken();
    if (newToken) {
      headers['Authorization'] = `Bearer ${newToken}`;
      return fetch(`${API_BASE_URL}${path}`, { ...options, headers });
    }
  }

  return res;
}

/**
 * Upload a file via multipart/form-data.
 */
export async function apiUpload(
  path: string,
  formData: FormData,
): Promise<Response> {
  const token = await getValidToken();

  const headers: Record<string, string> = {};
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  // Don't set Content-Type — browser sets it with boundary for multipart

  return fetch(`${API_BASE_URL}${path}`, {
    method: 'POST',
    headers,
    body: formData,
  });
}

// ── Auth API helpers ────────────────────────────────────────────────────────

export const authApi = {
  /**
   * Login com email + senha.
   * Backend retorna: { access, refresh, usuario: { id, email, nome_completo } }
   */
  async login(email: string, password: string) {
    const res = await fetch(`${API_BASE_URL}/api/auth/login/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const data = await res.json();
    if (res.ok && data.access) {
      setStoredTokens({
        access: data.access,
        refresh: data.refresh,
        user: data.usuario,
      });
    }
    return { ok: res.ok, status: res.status, data };
  },

  /**
   * Cadastro de novo usuario.
   * Backend retorna: { access, refresh, usuario: { id, email, nome_completo } }
   */
  async signUp(params: {
    email: string;
    senha: string;
    primeiro_nome: string;
    sobrenome: string;
    condominio_id: string;
    cpf?: string;
    telefone?: string;
    data_nascimento?: string;
    bloco?: string;
    unidade?: string;
    unidade_label?: string;
  }) {
    const res = await fetch(`${API_BASE_URL}/api/auth/cadastro/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(params),
    });
    const data = await res.json();
    if (res.ok && data.access) {
      setStoredTokens({
        access: data.access,
        refresh: data.refresh,
        user: data.usuario,
      });
    }
    return { ok: res.ok, status: res.status, data };
  },

  /**
   * Logout - invalida o refresh token no backend.
   */
  async logout() {
    const tokens = getStoredTokens();
    if (tokens?.refresh) {
      await fetch(`${API_BASE_URL}/api/auth/logout/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh: tokens.refresh }),
      }).catch(() => {});
    }
    clearStoredTokens();
  },

  /**
   * Solicitar recuperacao de senha.
   */
  async forgotPassword(email: string) {
    const res = await fetch(`${API_BASE_URL}/api/auth/recuperar-senha/`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email }),
    });
    return { ok: res.ok };
  },

  /**
   * Atualizar dados do usuario autenticado.
   */
  async updateUser(updates: Record<string, any>) {
    const res = await apiFetch('/api/auth/atualizar-usuario/', {
      method: 'PUT',
      body: JSON.stringify(updates),
    });
    const data = await res.json();
    return { ok: res.ok, data };
  },

  /**
   * Buscar dados completos do usuario autenticado.
   */
  async getUser() {
    const res = await apiFetch('/api/auth/usuario/');
    if (!res.ok) return null;
    return await res.json();
  },

  /**
   * Retorna sessao local (tokens armazenados).
   */
  async getSession() {
    const tokens = getStoredTokens();
    if (!tokens?.access) return null;
    return { user: tokens.user, access: tokens.access };
  },
};
