from common.serializers import SerializerBase

from chamados.models import Chamado


class ChamadoSerializer(SerializerBase):
    class Meta:
        model = Chamado
        fields = [
            "id", "condominio_id", "titulo", "descricao",
            "categoria", "prioridade", "status",
            "aberto_por_id", "unidade_id", "emergencial",
            "motivo_rejeicao", "motivo_cancelamento",
            "tipo_execucao", "ordem_servico_id",
            "criado_em", "atualizado_em",
        ]
