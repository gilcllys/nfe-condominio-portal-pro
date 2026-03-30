import uuid

from django.db import models


class Chamado(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    titulo = models.TextField()
    descricao = models.TextField(blank=True, null=True)
    unidade = models.TextField(blank=True, null=True)
    bloco = models.TextField(blank=True, null=True)
    status = models.TextField(default="pendente_triagem")
    criado_por = models.UUIDField(blank=True, null=True)
    condominio_id = models.UUIDField(blank=True, null=True)
    service_order_id = models.UUIDField(blank=True, null=True)
    close_reason = models.TextField(blank=True, null=True)
    prioridade = models.TextField(default="media")
    categoria = models.TextField(blank=True, null=True)
    tipo_execucao = models.TextField(blank=True, null=True)
    emergencial = models.BooleanField(default=False)
    motivo_cancelamento = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "chamados"


class Ticket(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    opened_by_user_id = models.UUIDField()
    unit_id = models.UUIDField(blank=True, null=True)
    title = models.TextField(blank=True, null=True)
    description = models.TextField()
    category = models.TextField(default="ELETRICA")
    priority = models.TextField(default="Media")
    status = models.TextField(default="ABERTO")
    rejection_reason = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "tickets"


class TicketFile(models.Model):
    ticket_id = models.UUIDField()
    file_id = models.UUIDField()

    class Meta:
        db_table = "ticket_files"
        unique_together = [("ticket_id", "file_id")]


class Dossier(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    work_order_id = models.UUIDField()
    file_id = models.UUIDField()
    hash_algorithm = models.TextField(default="SHA-256")
    hash_hex = models.TextField()
    generated_at = models.DateTimeField(auto_now_add=True)
    generated_by_user_id = models.UUIDField()

    class Meta:
        db_table = "dossiers"


class WorkOrder(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    ticket_id = models.UUIDField()
    created_by_user_id = models.UUIDField()
    os_number = models.BigIntegerField()
    os_type = models.TextField(blank=True, null=True)
    is_emergency = models.BooleanField(default=False)
    emergency_justification = models.TextField(blank=True, null=True)
    status = models.TextField(default="CRIADA")
    provider_id = models.UUIDField(blank=True, null=True)
    started_at = models.DateTimeField(blank=True, null=True)
    finished_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "work_orders"


class WorkOrderEvidence(models.Model):
    work_order_id = models.UUIDField()
    file_id = models.UUIDField()
    phase = models.TextField()

    class Meta:
        db_table = "work_order_evidence"
        unique_together = [("work_order_id", "file_id")]


class ServiceOrder(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    created_by = models.UUIDField()
    title = models.TextField()
    description = models.TextField(blank=True, null=True)
    location = models.TextField(blank=True, null=True)
    status = models.TextField(default="ABERTA")
    executor_type = models.TextField(blank=True, null=True)
    executor_name = models.TextField(blank=True, null=True)
    execution_notes = models.TextField(blank=True, null=True)
    priority = models.TextField(default="MEDIA")
    is_emergency = models.BooleanField(default=False)
    emergency_justification = models.TextField(blank=True, null=True)
    started_at = models.DateTimeField(blank=True, null=True)
    finished_at = models.DateTimeField(blank=True, null=True)
    provider_id = models.UUIDField(blank=True, null=True)
    os_number = models.BigIntegerField(blank=True, null=True)
    final_pdf_url = models.TextField(blank=True, null=True)
    chamado_id = models.UUIDField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "service_orders"


class ServiceOrderPhoto(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    service_order = models.ForeignKey(ServiceOrder, on_delete=models.CASCADE, db_column="service_order_id")
    photo_type = models.TextField()
    file_url = models.TextField()
    observation = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "service_order_photos"


class ServiceOrderMaterial(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    service_order = models.ForeignKey(ServiceOrder, on_delete=models.CASCADE, db_column="service_order_id")
    stock_item_id = models.UUIDField()
    quantity = models.DecimalField(max_digits=12, decimal_places=2)
    unit = models.TextField()
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "service_order_materials"


class ServiceOrderActivity(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    service_order = models.ForeignKey(ServiceOrder, on_delete=models.CASCADE, db_column="service_order_id")
    user = models.ForeignKey("core.User", on_delete=models.SET_NULL, null=True, db_column="user_id")
    activity_type = models.TextField()
    description = models.TextField(blank=True, null=True)
    metadata = models.JSONField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "service_order_activities"


class ServiceOrderApproval(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    service_order = models.ForeignKey(ServiceOrder, on_delete=models.CASCADE, db_column="service_order_id")
    approved_by = models.UUIDField()
    approver_role = models.TextField()
    decision = models.TextField()
    notes = models.TextField(blank=True, null=True)
    response_status = models.TextField(default="PENDENTE")
    due_at = models.DateTimeField(blank=True, null=True)
    responded_at = models.DateTimeField(blank=True, null=True)
    justification = models.TextField(blank=True, null=True)
    approval_type = models.TextField(default="ORCAMENTO")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "service_order_approvals"


class ServiceOrderDocument(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    service_order = models.ForeignKey(ServiceOrder, on_delete=models.CASCADE, db_column="service_order_id")
    fiscal_document_id = models.UUIDField()
    document_kind = models.TextField()
    notes = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "service_order_documents"


class ServiceOrderQuote(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    service_order = models.ForeignKey(ServiceOrder, on_delete=models.CASCADE, db_column="service_order_id")
    provider_name = models.TextField()
    value = models.DecimalField(max_digits=12, decimal_places=2)
    description = models.TextField(blank=True, null=True)
    file_url = models.TextField(blank=True, null=True)
    created_by = models.UUIDField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "service_order_quotes"


class ServiceOrderVote(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    service_order = models.ForeignKey(ServiceOrder, on_delete=models.CASCADE, db_column="service_order_id")
    user = models.ForeignKey("core.User", on_delete=models.CASCADE, db_column="user_id")
    role = models.TextField()
    vote = models.TextField()
    justification = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "service_order_votes"


class Approval(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    actor_user_id = models.UUIDField()
    action = models.TextField(blank=True, null=True)
    approved_budget_id = models.UUIDField(blank=True, null=True)
    review_reason = models.TextField(blank=True, null=True)
    review_details = models.TextField(blank=True, null=True)
    service_order_id = models.UUIDField(blank=True, null=True)
    budget_id = models.UUIDField(blank=True, null=True)
    approver_role = models.TextField(default="sindico")
    decision = models.TextField(blank=True, null=True)
    responded_at = models.DateTimeField(blank=True, null=True)
    expires_at = models.DateTimeField(blank=True, null=True)
    is_minerva = models.BooleanField(default=False)
    minerva_justification = models.TextField(blank=True, null=True)
    approval_type = models.TextField(default="ORCAMENTO")
    approver_id = models.UUIDField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "approvals"


class Budget(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    provider = models.ForeignKey("providers.Provider", on_delete=models.CASCADE, db_column="provider_id")
    amount_cents = models.BigIntegerField(blank=True, null=True)
    file_id = models.UUIDField(blank=True, null=True)
    created_by_user_id = models.UUIDField(blank=True, null=True)
    service_order_id = models.UUIDField(blank=True, null=True)
    status = models.TextField(default="pendente")
    description = models.TextField(blank=True, null=True)
    valid_until = models.DateField(blank=True, null=True)
    alcada_nivel = models.IntegerField(default=1)
    total_value = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    expires_at = models.DateTimeField(blank=True, null=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "budgets"
