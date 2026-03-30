import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { authApi } from '@/lib/api';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { useToast } from '@/hooks/use-toast';
import { NFeVigiaLogo } from '@/components/NFeVigiaLogo';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [forgotOpen, setForgotOpen] = useState(false);
  const [forgotEmail, setForgotEmail] = useState('');
  const [forgotLoading, setForgotLoading] = useState(false);

  const navigate = useNavigate();
  const { toast } = useToast();

  const handleForgotPassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setForgotLoading(true);
    try {
      const result = await authApi.forgotPassword(forgotEmail);
      if (!result.ok) throw new Error('Failed');
      toast({ title: 'E-mail enviado!', description: 'Se este e-mail estiver cadastrado, você receberá um link para redefinir sua senha.' });
      setForgotOpen(false);
      setForgotEmail('');
    } catch {
      toast({ title: 'Erro', description: 'Não foi possível enviar o e-mail. Tente novamente.', variant: 'destructive' });
    } finally {
      setForgotLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      const result = await authApi.login(email, password);
      if (!result.ok) {
        const msg = result.data?.error || result.data?.detail || '';
        let friendly = 'Ocorreu um erro. Tente novamente.';
        if (msg.toLowerCase().includes('credenciais invalidas') || msg.toLowerCase().includes('invalid')) {
          friendly = 'E-mail ou senha incorretos. Verifique seus dados e tente novamente.';
        } else if (msg.toLowerCase().includes('desativada') || msg.toLowerCase().includes('inactive')) {
          friendly = 'Sua conta está desativada. Entre em contato com o síndico.';
        }
        toast({ title: 'Erro', description: friendly, variant: 'destructive' });
        setLoading(false);
        return;
      }

      // Login bem-sucedido — JWT tokens ja foram salvos pelo authApi.login()
      // O CondoContext vai buscar o condominio ativo automaticamente
      localStorage.removeItem('nfe_vigia_active_condo');

      // Forcar reload para que AuthContext detecte os tokens salvos
      window.location.href = '/dashboard';
    } catch (error: any) {
      toast({ title: 'Erro', description: 'Ocorreu um erro. Tente novamente.', variant: 'destructive' });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <Card className="w-full max-w-md glass-card">
        <CardHeader className="text-center space-y-4">
          <div className="flex items-center justify-center">
            <NFeVigiaLogo height={40} />
          </div>
          <CardDescription className="text-muted-foreground">Acesse sua conta</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="email" className="text-foreground">E-mail</Label>
              <Input id="email" type="email" placeholder="seu@email.com" value={email} onChange={(e) => setEmail(e.target.value)} required className="bg-muted/50 border-border focus:border-primary" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="password" className="text-foreground">Senha</Label>
              <Input id="password" type="password" placeholder="••••••••" value={password} onChange={(e) => setPassword(e.target.value)} required minLength={6} className="bg-muted/50 border-border focus:border-primary" />
            </div>
            <Button type="submit" className="w-full bg-primary hover:bg-primary/90 text-primary-foreground font-semibold" disabled={loading || !email.trim() || !password || password.length < 6}>
              {loading ? 'Aguarde...' : 'Entrar'}
            </Button>
          </form>
          <div className="mt-3 text-center">
            <button type="button" onClick={() => setForgotOpen(true)} className="text-sm text-muted-foreground underline-offset-4 hover:underline hover:text-primary">
              Esqueci minha senha
            </button>
          </div>
          <div className="mt-4 text-center">
            <button
              type="button"
              onClick={() => navigate('/onboarding')}
              className="text-sm font-medium text-primary underline-offset-4 hover:underline"
            >
              Criar conta
            </button>
          </div>
        </CardContent>
      </Card>

      {/* Forgot password dialog */}
      <Dialog open={forgotOpen} onOpenChange={setForgotOpen}>
        <DialogContent className="glass-card">
          <DialogHeader>
            <DialogTitle>Recuperar senha</DialogTitle>
            <DialogDescription>Informe seu e-mail para receber o link de redefinição de senha.</DialogDescription>
          </DialogHeader>
          <form onSubmit={handleForgotPassword} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="forgot-email">E-mail</Label>
              <Input id="forgot-email" type="email" placeholder="seu@email.com" value={forgotEmail} onChange={(e) => setForgotEmail(e.target.value)} required className="bg-muted/50 border-border" />
            </div>
            <Button type="submit" className="w-full bg-primary hover:bg-primary/90" disabled={forgotLoading}>
              {forgotLoading ? 'Enviando...' : 'Enviar link de recuperação'}
            </Button>
          </form>
        </DialogContent>
      </Dialog>
    </div>
  );
}
