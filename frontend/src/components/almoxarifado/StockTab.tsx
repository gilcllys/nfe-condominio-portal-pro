import { useEffect, useState } from 'react';
import { apiFetch } from '@/lib/api';
import { useCondo } from '@/contexts/CondoContext';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Badge } from '@/components/ui/badge';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter, DialogDescription } from '@/components/ui/dialog';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Textarea } from '@/components/ui/textarea';
import { useToast } from '@/hooks/use-toast';
import { normalizeStockMoveType, STOCK_MOVE_TYPES, type StockMoveType } from '@/lib/stock-move-type';
import { Plus, ArrowUpDown, Package, Pencil, FolderPlus, Filter } from 'lucide-react';

interface StockCategory {
  id: string;
  nome: string;
  descricao: string | null;
}

interface StockItem {
  id: string;
  nome: string;
  unidade_medida: string;
  quantidade_minima: number;
  saldo_atual: number;
  categoria_id: string | null;
  categoria_nome: string | null;
  descricao: string | null;
}

interface NewItemForm {
  nome: string;
  unidade_medida: string;
  quantidade_minima: string;
  categoria_id: string;
  descricao: string;
}

interface EditItemForm {
  nome: string;
  quantidade_minima: string;
  categoria_id: string;
  descricao: string;
}

interface MovementForm {
  tipo_movimento: StockMoveType;
  quantidade: string;
  destination: string;
  notes: string;
}

interface NewCategoryForm {
  nome: string;
  descricao: string;
}

const UNITS = ['un', 'kg', 'L', 'm', 'm²', 'caixa', 'saco', 'rolo'];

const DEFAULT_CATEGORIES = [
  { nome: 'Máquinas e Equipamentos', descricao: 'Cortadores de grama, lavadoras, etc.' },
  { nome: 'Ferramentas', descricao: 'Ferramentas manuais e elétricas' },
  { nome: 'Lubrificantes e Químicos', descricao: 'Óleos, graxas, produtos químicos' },
  { nome: 'Material de Limpeza', descricao: 'Produtos e utensílios de limpeza' },
  { nome: 'Material Elétrico', descricao: 'Fios, lâmpadas, disjuntores' },
  { nome: 'Material Hidráulico', descricao: 'Tubos, conexões, registros' },
  { nome: 'Outros', descricao: 'Itens não categorizados' },
];

export default function StockTab() {
  const { condoId, role } = useCondo();
  const { toast } = useToast();
  const canCreate = role === 'SINDICO' || role === 'ADMIN';

  const [items, setItems] = useState<StockItem[]>([]);
  const [categories, setCategories] = useState<StockCategory[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterCategory, setFilterCategory] = useState<string>('all');

  // New Item dialog
  const [newItemOpen, setNewItemOpen] = useState(false);
  const [newItemForm, setNewItemForm] = useState<NewItemForm>({ nome: '', unidade_medida: '', quantidade_minima: '', categoria_id: '', descricao: '' });

  // Edit Item dialog
  const [editOpen, setEditOpen] = useState(false);
  const [editItem, setEditItem] = useState<StockItem | null>(null);
  const [editForm, setEditForm] = useState<EditItemForm>({ nome: '', quantidade_minima: '', categoria_id: '', descricao: '' });

  // Movement dialog
  const [moveOpen, setMoveOpen] = useState(false);
  const [moveItem, setMoveItem] = useState<StockItem | null>(null);
  const [moveForm, setMoveForm] = useState<MovementForm>({ tipo_movimento: STOCK_MOVE_TYPES.ENTRADA, quantidade: '', destination: 'almoxarifado', notes: '' });

  // New Category dialog
  const [catOpen, setCatOpen] = useState(false);
  const [catForm, setCatForm] = useState<NewCategoryForm>({ nome: '', descricao: '' });

  const [saving, setSaving] = useState(false);

  const fetchCategories = async () => {
    if (!condoId) return;
    try {
      const res = await apiFetch(`/api/categorias-estoque/?condominio_id=${condoId}`);
      const data = await res.json();
      const cats = Array.isArray(data) ? data : data?.results ?? [];

      // Seed default categories if none exist
      if (cats.length === 0) {
        const seedRes = await apiFetch(`/api/categorias-estoque/semear-padroes/?condominio_id=${condoId}`, {
          method: 'POST',
          body: JSON.stringify({ condominio_id: condoId }),
        });
        const seeded = await seedRes.json();
        const seededList = Array.isArray(seeded) ? seeded : seeded?.results ?? [];
        setCategories(seededList);
      } else {
        setCategories(cats);
      }
    } catch (err) {
      console.error('Error fetching categories:', err);
    }
  };

  const fetchItems = async () => {
    if (!condoId) return;
    setLoading(true);

    try {
      const res = await apiFetch(`/api/itens-estoque/?condominio_id=${condoId}`);
      const data = await res.json();
      const stockItems = Array.isArray(data) ? data : data?.results ?? [];

      // Fetch balance from the stock-movements/balance endpoint
      const balanceRes = await apiFetch(`/api/movimentacoes-estoque/saldo/?condominio_id=${condoId}`);
      const balances = await balanceRes.json();
      const balanceList = Array.isArray(balances) ? balances : balances?.results ?? [];

      const balanceMap: Record<string, number> = {};
      balanceList.forEach((b: any) => {
        balanceMap[b.item_id] = Number(b.saldo) || 0;
      });

      const catMap: Record<string, string> = {};
      categories.forEach(c => { catMap[c.id] = c.nome; });

      const merged: StockItem[] = stockItems.map((item: any) => ({
        ...item,
        saldo_atual: balanceMap[item.id] ?? 0,
        categoria_nome: item.categoria_id ? (catMap[item.categoria_id] || 'Sem categoria') : 'Sem categoria',
      }));

      setItems(merged);
    } catch (err) {
      console.error('Error fetching stock items:', err);
      toast({ title: 'Erro ao carregar itens', variant: 'destructive' });
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchCategories();
  }, [condoId]);

  useEffect(() => {
    if (categories.length > 0 || !loading) {
      fetchItems();
    }
  }, [condoId, categories]);

  const handleCreateCategory = async () => {
    if (!condoId) return;
    if (!catForm.nome.trim()) {
      toast({ title: 'Nome da categoria é obrigatório', variant: 'destructive' });
      return;
    }
    setSaving(true);

    try {
      const res = await apiFetch('/api/categorias-estoque/', {
        method: 'POST',
        body: JSON.stringify({
          condominio_id: condoId,
          nome: catForm.nome.trim(),
          descricao: catForm.descricao.trim() || null,
        }),
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        toast({ title: 'Erro ao criar categoria', description: errData.error || 'Tente novamente.', variant: 'destructive' });
      } else {
        toast({ title: 'Categoria criada!' });
        setCatOpen(false);
        setCatForm({ nome: '', descricao: '' });
        fetchCategories();
      }
    } catch {
      toast({ title: 'Erro ao criar categoria', variant: 'destructive' });
    }
    setSaving(false);
  };

  const handleCreateItem = async () => {
    if (!condoId) return;
    if (!newItemForm.nome.trim() || !newItemForm.unidade_medida || !newItemForm.quantidade_minima) {
      toast({ title: 'Preencha todos os campos obrigatórios', variant: 'destructive' });
      return;
    }

    setSaving(true);

    try {
      const res = await apiFetch('/api/itens-estoque/', {
        method: 'POST',
        body: JSON.stringify({
          condominio_id: condoId,
          nome: newItemForm.nome.trim(),
          unidade_medida: newItemForm.unidade_medida,
          quantidade_minima: Number(newItemForm.quantidade_minima),
          categoria_id: newItemForm.categoria_id || null,
          descricao: newItemForm.descricao.trim() || null,
        }),
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        toast({ title: 'Erro ao criar item', description: errData.error || 'Tente novamente.', variant: 'destructive' });
      } else {
        toast({ title: 'Item criado com sucesso' });
        setNewItemOpen(false);
        setNewItemForm({ nome: '', unidade_medida: '', quantidade_minima: '', categoria_id: '', descricao: '' });
        fetchItems();
      }
    } catch {
      toast({ title: 'Erro ao criar item', variant: 'destructive' });
    }
    setSaving(false);
  };

  const openEdit = (item: StockItem) => {
    setEditItem(item);
    setEditForm({
      nome: item.nome,
      quantidade_minima: String(item.quantidade_minima),
      categoria_id: item.categoria_id || '',
      descricao: item.descricao || '',
    });
    setEditOpen(true);
  };

  const handleEditItem = async () => {
    if (!editItem) return;
    if (!editForm.nome.trim()) {
      toast({ title: 'Nome é obrigatório', variant: 'destructive' });
      return;
    }
    setSaving(true);

    try {
      const res = await apiFetch(`/api/itens-estoque/${editItem.id}/`, {
        method: 'PATCH',
        body: JSON.stringify({
          nome: editForm.nome.trim(),
          quantidade_minima: Number(editForm.quantidade_minima) || 0,
          categoria_id: editForm.categoria_id || null,
          descricao: editForm.descricao.trim() || null,
        }),
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        toast({ title: 'Erro ao atualizar item', description: errData.error || 'Tente novamente.', variant: 'destructive' });
      } else {
        toast({ title: 'Item atualizado!' });
        setEditOpen(false);
        fetchItems();
      }
    } catch {
      toast({ title: 'Erro ao atualizar item', variant: 'destructive' });
    }
    setSaving(false);
  };

  const openMovement = (item: StockItem) => {
    setMoveItem(item);
    setMoveForm({ tipo_movimento: STOCK_MOVE_TYPES.ENTRADA, quantidade: '', destination: 'almoxarifado', notes: '' });
    setMoveOpen(true);
  };

  const handleMovement = async () => {
    if (!moveItem || !condoId) return;
    const qty = Number(moveForm.quantidade);
    if (!qty || qty <= 0) {
      toast({ title: 'Quantidade inválida', variant: 'destructive' });
      return;
    }

    if (moveForm.tipo_movimento === 'AJUSTE' && !moveForm.notes.trim()) {
      toast({ title: 'Justificativa é obrigatória para ajustes', variant: 'destructive' });
      return;
    }

    setSaving(true);

    try {
      const res = await apiFetch('/api/movimentacoes-estoque/', {
        method: 'POST',
        body: JSON.stringify({
          condominio_id: condoId,
          item_id: moveItem.id,
          tipo_movimento: normalizeStockMoveType(moveForm.tipo_movimento),
          quantidade: qty,
        }),
      });

      if (!res.ok) {
        const errData = await res.json().catch(() => ({}));
        toast({ title: 'Erro ao registrar movimentação', description: errData.error || 'Tente novamente.', variant: 'destructive' });
      } else {
        toast({ title: 'Movimentação registrada com sucesso' });
        setMoveOpen(false);
        fetchItems();
      }
    } catch {
      toast({ title: 'Erro ao registrar movimentação', variant: 'destructive' });
    }
    setSaving(false);
  };

  const filteredItems = filterCategory === 'all'
    ? items
    : filterCategory === 'none'
      ? items.filter(i => !i.categoria_id)
      : items.filter(i => i.categoria_id === filterCategory);

  return (
    <>
      <Card>
        <CardHeader className="flex flex-row items-center justify-between pb-2 gap-2 flex-wrap">
          <CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2">
            <Package className="h-4 w-4" />
            Itens em Estoque
          </CardTitle>
          <div className="flex gap-2 flex-wrap">
            {canCreate && (
              <>
                <Button size="sm" variant="outline" onClick={() => setCatOpen(true)}>
                  <FolderPlus className="h-4 w-4 mr-1" />
                  Nova Categoria
                </Button>
                <Button size="sm" onClick={() => setNewItemOpen(true)}>
                  <Plus className="h-4 w-4 mr-1" />
                  Novo Item
                </Button>
              </>
            )}
          </div>
        </CardHeader>
        <CardContent className="space-y-4">
          {/* Filter */}
          <div className="flex items-center gap-2">
            <Filter className="h-4 w-4 text-muted-foreground" />
            <Select value={filterCategory} onValueChange={setFilterCategory}>
              <SelectTrigger className="w-[220px]">
                <SelectValue placeholder="Filtrar por categoria" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">Todas as categorias</SelectItem>
                <SelectItem value="none">Sem categoria</SelectItem>
                {categories.map(c => (
                  <SelectItem key={c.id} value={c.id}>{c.nome}</SelectItem>
                ))}
              </SelectContent>
            </Select>
            <span className="text-xs text-muted-foreground">{filteredItems.length} ite{filteredItems.length === 1 ? 'm' : 'ns'}</span>
          </div>

          {loading ? (
            <p className="text-sm text-muted-foreground py-4 text-center">Carregando...</p>
          ) : filteredItems.length === 0 ? (
            <p className="text-sm text-muted-foreground py-4 text-center">Nenhum item encontrado.</p>
          ) : (
            <div className="overflow-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Nome</TableHead>
                    <TableHead>Categoria</TableHead>
                    <TableHead>Un.</TableHead>
                    <TableHead className="text-right">Saldo</TableHead>
                    <TableHead className="text-right">Mínimo</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Ações</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {filteredItems.map((item) => (
                    <TableRow key={item.id}>
                      <TableCell className="font-medium">{item.nome}</TableCell>
                      <TableCell>
                        <Badge variant="outline" className="text-xs font-normal">
                          {item.categoria_nome}
                        </Badge>
                      </TableCell>
                      <TableCell>{item.unidade_medida}</TableCell>
                      <TableCell className="text-right">{item.saldo_atual}</TableCell>
                      <TableCell className="text-right">{item.quantidade_minima}</TableCell>
                      <TableCell>
                        {item.saldo_atual > item.quantidade_minima ? (
                          <Badge className="bg-green-600 text-white hover:bg-green-700">OK</Badge>
                        ) : (
                          <Badge variant="destructive">Baixo</Badge>
                        )}
                      </TableCell>
                      <TableCell>
                        <div className="flex gap-1">
                          {canCreate && (
                            <Button size="sm" variant="ghost" onClick={() => openEdit(item)} title="Editar">
                              <Pencil className="h-3 w-3" />
                            </Button>
                          )}
                          <Button size="sm" variant="outline" onClick={() => openMovement(item)}>
                            <ArrowUpDown className="h-3 w-3 mr-1" />
                            Mov.
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* New Category Dialog */}
      <Dialog open={catOpen} onOpenChange={setCatOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Nova Categoria</DialogTitle>
            <DialogDescription>Crie uma categoria para organizar os itens do estoque.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>Nome *</Label>
              <Input value={catForm.nome} onChange={(e) => setCatForm(p => ({ ...p, nome: e.target.value }))} />
            </div>
            <div className="space-y-2">
              <Label>Descrição</Label>
              <Input value={catForm.descricao} onChange={(e) => setCatForm(p => ({ ...p, descricao: e.target.value }))} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCatOpen(false)}>Cancelar</Button>
            <Button onClick={handleCreateCategory} disabled={saving}>{saving ? 'Salvando...' : 'Salvar'}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* New Item Dialog */}
      <Dialog open={newItemOpen} onOpenChange={setNewItemOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Novo Item de Estoque</DialogTitle>
            <DialogDescription>Cadastre um novo item no almoxarifado.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>Nome *</Label>
              <Input value={newItemForm.nome} onChange={(e) => setNewItemForm(p => ({ ...p, nome: e.target.value }))} />
            </div>
            <div className="space-y-2">
              <Label>Categoria</Label>
              <Select value={newItemForm.categoria_id} onValueChange={(v) => setNewItemForm(p => ({ ...p, categoria_id: v }))}>
                <SelectTrigger><SelectValue placeholder="Selecione uma categoria" /></SelectTrigger>
                <SelectContent>
                  {categories.map(c => <SelectItem key={c.id} value={c.id}>{c.nome}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label>Unidade *</Label>
                <Select value={newItemForm.unidade_medida} onValueChange={(v) => setNewItemForm(p => ({ ...p, unidade_medida: v }))}>
                  <SelectTrigger><SelectValue placeholder="Selecione" /></SelectTrigger>
                  <SelectContent>
                    {UNITS.map(u => <SelectItem key={u} value={u}>{u}</SelectItem>)}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-2">
                <Label>Qtd. mínima *</Label>
                <Input type="number" min="0" value={newItemForm.quantidade_minima} onChange={(e) => setNewItemForm(p => ({ ...p, quantidade_minima: e.target.value }))} />
              </div>
            </div>
            <div className="space-y-2">
              <Label>Descrição</Label>
              <Textarea value={newItemForm.descricao} onChange={(e) => setNewItemForm(p => ({ ...p, descricao: e.target.value }))} placeholder="Detalhes adicionais do item..." />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setNewItemOpen(false)}>Cancelar</Button>
            <Button onClick={handleCreateItem} disabled={saving}>{saving ? 'Salvando...' : 'Salvar'}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Item Dialog */}
      <Dialog open={editOpen} onOpenChange={setEditOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Editar Item: {editItem?.nome}</DialogTitle>
            <DialogDescription>Edite nome, categoria e quantidade mínima. O saldo só pode ser alterado via movimentação.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>Nome *</Label>
              <Input value={editForm.nome} onChange={(e) => setEditForm(p => ({ ...p, nome: e.target.value }))} />
            </div>
            <div className="space-y-2">
              <Label>Categoria</Label>
              <Select value={editForm.categoria_id} onValueChange={(v) => setEditForm(p => ({ ...p, categoria_id: v }))}>
                <SelectTrigger><SelectValue placeholder="Sem categoria" /></SelectTrigger>
                <SelectContent>
                  {categories.map(c => <SelectItem key={c.id} value={c.id}>{c.nome}</SelectItem>)}
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Qtd. mínima</Label>
              <Input type="number" min="0" value={editForm.quantidade_minima} onChange={(e) => setEditForm(p => ({ ...p, quantidade_minima: e.target.value }))} />
            </div>
            <div className="space-y-2">
              <Label>Descrição</Label>
              <Textarea value={editForm.descricao} onChange={(e) => setEditForm(p => ({ ...p, descricao: e.target.value }))} />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setEditOpen(false)}>Cancelar</Button>
            <Button onClick={handleEditItem} disabled={saving}>{saving ? 'Salvando...' : 'Salvar'}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Movement Dialog */}
      <Dialog open={moveOpen} onOpenChange={setMoveOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Movimentar: {moveItem?.nome}</DialogTitle>
            <DialogDescription>Registre uma entrada, saída ou ajuste de estoque.</DialogDescription>
          </DialogHeader>
          <div className="space-y-4 py-2">
            <div className="space-y-2">
              <Label>Tipo *</Label>
              <Select value={moveForm.tipo_movimento} onValueChange={(v) => setMoveForm(p => ({ ...p, tipo_movimento: normalizeStockMoveType(v) }))}>
                <SelectTrigger><SelectValue /></SelectTrigger>
                <SelectContent>
                  <SelectItem value="ENTRADA">Entrada</SelectItem>
                  <SelectItem value="SAIDA">Saída</SelectItem>
                  <SelectItem value="AJUSTE">Ajuste (com justificativa)</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Quantidade *</Label>
              <Input type="number" min="1" value={moveForm.quantidade} onChange={(e) => setMoveForm(p => ({ ...p, quantidade: e.target.value }))} />
            </div>
            {moveForm.tipo_movimento === 'SAIDA' && (
              <div className="space-y-2">
                <Label>Destino</Label>
                <Select value={moveForm.destination} onValueChange={(v) => setMoveForm(p => ({ ...p, destination: v }))}>
                  <SelectTrigger><SelectValue /></SelectTrigger>
                  <SelectContent>
                    <SelectItem value="obra_aberta">Obra aberta</SelectItem>
                    <SelectItem value="em_espera">Em espera</SelectItem>
                    <SelectItem value="almoxarifado">Almoxarifado</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            )}
            <div className="space-y-2">
              <Label>{moveForm.tipo_movimento === 'AJUSTE' ? 'Justificativa *' : 'Observação'}</Label>
              <Textarea
                value={moveForm.notes}
                onChange={(e) => setMoveForm(p => ({ ...p, notes: e.target.value }))}
                placeholder={moveForm.tipo_movimento === 'AJUSTE' ? 'Justificativa obrigatória para ajuste...' : 'Observação opcional...'}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setMoveOpen(false)}>Cancelar</Button>
            <Button onClick={handleMovement} disabled={saving}>{saving ? 'Salvando...' : 'Confirmar'}</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  );
}
