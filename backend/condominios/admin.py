from django.contrib import admin

from condominios.models import (
    Condominio,
    ConfiguracaoFinanceira,
    MembroCondominio,
    PoliticaAprovacao,
)


@admin.register(Condominio)
class CondominioAdmin(admin.ModelAdmin):
    list_display = ["nome", "documento", "ativo", "status_assinatura", "criado_em"]
    list_filter = ["ativo", "status_assinatura"]
    search_fields = ["nome", "documento"]


@admin.register(MembroCondominio)
class MembroCondominioAdmin(admin.ModelAdmin):
    list_display = ["usuario", "condominio", "papel", "status", "padrao"]
    list_filter = ["papel", "status"]
    search_fields = ["usuario__email", "condominio__nome"]


@admin.register(ConfiguracaoFinanceira)
class ConfiguracaoFinanceiraAdmin(admin.ModelAdmin):
    list_display = ["condominio", "orcamento_anual", "criado_em"]


@admin.register(PoliticaAprovacao)
class PoliticaAprovacaoAdmin(admin.ModelAdmin):
    list_display = ["condominio", "tipo_politica", "ativo"]
    list_filter = ["ativo"]
