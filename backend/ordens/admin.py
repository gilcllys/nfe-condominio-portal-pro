from django.contrib import admin

from ordens.models import Aprovacao, Orcamento, OrdemServico


@admin.register(OrdemServico)
class OrdemServicoAdmin(admin.ModelAdmin):
    list_display = ["titulo", "condominio", "status", "prioridade", "criado_por", "criado_em"]
    list_filter = ["status", "prioridade", "condominio"]
    search_fields = ["titulo", "descricao"]


@admin.register(Aprovacao)
class AprovacaoAdmin(admin.ModelAdmin):
    list_display = ["condominio", "tipo_aprovacao", "decisao", "papel_aprovador", "criado_em"]
    list_filter = ["tipo_aprovacao", "decisao"]


@admin.register(Orcamento)
class OrcamentoAdmin(admin.ModelAdmin):
    list_display = ["condominio", "fornecedor", "valor_total", "status", "criado_em"]
    list_filter = ["status"]
