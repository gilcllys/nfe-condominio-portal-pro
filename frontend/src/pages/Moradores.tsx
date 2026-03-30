import { useEffect, useState } from 'react';
import { apiFetch } from '@/lib/api';
import { useCondo } from '@/contexts/CondoContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { useToast } from '@/hooks/use-toast';
import { Plus, Search, Pencil, Trash2, Users, Shield, UserPlus, Link2 } from 'lucide-react';
import { logActivity } from '@/lib/activity-log';
import RoleChangeDialog from '@/components/moradores/RoleChangeDialog';
import AddEmployeeDialog from '@/components/moradores/AddEmployeeDialog';
import InviteLinkDialog from '@/components/moradores/InviteLinkDialog';
import PendingApprovalsTab from '@/components/moradores/PendingApprovalsTab';

interface ResidentRow {
  id: string;
  condominio_id: string;
  bloco: string | null;
  unidade_label: string | null;
  nome_completo: string;
  documento: string | null;
  email: string | null;
  telefone: string | null;
  tipo_residencia: string | null;
  unidade_id: string | null;
  criado_em: string | null;
  atualizado_em: string | null;
  usuario_vinculado_id: string | null;
  usuario_vinculado_email: string | null;
  papel_vinculado: string | null;
}

interface ResidentForm {
  nome_completo: string;
  documento: string;
  email: string;
  telefone: string;
  bloco: string;
  unidade_label: string;
}

const ROLE_LABELS: Record<string, string> = {
  MORADOR: 'Morador',
  ZELADOR: 'Zelador',
  SINDICO: 'Síndico',
  SUBSINDICO: 'Subsíndico',
  CONSELHO: 'Conselho',
  ADMIN: 'Admin',
};

const ROLE_COLORS: Record<string, string> = {
  SINDICO: 'bg-primary/15 text-primary border-primary/30',
  ADMIN: 'bg-primary/15 text-primary border-primary/30',
  SUBSINDICO: 'bg-warning/15 text-warning border-warning/30',
  CONSELHO: 'bg-success/15 text-success border-success/30',
  ZELADOR: 'bg-secondary/20 text-secondary-foreground border-secondary/30',
  MORADOR: 'bg-muted/40 text-muted-foreground border-border',
};

const emptyForm: ResidentForm = { nome_completo: '', documento: '', email: '', telefone: '', bloco: '', unidade_label: '' };

const formatAddress = (r: ResidentRow) => {
  return [r.bloco, r.unidade_label].filter(Boolean).join(' · ') || '—';
};

export default function Moradores() {
  const { condoId, role: currentUserRole } = useCondo();
  const { toast } = useToast();

  const canManageRoles = currentUserRole === 'SINDICO' || currentUserRole === 'ADMIN';

  const [residents, setResidents] = useState<ResidentRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  const [modalOpen, setModalOpen] = useState(false);
  const [editingResident, setEditingResident] = useState<ResidentRow | null>(null);
  const [form, setForm] = useState<ResidentForm>(emptyForm);
  const [saving, setSaving] = useState(false);

  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [deletingResident, setDeletingResident] = useState<ResidentRow | null>(null);

  const [roleDialogOpen, setRoleDialogOpen] = useState(false);
  const [roleTarget, setRoleTarget] = useState<{ name: string; role: string | null; userId: string | null } | null>(null);
  const [employeeDialogOpen, setEmployeeDialogOpen] = useState(false);
  const [inviteDialogOpen, setInviteDialogOpen] = useState(false);

  const fetchResidents = async () => {
    if (!condoId) return;
    setLoading(true);
    try {
      const res = await apiFetch(`/api/moradores/?condominio_id=${condoId}`);
      if (!res.ok) throw new Error('Erro ao carregar moradores');
      const data = await res.json();
      setResidents((Array.isArray(data) ? data : data.results ?? []) as ResidentRow[]);
    } catch {
      toast({ title: 'Erro ao carregar moradores', description: 'Tente novamente.', variant: 'destructive' });
    }
    setLoading(false);
  };

  useEffect(() => { fetchResidents(); }, [condoId]);

  const filtered = residents.filter((r) => r.nome_completo.toLowerCase().includes(search.toLowerCase()));

  const openCreate = () => { setEditingResident(null); setForm(emptyForm); setModalOpen(true); };
  const openEdit = (resident: ResidentRow) => {
    setEditingResident(resident);
    setForm({ nome_completo: resident.nome_completo, documento: resident.documento ?? '', email: resident.email ?? '', telefone: resident.telefone ?? '', bloco: resident.bloco ?? '', unidade_label: resident.unidade_label ?? '' });
    setModalOpen(true);
  };
  const openDelete = (resident: ResidentRow) => { setDeletingResident(resident); setDeleteDialogOpen(true); };
  const openRoleChange = (resident: ResidentRow) => {
    setRoleTarget({ name: resident.nome_completo, role: resident.papel_vinculado ?? null, userId: resident.usuario_vinculado_id ?? null });
    setRoleDialogOpen(true);
  };

  const handleSave = async () => {
    if (!condoId || !form.nome_completo.trim()) { toast({ title: 'Nome completo é obrigatório', variant: 'destructive' }); return; }
    setSaving(true);
    const payload = {
      condominio_id: condoId, nome_completo: form.nome_completo.trim(), documento: form.documento.trim() || null,
      email: form.email.trim() || null, telefone: form.telefone.trim() || null, bloco: form.bloco.trim() || null,
      unidade_label: form.unidade_label.trim() || null, unidade_id: null,
    };

    if (editingResident) {
      try {
        const res = await apiFetch(`/api/moradores/${editingResident.id}/`, {
          method: 'PATCH',
          body: JSON.stringify(payload),
        });
        if (!res.ok) throw new Error('Erro ao atualizar morador');
        await logActivity({ condoId, action: 'update', entity: 'resident', entityId: editingResident.id, description: `Morador "${form.nome_completo.trim()}" atualizado` });
        toast({ title: 'Morador atualizado com sucesso' }); setModalOpen(false); fetchResidents();
      } catch {
        toast({ title: 'Erro ao atualizar morador', variant: 'destructive' });
      }
    } else {
      try {
        const res = await apiFetch('/api/moradores/', {
          method: 'POST',
          body: JSON.stringify(payload),
        });
        if (!res.ok) throw new Error('Erro ao cadastrar morador');
        const inserted = await res.json();
        await logActivity({ condoId, action: 'create', entity: 'resident', entityId: inserted?.id ?? '', description: `Morador "${form.nome_completo.trim()}" cadastrado` });
        toast({ title: 'Morador cadastrado com sucesso' }); setModalOpen(false); fetchResidents();
      } catch {
        toast({ title: 'Erro ao cadastrar morador', variant: 'destructive' });
      }
    }
    setSaving(false);
  };

  const handleDelete = async () => {
    if (!deletingResident || !condoId) return;
    try {
      const res = await apiFetch(`/api/moradores/${deletingResident.id}/`, { method: 'DELETE' });
      if (!res.ok) throw new Error('Erro ao excluir morador');
      await logActivity({ condoId, action: 'delete', entity: 'resident', entityId: deletingResident.id, description: `Morador "${deletingResident.nome_completo}" excluído` });
      toast({ title: 'Morador excluído com sucesso' }); fetchResidents();
    } catch {
      toast({ title: 'Erro ao excluir morador', variant: 'destructive' });
    }
    setDeleteDialogOpen(false); setDeletingResident(null);
  };

  const updateField = (field: keyof ResidentForm, value: string) => setForm((prev) => ({ ...prev, [field]: value }));

  return (
    <div className="space-y-6 enterprise-grid min-h-full -m-6 p-6">
      {/* Page Header */}
      <div className="space-y-1">
        <h1 className="text-2xl font-bold tracking-tight text-foreground">Moradores</h1>
        <p className="text-sm text-muted-foreground">Gerencie os moradores e permissões do seu condomínio.</p>
      </div>

      <Tabs defaultValue="lista">
        <TabsList className="bg-muted/30 border border-border/50 backdrop-blur-sm">
          <TabsTrigger value="lista" className="data-[state=active]:bg-primary/15 data-[state=active]:text-primary data-[state=active]:shadow-none">
            Lista de Moradores
          </TabsTrigger>
          {canManageRoles && (
            <TabsTrigger value="pendentes" className="data-[state=active]:bg-primary/15 data-[state=active]:text-primary data-[state=active]:shadow-none">
              Aguardando Aprovação
            </TabsTrigger>
          )}
        </TabsList>

        <TabsContent value="lista" className="mt-4">
          <Card className="premium-card overflow-hidden">
            <CardHeader className="flex flex-row items-center justify-between pb-4 gap-3 flex-wrap border-b border-border/50 bg-muted/20">
              <CardTitle className="text-sm font-semibold text-muted-foreground flex items-center gap-2 uppercase tracking-wider">
                <Users className="h-4 w-4 text-primary" />
                Moradores
                {!loading && (
                  <span className="ml-1 text-xs font-normal text-muted-foreground/60">({filtered.length})</span>
                )}
              </CardTitle>
              <div className="flex items-center gap-2 flex-wrap">
                {canManageRoles && (
                  <>
                    <Button
                      size="sm"
                      variant="outline"
                      className="border-border/60 bg-muted/20 hover:bg-muted/40 hover:border-primary/30 transition-all"
                      onClick={() => setInviteDialogOpen(true)}
                    >
                      <Link2 className="h-4 w-4 mr-1.5 text-primary" />
                      Gerar link de convite
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      className="border-border/60 bg-muted/20 hover:bg-muted/40 hover:border-primary/30 transition-all"
                      onClick={() => setEmployeeDialogOpen(true)}
                    >
                      <UserPlus className="h-4 w-4 mr-1.5 text-primary" />
                      Adicionar Funcionário
                    </Button>
                  </>
                )}
                <Button
                  size="sm"
                  className="btn-primary-gradient"
                  onClick={openCreate}
                >
                  <Plus className="h-4 w-4 mr-1.5" />
                  Novo Morador
                </Button>
              </div>
            </CardHeader>
            <CardContent className="space-y-4 pt-4">
              {/* Search */}
              <div className="relative max-w-md">
                <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground/60" />
                <Input
                  placeholder="Buscar por nome..."
                  value={search}
                  onChange={(e) => setSearch(e.target.value)}
                  className="pl-9 premium-input"
                />
              </div>

              {/* Table */}
              {loading ? (
                <div className="py-12 text-center">
                  <div className="inline-flex items-center gap-2 text-sm text-muted-foreground">
                    <div className="h-4 w-4 border-2 border-primary/30 border-t-primary rounded-full animate-spin" />
                    Carregando moradores...
                  </div>
                </div>
              ) : filtered.length === 0 ? (
                <div className="py-12 text-center">
                  <Users className="h-10 w-10 text-muted-foreground/30 mx-auto mb-3" />
                  <p className="text-sm text-muted-foreground">
                    {search ? 'Nenhum morador encontrado.' : 'Nenhum morador cadastrado.'}
                  </p>
                </div>
              ) : (
                <div className="overflow-x-auto rounded-lg border border-border/50">
                  <Table className="premium-table">
                    <TableHeader>
                      <TableRow className="border-b-0">
                        <TableHead className="py-3 px-4">Nome</TableHead>
                        <TableHead className="py-3 px-4">Função</TableHead>
                        <TableHead className="py-3 px-4">Email</TableHead>
                        <TableHead className="py-3 px-4">Telefone</TableHead>
                        <TableHead className="py-3 px-4">Endereço</TableHead>
                        <TableHead className="py-3 px-4 w-[130px]">Ações</TableHead>
                      </TableRow>
                    </TableHeader>
                    <TableBody>
                      {filtered.map((resident) => {
                        const hasAccount = !!resident.usuario_vinculado_id;
                        return (
                          <TableRow key={resident.id} className="group">
                            <TableCell className="font-medium py-3 px-4 text-foreground">
                              {resident.nome_completo}
                            </TableCell>
                            <TableCell className="py-3 px-4">
                              {resident.papel_vinculado ? (
                                <Badge
                                  variant="outline"
                                  className={`badge-premium text-xs ${ROLE_COLORS[resident.papel_vinculado] ?? 'bg-muted/40 text-muted-foreground border-border'}`}
                                >
                                  {ROLE_LABELS[resident.papel_vinculado] ?? resident.papel_vinculado}
                                </Badge>
                              ) : (
                                <span className="text-muted-foreground/50 text-xs">—</span>
                              )}
                            </TableCell>
                            <TableCell className="py-3 px-4 text-muted-foreground text-sm">
                              {resident.email ?? '—'}
                            </TableCell>
                            <TableCell className="py-3 px-4 text-muted-foreground text-sm">
                              {resident.telefone ?? '—'}
                            </TableCell>
                            <TableCell className="py-3 px-4 text-muted-foreground text-sm">
                              {formatAddress(resident)}
                            </TableCell>
                            <TableCell className="py-3 px-4">
                              <div className="flex items-center gap-0.5 opacity-70 group-hover:opacity-100 transition-opacity">
                                {canManageRoles && (
                                  <Button
                                    variant="ghost"
                                    size="icon"
                                    className="h-8 w-8 hover:bg-primary/10 hover:text-primary"
                                    onClick={() => hasAccount ? openRoleChange(resident) : undefined}
                                    disabled={!hasAccount}
                                    title={hasAccount ? 'Alterar função' : 'Morador sem conta de acesso'}
                                  >
                                    <Shield className={`h-4 w-4 ${!hasAccount ? 'opacity-30' : ''}`} />
                                  </Button>
                                )}
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  className="h-8 w-8 hover:bg-primary/10 hover:text-primary"
                                  onClick={() => openEdit(resident)}
                                >
                                  <Pencil className="h-4 w-4" />
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  className="h-8 w-8 hover:bg-destructive/10 hover:text-destructive"
                                  onClick={() => openDelete(resident)}
                                >
                                  <Trash2 className="h-4 w-4" />
                                </Button>
                              </div>
                            </TableCell>
                          </TableRow>
                        );
                      })}
                    </TableBody>
                  </Table>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        {canManageRoles && (
          <TabsContent value="pendentes" className="mt-4">
            {condoId && <PendingApprovalsTab condoId={condoId} />}
          </TabsContent>
        )}
      </Tabs>

      {/* Create / Edit Modal */}
      <Dialog open={modalOpen} onOpenChange={setModalOpen}>
        <DialogContent className="max-h-[calc(100vh-32px)] w-full max-w-[min(720px,calc(100vw-32px))] flex flex-col px-4 sm:px-6 overflow-y-auto premium-card border-border">
          <DialogHeader>
            <DialogTitle className="text-lg font-bold">{editingResident ? 'Editar Morador' : 'Novo Morador'}</DialogTitle>
            <DialogDescription>{editingResident ? 'Atualize os dados do morador.' : 'Preencha os dados para cadastrar um novo morador.'}</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-2 overflow-y-auto flex-1">
            <div className="space-y-2"><Label htmlFor="nome_completo" className="text-sm font-medium text-foreground">Nome completo *</Label><Input id="nome_completo" className="premium-input" value={form.nome_completo} onChange={(e) => updateField('nome_completo', e.target.value)} /></div>
            <div className="space-y-2"><Label htmlFor="documento" className="text-sm font-medium text-foreground">Documento</Label><Input id="documento" className="premium-input" value={form.documento} onChange={(e) => updateField('documento', e.target.value)} /></div>
            <div className="space-y-2"><Label htmlFor="email" className="text-sm font-medium text-foreground">Email</Label><Input id="email" type="email" className="premium-input" value={form.email} onChange={(e) => updateField('email', e.target.value)} /></div>
            <div className="space-y-2"><Label htmlFor="telefone" className="text-sm font-medium text-foreground">Telefone</Label><Input id="telefone" className="premium-input" value={form.telefone} onChange={(e) => updateField('telefone', e.target.value)} /></div>
            <div className="space-y-2"><Label htmlFor="bloco" className="text-sm font-medium text-foreground">Bloco (opcional)</Label><Input id="bloco" className="premium-input" placeholder="Ex: Bloco 26" value={form.bloco} onChange={(e) => updateField('bloco', e.target.value)} /></div>
            <div className="space-y-2"><Label htmlFor="unidade_label" className="text-sm font-medium text-foreground">Unidade / Apto / Casa (opcional)</Label><Input id="unidade_label" className="premium-input" placeholder="Ex: Apto 203" value={form.unidade_label} onChange={(e) => updateField('unidade_label', e.target.value)} /></div>
          </div>
          <DialogFooter className="sticky bottom-0 bg-card pt-4 border-t border-border/50">
            <Button variant="outline" className="border-border/60" onClick={() => setModalOpen(false)}>Cancelar</Button>
            <Button className="btn-primary-gradient" onClick={handleSave} disabled={saving}>{saving ? 'Salvando...' : editingResident ? 'Salvar' : 'Cadastrar'}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation */}
      <Dialog open={deleteDialogOpen} onOpenChange={setDeleteDialogOpen}>
        <DialogContent className="premium-card border-border">
          <DialogHeader>
            <DialogTitle className="text-lg font-bold">Excluir Morador</DialogTitle>
            <DialogDescription>Tem certeza que deseja excluir <strong className="text-foreground">{deletingResident?.nome_completo}</strong>? Esta ação não pode ser desfeita.</DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" className="border-border/60" onClick={() => setDeleteDialogOpen(false)}>Cancelar</Button>
            <Button variant="destructive" onClick={handleDelete}>Excluir</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Role Change Dialog */}
      {roleTarget && condoId && (
        <RoleChangeDialog open={roleDialogOpen} onOpenChange={setRoleDialogOpen} residentName={roleTarget.name} currentRole={roleTarget.role} userCondoUserId={roleTarget.userId} condoId={condoId} onSaved={fetchResidents} />
      )}

      {/* Add Employee Dialog */}
      {condoId && <AddEmployeeDialog open={employeeDialogOpen} onOpenChange={setEmployeeDialogOpen} condoId={condoId} onSaved={fetchResidents} />}

      {/* Invite Link Dialog */}
      {condoId && <InviteLinkDialog open={inviteDialogOpen} onOpenChange={setInviteDialogOpen} condoId={condoId} />}
    </div>
  );
}
