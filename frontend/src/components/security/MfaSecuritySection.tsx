import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Shield } from 'lucide-react';

/**
 * MFA Security Section - Desabilitado temporariamente.
 * O backend ainda nao suporta MFA. Sera re-habilitado quando o backend implementar
 * endpoints de MFA (enroll, challenge, verify, unenroll).
 */
export function MfaSecuritySection() {
  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Shield className="h-5 w-5 text-muted-foreground" />
            <CardTitle className="text-lg">Autenticação em 2 fatores (MFA)</CardTitle>
          </div>
          <Badge variant="secondary">Em breve</Badge>
        </div>
        <CardDescription>
          A autenticação em dois fatores adiciona uma camada extra de segurança à sua conta.
          Este recurso estará disponível em breve.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <p className="text-sm text-muted-foreground">
          Quando disponível, você poderá configurar um aplicativo autenticador (como Google Authenticator ou Authy)
          para gerar códigos de verificação no login.
        </p>
      </CardContent>
    </Card>
  );
}
