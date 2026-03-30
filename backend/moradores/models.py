from django.db import models

from common.managers import CondominioManager
from common.models import CondominioMixin, ModelBase


class Unidade(CondominioMixin, ModelBase):
    """Apartamento, casa, loja ou sala dentro do condominio."""

    codigo = models.CharField("codigo", max_length=20)
    descricao = models.TextField("descricao", blank=True, null=True)
    bloco = models.CharField("bloco", max_length=20, blank=True, null=True)
    andar = models.CharField("andar", max_length=10, blank=True, null=True)
    excluido_em = models.DateTimeField(blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "unidades"
        verbose_name = "Unidade"
        verbose_name_plural = "Unidades"
        unique_together = [("condominio", "codigo")]

    def __str__(self):
        bloco = f"Bloco {self.bloco} - " if self.bloco else ""
        return f"{bloco}{self.codigo}"


class Morador(CondominioMixin, ModelBase):
    """Morador cadastrado no condominio, vinculado opcionalmente a uma unidade."""

    unidade = models.ForeignKey(
        Unidade,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="moradores",
    )
    nome_completo = models.CharField("nome completo", max_length=255)
    documento = models.CharField("CPF/RG", max_length=20, blank=True, null=True)
    email = models.EmailField("email", blank=True, null=True)
    telefone = models.CharField("telefone", max_length=20, blank=True, null=True)
    bloco = models.CharField("bloco", max_length=20, blank=True, null=True)
    unidade_label = models.CharField("unidade", max_length=50, blank=True, null=True)
    tipo_residencia = models.CharField(
        "tipo de residencia", max_length=30, blank=True, null=True
    )
    torre = models.CharField("torre", max_length=20, blank=True, null=True)
    numero_apartamento = models.CharField(
        "numero apartamento", max_length=20, blank=True, null=True
    )
    rua = models.CharField("rua", max_length=255, blank=True, null=True)
    numero_rua = models.CharField("numero", max_length=20, blank=True, null=True)
    complemento = models.CharField("complemento", max_length=100, blank=True, null=True)
    data_nascimento = models.DateField("data nascimento", blank=True, null=True)

    objects = CondominioManager()

    class Meta:
        db_table = "moradores"
        verbose_name = "Morador"
        verbose_name_plural = "Moradores"

    def __str__(self):
        return self.nome_completo


class MoradorUnidade(ModelBase):
    """Vinculo N:N entre usuario e unidade."""

    usuario = models.ForeignKey(
        "contas.Usuario",
        on_delete=models.CASCADE,
        related_name="unidades",
    )
    unidade = models.ForeignKey(
        Unidade,
        on_delete=models.CASCADE,
        related_name="usuarios",
    )

    class Meta:
        db_table = "morador_unidades"
        verbose_name = "Morador-Unidade"
        verbose_name_plural = "Moradores-Unidades"
        unique_together = [("usuario", "unidade")]
