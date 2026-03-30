from django.db.models import Sum
from rest_framework import mixins, status, viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from common.views import CondominioViewMixin
from fiscal.models import (
    AprovacaoDocFiscal,
    DocumentoFiscal,
    ItemDocFiscal,
)
from fiscal.serializers import (
    AprovacaoDocFiscalSerializer,
    DocumentoFiscalSerializer,
    ItemDocFiscalSerializer,
)


class DocumentoFiscalViewSet(
    CondominioViewMixin,
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.RetrieveModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = DocumentoFiscalSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return DocumentoFiscal.objects.none()

        qs = DocumentoFiscal.objects.filter(condominio_id=condominio_id)
        status_filtro = self.request.query_params.get("status")
        if status_filtro:
            qs = qs.filter(status=status_filtro)
        return qs.order_by("-criado_em")

    def list(self, request, *args, **kwargs):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Response([])

        qs = self.get_queryset()

        if request.query_params.get("apenas_contagem") == "true":
            return Response({"contagem": qs.count()})

        if request.query_params.get("somar_valor") == "true":
            gte = request.query_params.get("criado_em__gte")
            if gte:
                qs = qs.filter(criado_em__gte=gte)
            total = qs.aggregate(total=Sum("valor"))["total"] or 0
            return Response({"total": float(total)})

        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)


class AprovacaoDocFiscalViewSet(CondominioViewMixin, viewsets.ModelViewSet):
    serializer_class = AprovacaoDocFiscalSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = AprovacaoDocFiscal.objects.all()
        condominio_id = self.get_condominio_id()
        aprovador_id = self.request.query_params.get("aprovador_id")
        documento_fiscal_id = self.request.query_params.get("documento_fiscal_id")

        if condominio_id:
            qs = qs.filter(condominio_id=condominio_id)
        if aprovador_id:
            qs = qs.filter(aprovador_id=aprovador_id)
        if documento_fiscal_id:
            qs = qs.filter(documento_fiscal_id=documento_fiscal_id)

        return qs.select_related("documento_fiscal").order_by("votado_em")

    def list(self, request, *args, **kwargs):
        condominio_id = self.get_condominio_id()

        if request.query_params.get("apenas_contagem") == "true":
            qs = (
                AprovacaoDocFiscal.objects.filter(condominio_id=condominio_id)
                if condominio_id
                else AprovacaoDocFiscal.objects.none()
            )
            decisao = request.query_params.get("decisao")
            if decisao:
                qs = qs.filter(decisao=decisao)
            return Response({"contagem": qs.count()})

        return super().list(request, *args, **kwargs)

    def create(self, request, *args, **kwargs):
        registros = request.data if isinstance(request.data, list) else [request.data]
        criados = []
        for reg in registros:
            a = AprovacaoDocFiscal.objects.create(
                documento_fiscal_id=reg["documento_fiscal_id"],
                condominio_id=reg["condominio_id"],
                aprovador_id=reg["aprovador_id"],
                papel_aprovador=reg["papel_aprovador"],
                decisao=reg.get("decisao", "pendente"),
                justificativa=reg.get("justificativa"),
                votado_em=reg.get("votado_em"),
            )
            criados.append(str(a.id))
        return Response({"ids": criados}, status=status.HTTP_201_CREATED)


class ItemDocFiscalViewSet(
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = ItemDocFiscalSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        qs = ItemDocFiscal.objects.all()
        doc_id = self.request.query_params.get("documento_fiscal_id")
        if doc_id:
            qs = qs.filter(documento_fiscal_id=doc_id)
        return qs.order_by("-criado_em")
