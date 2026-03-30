import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { NFeVigiaLogo } from '@/components/NFeVigiaLogo';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { useToast } from '@/hooks/use-toast';
import { setStoredTokens } from '@/lib/api';
import {
  Building2,
  User,
  ArrowLeft,
  ArrowRight,
  Loader2,
  Check,
  Eye,
  EyeOff,
} from 'lucide-react';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL as string || 'http://localhost:8000';

const ESTADOS_BR = [
  'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA',
  'PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO',
];

export default function Onboarding() {
  const navigate = useNavigate();
  const { toast } = useToast();

  // Step control
  const [step, setStep] = useState<1 | 2>(1);

  // Step 1 — Condominio
  const [condoNome, setCondoNome] = useState('');
  const [condoDocumento, setCondoDocumento] = useState('');
  const [condoEndereco, setCondoEndereco] = useState('');
  const [condoCidade, setCondoCidade] = useState('');
  const [condoEstado, setCondoEstado] = useState('');
  const [condoCep, setCondoCep] = useState('');

  // Step 2 — Sindico (usuario)
  const [primeiroNome, setPrimeiroNome] = useState('');
  const [sobrenome, setSobrenome] = useState('');
  const [email, setEmail] = useState('');
  const [telefone, setTelefone] = useState('');
  const [cpf, setCpf] = useState('');
  const [senha, setSenha] = useState('');
  const [confirmarSenha, setConfirmarSenha] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);

  const [submitting, setSubmitting] = useState(false);

  const canAdvance = condoNome.trim().length >= 2;
  const senhasIguais = senha === confirmarSenha;
  const senhaValida = senha.length >= 8;
  const canSubmit =
    primeiroNome.trim() &&
    sobrenome.trim() &&
    email.trim() &&
    senhaValida &&
    senhasIguais;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!canSubmit) return;

    setSubmitting(true);
    try {
      const res = await fetch(`${API_BASE_URL}/api/auth/onboarding/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          // Sindico
          email: email.trim().toLowerCase(),
          senha,
          primeiro_nome: primeiroNome.trim(),
          sobrenome: sobrenome.trim(),
          cpf: cpf.trim() || null,
          telefone: telefone.trim() || null,
          // Condominio
          condominio_nome: condoNome.trim(),
          condominio_documento: condoDocumento.trim() || null,
          condominio_endereco: condoEndereco.trim() || null,
          condominio_cidade: condoCidade.trim() || null,
          condominio_estado: condoEstado || null,
          condominio_cep: condoCep.trim() || null,
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        const msg = data?.error || data?.detail || 'Erro ao criar conta. Tente novamente.';
        if (res.status === 409) {
          toast({
            variant: 'destructive',
            title: 'Email ja cadastrado',
            description: 'Ja existe uma conta com este email. Faca login ou use outro email.',
          });
          setStep(2);
        } else {
          toast({ variant: 'destructive', title: 'Erro', description: msg });
        }
        return;
      }

      // Sucesso — salvar tokens e redirecionar
      if (data.access) {
        setStoredTokens({
          access: data.access,
          refresh: data.refresh,
          user: data.usuario,
        });
      }

      toast({
        title: 'Conta criada com sucesso!',
        description: `Bem-vindo ao NFe Vigia, ${data.usuario?.nome_completo || primeiroNome}!`,
      });

      // Limpar condo cache para que CondoContext busque o novo
      localStorage.removeItem('nfe_vigia_active_condo');
      navigate('/dashboard', { replace: true });
    } catch (err) {
      toast({
        variant: 'destructive',
        title: 'Erro de conexao',
        description: 'Nao foi possivel conectar ao servidor. Verifique sua internet e tente novamente.',
      });
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4 py-12">
      {/* Background grid */}
      <div className="fixed inset-0 enterprise-grid opacity-20 pointer-events-none" />

      <div className="relative w-full max-w-lg">
        {/* Logo */}
        <div className="mb-8 flex justify-center">
          <button onClick={() => navigate('/')} className="cursor-pointer">
            <NFeVigiaLogo height={36} />
          </button>
        </div>

        {/* Step indicator */}
        <div className="mb-6 flex items-center justify-center gap-3">
          <div className="flex items-center gap-2">
            <div
              className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold transition-colors ${
                step === 1
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-primary/20 text-primary'
              }`}
            >
              {step > 1 ? <Check className="h-4 w-4" /> : '1'}
            </div>
            <span className={`text-sm font-medium ${step === 1 ? 'text-foreground' : 'text-muted-foreground'}`}>
              Condominio
            </span>
          </div>
          <div className="h-px w-8 bg-border" />
          <div className="flex items-center gap-2">
            <div
              className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-semibold transition-colors ${
                step === 2
                  ? 'bg-primary text-primary-foreground'
                  : 'bg-muted text-muted-foreground'
              }`}
            >
              2
            </div>
            <span className={`text-sm font-medium ${step === 2 ? 'text-foreground' : 'text-muted-foreground'}`}>
              Sindico
            </span>
          </div>
        </div>

        {/* Step 1 — Condominio */}
        {step === 1 && (
          <Card className="glass-card">
            <CardHeader className="text-center">
              <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
                <Building2 className="h-6 w-6 text-primary" />
              </div>
              <CardTitle className="text-xl">Dados do condominio</CardTitle>
              <CardDescription>
                Informe os dados do condominio que voce administra
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="condo-nome">Nome do condominio *</Label>
                <Input
                  id="condo-nome"
                  placeholder="Ex: Residencial Flores"
                  value={condoNome}
                  onChange={(e) => setCondoNome(e.target.value)}
                  className="bg-muted/50 border-border focus:border-primary"
                  autoFocus
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="condo-doc">CNPJ <Badge variant="secondary" className="ml-1 text-[10px]">Opcional</Badge></Label>
                <Input
                  id="condo-doc"
                  placeholder="00.000.000/0000-00"
                  value={condoDocumento}
                  onChange={(e) => setCondoDocumento(e.target.value)}
                  className="bg-muted/50 border-border focus:border-primary"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="condo-end">Endereco <Badge variant="secondary" className="ml-1 text-[10px]">Opcional</Badge></Label>
                <Input
                  id="condo-end"
                  placeholder="Rua, numero, bairro"
                  value={condoEndereco}
                  onChange={(e) => setCondoEndereco(e.target.value)}
                  className="bg-muted/50 border-border focus:border-primary"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-2">
                  <Label htmlFor="condo-cidade">Cidade</Label>
                  <Input
                    id="condo-cidade"
                    placeholder="Cidade"
                    value={condoCidade}
                    onChange={(e) => setCondoCidade(e.target.value)}
                    className="bg-muted/50 border-border focus:border-primary"
                  />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="condo-estado">Estado</Label>
                  <select
                    id="condo-estado"
                    value={condoEstado}
                    onChange={(e) => setCondoEstado(e.target.value)}
                    className="flex h-10 w-full rounded-md border border-border bg-muted/50 px-3 py-2 text-sm text-foreground focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary"
                  >
                    <option value="">UF</option>
                    {ESTADOS_BR.map((uf) => (
                      <option key={uf} value={uf}>{uf}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="condo-cep">CEP</Label>
                <Input
                  id="condo-cep"
                  placeholder="00000-000"
                  value={condoCep}
                  onChange={(e) => setCondoCep(e.target.value)}
                  maxLength={10}
                  className="bg-muted/50 border-border focus:border-primary"
                />
              </div>

              <div className="flex gap-3 pt-2">
                <Button
                  variant="outline"
                  className="flex-1"
                  onClick={() => navigate('/')}
                >
                  <ArrowLeft className="mr-2 h-4 w-4" />
                  Voltar
                </Button>
                <Button
                  className="flex-1 btn-primary-gradient"
                  disabled={!canAdvance}
                  onClick={() => setStep(2)}
                >
                  Proximo
                  <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Step 2 — Sindico */}
        {step === 2 && (
          <Card className="glass-card">
            <CardHeader className="text-center">
              <div className="mx-auto mb-2 flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
                <User className="h-6 w-6 text-primary" />
              </div>
              <CardTitle className="text-xl">Dados do sindico</CardTitle>
              <CardDescription>
                Crie sua conta de administrador
              </CardDescription>
            </CardHeader>
            <CardContent>
              <form onSubmit={handleSubmit} className="space-y-4">
                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <Label htmlFor="primeiro-nome">Nome *</Label>
                    <Input
                      id="primeiro-nome"
                      placeholder="Nome"
                      value={primeiroNome}
                      onChange={(e) => setPrimeiroNome(e.target.value)}
                      required
                      className="bg-muted/50 border-border focus:border-primary"
                      autoFocus
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="sobrenome">Sobrenome *</Label>
                    <Input
                      id="sobrenome"
                      placeholder="Sobrenome"
                      value={sobrenome}
                      onChange={(e) => setSobrenome(e.target.value)}
                      required
                      className="bg-muted/50 border-border focus:border-primary"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="email">E-mail *</Label>
                  <Input
                    id="email"
                    type="email"
                    placeholder="seu@email.com"
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    required
                    className="bg-muted/50 border-border focus:border-primary"
                  />
                </div>

                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-2">
                    <Label htmlFor="telefone">Telefone <Badge variant="secondary" className="ml-1 text-[10px]">Opcional</Badge></Label>
                    <Input
                      id="telefone"
                      placeholder="(11) 99999-9999"
                      value={telefone}
                      onChange={(e) => setTelefone(e.target.value)}
                      className="bg-muted/50 border-border focus:border-primary"
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="cpf">CPF <Badge variant="secondary" className="ml-1 text-[10px]">Opcional</Badge></Label>
                    <Input
                      id="cpf"
                      placeholder="000.000.000-00"
                      value={cpf}
                      onChange={(e) => setCpf(e.target.value)}
                      className="bg-muted/50 border-border focus:border-primary"
                    />
                  </div>
                </div>

                <div className="space-y-2">
                  <Label htmlFor="senha">Senha *</Label>
                  <div className="relative">
                    <Input
                      id="senha"
                      type={showPassword ? 'text' : 'password'}
                      placeholder="Minimo 8 caracteres"
                      value={senha}
                      onChange={(e) => setSenha(e.target.value)}
                      required
                      minLength={8}
                      className="bg-muted/50 border-border focus:border-primary pr-10"
                    />
                    <button
                      type="button"
                      onClick={() => setShowPassword(!showPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                    >
                      {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </button>
                  </div>
                  {senha && !senhaValida && (
                    <p className="text-xs text-destructive">A senha deve ter pelo menos 8 caracteres</p>
                  )}
                </div>

                <div className="space-y-2">
                  <Label htmlFor="confirmar-senha">Confirmar senha *</Label>
                  <div className="relative">
                    <Input
                      id="confirmar-senha"
                      type={showConfirmPassword ? 'text' : 'password'}
                      placeholder="Repita a senha"
                      value={confirmarSenha}
                      onChange={(e) => setConfirmarSenha(e.target.value)}
                      required
                      className="bg-muted/50 border-border focus:border-primary pr-10"
                    />
                    <button
                      type="button"
                      onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                      className="absolute right-3 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground"
                    >
                      {showConfirmPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                    </button>
                  </div>
                  {confirmarSenha && !senhasIguais && (
                    <p className="text-xs text-destructive">As senhas nao coincidem</p>
                  )}
                </div>

                <div className="flex gap-3 pt-2">
                  <Button
                    type="button"
                    variant="outline"
                    className="flex-1"
                    onClick={() => setStep(1)}
                    disabled={submitting}
                  >
                    <ArrowLeft className="mr-2 h-4 w-4" />
                    Voltar
                  </Button>
                  <Button
                    type="submit"
                    className="flex-1 btn-primary-gradient"
                    disabled={!canSubmit || submitting}
                  >
                    {submitting ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Criando...
                      </>
                    ) : (
                      <>
                        Criar conta
                        <ArrowRight className="ml-2 h-4 w-4" />
                      </>
                    )}
                  </Button>
                </div>

                <p className="text-center text-sm text-muted-foreground">
                  Ja tem conta?{' '}
                  <button
                    type="button"
                    onClick={() => navigate('/login')}
                    className="text-primary hover:underline font-medium"
                  >
                    Faca login
                  </button>
                </p>
              </form>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}
