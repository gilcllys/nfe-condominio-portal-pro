from django.db import models

from common.managers import CondominioManager
from common.models import CondominioMixin, ModelBase


class Fornecedor(CondominioMixin, ModelBase):
    """Fornecedor/prestador de servico de um condominio."""

    razao_social = models.CharField("razao social", max_length=255)
    nome_fantasia = models.CharField("nome fantasia", max_length=255, blank=True, null=True)
    documento = models.CharField("CNPJ/CPF", max_length=20, blank=True, null=True)
    email = models.EmailField(blank=True, null=True)
    telefone = models.CharField(max_length=20, blank=True, null=True)
    possui_restricao = models.BooleanField("possui restricao", default=False)
    nota_restricao = models.TextField("nota restricao", blank=True, null=True)
    endereco = models.TextField(blank=True, null=True)
    bairro = models.CharField(max_length=100, blank=True, null=True)
    cep = models.CharField(max_length=10, blank=True, null=True)
    website = models.URLField(blank=True, null=True)
    natureza_juridica = models.CharField(max_length=100, blank=True, null=True)
    capital_social = models.DecimalField(
        max_digits=15, decimal_places=2, blank=True, null=True
    )
    porte_empresa = models.CharField(max_length=50, blank=True, null=True)
    data_abertura = models.DateField(blank=True, null=True)
    atividade_principal = models.TextField(blank=True, null=True)
    pontuacao_risco = models.IntegerField(blank=True, null=True)
    nivel_risco = models.CharField(max_length=20, blank=True, null=True)
    tipo_servico = models.CharField(max_length=100, blank=True, null=True)
    status = models.CharField(max_length=20, default="ativo")
    observacoes = models.TextField(blank=True, null=True)
    cidade = models.CharField(max_length=100, blank=True, null=True)
    estado = models.CharField(max_length=2, blank=True, null=True)
    excluido_em = models.DateTimeField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "fornecedores"
        verbose_name = "Fornecedor"
        verbose_name_plural = "Fornecedores"

    def __str__(self):
        return self.nome_fantasia or self.razao_social or str(self.id)


class AnaliseRiscoFornecedor(ModelBase):
    """Analise de risco de um fornecedor."""

    fornecedor = models.ForeignKey(
        Fornecedor,
        on_delete=models.CASCADE,
        related_name="analises_risco",
        blank=True,
        null=True,
    )
    condominio = models.ForeignKey(
        "condominios.Condominio",
        on_delete=models.CASCADE,
        related_name="analises_risco_fornecedor",
        blank=True,
        null=True,
    )
    pontuacao = models.IntegerField(blank=True, null=True)
    nivel_risco = models.CharField(max_length=20, blank=True, null=True)
    situacao_receita = models.CharField(max_length=50, blank=True, null=True)
    possui_protestos = models.BooleanField(default=False)
    possui_processos = models.BooleanField(default=False)
    noticias_negativas = models.BooleanField(default=False)
    historico_interno = models.TextField(blank=True, null=True)
    recomendacao = models.TextField(blank=True, null=True)
    relatorio_completo = models.TextField(blank=True, null=True)
    consultado_em = models.DateTimeField(blank=True, null=True)
    consultado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="analises_risco_realizadas",
    )

    class Meta:
        db_table = "analises_risco_fornecedor"
        verbose_name = "Analise de Risco"
        verbose_name_plural = "Analises de Risco"


class Contrato(CondominioMixin, ModelBase):
    """Contrato com fornecedor."""

    fornecedor = models.ForeignKey(
        Fornecedor,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="contratos",
    )
    titulo = models.CharField("titulo", max_length=255)
    descricao = models.TextField(blank=True, null=True)
    tipo_contrato = models.CharField(max_length=30, default="OUTROS")
    valor = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    data_inicio = models.DateField(blank=True, null=True)
    data_fim = models.DateField(blank=True, null=True)
    url_arquivo = models.TextField(blank=True, null=True)
    status = models.CharField(max_length=20, default="RASCUNHO")
    criado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="contratos_criados",
    )

    objects = CondominioManager()

    class Meta:
        db_table = "contratos"
        verbose_name = "Contrato"
        verbose_name_plural = "Contratos"

    def __str__(self):
        return self.titulo
