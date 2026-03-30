import { useNavigate } from 'react-router-dom';
import { NFeVigiaLogo } from '@/components/NFeVigiaLogo';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  ClipboardList,
  FileText,
  Sparkles,
  CheckCircle2,
  Package,
  Users,
  ShieldAlert,
  FileSignature,
  Eye,
  BarChart3,
  ArrowRight,
  Zap,
  Brain,
  ScanSearch,
  Check,
  Building2,
} from 'lucide-react';

const features = [
  {
    icon: ClipboardList,
    title: 'Ordens de Servico',
    description: 'Gerencie manutencoes e reparos com fluxo completo de abertura, acompanhamento e finalizacao.',
  },
  {
    icon: FileText,
    title: 'Notas Fiscais com IA',
    description: 'Leitura automatica de NFs via OCR inteligente com Claude AI. Dados extraidos em segundos.',
    highlight: true,
  },
  {
    icon: CheckCircle2,
    title: 'Aprovacoes Multi-nivel',
    description: 'Fluxo de aprovacao configuravel com alcadas por valor. Transparencia total nas decisoes.',
  },
  {
    icon: Package,
    title: 'Almoxarifado',
    description: 'Controle de estoque de materiais com entradas, saidas e alertas de reposicao.',
  },
  {
    icon: Users,
    title: 'Prestadores & Risco IA',
    description: 'Cadastro de fornecedores com analise de risco automatica via inteligencia artificial.',
    highlight: true,
  },
  {
    icon: FileSignature,
    title: 'Contratos',
    description: 'Gestao completa de contratos com alertas de vencimento e renovacao automatica.',
  },
  {
    icon: Eye,
    title: 'Portal de Transparencia',
    description: 'Acesso publico a documentos e prestacao de contas do condominio.',
  },
  {
    icon: BarChart3,
    title: 'Dashboard em Tempo Real',
    description: 'Visao consolidada de todas as operacoes com graficos e indicadores atualizados.',
  },
];

const PRECO_MENSAL = 356;
const DESCONTO_ANUAL = 0.10;
const PRECO_ANUAL_TOTAL = PRECO_MENSAL * 12 * (1 - DESCONTO_ANUAL);
const PRECO_ANUAL_MES = PRECO_ANUAL_TOTAL / 12;

export default function LandingPage() {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-background text-foreground">
      {/* ── Navbar ─────────────────────────────────────────────────────────── */}
      <nav className="fixed top-0 left-0 right-0 z-50 border-b border-border/50 bg-background/80 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
          <NFeVigiaLogo height={32} />
          <div className="flex items-center gap-3">
            <Button
              variant="ghost"
              className="text-muted-foreground hover:text-foreground"
              onClick={() => navigate('/login')}
            >
              Entrar
            </Button>
            <Button
              className="btn-primary-gradient"
              onClick={() => navigate('/onboarding')}
            >
              Comecar gratis
            </Button>
          </div>
        </div>
      </nav>

      {/* ── Hero ──────────────────────────────────────────────────────────── */}
      <section className="relative overflow-hidden pt-32 pb-20 sm:pt-40 sm:pb-28">
        {/* Background grid */}
        <div className="absolute inset-0 enterprise-grid opacity-40" />
        {/* Glow */}
        <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] rounded-full bg-primary/8 blur-[128px]" />

        <div className="relative mx-auto max-w-4xl px-4 text-center sm:px-6">
          <Badge className="mb-6 border-primary/30 bg-primary/10 text-primary">
            <Zap className="mr-1 h-3 w-3" />
            Plataforma SaaS para condominios
          </Badge>

          <h1 className="text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
            Gestao condominial{' '}
            <span className="bg-gradient-to-r from-primary to-sky-400 bg-clip-text text-transparent">
              inteligente
            </span>
          </h1>

          <p className="mx-auto mt-6 max-w-2xl text-lg text-muted-foreground sm:text-xl">
            Automatize a administracao do seu condominio com inteligencia artificial.
            Notas fiscais, ordens de servico, aprovacoes e transparencia — tudo em um so lugar.
          </p>

          <div className="mt-10 flex flex-col items-center gap-4 sm:flex-row sm:justify-center">
            <Button
              size="lg"
              className="btn-primary-gradient px-8 text-base gap-2"
              onClick={() => navigate('/onboarding')}
            >
              Comece gratuitamente
              <ArrowRight className="h-4 w-4" />
            </Button>
            <Button
              size="lg"
              variant="outline"
              className="px-8 text-base border-border/60 hover:border-primary/40"
              onClick={() => {
                document.getElementById('funcionalidades')?.scrollIntoView({ behavior: 'smooth' });
              }}
            >
              Saiba mais
            </Button>
          </div>
        </div>
      </section>

      {/* ── Funcionalidades ───────────────────────────────────────────────── */}
      <section id="funcionalidades" className="relative py-20 sm:py-28">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <Badge className="mb-4 border-primary/30 bg-primary/10 text-primary">Funcionalidades</Badge>
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Tudo que seu condominio precisa
            </h2>
            <p className="mx-auto mt-4 max-w-2xl text-muted-foreground">
              Uma plataforma completa para administrar o condominio de forma profissional, transparente e eficiente.
            </p>
          </div>

          <div className="mt-16 grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
            {features.map((feature) => {
              const Icon = feature.icon;
              return (
                <div
                  key={feature.title}
                  className={`group relative rounded-xl border p-6 transition-all hover:border-primary/40 hover:shadow-lg hover:shadow-primary/5 ${
                    feature.highlight
                      ? 'border-primary/20 bg-primary/5'
                      : 'border-border/60 bg-card/60'
                  }`}
                >
                  {feature.highlight && (
                    <div className="absolute -top-2 right-4">
                      <Badge className="bg-primary/20 text-primary border-primary/30 text-[10px]">
                        <Sparkles className="mr-1 h-2.5 w-2.5" />
                        IA
                      </Badge>
                    </div>
                  )}
                  <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-lg bg-primary/10 text-primary group-hover:bg-primary/20 transition-colors">
                    <Icon className="h-5 w-5" />
                  </div>
                  <h3 className="font-semibold text-foreground">{feature.title}</h3>
                  <p className="mt-2 text-sm text-muted-foreground leading-relaxed">{feature.description}</p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* ── Diferenciais IA ───────────────────────────────────────────────── */}
      <section className="relative py-20 sm:py-28 overflow-hidden">
        <div className="absolute inset-0 bg-gradient-to-b from-primary/3 to-transparent" />
        <div className="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <Badge className="mb-4 border-primary/30 bg-primary/10 text-primary">
              <Brain className="mr-1 h-3 w-3" />
              Inteligencia Artificial
            </Badge>
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Tecnologia de ponta na gestao condominial
            </h2>
            <p className="mx-auto mt-4 max-w-2xl text-muted-foreground">
              Utilizamos Claude AI da Anthropic para automatizar processos e trazer insights que economizam tempo e dinheiro.
            </p>
          </div>

          <div className="mt-16 grid gap-8 md:grid-cols-2">
            {/* Card OCR */}
            <div className="rounded-xl border border-primary/20 bg-card/80 p-8 backdrop-blur-sm">
              <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10">
                <ScanSearch className="h-6 w-6 text-primary" />
              </div>
              <h3 className="text-xl font-semibold">OCR Inteligente de Notas Fiscais</h3>
              <p className="mt-3 text-muted-foreground leading-relaxed">
                Envie a foto ou PDF da nota fiscal e nossa IA extrai automaticamente todos os dados:
                fornecedor, valores, CNPJ, descricao dos servicos, impostos e mais. Sem digitacao manual.
              </p>
              <ul className="mt-4 space-y-2">
                {['Leitura de PDF e imagens', 'Extracao de campos automatica', 'Validacao cruzada de dados'].map((item) => (
                  <li key={item} className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Check className="h-4 w-4 text-primary shrink-0" />
                    {item}
                  </li>
                ))}
              </ul>
            </div>

            {/* Card Risco */}
            <div className="rounded-xl border border-primary/20 bg-card/80 p-8 backdrop-blur-sm">
              <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-xl bg-primary/10">
                <ShieldAlert className="h-6 w-6 text-primary" />
              </div>
              <h3 className="text-xl font-semibold">Analise de Risco de Fornecedores</h3>
              <p className="mt-3 text-muted-foreground leading-relaxed">
                A IA avalia automaticamente o risco de cada prestador com base em historico de servicos,
                documentacao, reclamacoes e indicadores financeiros. Tome decisoes mais seguras.
              </p>
              <ul className="mt-4 space-y-2">
                {['Score de risco automatico', 'Alertas de irregularidades', 'Historico de avaliacoes'].map((item) => (
                  <li key={item} className="flex items-center gap-2 text-sm text-muted-foreground">
                    <Check className="h-4 w-4 text-primary shrink-0" />
                    {item}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* ── Precos ────────────────────────────────────────────────────────── */}
      <section id="precos" className="relative py-20 sm:py-28">
        <div className="mx-auto max-w-5xl px-4 sm:px-6 lg:px-8">
          <div className="text-center">
            <Badge className="mb-4 border-primary/30 bg-primary/10 text-primary">Planos</Badge>
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Simples e transparente
            </h2>
            <p className="mx-auto mt-4 max-w-2xl text-muted-foreground">
              Um unico plano completo com todas as funcionalidades. Sem surpresas, sem taxas extras.
            </p>
          </div>

          <div className="mt-16 grid gap-8 md:grid-cols-2">
            {/* Plano Mensal */}
            <div className="relative rounded-xl border border-border/60 bg-card/60 p-8 transition-all hover:border-border">
              <h3 className="text-lg font-semibold text-foreground">Mensal</h3>
              <p className="mt-1 text-sm text-muted-foreground">Flexibilidade sem compromisso</p>
              <div className="mt-6">
                <span className="text-4xl font-bold text-foreground">
                  R$ {PRECO_MENSAL.toLocaleString('pt-BR')}
                </span>
                <span className="text-muted-foreground">/mes</span>
              </div>
              <ul className="mt-8 space-y-3">
                {[
                  'Todas as funcionalidades',
                  'IA para notas fiscais',
                  'Analise de risco IA',
                  'Suporte por email',
                  'Atualizacoes automaticas',
                ].map((item) => (
                  <li key={item} className="flex items-center gap-3 text-sm text-muted-foreground">
                    <Check className="h-4 w-4 text-primary shrink-0" />
                    {item}
                  </li>
                ))}
              </ul>
              <Button
                className="mt-8 w-full border-border/60 hover:border-primary/40"
                variant="outline"
                size="lg"
                onClick={() => navigate('/onboarding')}
              >
                Comecar agora
              </Button>
            </div>

            {/* Plano Anual */}
            <div className="relative rounded-xl border-2 border-primary/40 bg-card/80 p-8 shadow-lg shadow-primary/5">
              <div className="absolute -top-3 right-6">
                <Badge className="bg-primary text-primary-foreground border-0 px-3 py-1 font-semibold">
                  Economia de 10%
                </Badge>
              </div>
              <h3 className="text-lg font-semibold text-foreground">Anual</h3>
              <p className="mt-1 text-sm text-muted-foreground">Melhor custo-beneficio</p>
              <div className="mt-6">
                <span className="text-4xl font-bold text-foreground">
                  R$ {PRECO_ANUAL_MES.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
                <span className="text-muted-foreground">/mes</span>
              </div>
              <p className="mt-1 text-sm text-muted-foreground">
                R$ {PRECO_ANUAL_TOTAL.toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} cobrados anualmente
              </p>
              <ul className="mt-8 space-y-3">
                {[
                  'Todas as funcionalidades',
                  'IA para notas fiscais',
                  'Analise de risco IA',
                  'Suporte prioritario',
                  'Atualizacoes automaticas',
                ].map((item) => (
                  <li key={item} className="flex items-center gap-3 text-sm text-muted-foreground">
                    <Check className="h-4 w-4 text-primary shrink-0" />
                    {item}
                  </li>
                ))}
              </ul>
              <Button
                className="mt-8 w-full btn-primary-gradient"
                size="lg"
                onClick={() => navigate('/onboarding')}
              >
                Comecar agora
                <ArrowRight className="ml-2 h-4 w-4" />
              </Button>
            </div>
          </div>
        </div>
      </section>

      {/* ── CTA Final ─────────────────────────────────────────────────────── */}
      <section className="relative py-20 sm:py-28">
        <div className="absolute inset-0 bg-gradient-to-t from-primary/5 to-transparent" />
        <div className="relative mx-auto max-w-3xl px-4 text-center sm:px-6">
          <div className="rounded-2xl border border-primary/20 bg-card/60 p-12 backdrop-blur-sm">
            <Building2 className="mx-auto h-12 w-12 text-primary/60 mb-6" />
            <h2 className="text-3xl font-bold tracking-tight sm:text-4xl">
              Pronto para modernizar seu condominio?
            </h2>
            <p className="mt-4 text-lg text-muted-foreground">
              Cadastre-se em minutos e comece a usar hoje. Sem cartao de credito, sem burocracia.
            </p>
            <Button
              size="lg"
              className="mt-8 btn-primary-gradient px-10 text-base gap-2"
              onClick={() => navigate('/onboarding')}
            >
              Criar minha conta
              <ArrowRight className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </section>

      {/* ── Footer ────────────────────────────────────────────────────────── */}
      <footer className="border-t border-border/50 py-8">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div className="flex flex-col items-center justify-between gap-4 sm:flex-row">
            <NFeVigiaLogo height={24} />
            <p className="text-sm text-muted-foreground">
              &copy; {new Date().getFullYear()} NFe Vigia. Todos os direitos reservados.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
}
