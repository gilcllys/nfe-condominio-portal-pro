from django.db.models import Sum, Case, When, F, DecimalField, Value
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from common.views import CondominioViewMixin
from estoque.models import CategoriaEstoque, ItemEstoque, MovimentacaoEstoque
from estoque.serializers import (
    CategoriaEstoqueSerializer,
    ItemEstoqueSerializer,
    MovimentacaoEstoqueSerializer,
)


class ItemEstoqueViewSet(
    CondominioViewMixin,
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    mixins.UpdateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = ItemEstoqueSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return ItemEstoque.objects.none()
        qs = ItemEstoque.objects.filter(condominio_id=condominio_id)
        if self.request.query_params.get("incluir_excluidos") != "true":
            qs = qs.filter(excluido_em__isnull=True)
        nome = self.request.query_params.get("nome")
        if nome:
            qs = qs.filter(nome=nome)
        return qs.order_by("nome")

    @action(detail=False, methods=["get"], url_path="saldos")
    def saldos(self, request):
        """GET /api/itens-estoque/saldos/?condominio_id=... — saldo de cada item."""
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Response([])

        itens = ItemEstoque.objects.filter(
            condominio_id=condominio_id, excluido_em__isnull=True
        ).annotate(
            total_entrada=Sum(
                Case(
                    When(movimentacoes__tipo_movimento="ENTRADA", then=F("movimentacoes__quantidade")),
                    default=Value(0),
                    output_field=DecimalField(),
                )
            ),
            total_saida=Sum(
                Case(
                    When(movimentacoes__tipo_movimento="SAIDA", then=F("movimentacoes__quantidade")),
                    default=Value(0),
                    output_field=DecimalField(),
                )
            ),
        )

        resultado = []
        for item in itens:
            entrada = float(item.total_entrada or 0)
            saida = float(item.total_saida or 0)
            resultado.append({
                "item_id": str(item.id),
                "nome": item.nome,
                "saldo": entrada - saida,
            })
        return Response(resultado)


class CategoriaEstoqueViewSet(
    CondominioViewMixin,
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = CategoriaEstoqueSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return CategoriaEstoque.objects.none()
        return CategoriaEstoque.objects.filter(condominio_id=condominio_id).order_by("nome")

    @action(detail=False, methods=["post"], url_path="semear-padroes")
    def semear_padroes(self, request):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Response(
                {"error": "condominio_id e obrigatorio"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        existentes = CategoriaEstoque.objects.filter(condominio_id=condominio_id).count()
        if existentes > 0:
            cats = CategoriaEstoque.objects.filter(condominio_id=condominio_id).order_by("nome")
            return Response(CategoriaEstoqueSerializer(cats, many=True).data)

        padroes = [
            {"nome": "Maquinas e Equipamentos", "descricao": "Cortadores de grama, lavadoras, etc."},
            {"nome": "Ferramentas", "descricao": "Ferramentas manuais e eletricas"},
            {"nome": "Lubrificantes e Quimicos", "descricao": "Oleos, graxas, produtos quimicos"},
            {"nome": "Material de Limpeza", "descricao": "Produtos e utensilios de limpeza"},
            {"nome": "Material Eletrico", "descricao": "Fios, lampadas, disjuntores"},
            {"nome": "Material Hidraulico", "descricao": "Tubos, conexoes, registros"},
            {"nome": "Outros", "descricao": "Itens nao categorizados"},
        ]
        criados = []
        for p in padroes:
            criados.append(CategoriaEstoque.objects.create(condominio_id=condominio_id, **p))
        return Response(
            CategoriaEstoqueSerializer(criados, many=True).data,
            status=status.HTTP_201_CREATED,
        )


class MovimentacaoEstoqueViewSet(
    CondominioViewMixin,
    mixins.ListModelMixin,
    mixins.CreateModelMixin,
    viewsets.GenericViewSet,
):
    serializer_class = MovimentacaoEstoqueSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return MovimentacaoEstoque.objects.none()
        return MovimentacaoEstoque.objects.filter(condominio_id=condominio_id).order_by("-criado_em")

    @action(detail=False, methods=["get"], url_path="saldo")
    def saldo(self, request):
        """GET /api/movimentacoes-estoque/saldo/?condominio_id=... — saldo agrupado por item."""
        condominio_id = self.get_condominio_id()
        if not condominio_id:
            return Response([])

        movs = (
            MovimentacaoEstoque.objects.filter(
                condominio_id=condominio_id, excluido_em__isnull=True
            )
            .values("item_id")
            .annotate(
                total_entrada=Sum(
                    Case(
                        When(tipo_movimento="ENTRADA", then=F("quantidade")),
                        default=Value(0),
                        output_field=DecimalField(),
                    )
                ),
                total_saida=Sum(
                    Case(
                        When(tipo_movimento="SAIDA", then=F("quantidade")),
                        default=Value(0),
                        output_field=DecimalField(),
                    )
                ),
            )
        )

        resultado = []
        for m in movs:
            entrada = float(m["total_entrada"] or 0)
            saida = float(m["total_saida"] or 0)
            resultado.append({
                "item_id": str(m["item_id"]),
                "saldo": entrada - saida,
            })
        return Response(resultado)
