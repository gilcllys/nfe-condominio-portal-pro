import uuid

from django.db import models


class FiscalDocument(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    created_by = models.UUIDField(blank=True, null=True)
    document_type = models.TextField(default="NF")
    source_type = models.TextField()
    issuer_name = models.TextField(blank=True, null=True)
    issuer_document = models.TextField(blank=True, null=True)
    taker_name = models.TextField(blank=True, null=True)
    taker_document = models.TextField(blank=True, null=True)
    document_number = models.TextField(blank=True, null=True)
    series = models.TextField(blank=True, null=True)
    verification_code = models.TextField(blank=True, null=True)
    issue_date = models.DateTimeField(blank=True, null=True)
    service_city = models.TextField(blank=True, null=True)
    service_state = models.TextField(blank=True, null=True)
    gross_amount = models.DecimalField(max_digits=14, decimal_places=2, blank=True, null=True)
    net_amount = models.DecimalField(max_digits=14, decimal_places=2, blank=True, null=True)
    tax_amount = models.DecimalField(max_digits=14, decimal_places=2, blank=True, null=True)
    status = models.TextField(default="PENDENTE")
    access_key = models.TextField(blank=True, null=True)
    file_url = models.TextField(blank=True, null=True)
    raw_payload = models.JSONField(blank=True, null=True)
    service_order_id = models.UUIDField(blank=True, null=True)
    approval_status = models.TextField(default="pendente")
    approved_by_subsindico = models.UUIDField(blank=True, null=True)
    approved_by_subsindico_at = models.DateTimeField(blank=True, null=True)
    sindico_voto_minerva = models.BooleanField(default=False)
    sindico_voto_at = models.DateTimeField(blank=True, null=True)
    alcada_nivel = models.IntegerField(default=1)
    notify_residents = models.BooleanField(default=False)
    amount = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    supplier = models.TextField(blank=True, null=True)
    number = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "fiscal_documents"


class FiscalDocumentApproval(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    fiscal_document = models.ForeignKey(FiscalDocument, on_delete=models.CASCADE, db_column="fiscal_document_id")
    approver_user = models.ForeignKey("core.User", on_delete=models.CASCADE, db_column="approver_user_id")
    approver_role = models.TextField()
    decision = models.TextField(blank=True, null=True)
    justification = models.TextField(blank=True, null=True)
    voted_at = models.DateTimeField(blank=True, null=True)
    expires_at = models.DateTimeField(blank=True, null=True)
    is_minerva = models.BooleanField(default=False)
    minerva_justification = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "fiscal_document_approvals"


class FiscalDocumentItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    fiscal_document = models.ForeignKey(FiscalDocument, on_delete=models.CASCADE, db_column="fiscal_document_id")
    stock_item_id = models.UUIDField(blank=True, null=True)
    qty = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    unit_price = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "fiscal_document_items"


class Invoice(models.Model):
    """Legacy invoices table from Supabase backup."""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    invoice_type = models.TextField()
    work_order_id = models.UUIDField(blank=True, null=True)
    provider_id = models.UUIDField(blank=True, null=True)
    invoice_number = models.TextField(blank=True, null=True)
    invoice_key = models.TextField(blank=True, null=True)
    issued_at = models.DateField(blank=True, null=True)
    amount_cents = models.BigIntegerField(blank=True, null=True)
    file_id = models.UUIDField(blank=True, null=True)
    created_by_user_id = models.UUIDField()
    created_at = models.DateTimeField(auto_now_add=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "invoices"


class StockCategory(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    name = models.TextField()
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "stock_categories"


class StockItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    name = models.TextField()
    unit = models.TextField(default="UN")
    min_qty = models.DecimalField(max_digits=18, decimal_places=3, default=0)
    is_active = models.BooleanField(default=True)
    category = models.ForeignKey(StockCategory, on_delete=models.SET_NULL, null=True, blank=True, db_column="category_id")
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        db_table = "stock_items"


class StockMovement(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4)
    condo = models.ForeignKey("core.Condo", on_delete=models.CASCADE, db_column="condo_id")
    item = models.ForeignKey(StockItem, on_delete=models.CASCADE, db_column="item_id")
    move_type = models.TextField()
    qty = models.DecimalField(max_digits=18, decimal_places=3)
    unit_cost_cents = models.BigIntegerField(blank=True, null=True)
    supplier_name = models.TextField(blank=True, null=True)
    note = models.TextField(blank=True, null=True)
    moved_by_user_id = models.UUIDField()
    moved_at = models.DateTimeField(auto_now_add=True)
    deleted_at = models.DateTimeField(blank=True, null=True)
    destination = models.TextField(blank=True, null=True)
    service_order_id = models.UUIDField(blank=True, null=True)
    fiscal_document_id = models.UUIDField(blank=True, null=True)

    class Meta:
        db_table = "stock_movements"
