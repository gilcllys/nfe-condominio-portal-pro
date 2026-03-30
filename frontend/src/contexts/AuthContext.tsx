import { authApi, getStoredTokens } from '@/lib/api';
import React, { createContext, useContext, useEffect, useState } from 'react';

interface AuthUser {
  id: string;
  email?: string;
  nome_completo?: string;
  [key: string]: any;
}

interface AuthContextType {
  session: { user: AuthUser; access: string } | null;
  user: AuthUser | null;
  loading: boolean;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  session: null,
  user: null,
  loading: true,
  signOut: async () => {},
});

export const useAuth = () => useContext(AuthContext);

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [session, setSession] = useState<{ user: AuthUser; access: string } | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Intercept recovery tokens in the URL hash and redirect to /reset-password
    const hash = window.location.hash;
    if (hash) {
      const params = new URLSearchParams(hash.substring(1));
      const type = params.get('type');
      if (type === 'recovery') {
        window.location.replace('/reset-password');
        return;
      }
    }

    // Check stored tokens on mount
    const tokens = getStoredTokens();
    if (tokens?.access && tokens.user) {
      setSession({ user: tokens.user, access: tokens.access });
    }
    setLoading(false);

    // Listen for storage changes (other tabs)
    const handleStorage = (e: StorageEvent) => {
      if (e.key === 'nfe_vigia_tokens') {
        if (!e.newValue) {
          setSession(null);
        } else {
          try {
            const t = JSON.parse(e.newValue);
            if (t.access && t.user) {
              setSession({ user: t.user, access: t.access });
            }
          } catch {}
        }
      }
    };
    window.addEventListener('storage', handleStorage);
    return () => window.removeEventListener('storage', handleStorage);
  }, []);

  const signOut = async () => {
    try { localStorage.removeItem('nfe_vigia_active_condo'); } catch {}
    await authApi.logout();
    setSession(null);
  };

  return (
    <AuthContext.Provider value={{ session, user: session?.user ?? null, loading, signOut }}>
      {children}
    </AuthContext.Provider>
  );
};
