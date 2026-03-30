from rest_framework import mixins, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from common.views import CondominioViewMixin
from fornecedores.models import Contrato, Fornecedor
from fornecedores.serializers import ContratoSerializer, FornecedorSerializer


class FornecedorViewSet(CondominioViewMixin, mixins.ListModelMixin, viewsets.GenericViewSet):
    serializer_class = FornecedorSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Fornecedor.objects.none()
        qs = Fornecedor.objects.filter(
            condominio_id=condominio_id, excluido_em__isnull=True
        ).order_by("nome_fantasia")
        return qs

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        campos_param = request.query_params.get("campos")
        if campos_param:
            campos = [f.strip() for f in campos_param.split(",")]
            resultado = list(qs.values(*campos))
            for r in resultado:
                for k in ["id", "condominio_id"]:
                    if r.get(k):
                        r[k] = str(r[k])
            return Response(resultado)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)


class ContratoViewSet(CondominioViewMixin, viewsets.ModelViewSet):
    serializer_class = ContratoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Contrato.objects.none()

        qs = Contrato.objects.filter(condominio_id=condominio_id)
        status_filtro = self.request.query_params.get("status")
        if status_filtro:
            qs = qs.filter(status=status_filtro)
        tipo = self.request.query_params.get("tipo_contrato")
        if tipo:
            qs = qs.filter(tipo_contrato=tipo)
        return qs.order_by("-criado_em")
