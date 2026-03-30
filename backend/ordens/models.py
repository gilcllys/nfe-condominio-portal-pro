from django.db import models

from common.managers import CondominioManager
from common.models import CondominioMixin, ModelBase


# ── Ordem de Servico ─────────────────────────────────────────────────────


class OrdemServico(CondominioMixin, ModelBase):
    """Ordem de servico para manutencao/execucao."""

    criado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="ordens_criadas",
    )
    titulo = models.CharField("titulo", max_length=255)
    descricao = models.TextField("descricao", blank=True, null=True)
    localizacao = models.CharField("localizacao", max_length=255, blank=True, null=True)
    status = models.CharField("status", max_length=30, default="ABERTA")
    tipo_executor = models.CharField("tipo executor", max_length=50, blank=True, null=True)
    nome_executor = models.CharField("nome executor", max_length=255, blank=True, null=True)
    notas_execucao = models.TextField("notas execucao", blank=True, null=True)
    prioridade = models.CharField("prioridade", max_length=20, default="MEDIA")
    emergencial = models.BooleanField("emergencial", default=False)
    justificativa_emergencia = models.TextField(blank=True, null=True)
    iniciado_em = models.DateTimeField(blank=True, null=True)
    finalizado_em = models.DateTimeField(blank=True, null=True)
    fornecedor = models.ForeignKey(
        "fornecedores.Fornecedor",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ordens_servico",
    )
    numero_os = models.BigIntegerField("numero OS", blank=True, null=True)
    pdf_final_url = models.TextField(blank=True, null=True)
    chamado_id = models.UUIDField(blank=True, null=True)
    excluido_em = models.DateTimeField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "ordens_servico"
        verbose_name = "Ordem de Servico"
        verbose_name_plural = "Ordens de Servico"

    def __str__(self):
        return f"OS #{self.numero_os or self.id} - {self.titulo}"


class FotoOrdemServico(ModelBase):
    """Fotos anexadas a uma ordem de servico."""

    ordem_servico = models.ForeignKey(
        OrdemServico, on_delete=models.CASCADE, related_name="fotos"
    )
    tipo_foto = models.CharField("tipo", max_length=30)
    url_arquivo = models.TextField("URL arquivo")
    observacao = models.TextField("observacao", blank=True, null=True)

    class Meta:
        db_table = "fotos_ordem_servico"
        verbose_name = "Foto da OS"
        verbose_name_plural = "Fotos da OS"


class MaterialOrdemServico(ModelBase):
    """Material utilizado em uma ordem de servico."""

    ordem_servico = models.ForeignKey(
        OrdemServico, on_delete=models.CASCADE, related_name="materiais"
    )
    item_estoque = models.ForeignKey(
        "estoque.ItemEstoque",
        on_delete=models.SET_NULL,
        null=True,
        related_name="materiais_os",
    )
    quantidade = models.DecimalField(max_digits=12, decimal_places=2)
    unidade_medida = models.CharField("unidade", max_length=20)
    notas = models.TextField(blank=True, null=True)

    class Meta:
        db_table = "materiais_ordem_servico"
        verbose_name = "Material da OS"
        verbose_name_plural = "Materiais da OS"


class AtividadeOrdemServico(ModelBase):
    """Registro de atividade/historico de uma ordem de servico."""

    ordem_servico = models.ForeignKey(
        OrdemServico, on_delete=models.CASCADE, related_name="atividades"
    )
    usuario = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="atividades_os",
    )
    tipo_atividade = models.CharField("tipo", max_length=50)
    descricao = models.TextField(blank=True, null=True)
    metadados = models.JSONField(blank=True, null=True)

    class Meta:
        db_table = "atividades_ordem_servico"
        verbose_name = "Atividade da OS"
        verbose_name_plural = "Atividades da OS"


class AprovacaoOrdemServico(ModelBase):
    """Aprovacao vinculada diretamente a uma ordem de servico."""

    ordem_servico = models.ForeignKey(
        OrdemServico, on_delete=models.CASCADE, related_name="aprovacoes"
    )
    aprovado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="aprovacoes_os",
    )
    papel_aprovador = models.CharField("papel", max_length=30)
    decisao = models.CharField("decisao", max_length=20)
    notas = models.TextField(blank=True, null=True)
    status_resposta = models.CharField(max_length=20, default="PENDENTE")
    prazo = models.DateTimeField(blank=True, null=True)
    respondido_em = models.DateTimeField(blank=True, null=True)
    justificativa = models.TextField(blank=True, null=True)
    tipo_aprovacao = models.CharField(max_length=30, default="ORCAMENTO")

    class Meta:
        db_table = "aprovacoes_ordem_servico"
        verbose_name = "Aprovacao da OS"
        verbose_name_plural = "Aprovacoes da OS"


class CotacaoOrdemServico(ModelBase):
    """Cotacao/orcamento de fornecedor para uma OS."""

    ordem_servico = models.ForeignKey(
        OrdemServico, on_delete=models.CASCADE, related_name="cotacoes"
    )
    nome_fornecedor = models.CharField(max_length=255)
    valor = models.DecimalField(max_digits=12, decimal_places=2)
    descricao = models.TextField(blank=True, null=True)
    url_arquivo = models.TextField(blank=True, null=True)
    criado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="cotacoes_criadas",
    )

    class Meta:
        db_table = "cotacoes_ordem_servico"
        verbose_name = "Cotacao da OS"
        verbose_name_plural = "Cotacoes da OS"


class VotoOrdemServico(ModelBase):
    """Voto de membro em uma ordem de servico."""

    ordem_servico = models.ForeignKey(
        OrdemServico, on_delete=models.CASCADE, related_name="votos"
    )
    usuario = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.CASCADE,
        related_name="votos_os",
    )
    papel = models.CharField(max_length=30)
    voto = models.CharField(max_length=20)
    justificativa = models.TextField(blank=True, null=True)

    class Meta:
        db_table = "votos_ordem_servico"
        verbose_name = "Voto da OS"
        verbose_name_plural = "Votos da OS"


class DocumentoOrdemServico(ModelBase):
    """Documento fiscal vinculado a uma OS."""

    ordem_servico = models.ForeignKey(
        OrdemServico, on_delete=models.CASCADE, related_name="documentos"
    )
    documento_fiscal = models.ForeignKey(
        "fiscal.DocumentoFiscal",
        on_delete=models.CASCADE,
        related_name="ordens_servico",
    )
    tipo_documento = models.CharField(max_length=30)
    notas = models.TextField(blank=True, null=True)

    class Meta:
        db_table = "documentos_ordem_servico"
        verbose_name = "Documento da OS"
        verbose_name_plural = "Documentos da OS"


# ── Aprovacao Geral ──────────────────────────────────────────────────────


class Aprovacao(CondominioMixin, ModelBase):
    """Aprovacao geral (pode ser de OS, orcamento, etc.)."""

    usuario_ator_id = models.UUIDField(blank=True, null=True)
    acao = models.CharField(max_length=50, blank=True, null=True)
    orcamento_aprovado_id = models.UUIDField(blank=True, null=True)
    motivo_revisao = models.TextField(blank=True, null=True)
    detalhes_revisao = models.TextField(blank=True, null=True)
    ordem_servico = models.ForeignKey(
        OrdemServico,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="aprovacoes_gerais",
    )
    orcamento = models.ForeignKey(
        "ordens.Orcamento",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="aprovacoes",
    )
    papel_aprovador = models.CharField(max_length=30, default="sindico")
    decisao = models.CharField(max_length=20, blank=True, null=True)
    respondido_em = models.DateTimeField(blank=True, null=True)
    expira_em = models.DateTimeField(blank=True, null=True)
    minerva = models.BooleanField(default=False)
    justificativa_minerva = models.TextField(blank=True, null=True)
    tipo_aprovacao = models.CharField(max_length=30, default="ORCAMENTO")
    aprovador = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="aprovacoes_gerais",
    )

    objects = CondominioManager()

    class Meta:
        db_table = "aprovacoes"
        verbose_name = "Aprovacao"
        verbose_name_plural = "Aprovacoes"


# ── Orcamento ────────────────────────────────────────────────────────────


class Orcamento(CondominioMixin, ModelBase):
    """Orcamento vinculado a um fornecedor e opcionalmente a uma OS."""

    fornecedor = models.ForeignKey(
        "fornecedores.Fornecedor",
        on_delete=models.CASCADE,
        related_name="orcamentos",
    )
    valor_centavos = models.BigIntegerField(blank=True, null=True)
    arquivo_id = models.UUIDField(blank=True, null=True)
    criado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="orcamentos_criados",
    )
    ordem_servico_id = models.UUIDField(blank=True, null=True)
    status = models.CharField(max_length=20, default="pendente")
    descricao = models.TextField(blank=True, null=True)
    valido_ate = models.DateField(blank=True, null=True)
    nivel_alcada = models.IntegerField(default=1)
    valor_total = models.DecimalField(
        max_digits=10, decimal_places=2, blank=True, null=True
    )
    expira_em = models.DateTimeField(blank=True, null=True)
    excluido_em = models.DateTimeField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "orcamentos"
        verbose_name = "Orcamento"
        verbose_name_plural = "Orcamentos"


# ── Dossie ───────────────────────────────────────────────────────────────


class Dossie(CondominioMixin, ModelBase):
    """Dossie de uma ordem de trabalho."""

    ordem_trabalho_id = models.UUIDField()
    arquivo_id = models.UUIDField()
    algoritmo_hash = models.CharField(max_length=20, default="SHA-256")
    hash_hex = models.CharField(max_length=128)
    gerado_em = models.DateTimeField(auto_now_add=True)
    gerado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="dossies_gerados",
    )

    class Meta:
        db_table = "dossies"
        verbose_name = "Dossie"
        verbose_name_plural = "Dossies"


# ── Ordem de Trabalho ────────────────────────────────────────────────────


class OrdemTrabalho(CondominioMixin, ModelBase):
    """Ordem de trabalho (work order)."""

    chamado_id = models.UUIDField(blank=True, null=True)
    criado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="ordens_trabalho_criadas",
    )
    numero_ot = models.BigIntegerField("numero OT")
    tipo_ot = models.CharField(max_length=50, blank=True, null=True)
    emergencial = models.BooleanField(default=False)
    justificativa_emergencia = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=30, default="CRIADA")
    fornecedor = models.ForeignKey(
        "fornecedores.Fornecedor",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ordens_trabalho",
    )
    iniciado_em = models.DateTimeField(blank=True, null=True)
    finalizado_em = models.DateTimeField(blank=True, null=True)
    excluido_em = models.DateTimeField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "ordens_trabalho"
        verbose_name = "Ordem de Trabalho"
        verbose_name_plural = "Ordens de Trabalho"


class EvidenciaOrdemTrabalho(ModelBase):
    """Evidencia (foto/documento) de uma ordem de trabalho."""

    ordem_trabalho = models.ForeignKey(
        OrdemTrabalho, on_delete=models.CASCADE, related_name="evidencias"
    )
    arquivo_id = models.UUIDField()
    fase = models.CharField("fase", max_length=30)

    class Meta:
        db_table = "evidencias_ordem_trabalho"
        verbose_name = "Evidencia da OT"
        verbose_name_plural = "Evidencias da OT"
        unique_together = [("ordem_trabalho", "arquivo_id")]
