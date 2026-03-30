from common.serializers import SerializerBase

from moradores.models import Morador, Unidade


class UnidadeSerializer(SerializerBase):
    class Meta:
        model = Unidade
        fields = [
            "id", "condominio_id", "codigo", "descricao",
            "bloco", "andar", "criado_em", "atualizado_em",
        ]


class MoradorSerializer(SerializerBase):
    class Meta:
        model = Morador
        fields = [
            "id", "condominio_id", "unidade_id", "nome_completo",
            "documento", "email", "telefone", "bloco",
            "unidade_label", "tipo_residencia", "criado_em", "atualizado_em",
        ]
