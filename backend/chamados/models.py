from django.db import models

from common.managers import CondominioManager
from common.models import CondominioMixin, ModelBase


class Chamado(CondominioMixin, ModelBase):
    """Chamado/ticket aberto por morador ou funcionario."""

    class Prioridade(models.TextChoices):
        BAIXA = "baixa", "Baixa"
        MEDIA = "media", "Media"
        ALTA = "alta", "Alta"
        URGENTE = "urgente", "Urgente"

    class StatusChamado(models.TextChoices):
        ABERTO = "ABERTO", "Aberto"
        EM_ANDAMENTO = "EM_ANDAMENTO", "Em Andamento"
        RESOLVIDO = "RESOLVIDO", "Resolvido"
        CANCELADO = "CANCELADO", "Cancelado"
        PENDENTE_TRIAGEM = "PENDENTE_TRIAGEM", "Pendente Triagem"

    titulo = models.CharField("titulo", max_length=255)
    descricao = models.TextField("descricao")
    categoria = models.CharField("categoria", max_length=50, blank=True, null=True)
    prioridade = models.CharField(
        "prioridade",
        max_length=20,
        choices=Prioridade.choices,
        default=Prioridade.MEDIA,
    )
    status = models.CharField(
        "status",
        max_length=30,
        choices=StatusChamado.choices,
        default=StatusChamado.ABERTO,
    )
    aberto_por = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.SET_NULL,
        null=True,
        related_name="chamados_abertos",
    )
    unidade = models.ForeignKey(
        "moradores.Unidade",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="chamados",
    )
    emergencial = models.BooleanField("emergencial", default=False)
    motivo_rejeicao = models.TextField("motivo rejeicao", blank=True, null=True)
    motivo_cancelamento = models.TextField("motivo cancelamento", blank=True, null=True)
    tipo_execucao = models.CharField(
        "tipo execucao", max_length=50, blank=True, null=True
    )
    ordem_servico = models.ForeignKey(
        "ordens.OrdemServico",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="chamados",
    )
    motivo_fechamento = models.TextField("motivo fechamento", blank=True, null=True)
    excluido_em = models.DateTimeField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "chamados"
        verbose_name = "Chamado"
        verbose_name_plural = "Chamados"

    def __str__(self):
        return f"#{self.id} - {self.titulo}"


class ArquivoChamado(ModelBase):
    """Arquivo anexo a um chamado."""

    chamado = models.ForeignKey(
        Chamado,
        on_delete=models.CASCADE,
        related_name="arquivos",
    )
    arquivo = models.ForeignKey(
        "condominios.Arquivo",
        on_delete=models.CASCADE,
        related_name="chamados",
    )

    class Meta:
        db_table = "arquivos_chamado"
        verbose_name = "Arquivo do Chamado"
        verbose_name_plural = "Arquivos do Chamado"
        unique_together = [("chamado", "arquivo")]
