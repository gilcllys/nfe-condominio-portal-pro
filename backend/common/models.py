import uuid

from django.db import models


class ModelBase(models.Model):
    """
    Modelo base abstrato.
    Todos os modelos do projeto herdam dele para garantir consistencia.
    Fornece: id (UUID), criado_em e atualizado_em.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True
        ordering = ["-criado_em"]


class CondominioMixin(models.Model):
    """
    Mixin abstrato que adiciona FK para Condominio.
    Garante isolamento multi-tenant: todo modelo de dominio
    deve herdar este mixin para vincular-se a um condominio.
    """

    condominio = models.ForeignKey(
        "condominios.Condominio",
        on_delete=models.CASCADE,
        related_name="%(app_label)s_%(class)ss",
    )

    class Meta:
        abstract = True
