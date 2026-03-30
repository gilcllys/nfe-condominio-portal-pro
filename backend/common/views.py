from rest_framework.response import Response
from rest_framework import status


class CondominioViewMixin:
    """
    Mixin para views que precisam extrair condominio_id do request.
    Filtra automaticamente o queryset pelo condominio do usuario.
    Injeta condominio_id no perform_create para garantir que o campo
    seja preenchido ao criar novos registros.
    """

    def get_condominio_id(self):
        """Extrai condominio_id do query_params ou body."""
        request = self.request
        return (
            request.query_params.get("condominio_id")
            or request.data.get("condominio_id")
        )

    def get_queryset(self):
        qs = super().get_queryset()
        condominio_id = self.get_condominio_id()
        if condominio_id:
            return qs.filter(condominio_id=condominio_id)
        return qs.none()

    def perform_create(self, serializer):
        extra = {}
        condominio_id = self.get_condominio_id()
        if condominio_id:
            extra["condominio_id"] = condominio_id
        serializer.save(**extra)
