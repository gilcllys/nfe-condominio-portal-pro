from django.contrib import admin

from fiscal.models import AprovacaoDocFiscal, DocumentoFiscal


@admin.register(DocumentoFiscal)
class DocumentoFiscalAdmin(admin.ModelAdmin):
    list_display = ["numero", "condominio", "tipo_documento", "status", "valor", "criado_em"]
    list_filter = ["status", "tipo_documento", "condominio"]
    search_fields = ["numero", "nome_emissor", "fornecedor"]


@admin.register(AprovacaoDocFiscal)
class AprovacaoDocFiscalAdmin(admin.ModelAdmin):
    list_display = ["documento_fiscal", "aprovador", "decisao", "papel_aprovador"]
    list_filter = ["decisao"]
