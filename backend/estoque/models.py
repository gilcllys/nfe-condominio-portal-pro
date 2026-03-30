from django.db import models

from common.managers import CondominioManager
from common.models import CondominioMixin, ModelBase


class CategoriaEstoque(CondominioMixin, ModelBase):
    """Categoria de item de estoque."""

    nome = models.CharField("nome", max_length=100)
    descricao = models.TextField("descricao", blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "categorias_estoque"
        verbose_name = "Categoria de Estoque"
        verbose_name_plural = "Categorias de Estoque"

    def __str__(self):
        return self.nome


class ItemEstoque(CondominioMixin, ModelBase):
    """Item do estoque de um condominio."""

    categoria = models.ForeignKey(
        CategoriaEstoque,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="itens",
    )
    nome = models.CharField("nome", max_length=255)
    unidade_medida = models.CharField("unidade", max_length=20, default="UN")
    quantidade_minima = models.DecimalField(
        "qtd minima", max_digits=18, decimal_places=3, default=0
    )
    ativo = models.BooleanField("ativo", default=True)
    descricao = models.TextField("descricao", blank=True, null=True)
    excluido_em = models.DateTimeField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "itens_estoque"
        verbose_name = "Item de Estoque"
        verbose_name_plural = "Itens de Estoque"

    def __str__(self):
        return self.nome


class MovimentacaoEstoque(CondominioMixin, ModelBase):
    """Movimentacao (entrada/saida) de um item do estoque."""

    item = models.ForeignKey(
        ItemEstoque,
        on_delete=models.CASCADE,
        related_name="movimentacoes",
    )
    tipo_movimento = models.CharField("tipo", max_length=20)  # ENTRADA, SAIDA
    quantidade = models.DecimalField(max_digits=18, decimal_places=3)
    custo_unitario_centavos = models.BigIntegerField(blank=True, null=True)
    nome_fornecedor = models.CharField(max_length=255, blank=True, null=True)
    observacao = models.TextField(blank=True, null=True)
    movido_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="movimentacoes_estoque",
    )
    movido_em = models.DateTimeField(auto_now_add=True)
    excluido_em = models.DateTimeField(blank=True, null=True)
    destino = models.CharField(max_length=255, blank=True, null=True)
    ordem_servico_id = models.UUIDField(blank=True, null=True)
    documento_fiscal_id = models.UUIDField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "movimentacoes_estoque"
        verbose_name = "Movimentacao de Estoque"
        verbose_name_plural = "Movimentacoes de Estoque"
