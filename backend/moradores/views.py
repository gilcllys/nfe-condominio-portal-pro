from rest_framework import mixins, status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from common.views import CondominioViewMixin
from condominios.models import MembroCondominio
from moradores.models import Morador, Unidade
from moradores.serializers import MoradorSerializer, UnidadeSerializer


class MoradorViewSet(CondominioViewMixin, viewsets.ModelViewSet):
    serializer_class = MoradorSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Morador.objects.none()
        qs = Morador.objects.filter(condominio_id=condominio_id)
        email = self.request.query_params.get("email")
        if email:
            qs = qs.filter(email__iexact=email)
        return qs.order_by("nome_completo")

    def list(self, request, *args, **kwargs):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Response([])

        moradores = self.get_queryset()
        resultado = []
        for m in moradores:
            linha = MoradorSerializer(m).data
            # Tentar match com usuario por email
            linha["usuario_vinculado_id"] = None
            linha["usuario_vinculado_email"] = None
            linha["papel_vinculado"] = None
            if m.email:
                membro = (
                    MembroCondominio.objects.filter(
                        condominio_id=condominio_id,
                        usuario__email__iexact=m.email,
                    )
                    .select_related("usuario")
                    .first()
                )
                if membro:
                    linha["usuario_vinculado_id"] = str(membro.usuario_id)
                    linha["usuario_vinculado_email"] = membro.usuario.email
                    linha["papel_vinculado"] = membro.papel
            resultado.append(linha)
        return Response(resultado)


class UnidadeViewSet(CondominioViewMixin, viewsets.ModelViewSet):
    serializer_class = UnidadeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Unidade.objects.none()
        return Unidade.objects.filter(
            condominio_id=condominio_id, excluido_em__isnull=True
        ).order_by("codigo")
