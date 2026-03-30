from django.contrib import admin

from fornecedores.models import Contrato, Fornecedor


@admin.register(Fornecedor)
class FornecedorAdmin(admin.ModelAdmin):
    list_display = ["razao_social", "nome_fantasia", "condominio", "status", "documento"]
    list_filter = ["status", "condominio"]
    search_fields = ["razao_social", "nome_fantasia", "documento"]


@admin.register(Contrato)
class ContratoAdmin(admin.ModelAdmin):
    list_display = ["titulo", "condominio", "fornecedor", "status", "valor"]
    list_filter = ["status", "tipo_contrato"]
    search_fields = ["titulo"]
