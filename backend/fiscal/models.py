from django.db import models

from common.managers import CondominioManager
from common.models import CondominioMixin, ModelBase


class DocumentoFiscal(CondominioMixin, ModelBase):
    """Documento fiscal (NF, NFS-e, etc.)."""

    criado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="documentos_fiscais_criados",
    )
    tipo_documento = models.CharField(max_length=20, default="NF")
    tipo_fonte = models.CharField("tipo fonte", max_length=30)
    nome_emissor = models.CharField(max_length=255, blank=True, null=True)
    documento_emissor = models.CharField(max_length=20, blank=True, null=True)
    nome_tomador = models.CharField(max_length=255, blank=True, null=True)
    documento_tomador = models.CharField(max_length=20, blank=True, null=True)
    numero_documento = models.CharField(max_length=50, blank=True, null=True)
    serie = models.CharField(max_length=10, blank=True, null=True)
    codigo_verificacao = models.CharField(max_length=100, blank=True, null=True)
    data_emissao = models.DateTimeField(blank=True, null=True)
    cidade_servico = models.CharField(max_length=100, blank=True, null=True)
    estado_servico = models.CharField(max_length=2, blank=True, null=True)
    valor_bruto = models.DecimalField(
        max_digits=14, decimal_places=2, blank=True, null=True
    )
    valor_liquido = models.DecimalField(
        max_digits=14, decimal_places=2, blank=True, null=True
    )
    valor_impostos = models.DecimalField(
        max_digits=14, decimal_places=2, blank=True, null=True
    )
    status = models.CharField(max_length=20, default="PENDENTE")
    chave_acesso = models.TextField(blank=True, null=True)
    url_arquivo = models.TextField(blank=True, null=True)
    payload_original = models.JSONField(blank=True, null=True)
    ordem_servico_id = models.UUIDField(blank=True, null=True)
    status_aprovacao = models.CharField(max_length=20, default="pendente")
    aprovado_por_subsindico_id = models.UUIDField(blank=True, null=True)
    aprovado_por_subsindico_em = models.DateTimeField(blank=True, null=True)
    voto_minerva_sindico = models.BooleanField(default=False)
    voto_minerva_sindico_em = models.DateTimeField(blank=True, null=True)
    nivel_alcada = models.IntegerField(default=1)
    notificar_moradores = models.BooleanField(default=False)
    valor = models.DecimalField(
        max_digits=10, decimal_places=2, blank=True, null=True
    )
    fornecedor = models.CharField(max_length=255, blank=True, null=True)
    numero = models.CharField(max_length=50, blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "documentos_fiscais"
        verbose_name = "Documento Fiscal"
        verbose_name_plural = "Documentos Fiscais"

    def __str__(self):
        return f"Doc #{self.numero or self.id}"


class AprovacaoDocFiscal(CondominioMixin, ModelBase):
    """Aprovacao de um documento fiscal."""

    documento_fiscal = models.ForeignKey(
        DocumentoFiscal,
        on_delete=models.CASCADE,
        related_name="aprovacoes",
    )
    aprovador = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.CASCADE,
        related_name="aprovacoes_doc_fiscal",
    )
    papel_aprovador = models.CharField(max_length=30)
    decisao = models.CharField(max_length=20, blank=True, null=True)
    justificativa = models.TextField(blank=True, null=True)
    votado_em = models.DateTimeField(blank=True, null=True)
    expira_em = models.DateTimeField(blank=True, null=True)
    minerva = models.BooleanField(default=False)
    justificativa_minerva = models.TextField(blank=True, null=True)

    class Meta:
        db_table = "aprovacoes_doc_fiscal"
        verbose_name = "Aprovacao Doc Fiscal"
        verbose_name_plural = "Aprovacoes Doc Fiscal"


class ItemDocFiscal(ModelBase):
    """Item de um documento fiscal."""

    documento_fiscal = models.ForeignKey(
        DocumentoFiscal,
        on_delete=models.CASCADE,
        related_name="itens",
    )
    item_estoque_id = models.UUIDField(blank=True, null=True)
    quantidade = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    preco_unitario = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    descricao = models.TextField(blank=True, null=True)

    class Meta:
        db_table = "itens_doc_fiscal"
        verbose_name = "Item Doc Fiscal"
        verbose_name_plural = "Itens Doc Fiscal"


class NotaFiscal(CondominioMixin, ModelBase):
    """Nota fiscal (legacy - tabela invoices do Supabase)."""

    tipo_nota = models.CharField(max_length=30)
    ordem_trabalho_id = models.UUIDField(blank=True, null=True)
    fornecedor_id = models.UUIDField(blank=True, null=True)
    numero_nota = models.CharField(max_length=50, blank=True, null=True)
    chave_nota = models.CharField(max_length=100, blank=True, null=True)
    emitido_em = models.DateField(blank=True, null=True)
    valor_centavos = models.BigIntegerField(blank=True, null=True)
    arquivo_id = models.UUIDField(blank=True, null=True)
    criado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="notas_fiscais_criadas",
    )
    excluido_em = models.DateTimeField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "notas_fiscais"
        verbose_name = "Nota Fiscal"
        verbose_name_plural = "Notas Fiscais"
