import { useEffect, useState } from 'react';
import { Navigate, useLocation } from 'react-router-dom';
import { apiFetch } from '@/lib/api';
import { useCondo } from '@/contexts/CondoContext';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { AlertTriangle, Clock, Loader2 } from 'lucide-react';
import { Link } from 'react-router-dom';

type SubscriptionStatus = 'trial' | 'active' | 'past_due' | 'canceled' | null;

interface StatusInfo {
  status: SubscriptionStatus;
  expira_em: string | null;
  dias_restantes: number | null;
  assinatura_id: string | null;
  trial_expirado: boolean;
}

interface BillingGuardProps {
  children: React.ReactNode;
}

/**
 * Wraps protected routes and enforces subscription access:
 * - trial (not expired) → full access with countdown banner
 * - active             → full access
 * - past_due           → access with warning banner
 * - trial expired      → redirect to /billing
 * - canceled           → redirect to /billing
 * - unknown/loading    → allow (fail-open to avoid locking out on transient errors)
 */
export function BillingGuard({ children }: BillingGuardProps) {
  const { condoId, loading: condoLoading } = useCondo();
  const location = useLocation();

  const [statusInfo, setStatusInfo] = useState<StatusInfo | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!condoId) {
      setLoading(false);
      return;
    }

    const fetchStatus = async () => {
      setLoading(true);
      try {
        const res = await apiFetch(`/api/assinaturas/status/?condominio_id=${condoId}`);
        const data = await res.json();
        setStatusInfo(data as StatusInfo);
      } catch {
        setStatusInfo(null); // fail-open
      }
      setLoading(false);
    };

    fetchStatus();
  }, [condoId]);

  // Still loading condo or subscription — fail open (don't flash a redirect)
  if (condoLoading || loading) {
    return (
      <div className="flex items-center justify-center py-16">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  // Already on /billing — always allow to avoid redirect loops
  if (location.pathname === '/billing') {
    return <>{children}</>;
  }

  const status = statusInfo?.status ?? null;
  const trialExpirado = statusInfo?.trial_expirado ?? false;

  // Trial expired or Canceled — hard block, redirect to billing
  if (status === 'canceled' || trialExpirado) {
    return <Navigate to="/billing" replace />;
  }

  // Past due — soft warning banner + access
  if (status === 'past_due') {
    return (
      <div className="space-y-4">
        <Alert variant="destructive" className="border-warning/50 bg-warning/10 text-warning [&>svg]:text-warning">
          <AlertTriangle className="h-4 w-4" />
          <AlertTitle className="text-warning">Pagamento pendente</AlertTitle>
          <AlertDescription className="flex items-center justify-between gap-4 flex-wrap">
            <span className="text-warning/80 text-sm">
              Houve uma falha no pagamento da assinatura. Atualize seus dados para evitar a suspensão do acesso.
            </span>
            <Button size="sm" variant="outline" className="border-warning/50 text-warning hover:bg-warning/10 shrink-0" asChild>
              <Link to="/billing">Resolver agora</Link>
            </Button>
          </AlertDescription>
        </Alert>
        {children}
      </div>
    );
  }

  // Trial active — show countdown banner + full access
  if (status === 'trial' && statusInfo?.dias_restantes !== null && statusInfo?.dias_restantes !== undefined) {
    const dias = statusInfo.dias_restantes;
    return (
      <div className="space-y-4">
        <Alert className="border-primary/30 bg-primary/5 [&>svg]:text-primary">
          <Clock className="h-4 w-4" />
          <AlertTitle className="text-primary">Período de teste</AlertTitle>
          <AlertDescription className="flex items-center justify-between gap-4 flex-wrap">
            <span className="text-primary/80 text-sm">
              {dias <= 1
                ? 'Seu período de teste expira hoje. Assine agora para continuar usando.'
                : `Você tem ${dias} dias restantes no período de teste gratuito.`
              }
            </span>
            <Button size="sm" variant="outline" className="border-primary/50 text-primary hover:bg-primary/10 shrink-0" asChild>
              <Link to="/billing">Assinar agora</Link>
            </Button>
          </AlertDescription>
        </Alert>
        {children}
      </div>
    );
  }

  // active / null (fail-open) — full access
  return <>{children}</>;
}
