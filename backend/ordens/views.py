from django.db.models import Count
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from common.views import CondominioViewMixin
from ordens.models import (
    Aprovacao,
    AtividadeOrdemServico,
    FotoOrdemServico,
    MaterialOrdemServico,
    Orcamento,
    OrdemServico,
)
from ordens.serializers import (
    AprovacaoSerializer,
    AtividadeOrdemServicoSerializer,
    FotoOrdemServicoSerializer,
    MaterialOrdemServicoSerializer,
    OrcamentoSerializer,
    OrdemServicoSerializer,
)


class OrdemServicoViewSet(CondominioViewMixin, viewsets.ModelViewSet):
    serializer_class = OrdemServicoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return OrdemServico.objects.none()

        qs = OrdemServico.objects.filter(condominio_id=condominio_id)
        criado_por = self.request.query_params.get("criado_por")
        if criado_por:
            qs = qs.filter(criado_por_id=criado_por)
        return qs.order_by("-criado_em")

    def list(self, request, *args, **kwargs):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Response([])

        qs = self.get_queryset()
        offset = int(request.query_params.get("offset", 0))
        limite = int(request.query_params.get("limite", 20))
        qs = qs[offset : offset + limite]

        ordens = list(qs.values())
        ids = [o["id"] for o in ordens]

        contagem_fotos = dict(
            FotoOrdemServico.objects.filter(ordem_servico_id__in=ids)
            .values("ordem_servico_id")
            .annotate(cnt=Count("id"))
            .values_list("ordem_servico_id", "cnt")
        )

        for o in ordens:
            o["contagem_fotos"] = contagem_fotos.get(o["id"], 0)
            for k in ["id", "condominio_id", "criado_por_id", "fornecedor_id", "chamado_id"]:
                if o.get(k):
                    o[k] = str(o[k])
        return Response(ordens)


class FotoOrdemServicoViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = FotoOrdemServicoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        os_id = self.kwargs.get("os_id")
        return FotoOrdemServico.objects.filter(ordem_servico_id=os_id)

    def perform_create(self, serializer):
        os_id = self.kwargs.get("os_id")
        serializer.save(ordem_servico_id=os_id)


class AtividadeOrdemServicoViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = AtividadeOrdemServicoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        os_id = self.kwargs.get("os_id")
        return AtividadeOrdemServico.objects.filter(
            ordem_servico_id=os_id
        ).order_by("-criado_em")

    def perform_create(self, serializer):
        os_id = self.kwargs.get("os_id")
        serializer.save(ordem_servico_id=os_id, usuario=self.request.user)


class MaterialOrdemServicoViewSet(viewsets.ModelViewSet):
    serializer_class = MaterialOrdemServicoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        os_id = self.request.query_params.get("ordem_servico_id")
        if os_id:
            return MaterialOrdemServico.objects.filter(ordem_servico_id=os_id)
        return MaterialOrdemServico.objects.all()


class AprovacaoViewSet(CondominioViewMixin, viewsets.ModelViewSet):
    serializer_class = AprovacaoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        os_id = self.request.query_params.get("ordem_servico_id")
        condominio_id = self.get_condominio_id()
        aprovador_id = self.request.query_params.get("aprovador_id")

        qs = Aprovacao.objects.all()
        if os_id:
            qs = qs.filter(ordem_servico_id=os_id)
        if condominio_id:
            qs = qs.filter(condominio_id=condominio_id)
        if aprovador_id:
            qs = qs.filter(aprovador_id=aprovador_id)
        return qs.order_by("-criado_em")

    def create(self, request, *args, **kwargs):
        registros = request.data if isinstance(request.data, list) else [request.data]
        criados = []
        for reg in registros:
            a = Aprovacao.objects.create(
                ordem_servico_id=reg.get("ordem_servico_id"),
                condominio_id=reg["condominio_id"],
                aprovador_id=reg["aprovador_id"],
                papel_aprovador=reg["papel_aprovador"],
                tipo_aprovacao=reg.get("tipo_aprovacao", ""),
                decisao=reg.get("decisao", "pendente"),
                justificativa_minerva=reg.get("justificativa"),
                expira_em=reg.get("expira_em"),
                minerva=reg.get("minerva", False),
            )
            criados.append(str(a.id))
        return Response({"ids": criados}, status=status.HTTP_201_CREATED)


class OrcamentoViewSet(CondominioViewMixin, viewsets.ModelViewSet):
    serializer_class = OrcamentoSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        os_id = self.request.query_params.get("ordem_servico_id")
        condominio_id = self.get_condominio_id()
        qs = Orcamento.objects.all()
        if os_id:
            qs = qs.filter(ordem_servico_id=os_id)
        if condominio_id:
            qs = qs.filter(condominio_id=condominio_id)
        return qs.order_by("-criado_em")

    def perform_create(self, serializer):
        extra = {}
        if not self.request.data.get("criado_por_id"):
            extra["criado_por"] = self.request.user
        serializer.save(**extra)
