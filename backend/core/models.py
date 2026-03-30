import uuid

from django.db import models


class Condo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    name = models.TextField()
    document = models.TextField(blank=True, null=True)
    invite_code = models.TextField(blank=True, null=True)
    invite_active = models.BooleanField(default=False)
    subscription_status = models.TextField(default="trial")
    subscription_id = models.TextField(blank=True, null=True)
    subscription_expires_at = models.DateTimeField(blank=True, null=True)
    pagarme_customer_id = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "condos"

    def __str__(self):
        return self.name or str(self.id)


class CondoFinancialConfig(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.OneToOneField(Condo, on_delete=models.CASCADE, db_column="condo_id")
    alcada_1_limite = models.DecimalField(max_digits=10, decimal_places=2, default=500)
    alcada_2_limite = models.DecimalField(max_digits=10, decimal_places=2, default=2000)
    alcada_3_limite = models.DecimalField(max_digits=10, decimal_places=2, default=10000)
    approval_deadline_hours = models.IntegerField(default=48)
    notify_residents_above = models.DecimalField(max_digits=10, decimal_places=2, default=10000)
    monthly_limit_manutencao = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    monthly_limit_limpeza = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    monthly_limit_seguranca = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    annual_budget = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    annual_budget_alert_pct = models.IntegerField(default=70)
    monthly_budget = models.DecimalField(max_digits=12, decimal_places=2, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "condo_financial_config"


class CondoApprovalPolicy(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    policy_type = models.TextField()
    use_amount_limit = models.BooleanField(default=False)
    min_amount = models.DecimalField(max_digits=14, decimal_places=2, blank=True, null=True)
    max_amount = models.DecimalField(max_digits=14, decimal_places=2, blank=True, null=True)
    require_sindico = models.BooleanField(default=True)
    require_sub_sindico = models.BooleanField(default=False)
    require_conselho_fiscal = models.BooleanField(default=False)
    decision_mode = models.TextField(default="MAIORIA")
    syndic_tiebreaker = models.BooleanField(default=True)
    active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "condo_approval_policies"


class User(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    auth_user_id = models.UUIDField(unique=True, blank=True, null=True)
    full_name = models.TextField()
    email = models.TextField()
    password_hash = models.TextField(blank=True, null=True)
    cpf_rg = models.TextField(blank=True, null=True)
    birth_date = models.DateField(blank=True, null=True)
    profile = models.TextField(default="MORADOR")
    is_active = models.BooleanField(default=True)
    status = models.TextField(default="ativo", blank=True, null=True)
    residence_type = models.TextField(blank=True, null=True)
    condo = models.ForeignKey(Condo, on_delete=models.SET_NULL, blank=True, null=True, db_column="condo_id")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "users"

    def __str__(self):
        return self.full_name or str(self.id)


class UserCondo(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    user = models.ForeignKey(User, on_delete=models.CASCADE, db_column="user_id")
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    role = models.TextField(default="MORADOR")
    is_default = models.BooleanField(default=False)
    status = models.TextField(default="ativo")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "user_condos"


class UserSession(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    user = models.ForeignKey(User, on_delete=models.CASCADE, db_column="user_id")
    session_token = models.TextField()
    expires_at = models.DateTimeField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "user_sessions"


class Resident(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    unit_id = models.UUIDField(blank=True, null=True)
    full_name = models.TextField()
    document = models.TextField(blank=True, null=True)
    email = models.TextField(blank=True, null=True)
    phone = models.TextField(blank=True, null=True)
    unit_label = models.TextField(blank=True, null=True)
    block = models.TextField(blank=True, null=True)
    unit = models.TextField(blank=True, null=True)
    residence_type = models.TextField(blank=True, null=True)
    tower_block = models.TextField(blank=True, null=True)
    apartment_number = models.TextField(blank=True, null=True)
    street = models.TextField(blank=True, null=True)
    street_number = models.TextField(blank=True, null=True)
    complement = models.TextField(blank=True, null=True)
    cpf_rg = models.TextField(blank=True, null=True)
    birth_date = models.DateField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "residents"


class Unit(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    code = models.TextField()
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "units"


class UserUnit(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, db_column="user_id")
    unit = models.ForeignKey(Unit, on_delete=models.CASCADE, db_column="unit_id")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "user_units"
        unique_together = [("user", "unit")]


class ActivityLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, db_column="user_id")
    action = models.TextField()
    entity = models.TextField(blank=True, null=True)
    entity_id = models.UUIDField(blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "activity_logs"


class AuditEvent(models.Model):
    id = models.BigAutoField(primary_key=True)
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    actor_user_id = models.UUIDField(blank=True, null=True)
    entity_type = models.TextField()
    entity_id = models.UUIDField(blank=True, null=True)
    event_type = models.TextField()
    event_at = models.DateTimeField(auto_now_add=True)
    details = models.JSONField(blank=True, null=True)

    class Meta:
        db_table = "audit_events"


class SindicoTransferLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    old_user_id = models.UUIDField()
    new_user_id = models.UUIDField()
    changed_by = models.UUIDField(blank=True, null=True)
    old_role = models.TextField(blank=True, null=True)
    new_role = models.TextField(blank=True, null=True)
    old_user_deactivated = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "sindico_transfer_logs"


class Subscription(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    provider = models.TextField(default="ASAAS")
    external_customer_id = models.TextField(blank=True, null=True)
    external_subscription_id = models.TextField(blank=True, null=True)
    status = models.TextField(default="ATIVO")
    updated_at = models.DateTimeField(auto_now=True)
    created_at = models.DateTimeField(auto_now_add=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "subscriptions"


class File(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey(Condo, on_delete=models.CASCADE, db_column="condo_id")
    kind = models.TextField()
    storage_key = models.TextField()
    file_name = models.TextField()
    content_type = models.TextField()
    size_bytes = models.BigIntegerField()
    sha256_hex = models.TextField(blank=True, null=True)
    created_by_user_id = models.UUIDField()
    created_at = models.DateTimeField(auto_now_add=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "files"
