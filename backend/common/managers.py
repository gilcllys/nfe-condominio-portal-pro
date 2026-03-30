from django.db import models


class CondominioManager(models.Manager):
    """Manager com metodo utilitario para filtrar por condominio."""

    def para_condominio(self, condominio_id):
        return self.filter(condominio_id=condominio_id)

    def ativos(self):
        """Retorna apenas registros nao excluidos (soft delete)."""
        return self.filter(excluido_em__isnull=True)
