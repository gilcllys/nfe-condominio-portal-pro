from django.contrib import admin

from moradores.models import Morador, Unidade


@admin.register(Unidade)
class UnidadeAdmin(admin.ModelAdmin):
    list_display = ["codigo", "condominio", "bloco", "andar"]
    list_filter = ["condominio"]
    search_fields = ["codigo", "descricao"]


@admin.register(Morador)
class MoradorAdmin(admin.ModelAdmin):
    list_display = ["nome_completo", "condominio", "email", "telefone", "bloco", "unidade_label"]
    list_filter = ["condominio"]
    search_fields = ["nome_completo", "email", "documento"]
