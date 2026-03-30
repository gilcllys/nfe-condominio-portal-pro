from common.serializers import SerializerBase

from ordens.models import (
    Aprovacao,
    AtividadeOrdemServico,
    CotacaoOrdemServico,
    FotoOrdemServico,
    MaterialOrdemServico,
    Orcamento,
    OrdemServico,
    VotoOrdemServico,
)


class OrdemServicoSerializer(SerializerBase):
    class Meta:
        model = OrdemServico
        fields = [
            "id", "condominio_id", "titulo", "descricao",
            "localizacao", "status", "prioridade", "emergencial",
            "tipo_executor", "fornecedor_id", "chamado_id",
            "pdf_final_url", "criado_por_id", "numero_os",
            "criado_em", "atualizado_em",
        ]


class FotoOrdemServicoSerializer(SerializerBase):
    class Meta:
        model = FotoOrdemServico
        fields = [
            "id", "ordem_servico_id", "tipo_foto",
            "url_arquivo", "observacao", "criado_em",
        ]


class MaterialOrdemServicoSerializer(SerializerBase):
    class Meta:
        model = MaterialOrdemServico
        fields = [
            "id", "ordem_servico_id", "item_estoque_id",
            "quantidade", "unidade_medida", "notas", "criado_em",
        ]


class AtividadeOrdemServicoSerializer(SerializerBase):
    class Meta:
        model = AtividadeOrdemServico
        fields = [
            "id", "ordem_servico_id", "usuario_id",
            "tipo_atividade", "descricao", "metadados", "criado_em",
        ]


class CotacaoOrdemServicoSerializer(SerializerBase):
    class Meta:
        model = CotacaoOrdemServico
        fields = [
            "id", "ordem_servico_id", "nome_fornecedor",
            "valor", "descricao", "url_arquivo",
            "criado_por_id", "criado_em",
        ]


class VotoOrdemServicoSerializer(SerializerBase):
    class Meta:
        model = VotoOrdemServico
        fields = [
            "id", "ordem_servico_id", "usuario_id",
            "papel", "voto", "justificativa", "criado_em",
        ]


class AprovacaoSerializer(SerializerBase):
    class Meta:
        model = Aprovacao
        fields = [
            "id", "ordem_servico_id", "condominio_id",
            "aprovador_id", "papel_aprovador", "tipo_aprovacao",
            "decisao", "motivo_revisao", "detalhes_revisao",
            "expira_em", "respondido_em", "minerva",
            "justificativa_minerva", "criado_em",
        ]


class OrcamentoSerializer(SerializerBase):
    class Meta:
        model = Orcamento
        fields = [
            "id", "ordem_servico_id", "condominio_id",
            "fornecedor_id", "descricao", "valor_total",
            "status", "valido_ate", "criado_por_id",
            "nivel_alcada", "valor_centavos", "criado_em",
        ]
