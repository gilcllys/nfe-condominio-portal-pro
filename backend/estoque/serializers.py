from common.serializers import SerializerBase

from estoque.models import CategoriaEstoque, ItemEstoque, MovimentacaoEstoque


class CategoriaEstoqueSerializer(SerializerBase):
    class Meta:
        model = CategoriaEstoque
        fields = ["id", "condominio_id", "nome", "descricao", "criado_em"]


class ItemEstoqueSerializer(SerializerBase):
    class Meta:
        model = ItemEstoque
        fields = [
            "id", "condominio_id", "categoria_id", "nome",
            "descricao", "unidade_medida", "quantidade_minima",
            "ativo", "excluido_em", "criado_em",
        ]


class MovimentacaoEstoqueSerializer(SerializerBase):
    class Meta:
        model = MovimentacaoEstoque
        fields = [
            "id", "condominio_id", "item_id", "tipo_movimento",
            "quantidade", "ordem_servico_id", "documento_fiscal_id",
            "criado_em",
        ]
