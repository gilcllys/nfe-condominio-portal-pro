from django.contrib import admin

from chamados.models import Chamado


@admin.register(Chamado)
class ChamadoAdmin(admin.ModelAdmin):
    list_display = ["titulo", "condominio", "status", "prioridade", "aberto_por", "criado_em"]
    list_filter = ["status", "prioridade", "condominio"]
    search_fields = ["titulo", "descricao"]
