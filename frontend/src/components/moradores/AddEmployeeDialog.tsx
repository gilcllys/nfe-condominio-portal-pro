import { useState } from 'react';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription, DialogFooter } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { apiFetch, authApi } from '@/lib/api';
import { useToast } from '@/hooks/use-toast';
import { logActivity } from '@/lib/activity-log';

interface AddEmployeeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  condoId: string;
  onSaved: () => void;
}

interface EmployeeForm {
  primeiro_nome: string;
  sobrenome: string;
  email: string;
  password: string;
  telefone: string;
}

const emptyForm: EmployeeForm = { primeiro_nome: '', sobrenome: '', email: '', password: '', telefone: '' };

export default function AddEmployeeDialog({ open, onOpenChange, condoId, onSaved }: AddEmployeeDialogProps) {
  const { toast } = useToast();
  const [form, setForm] = useState<EmployeeForm>(emptyForm);
  const [saving, setSaving] = useState(false);

  const updateField = (field: keyof EmployeeForm, value: string) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSave = async () => {
    if (!form.primeiro_nome.trim() || !form.email.trim() || !form.password.trim()) {
      toast({ title: 'Nome, email e senha são obrigatórios', variant: 'destructive' });
      return;
    }
    if (form.password.length < 6) {
      toast({ title: 'A senha deve ter no mínimo 6 caracteres', variant: 'destructive' });
      return;
    }

    setSaving(true);

    try {
      // 1. Create user + member via /api/auth/cadastro/
      // This endpoint creates the user, membro_condominio (MORADOR/PENDENTE), and morador
      const signUpResult = await authApi.signUp({
        email: form.email.trim(),
        senha: form.password.trim(),
        primeiro_nome: form.primeiro_nome.trim(),
        sobrenome: form.sobrenome.trim() || form.primeiro_nome.trim(),
        telefone: form.telefone.trim() || null,
        condominio_id: condoId,
      });

      if (!signUpResult.ok) {
        const errMsg = signUpResult.data?.message || signUpResult.data?.error || 'Erro desconhecido';
        toast({ title: 'Erro ao criar conta', description: errMsg, variant: 'destructive' });
        setSaving(false);
        return;
      }

      const userId = signUpResult.data?.usuario?.id;
      if (!userId) {
        toast({ title: 'Erro inesperado: ID do usuário não retornado', variant: 'destructive' });
        setSaving(false);
        return;
      }

      // 2. Update member role to ZELADOR and approve
      await apiFetch('/api/membros/aprovar/', {
        method: 'POST',
        body: JSON.stringify({
          usuario_id: userId,
          condominio_id: condoId,
        }),
      });

      await logActivity({
        condoId,
        action: 'create',
        entity: 'user',
        entityId: userId,
        description: `Funcionário "${form.primeiro_nome.trim()}" adicionado como Zelador`,
      });

      toast({ title: 'Funcionário adicionado com sucesso' });
      setForm(emptyForm);
      onSaved();
      onOpenChange(false);
    } catch (err: any) {
      toast({ title: 'Erro ao adicionar funcionário', description: err.message || 'Tente novamente.', variant: 'destructive' });
    }
    setSaving(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-md">
        <DialogHeader>
          <DialogTitle>Adicionar Funcionário</DialogTitle>
          <DialogDescription>
            O funcionário será criado com o papel de <strong>Zelador</strong>.
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4 py-2">
          <div className="space-y-2">
            <Label htmlFor="emp_name">Primeiro nome *</Label>
            <Input id="emp_name" value={form.primeiro_nome} onChange={(e) => updateField('primeiro_nome', e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="emp_sobrenome">Sobrenome *</Label>
            <Input id="emp_sobrenome" value={form.sobrenome} onChange={(e) => updateField('sobrenome', e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="emp_email">Email *</Label>
            <Input id="emp_email" type="email" value={form.email} onChange={(e) => updateField('email', e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="emp_password">Senha *</Label>
            <Input id="emp_password" type="password" value={form.password} onChange={(e) => updateField('password', e.target.value)} />
          </div>
          <div className="space-y-2">
            <Label htmlFor="emp_phone">Telefone</Label>
            <Input id="emp_phone" value={form.telefone} onChange={(e) => updateField('telefone', e.target.value)} />
          </div>
        </div>
        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>Cancelar</Button>
          <Button onClick={handleSave} disabled={saving}>
            {saving ? 'Salvando...' : 'Adicionar'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
