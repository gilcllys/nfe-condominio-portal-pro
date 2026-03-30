/**
 * Aal2ChallengeDialog - Desabilitado temporariamente.
 * O backend ainda nao suporta MFA/AAL2.
 * Sera re-habilitado quando o backend implementar endpoints de MFA.
 */

interface Aal2ChallengeDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSuccess: () => void;
}

export function Aal2ChallengeDialog({ open, onOpenChange, onSuccess }: Aal2ChallengeDialogProps) {
  // MFA nao suportado no backend — noop
  return null;
}
