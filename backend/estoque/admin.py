from django.contrib import admin

from estoque.models import CategoriaEstoque, ItemEstoque


@admin.register(CategoriaEstoque)
class CategoriaEstoqueAdmin(admin.ModelAdmin):
    list_display = ["nome", "condominio", "criado_em"]
    list_filter = ["condominio"]


@admin.register(ItemEstoque)
class ItemEstoqueAdmin(admin.ModelAdmin):
    list_display = ["nome", "condominio", "categoria", "unidade_medida", "ativo"]
    list_filter = ["condominio", "ativo"]
    search_fields = ["nome"]
