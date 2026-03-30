from django.db import models

from common.models import ModelBase


class Condominio(ModelBase):
    """
    Modelo topo da hierarquia multi-tenant.
    Todos os outros modelos de dominio possuem FK para Condominio.
    Garante isolamento total de dados entre condominios.
    """

    nome = models.CharField("nome", max_length=255)
    documento = models.CharField("CNPJ", max_length=20, blank=True, null=True)
    endereco = models.TextField("endereco", blank=True, null=True)
    cidade = models.CharField("cidade", max_length=100, blank=True, null=True)
    estado = models.CharField("estado", max_length=2, blank=True, null=True)
    cep = models.CharField("CEP", max_length=10, blank=True, null=True)
    telefone = models.CharField("telefone", max_length=20, blank=True, null=True)
    email = models.EmailField("email", blank=True, null=True)
    ativo = models.BooleanField("ativo", default=True)

    # Convite
    codigo_convite = models.CharField(
        "codigo de convite", max_length=50, blank=True, null=True, unique=True
    )
    convite_ativo = models.BooleanField("convite ativo", default=False)

    # Assinatura
    status_assinatura = models.CharField(
        "status da assinatura", max_length=20, default="trial"
    )
    assinatura_id = models.CharField(
        "ID da assinatura", max_length=100, blank=True, null=True
    )
    assinatura_expira_em = models.DateTimeField(
        "expiracao da assinatura", blank=True, null=True
    )

    # Pagamento
    pagarme_customer_id = models.CharField(
        "ID cliente Pagar.me", max_length=100, blank=True, null=True
    )

    class Meta:
        db_table = "condominios"
        verbose_name = "Condominio"
        verbose_name_plural = "Condominios"

    def __str__(self):
        return self.nome


class MembroCondominio(ModelBase):
    """
    Vinculo entre Usuario e Condominio com papel (role).
    Um usuario pode pertencer a varios condominios com papeis diferentes.
    """

    class Papel(models.TextChoices):
        SINDICO = "SINDICO", "Sindico"
        SUB_SINDICO = "SUB_SINDICO", "Sub-Sindico"
        CONSELHEIRO = "CONSELHEIRO", "Conselheiro Fiscal"
        FUNCIONARIO = "FUNCIONARIO", "Funcionario"
        MORADOR = "MORADOR", "Morador"
        ADMIN = "ADMIN", "Administrador"

    class Status(models.TextChoices):
        ATIVO = "ativo", "Ativo"
        PENDENTE = "pendente", "Pendente"
        INATIVO = "inativo", "Inativo"
        RECUSADO = "recusado", "Recusado"

    usuario = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.CASCADE,
        related_name="membros_condominio",
    )
    condominio = models.ForeignKey(
        Condominio,
        on_delete=models.CASCADE,
        related_name="membros",
    )
    papel = models.CharField(
        "papel", max_length=20, choices=Papel.choices, default=Papel.MORADOR
    )
    status = models.CharField(
        "status", max_length=20, choices=Status.choices, default=Status.PENDENTE
    )
    padrao = models.BooleanField("condominio padrao", default=False)

    class Meta:
        db_table = "membros_condominio"
        verbose_name = "Membro do Condominio"
        verbose_name_plural = "Membros do Condominio"
        unique_together = [("usuario", "condominio")]

    def __str__(self):
        return f"{self.usuario} - {self.condominio} ({self.papel})"


class ConfiguracaoFinanceira(ModelBase):
    """Configuracao financeira 1:1 com Condominio."""

    condominio = models.OneToOneField(
        Condominio,
        on_delete=models.CASCADE,
        related_name="config_financeira",
    )
    alcada_1_limite = models.DecimalField(
        "limite alcada 1", max_digits=10, decimal_places=2, default=500
    )
    alcada_2_limite = models.DecimalField(
        "limite alcada 2", max_digits=10, decimal_places=2, default=2000
    )
    alcada_3_limite = models.DecimalField(
        "limite alcada 3", max_digits=10, decimal_places=2, default=10000
    )
    prazo_aprovacao_horas = models.IntegerField("prazo aprovacao (horas)", default=48)
    notificar_moradores_acima = models.DecimalField(
        "notificar moradores acima de",
        max_digits=10,
        decimal_places=2,
        default=10000,
    )
    limite_mensal_manutencao = models.DecimalField(
        max_digits=10, decimal_places=2, blank=True, null=True
    )
    limite_mensal_limpeza = models.DecimalField(
        max_digits=10, decimal_places=2, blank=True, null=True
    )
    limite_mensal_seguranca = models.DecimalField(
        max_digits=10, decimal_places=2, blank=True, null=True
    )
    orcamento_anual = models.DecimalField(
        max_digits=10, decimal_places=2, blank=True, null=True
    )
    alerta_orcamento_pct = models.IntegerField("alerta orcamento %", default=70)
    orcamento_mensal = models.DecimalField(
        max_digits=12, decimal_places=2, blank=True, null=True
    )

    class Meta:
        db_table = "configuracoes_financeiras"
        verbose_name = "Configuracao Financeira"
        verbose_name_plural = "Configuracoes Financeiras"

    def __str__(self):
        return f"Config Financeira - {self.condominio}"


class PoliticaAprovacao(ModelBase):
    """Politicas de aprovacao configuradas por condominio."""

    condominio = models.ForeignKey(
        Condominio,
        on_delete=models.CASCADE,
        related_name="politicas_aprovacao",
    )
    tipo_politica = models.CharField("tipo", max_length=50)
    usar_limite_valor = models.BooleanField(default=False)
    valor_minimo = models.DecimalField(
        max_digits=14, decimal_places=2, blank=True, null=True
    )
    valor_maximo = models.DecimalField(
        max_digits=14, decimal_places=2, blank=True, null=True
    )
    requer_sindico = models.BooleanField(default=True)
    requer_sub_sindico = models.BooleanField(default=False)
    requer_conselho = models.BooleanField(default=False)
    modo_decisao = models.CharField(max_length=20, default="MAIORIA")
    sindico_desempate = models.BooleanField(default=True)
    ativo = models.BooleanField(default=True)

    class Meta:
        db_table = "politicas_aprovacao"
        verbose_name = "Politica de Aprovacao"
        verbose_name_plural = "Politicas de Aprovacao"

    def __str__(self):
        return f"{self.tipo_politica} - {self.condominio}"


class LogAtividade(ModelBase):
    """Log de atividades dentro de um condominio."""

    condominio = models.ForeignKey(
        Condominio,
        on_delete=models.CASCADE,
        related_name="logs_atividade",
    )
    usuario = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="logs_atividade",
    )
    acao = models.CharField(max_length=100)
    entidade = models.CharField(max_length=100, blank=True, null=True)
    entidade_id = models.UUIDField(blank=True, null=True)
    descricao = models.TextField(blank=True, null=True)

    class Meta:
        db_table = "logs_atividade"
        verbose_name = "Log de Atividade"
        verbose_name_plural = "Logs de Atividade"


class EventoAuditoria(models.Model):
    """Eventos de auditoria para rastreabilidade."""

    id = models.BigAutoField(primary_key=True)
    condominio = models.ForeignKey(
        Condominio,
        on_delete=models.CASCADE,
        related_name="eventos_auditoria",
    )
    usuario_id = models.UUIDField(blank=True, null=True)
    tipo_entidade = models.CharField(max_length=100)
    entidade_id = models.UUIDField(blank=True, null=True)
    tipo_evento = models.CharField(max_length=100)
    ocorrido_em = models.DateTimeField(auto_now_add=True)
    detalhes = models.JSONField(blank=True, null=True)

    class Meta:
        db_table = "eventos_auditoria"
        verbose_name = "Evento de Auditoria"
        verbose_name_plural = "Eventos de Auditoria"


class LogTransferenciaSindico(ModelBase):
    """Log de transferencia de papel de sindico."""

    condominio = models.ForeignKey(
        Condominio,
        on_delete=models.CASCADE,
        related_name="transferencias_sindico",
    )
    usuario_anterior_id = models.UUIDField()
    usuario_novo_id = models.UUIDField()
    alterado_por_id = models.UUIDField(blank=True, null=True)
    papel_anterior = models.CharField(max_length=20, blank=True, null=True)
    papel_novo = models.CharField(max_length=20, blank=True, null=True)
    usuario_anterior_desativado = models.BooleanField(default=True)

    class Meta:
        db_table = "logs_transferencia_sindico"
        verbose_name = "Log Transferencia Sindico"
        verbose_name_plural = "Logs Transferencia Sindico"


class Assinatura(ModelBase):
    """Assinatura/subscription do condominio na plataforma."""

    condominio = models.ForeignKey(
        Condominio,
        on_delete=models.CASCADE,
        related_name="assinaturas",
    )
    provedor = models.CharField(max_length=20, default="ASAAS")
    id_cliente_externo = models.CharField(max_length=100, blank=True, null=True)
    id_assinatura_externa = models.CharField(max_length=100, blank=True, null=True)
    status = models.CharField(max_length=20, default="ATIVO")
    excluido_em = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "assinaturas"
        verbose_name = "Assinatura"
        verbose_name_plural = "Assinaturas"


class Arquivo(ModelBase):
    """Arquivo generico vinculado a um condominio."""

    condominio = models.ForeignKey(
        Condominio,
        on_delete=models.CASCADE,
        related_name="arquivos",
    )
    tipo = models.CharField(max_length=50)
    chave_storage = models.TextField()
    nome_arquivo = models.CharField(max_length=255)
    tipo_conteudo = models.CharField(max_length=100)
    tamanho_bytes = models.BigIntegerField()
    sha256_hex = models.CharField(max_length=64, blank=True, null=True)
    criado_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="arquivos_criados",
    )
    excluido_em = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "arquivos"
        verbose_name = "Arquivo"
        verbose_name_plural = "Arquivos"
