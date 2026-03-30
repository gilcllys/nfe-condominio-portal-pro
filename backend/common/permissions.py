from rest_framework.permissions import BasePermission


class EhMembroCondominio(BasePermission):
    """Verifica se o usuario autenticado e membro ativo do condominio."""

    def has_permission(self, request, view):
        from condominios.models import MembroCondominio

        user = request.user
        if not user or not user.is_authenticated:
            return False

        condominio_id = (
            request.data.get("condominio_id")
            or request.query_params.get("condominio_id")
        )
        if not condominio_id:
            return False

        return MembroCondominio.objects.filter(
            usuario=user,
            condominio_id=condominio_id,
            status=MembroCondominio.Status.ATIVO,
        ).exists()


class EhAdminCondominio(BasePermission):
    """Verifica se o usuario e ADMIN ou SINDICO do condominio."""

    def has_permission(self, request, view):
        from condominios.models import MembroCondominio

        user = request.user
        if not user or not user.is_authenticated:
            return False

        condominio_id = (
            request.data.get("condominio_id")
            or request.query_params.get("condominio_id")
        )
        if not condominio_id:
            return False

        return MembroCondominio.objects.filter(
            usuario=user,
            condominio_id=condominio_id,
            papel__in=[MembroCondominio.Papel.ADMIN, MembroCondominio.Papel.SINDICO],
            status=MembroCondominio.Status.ATIVO,
        ).exists()
