from django.contrib import admin

from contas.models import Usuario


@admin.register(Usuario)
class UsuarioAdmin(admin.ModelAdmin):
    list_display = ["email", "first_name", "last_name", "is_active", "is_staff", "criado_em"]
    list_filter = ["is_active", "is_staff"]
    search_fields = ["email", "first_name", "last_name", "cpf"]
    ordering = ["-criado_em"]
