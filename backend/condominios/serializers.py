from common.serializers import SerializerBase

from condominios.models import (
    Condominio,
    ConfiguracaoFinanceira,
    LogAtividade,
    MembroCondominio,
)


class CondominioSerializer(SerializerBase):
    class Meta:
        model = Condominio
        fields = [
            "id",
            "nome",
            "documento",
            "endereco",
            "cidade",
            "estado",
            "cep",
            "telefone",
            "email",
            "ativo",
            "codigo_convite",
            "convite_ativo",
            "status_assinatura",
            "assinatura_id",
            "assinatura_expira_em",
            "criado_em",
            "atualizado_em",
        ]


class MembroCondominioSerializer(SerializerBase):
    class Meta:
        model = MembroCondominio
        fields = [
            "id",
            "usuario_id",
            "condominio_id",
            "papel",
            "status",
            "padrao",
            "criado_em",
            "atualizado_em",
        ]


class ConfiguracaoFinanceiraSerializer(SerializerBase):
    class Meta:
        model = ConfiguracaoFinanceira
        fields = [
            "id",
            "condominio_id",
            "alcada_1_limite",
            "alcada_2_limite",
            "alcada_3_limite",
            "prazo_aprovacao_horas",
            "notificar_moradores_acima",
            "limite_mensal_manutencao",
            "limite_mensal_limpeza",
            "limite_mensal_seguranca",
            "orcamento_anual",
            "alerta_orcamento_pct",
            "orcamento_mensal",
            "criado_em",
            "atualizado_em",
        ]


class LogAtividadeSerializer(SerializerBase):
    class Meta:
        model = LogAtividade
        fields = [
            "id",
            "condominio_id",
            "usuario_id",
            "acao",
            "entidade",
            "entidade_id",
            "descricao",
            "criado_em",
        ]
