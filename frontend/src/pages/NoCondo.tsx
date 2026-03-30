import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '@/contexts/AuthContext';
import { useCondo } from '@/contexts/CondoContext';
import { apiFetch } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Building2, Loader2, ShieldAlert } from 'lucide-react';
import { toast } from '@/hooks/use-toast';

export default function NoCondo() {
  const { signOut, user } = useAuth();
  const { refresh } = useCondo();
  const navigate = useNavigate();

  const [isSindico, setIsSindico] = useState<boolean | null>(null);
  const [name, setName] = useState('');
  const [cnpj, setCnpj] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const checkRole = async () => {
      if (!user) return;
      try {
        // Buscar condominios do usuario para verificar se ele e sindico em algum
        const res = await apiFetch('/api/condominios/meus/');
        if (res.ok) {
          const data = await res.json();
          const temCondoComoSindico = Array.isArray(data) && data.some(
            (c: any) => c.papel === 'SINDICO' || c.papel === 'ADMIN'
          );
          setIsSindico(temCondoComoSindico);

          // Se tem condominios, redirecionar para dashboard
          if (Array.isArray(data) && data.length > 0) {
            await refresh();
            navigate('/dashboard', { replace: true });
            return;
          }
        } else {
          setIsSindico(false);
        }
      } catch {
        setIsSindico(false);
      }
    };
    checkRole();
  }, [user]);

  const handleCreate = async () => {
    setSubmitting(true);
    try {
      const res = await apiFetch('/api/condominios/criar/', {
        method: 'POST',
        body: JSON.stringify({
          nome: name.trim(),
          documento: cnpj.trim() || null,
        }),
      });

      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        toast({
          variant: 'destructive',
          title: 'Erro ao criar condominio',
          description: err?.error || 'Tente novamente.',
        });
        setSubmitting(false);
        return;
      }

      await refresh();
      navigate('/dashboard');
    } catch {
      toast({
        variant: 'destructive',
        title: 'Erro ao criar condominio',
        description: 'Tente novamente.',
      });
      setSubmitting(false);
    }
  };

  // Loading check
  if (isSindico === null) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-muted/30">
        <Loader2 className="h-8 w-8 animate-spin text-primary" />
      </div>
    );
  }

  // Non-sindico: show access pending message
  if (!isSindico) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-muted/30 px-4">
        <Card className="w-full max-w-md">
          <CardHeader className="text-center">
            <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-muted">
              <ShieldAlert className="h-6 w-6 text-muted-foreground" />
            </div>
            <CardTitle className="text-xl">Acesso nao liberado</CardTitle>
            <CardDescription>
              Seu acesso ainda nao foi liberado. Aguarde a aprovacao do sindico ou solicite o link de convite.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <Button variant="outline" onClick={signOut} className="w-full">
              Sair
            </Button>
            <Button variant="link" onClick={() => navigate('/')} className="w-full text-muted-foreground">
              Voltar para a pagina inicial
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  // Sindico: can create condo
  return (
    <div className="flex min-h-screen items-center justify-center bg-muted/30 px-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-muted">
            <Building2 className="h-6 w-6 text-muted-foreground" />
          </div>
          <CardTitle className="text-xl">Criar novo condominio</CardTitle>
          <CardDescription>Cadastre um condominio para comecar a usar o NFe Vigia.</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label htmlFor="condo-name">Nome do condominio</Label>
            <Input
              id="condo-name"
              placeholder="Ex: Residencial Flores"
              value={name}
              onChange={(e) => setName(e.target.value)}
              disabled={submitting}
            />
          </div>
          <div className="space-y-2">
            <Label htmlFor="condo-cnpj">CNPJ (opcional)</Label>
            <Input
              id="condo-cnpj"
              placeholder="00.000.000/0000-00"
              value={cnpj}
              onChange={(e) => setCnpj(e.target.value)}
              disabled={submitting}
            />
          </div>
          <Button
            className="w-full"
            disabled={!name.trim() || submitting}
            onClick={handleCreate}
          >
            {submitting && <Loader2 className="animate-spin" />}
            Criar condominio
          </Button>
          <Button variant="outline" onClick={signOut} className="w-full" disabled={submitting}>
            Sair
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
