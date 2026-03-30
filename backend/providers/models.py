import uuid

from django.db import models


class Provider(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    legal_name = models.TextField()
    trade_name = models.TextField(blank=True, null=True)
    document = models.TextField(blank=True, null=True)
    email = models.TextField(blank=True, null=True)
    phone = models.TextField(blank=True, null=True)
    has_restriction = models.BooleanField(default=False)
    restriction_note = models.TextField(blank=True, null=True)
    address = models.TextField(blank=True, null=True)
    neighborhood = models.TextField(blank=True, null=True)
    zip_code = models.TextField(blank=True, null=True)
    website = models.TextField(blank=True, null=True)
    legal_nature = models.TextField(blank=True, null=True)
    share_capital = models.DecimalField(max_digits=15, decimal_places=2, blank=True, null=True)
    company_size = models.TextField(blank=True, null=True)
    opening_date = models.DateField(blank=True, null=True)
    main_activity = models.TextField(blank=True, null=True)
    risk_score = models.IntegerField(blank=True, null=True)
    risk_level = models.TextField(blank=True, null=True)
    tipo_servico = models.TextField(blank=True, null=True)
    status = models.TextField(default="ativo")
    observacoes = models.TextField(blank=True, null=True)
    cidade = models.TextField(blank=True, null=True)
    estado = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "providers"

    def __str__(self):
        return self.trade_name or self.legal_name or str(self.id)


class ProviderRiskAnalysis(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    provider = models.ForeignKey(Provider, on_delete=models.CASCADE, db_column="provider_id", blank=True, null=True)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id", blank=True, null=True)
    score = models.IntegerField(blank=True, null=True)
    nivel_risco = models.TextField(blank=True, null=True)
    situacao_receita = models.TextField(blank=True, null=True)
    possui_protestos = models.BooleanField(default=False)
    possui_processos = models.BooleanField(default=False)
    noticias_negativas = models.BooleanField(default=False)
    historico_interno = models.TextField(blank=True, null=True)
    recomendacao = models.TextField(blank=True, null=True)
    relatorio_completo = models.TextField(blank=True, null=True)
    consultado_em = models.DateTimeField(blank=True, null=True)
    consultado_por = models.UUIDField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "provider_risk_analysis"


class Contract(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    provider = models.ForeignKey(Provider, on_delete=models.SET_NULL, null=True, blank=True, db_column="provider_id")
    title = models.TextField()
    description = models.TextField(blank=True, null=True)
    contract_type = models.TextField(default="OUTROS")
    value = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    start_date = models.DateField(blank=True, null=True)
    end_date = models.DateField(blank=True, null=True)
    file_url = models.TextField(blank=True, null=True)
    status = models.TextField(default="RASCUNHO")
    created_by = models.UUIDField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "contracts"
