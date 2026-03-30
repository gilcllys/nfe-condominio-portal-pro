import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { apiFetch, authApi } from '@/lib/api';
import { useCondo } from '@/contexts/CondoContext';
import { useFinancialConfig, getRequiredRoles } from '@/hooks/useFinancialConfig';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { cn } from '@/lib/utils';
import { FileText, Search, Clock, ClipboardList, FileCheck2 } from 'lucide-react';
import { differenceInHours } from 'date-fns';

type ActiveTab = 'nf' | 'os' | 'contratos';

// ─── NF types ───────────────────────────────────────────────────────────────

interface ApprovalVote {
  papel_aprovador: string;
  decisao: string | null;
}

interface PendingDoc {
  id: string;
  numero: string | null;
  valor: number | null;
  fornecedor: string | null;
  criado_em: string;
  status: string;
  nextPendingRole: string | null;
  requiredRoles: string[];
}

// ─── OS types ────────────────────────────────────────────────────────────────

interface PendingOS {
  id: string;
  titulo: string;
  status: string;
  criado_em: string;
  emergencial: boolean;
  prioridade: string | null;
  pendingVotes: number;
  totalVotes: number;
  myVotePending: boolean;
  myVoted: boolean;
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

const STATUS_OPTIONS = [
  { value: 'ALL', label: 'Todos' },
  { value: 'PENDENTE', label: 'Pendentes' },
  { value: 'PROCESSADO', label: 'Aprovadas' },
  { value: 'CANCELADO', label: 'Canceladas' },
];

const ROLE_PRIORITY = ['SUBSINDICO', 'CONSELHO', 'SINDICO'];

function getNextPendingRole(votes: ApprovalVote[]): string | null {
  for (const role of ROLE_PRIORITY) {
    const vote = votes.find((v) => v.papel_aprovador === role);
    if (!vote || !vote.decisao || vote.decisao === 'pendente') return role;
  }
  return null;
}

function getTierBadgeFromRole(role: string | null): { label: string; className: string } {
  if (role === 'SINDICO') return { label: 'SÍNDICO', className: 'bg-secondary text-secondary-foreground' };
  if (role === 'CONSELHO') return { label: 'CONSELHO', className: 'bg-warning text-warning-foreground' };
  return { label: 'SUBSÍNDICO', className: 'bg-primary text-primary-foreground' };
}

function getDeadlineInfo(createdAt: string, deadlineHours: number | null): { label: string; expired: boolean } {
  if (!deadlineHours) return { label: '—', expired: false };
  const deadline = new Date(new Date(createdAt).getTime() + deadlineHours * 60 * 60 * 1000);
  const hoursLeft = differenceInHours(deadline, new Date());
  if (hoursLeft <= 0) return { label: 'Prazo expirado', expired: true };
  if (hoursLeft < 24) return { label: `${hoursLeft}h restantes`, expired: false };
  const days = Math.ceil(hoursLeft / 24);
  return { label: `${days} dia${days > 1 ? 's' : ''}`, expired: false };
}

function getStatusBadge(status: string): { label: string; variant: 'default' | 'secondary' | 'destructive' | 'outline' } {
  if (status === 'PROCESSADO') return { label: 'Aprovada', variant: 'secondary' };
  if (status === 'CANCELADO') return { label: 'Cancelada', variant: 'destructive' };
  return { label: 'Pendente', variant: 'default' };
}

const priorityLabel: Record<string, string> = {
  BAIXA: 'Baixa',
  MEDIA: 'Média',
  ALTA: 'Alta',
  URGENTE: 'Urgente',
};

// ─── Main component ──────────────────────────────────────────────────────────

export default function Aprovacoes() {
  const navigate = useNavigate();
  const { condoId } = useCondo();
  const { config } = useFinancialConfig(condoId);
  const deadlineHours = config?.prazo_aprovacao_horas ?? null;

  // NF state
  const [docs, setDocs] = useState<PendingDoc[]>([]);
  const [loadingNF, setLoadingNF] = useState(true);
  const [filterStatus, setFilterStatus] = useState('PENDENTE');

  // OS state
  const [pendingOS, setPendingOS] = useState<PendingOS[]>([]);
  const [loadingOS, setLoadingOS] = useState(true);

  // Tab state
  const [activeTab, setActiveTab] = useState<ActiveTab>('nf');

  // ── Fetch NFs ──────────────────────────────────────────────────────────────

  useEffect(() => {
    if (!condoId) { setLoadingNF(false); return; }

    const fetchNFs = async () => {
      setLoadingNF(true);

      const params = new URLSearchParams({ condominio_id: condoId, ordering: '-criado_em' });
      if (filterStatus !== 'ALL') params.append('status', filterStatus);

      const docRes = await apiFetch(`/api/documentos-fiscais/?${params}`);
      const docData = docRes.ok ? await docRes.json() : [];
      const docList = Array.isArray(docData) ? docData : docData.results ?? [];

      if (docList.length === 0) {
        setDocs([]);
        setLoadingNF(false);
        return;
      }

      const docIds = (docList as any[]).map(d => d.id);
      const approvalsRes = await apiFetch(`/api/aprovacoes-doc-fiscal/?documento_fiscal_id=${docIds.join(',')}`);
      const approvalsData = approvalsRes.ok ? await approvalsRes.json() : [];
      const approvalsList = Array.isArray(approvalsData) ? approvalsData : approvalsData.results ?? [];

      const approvalsMap = new Map<string, ApprovalVote[]>();
      for (const a of approvalsList as any[]) {
        const list = approvalsMap.get(a.documento_fiscal_id) ?? [];
        list.push({ papel_aprovador: a.papel_aprovador, decisao: a.decisao });
        approvalsMap.set(a.documento_fiscal_id, list);
      }

      const mapped = (docList as any[]).map(d => {
        const votes: ApprovalVote[] = approvalsMap.get(d.id) ?? [];
        const nextPendingRole = getNextPendingRole(votes);
        return {
          id: d.id,
          numero: d.numero,
          valor: d.valor,
          fornecedor: d.fornecedor,
          criado_em: d.criado_em,
          status: d.status,
          nextPendingRole,
          requiredRoles: getRequiredRoles(d.valor ?? 0, config),
        };
      });

      if (filterStatus === 'PENDENTE') {
        setDocs(mapped.filter(d => d.nextPendingRole !== null));
      } else {
        setDocs(mapped);
      }
      setLoadingNF(false);
    };

    fetchNFs();
  }, [condoId, config, filterStatus]);

  // ── Fetch OS Orçamentos ────────────────────────────────────────────────────

  useEffect(() => {
    if (!condoId) { setLoadingOS(false); return; }

    const fetchOS = async () => {
      setLoadingOS(true);

      // Fetch current internal user id for "my vote" detection
      const authUser = await authApi.getUser();
      let internalUserId: string | null = null;
      if (authUser) {
        const userRes = await apiFetch(`/api/auth/usuario/?auth_user_id=${authUser.id}`);
        if (userRes.ok) {
          const userData = await userRes.json();
          const userList = Array.isArray(userData) ? userData : userData.results ?? [];
          internalUserId = userList[0]?.id ?? null;
        }
      }

      const ordersRes = await apiFetch(`/api/ordens-servico/?condominio_id=${condoId}&status=AGUARDANDO_APROVACAO&ordering=-criado_em`);
      const ordersData = ordersRes.ok ? await ordersRes.json() : [];
      const orders = Array.isArray(ordersData) ? ordersData : ordersData.results ?? [];

      if (orders.length === 0) {
        setPendingOS([]);
        setLoadingOS(false);
        return;
      }

      const orderIds = (orders as any[]).map(o => o.id);
      const approvalsRes = await apiFetch(`/api/aprovacoes/?ordem_servico_id=${orderIds.join(',')}&tipo_aprovacao=ORCAMENTO`);
      const approvalsData = approvalsRes.ok ? await approvalsRes.json() : [];
      const approvalsList = Array.isArray(approvalsData) ? approvalsData : approvalsData.results ?? [];

      const approvalsMap = new Map<string, { total: number; pending: number; myPending: boolean; myVoted: boolean }>();
      for (const a of approvalsList as any[]) {
        const current = approvalsMap.get(a.ordem_servico_id) ?? { total: 0, pending: 0, myPending: false, myVoted: false };
        current.total++;
        if (a.decisao === 'pendente') {
          current.pending++;
          if (internalUserId && a.aprovador_id === internalUserId) current.myPending = true;
        } else {
          if (internalUserId && a.aprovador_id === internalUserId) current.myVoted = true;
        }
        approvalsMap.set(a.ordem_servico_id, current);
      }

      const mapped: PendingOS[] = (orders as any[]).map(o => {
        const ap = approvalsMap.get(o.id) ?? { total: 0, pending: 0, myPending: false, myVoted: false };
        return {
          id: o.id,
          titulo: o.titulo,
          status: o.status,
          criado_em: o.criado_em,
          emergencial: o.emergencial,
          prioridade: o.prioridade,
          pendingVotes: ap.pending,
          totalVotes: ap.total,
          myVotePending: ap.myPending,
          myVoted: ap.myVoted,
        };
      });

      setPendingOS(mapped);
      setLoadingOS(false);
    };

    fetchOS();
  }, [condoId]);

  // ── Render ────────────────────────────────────────────────────────────────

  const TAB_ITEMS: { value: ActiveTab; label: string; icon: React.ReactNode; badge?: number }[] = [
    { value: 'nf', label: 'Notas Fiscais', icon: <FileText className="h-4 w-4" /> },
    { value: 'os', label: 'Orçamentos de OS', icon: <ClipboardList className="h-4 w-4" />, badge: pendingOS.length > 0 ? pendingOS.length : undefined },
    { value: 'contratos', label: 'Contratos', icon: <FileCheck2 className="h-4 w-4" /> },
  ];

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold text-foreground">Aprovações</h1>

      {/* Tab bar */}
      <div className="inline-flex h-10 items-center justify-start rounded-md bg-muted p-1 text-muted-foreground gap-0.5">
        {TAB_ITEMS.map((tab) => (
          <button
            key={tab.value}
            type="button"
            onClick={() => setActiveTab(tab.value)}
            className={cn(
              'inline-flex items-center gap-2 whitespace-nowrap rounded-sm px-3 py-1.5 text-sm font-medium transition-all',
              activeTab === tab.value
                ? 'bg-background text-foreground shadow-sm'
                : 'hover:bg-background/50 hover:text-foreground'
            )}
          >
            {tab.icon}
            {tab.label}
            {tab.badge !== undefined && (
              <Badge variant="default" className="ml-1 text-xs px-1.5 py-0">{tab.badge}</Badge>
            )}
          </button>
        ))}
      </div>

      {/* ── Tab: NFs ─────────────────────────────────────────────────────── */}
      {activeTab === 'nf' && (
        <>
          <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
            <p className="text-sm text-muted-foreground">Aprovações de Notas Fiscais do almoxarifado</p>
            <Select value={filterStatus} onValueChange={setFilterStatus}>
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Filtrar status" />
              </SelectTrigger>
              <SelectContent>
                {STATUS_OPTIONS.map((status) => (
                  <SelectItem key={status.value} value={status.value}>{status.label}</SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          <div className="glass-card">
            <div className="grid grid-cols-7 gap-4 border-b border-border/50 px-5 py-3 text-xs font-medium uppercase tracking-wider text-muted-foreground">
              <span>Documento</span>
              <span>Fornecedor</span>
              <span>Valor</span>
              <span>Alçada</span>
              <span>Prazo</span>
              <span>Status</span>
              <span className="text-right">Ações</span>
            </div>

            {loadingNF ? (
              <div className="px-5 py-12 text-center text-sm text-muted-foreground">Carregando...</div>
            ) : docs.length === 0 ? (
              <div className="px-5 py-12 text-center text-sm text-muted-foreground">Nenhuma NF encontrada para este filtro.</div>
            ) : (
              docs.map((doc) => {
                const tier = getTierBadgeFromRole(doc.nextPendingRole);
                const deadline = getDeadlineInfo(doc.criado_em, deadlineHours);
                return (
                  <div key={doc.id} className="grid grid-cols-7 items-center gap-4 border-b border-border/30 px-5 py-4 transition-colors hover:bg-muted/30">
                    <div className="flex items-center gap-2">
                      <FileText className="h-4 w-4 text-muted-foreground" />
                      <span className="text-sm font-medium text-foreground">NF #{doc.numero ?? '—'}</span>
                    </div>
                    <span className="truncate text-sm text-foreground">{doc.fornecedor ?? '—'}</span>
                    <span className="text-sm text-foreground">
                      {doc.valor != null ? `R$ ${doc.valor.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}` : '—'}
                    </span>
                    <Badge className={`${tier.className} w-fit text-xs`}>{tier.label}</Badge>
                    <div className="flex items-center gap-1 text-sm text-muted-foreground">
                      <Clock className="h-3 w-3" />
                      <span className={deadline.expired ? 'font-medium text-destructive' : ''}>{deadline.label}</span>
                    </div>
                    <Badge variant={getStatusBadge(doc.status).variant} className="w-fit text-xs">
                      {getStatusBadge(doc.status).label}
                    </Badge>
                    <div className="flex justify-end">
                      <Button
                        size="sm"
                        variant="outline"
                        className="h-7 gap-1 border-primary/30 text-xs text-primary hover:bg-primary/10"
                        onClick={() => navigate(`/aprovacoes/${doc.id}`)}
                      >
                        <Search className="h-3 w-3" />
                        Analisar
                      </Button>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </>
      )}

      {/* ── Tab: OS Orçamentos ───────────────────────────────────────────── */}
      {activeTab === 'os' && (
        <>
          <div className="mb-4">
            <p className="text-sm text-muted-foreground">Ordens de Serviço aguardando aprovação de orçamentos</p>
          </div>

          <div className="glass-card">
            <div className="grid grid-cols-6 gap-4 border-b border-border/50 px-5 py-3 text-xs font-medium uppercase tracking-wider text-muted-foreground">
              <span className="col-span-2">Ordem de Serviço</span>
              <span>Prioridade</span>
              <span>Votos pendentes</span>
              <span>Meu voto</span>
              <span className="text-right">Ações</span>
            </div>

            {loadingOS ? (
              <div className="px-5 py-12 text-center text-sm text-muted-foreground">Carregando...</div>
            ) : pendingOS.length === 0 ? (
              <div className="px-5 py-12 text-center text-sm text-muted-foreground">
                Nenhuma OS aguardando aprovação de orçamentos.
              </div>
            ) : (
              pendingOS.map((os) => (
                <div key={os.id} className="grid grid-cols-6 items-center gap-4 border-b border-border/30 px-5 py-4 transition-colors hover:bg-muted/30">
                  <div className="col-span-2 space-y-1">
                    <div className="flex items-center gap-2">
                      <ClipboardList className="h-4 w-4 text-muted-foreground" />
                      <span className="truncate text-sm font-medium text-foreground">{os.titulo}</span>
                      {os.emergencial && (
                        <Badge variant="destructive" className="text-xs">Emergencial</Badge>
                      )}
                    </div>
                    <p className="pl-6 text-xs text-muted-foreground">OS #{os.id.slice(0, 8)}</p>
                  </div>
                  <span className="text-sm text-foreground">
                    {os.prioridade ? (priorityLabel[os.prioridade] ?? os.prioridade) : '—'}
                  </span>
                  <div className="flex items-center gap-1 text-sm text-muted-foreground">
                    <Clock className="h-3 w-3" />
                    <span>{os.pendingVotes}/{os.totalVotes}</span>
                  </div>
                  <div>
                    {os.totalVotes === 0 ? (
                      <Badge variant="outline" className="text-xs">Sem aprovadores</Badge>
                    ) : os.myVotePending ? (
                      <Badge className="bg-primary text-primary-foreground text-xs">Aguardando seu voto</Badge>
                    ) : os.myVoted ? (
                      <Badge variant="secondary" className="text-xs">Já votado</Badge>
                    ) : (
                      <span className="text-sm text-muted-foreground">—</span>
                    )}
                  </div>
                  <div className="flex justify-end">
                    <Button
                      size="sm"
                      variant="outline"
                      className="h-7 gap-1 border-primary/30 text-xs text-primary hover:bg-primary/10"
                      onClick={() => navigate(`/ordens-servico/${os.id}`)}
                    >
                      <Search className="h-3 w-3" />
                      Ver OS
                    </Button>
                  </div>
                </div>
              ))
            )}
          </div>
        </>
      )}

      {/* ── Tab: Contratos ───────────────────────────────────────────────── */}
      {activeTab === 'contratos' && (
        <>
          <div className="mb-4">
            <p className="text-sm text-muted-foreground">Contratos aguardando aprovação</p>
          </div>
          <div className="glass-card px-5 py-12 text-center text-sm text-muted-foreground">
            Aprovação de contratos será disponibilizada em breve.
          </div>
        </>
      )}
    </div>
  );
}
