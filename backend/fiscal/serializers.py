from rest_framework import serializers

from common.serializers import SerializerBase
from fiscal.models import (
    AprovacaoDocFiscal,
    DocumentoFiscal,
    ItemDocFiscal,
)


class DocumentoFiscalSerializer(SerializerBase):
    class Meta:
        model = DocumentoFiscal
        fields = [
            "id", "condominio_id", "ordem_servico_id", "numero",
            "valor", "valor_bruto", "data_emissao",
            "nome_emissor", "fornecedor", "url_arquivo",
            "tipo_fonte", "tipo_documento", "status",
            "status_aprovacao", "criado_por_id", "criado_em",
        ]


class AprovacaoDocFiscalSerializer(SerializerBase):
    documento_fiscal_dados = DocumentoFiscalSerializer(
        source="documento_fiscal", read_only=True
    )

    class Meta:
        model = AprovacaoDocFiscal
        fields = [
            "id", "documento_fiscal_id", "condominio_id",
            "aprovador_id", "papel_aprovador",
            "decisao", "votado_em", "justificativa",
            "criado_em", "documento_fiscal_dados",
        ]


class ItemDocFiscalSerializer(SerializerBase):
    class Meta:
        model = ItemDocFiscal
        fields = [
            "id", "documento_fiscal_id", "item_estoque_id",
            "quantidade", "preco_unitario", "descricao", "criado_em",
        ]


class ExtrairNFSerializer(serializers.Serializer):
    arquivoBase64 = serializers.CharField()
    tipoMidia = serializers.CharField()
