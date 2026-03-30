from rest_framework import serializers

from common.serializers import SerializerBase
from fornecedores.models import Contrato, Fornecedor


class FornecedorSerializer(SerializerBase):
    class Meta:
        model = Fornecedor
        fields = [
            "id", "condominio_id", "documento", "razao_social",
            "nome_fantasia", "telefone", "email", "endereco",
            "bairro", "cidade", "estado", "cep",
            "tipo_servico", "observacoes", "status", "pontuacao_risco",
            "excluido_em", "criado_em", "atualizado_em",
        ]


class ContratoSerializer(SerializerBase):
    class Meta:
        model = Contrato
        fields = [
            "id", "condominio_id", "fornecedor_id", "titulo",
            "descricao", "tipo_contrato", "valor",
            "data_inicio", "data_fim", "url_arquivo", "status",
            "criado_por_id", "criado_em", "atualizado_em",
        ]


class AnalisarRiscoSerializer(serializers.Serializer):
    dados_cnpj = serializers.DictField()
