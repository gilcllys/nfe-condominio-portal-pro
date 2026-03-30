from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from chamados.models import Chamado
from chamados.serializers import ChamadoSerializer
from common.views import CondominioViewMixin


class ChamadoViewSet(CondominioViewMixin, viewsets.ModelViewSet):
    serializer_class = ChamadoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Chamado.objects.none()

        qs = Chamado.objects.filter(condominio_id=condominio_id)
        status_in = self.request.query_params.get("status__in")
        if status_in:
            qs = qs.filter(status__in=status_in.split(","))

        aberto_por = self.request.query_params.get("aberto_por")
        if aberto_por:
            qs = qs.filter(aberto_por_id=aberto_por)

        return qs.order_by("-criado_em")

    def perform_create(self, serializer):
        if not serializer.validated_data.get("aberto_por"):
            serializer.save(aberto_por=self.request.user)
        else:
            serializer.save()
