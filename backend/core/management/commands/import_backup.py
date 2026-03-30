"""
Django management command to import data from Supabase backup SQL.

Reads the backup_supabse.sql file, extracts COPY data sections,
and inserts them into the public schema Django-managed tables.
"""

import re
import uuid
from io import StringIO

from django.core.management.base import BaseCommand
from django.db import connection


# Mapping: nfe_vigia table → public table, with column mapping
# Format: (backup_table, django_table, [(backup_col, django_col), ...])
# If django_col is None, the column is skipped
TABLE_MAPPINGS = {
    "condos": {
        "target": "condos",
        "columns": [
            ("id", "id"),
            ("name", "name"),
            ("document", "document"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("deleted_at", "deleted_at"),
            ("invite_code", "invite_code"),
            ("invite_active", "invite_active"),
            ("subscription_status", "subscription_status"),
            ("subscription_id", "subscription_id"),
            ("subscription_expires_at", "subscription_expires_at"),
            ("pagarme_customer_id", "pagarme_customer_id"),
        ],
    },
    "users": {
        "target": "users",
        "columns": [
            ("id", "id"),
            ("auth_user_id", "auth_user_id"),
            ("condo_id", "condo_id"),
            ("full_name", "full_name"),
            ("email", "email"),
            ("profile", "profile"),
            ("is_active", "is_active"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("deleted_at", "deleted_at"),
            ("status", "status"),
            ("cpf_rg", "cpf_rg"),
            ("birth_date", "birth_date"),
            ("residence_type", "residence_type"),
        ],
    },
    "user_condos": {
        "target": "user_condos",
        "columns": [
            ("id", "id"),
            ("user_id", "user_id"),
            ("condo_id", "condo_id"),
            ("role", "role"),
            ("is_default", "is_default"),
            ("created_at", "created_at"),
            ("status", "status"),
        ],
    },
    "user_sessions": None,  # Skip: old Supabase sessions are not valid
    "residents": {
        "target": "residents",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("unit_id", "unit_id"),
            ("full_name", "full_name"),
            ("document", "document"),
            ("email", "email"),
            ("phone", "phone"),
            ("created_at", "created_at"),
            ("unit_label", "unit_label"),
            ("block", "block"),
            ("unit", "unit"),
            ("residence_type", "residence_type"),
            ("tower_block", "tower_block"),
            ("apartment_number", "apartment_number"),
            ("street", "street"),
            ("street_number", "street_number"),
            ("complement", "complement"),
            ("cpf_rg", "cpf_rg"),
            ("birth_date", "birth_date"),
        ],
    },
    "units": {
        "target": "units",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("code", "code"),
            ("description", "description"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("deleted_at", "deleted_at"),
        ],
    },
    "condo_financial_config": {
        "target": "condo_financial_config",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("alcada_1_limite", "alcada_1_limite"),
            ("alcada_2_limite", "alcada_2_limite"),
            ("alcada_3_limite", "alcada_3_limite"),
            ("approval_deadline_hours", "approval_deadline_hours"),
            ("notify_residents_above", "notify_residents_above"),
            ("monthly_limit_manutencao", "monthly_limit_manutencao"),
            ("monthly_limit_limpeza", "monthly_limit_limpeza"),
            ("monthly_limit_seguranca", "monthly_limit_seguranca"),
            ("annual_budget", "annual_budget"),
            ("annual_budget_alert_pct", "annual_budget_alert_pct"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("monthly_budget", "monthly_budget"),
        ],
    },
    "condo_approval_policies": {
        "target": "condo_approval_policies",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("policy_type", "policy_type"),
            ("use_amount_limit", "use_amount_limit"),
            ("min_amount", "min_amount"),
            ("max_amount", "max_amount"),
            ("require_sindico", "require_sindico"),
            ("require_sub_sindico", "require_sub_sindico"),
            ("require_conselho_fiscal", "require_conselho_fiscal"),
            ("decision_mode", "decision_mode"),
            ("syndic_tiebreaker", "syndic_tiebreaker"),
            ("active", "active"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
        ],
    },
    "providers": {
        "target": "providers",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("legal_name", "legal_name"),
            ("trade_name", "trade_name"),
            ("document", "document"),
            ("email", "email"),
            ("phone", "phone"),
            ("has_restriction", "has_restriction"),
            ("restriction_note", "restriction_note"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("deleted_at", "deleted_at"),
            ("address", "address"),
            ("neighborhood", "neighborhood"),
            ("zip_code", "zip_code"),
            ("website", "website"),
            ("legal_nature", "legal_nature"),
            ("share_capital", "share_capital"),
            ("company_size", "company_size"),
            ("opening_date", "opening_date"),
            ("main_activity", "main_activity"),
            ("risk_score", "risk_score"),
            ("risk_level", "risk_level"),
            ("tipo_servico", "tipo_servico"),
            ("status", "status"),
            ("observacoes", "observacoes"),
            ("cidade", "cidade"),
            ("estado", "estado"),
        ],
    },
    "provider_risk_analysis": {
        "target": "provider_risk_analysis",
        "columns": [
            ("id", "id"),
            ("provider_id", "provider_id"),
            ("condo_id", "condo_id"),
            ("score", "score"),
            ("nivel_risco", "nivel_risco"),
            ("situacao_receita", "situacao_receita"),
            ("possui_protestos", "possui_protestos"),
            ("possui_processos", "possui_processos"),
            ("noticias_negativas", "noticias_negativas"),
            ("historico_interno", "historico_interno"),
            ("recomendacao", "recomendacao"),
            ("relatorio_completo", "relatorio_completo"),
            ("consultado_em", "consultado_em"),
            ("consultado_por", "consultado_por"),
            ("created_at", "created_at"),
        ],
    },
    "contracts": {
        "target": "contracts",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("provider_id", "provider_id"),
            ("title", "title"),
            ("description", "description"),
            ("contract_type", "contract_type"),
            ("value", "value"),
            ("start_date", "start_date"),
            ("end_date", "end_date"),
            ("file_url", "file_url"),
            ("status", "status"),
            ("created_by", "created_by"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
        ],
    },
    "fiscal_documents": {
        "target": "fiscal_documents",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("created_by", "created_by"),
            ("document_type", "document_type"),
            ("source_type", "source_type"),
            ("issuer_name", "issuer_name"),
            ("issuer_document", "issuer_document"),
            ("taker_name", "taker_name"),
            ("taker_document", "taker_document"),
            ("document_number", "document_number"),
            ("series", "series"),
            ("verification_code", "verification_code"),
            ("issue_date", "issue_date"),
            ("service_city", "service_city"),
            ("service_state", "service_state"),
            ("gross_amount", "gross_amount"),
            ("net_amount", "net_amount"),
            ("tax_amount", "tax_amount"),
            ("status", "status"),
            ("access_key", "access_key"),
            ("file_url", "file_url"),
            ("raw_payload", "raw_payload"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("service_order_id", "service_order_id"),
            ("approval_status", "approval_status"),
            ("approved_by_subsindico", "approved_by_subsindico"),
            ("approved_by_subsindico_at", "approved_by_subsindico_at"),
            ("sindico_voto_minerva", "sindico_voto_minerva"),
            ("sindico_voto_at", "sindico_voto_at"),
            ("alcada_nivel", "alcada_nivel"),
            ("notify_residents", "notify_residents"),
            ("amount", "amount"),
            ("supplier", "supplier"),
            ("number", "number"),
        ],
    },
    "fiscal_document_approvals": {
        "target": "fiscal_document_approvals",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("fiscal_document_id", "fiscal_document_id"),
            ("approver_user_id", "approver_user_id"),
            ("approver_role", "approver_role"),
            ("decision", "decision"),
            ("justification", "justification"),
            ("voted_at", "voted_at"),
            ("created_at", "created_at"),
            ("expires_at", "expires_at"),
            ("is_minerva", "is_minerva"),
            ("minerva_justification", "minerva_justification"),
        ],
    },
    "fiscal_document_items": {
        "target": "fiscal_document_items",
        "columns": [
            ("id", "id"),
            ("fiscal_document_id", "fiscal_document_id"),
            ("stock_item_id", "stock_item_id"),
            ("qty", "qty"),
            ("unit_price", "unit_price"),
            ("description", "description"),
            ("created_at", "created_at"),
        ],
    },
    "invoices": {
        "target": "invoices",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("invoice_type", "invoice_type"),
            ("work_order_id", "work_order_id"),
            ("provider_id", "provider_id"),
            ("invoice_number", "invoice_number"),
            ("invoice_key", "invoice_key"),
            ("issued_at", "issued_at"),
            ("amount_cents", "amount_cents"),
            ("file_id", "file_id"),
            ("created_by_user_id", "created_by_user_id"),
            ("created_at", "created_at"),
            ("deleted_at", "deleted_at"),
        ],
    },
    "stock_categories": {
        "target": "stock_categories",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("name", "name"),
            ("description", "description"),
            ("created_at", "created_at"),
        ],
    },
    "stock_items": {
        "target": "stock_items",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("name", "name"),
            ("unit", "unit"),
            ("min_qty", "min_qty"),
            ("is_active", "is_active"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("deleted_at", "deleted_at"),
            ("category_id", "category_id"),
            ("description", "description"),
        ],
    },
    "stock_movements": {
        "target": "stock_movements",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("item_id", "item_id"),
            ("move_type", "move_type"),
            ("qty", "qty"),
            ("unit_cost_cents", "unit_cost_cents"),
            ("supplier_name", "supplier_name"),
            ("note", "note"),
            ("moved_by_user_id", "moved_by_user_id"),
            ("moved_at", "moved_at"),
            ("deleted_at", "deleted_at"),
            ("destination", "destination"),
            ("service_order_id", "service_order_id"),
            ("fiscal_document_id", "fiscal_document_id"),
        ],
    },
    "subscriptions": {
        "target": "subscriptions",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("provider", "provider"),
            ("external_customer_id", "external_customer_id"),
            ("external_subscription_id", "external_subscription_id"),
            ("status", "status"),
            ("updated_at", "updated_at"),
            ("created_at", "created_at"),
            ("deleted_at", "deleted_at"),
        ],
    },
    "files": {
        "target": "files",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("kind", "kind"),
            ("storage_key", "storage_key"),
            ("file_name", "file_name"),
            ("content_type", "content_type"),
            ("size_bytes", "size_bytes"),
            ("sha256_hex", "sha256_hex"),
            ("created_by_user_id", "created_by_user_id"),
            ("created_at", "created_at"),
            ("deleted_at", "deleted_at"),
        ],
    },
    "chamados": {
        "target": "chamados",
        "columns": [
            ("id", "id"),
            ("titulo", "titulo"),
            ("descricao", "descricao"),
            ("unidade", "unidade"),
            ("bloco", "bloco"),
            ("status", "status"),
            ("criado_por", "criado_por"),
            ("condominio_id", "condominio_id"),
            ("service_order_id", "service_order_id"),
            ("close_reason", "close_reason"),
            ("prioridade", "prioridade"),
            ("categoria", "categoria"),
            ("tipo_execucao", "tipo_execucao"),
            ("emergencial", "emergencial"),
            ("motivo_cancelamento", "motivo_cancelamento"),
            ("created_at", "created_at"),
        ],
    },
    "tickets": {
        "target": "tickets",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("opened_by_user_id", "opened_by_user_id"),
            ("unit_id", "unit_id"),
            ("title", "title"),
            ("description", "description"),
            ("category", "category"),
            ("priority", "priority"),
            ("status", "status"),
            ("rejection_reason", "rejection_reason"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("deleted_at", "deleted_at"),
        ],
    },
    "ticket_files": {
        "target": "ticket_files",
        "columns": [
            ("ticket_id", "ticket_id"),
            ("file_id", "file_id"),
        ],
    },
    "service_orders": {
        "target": "service_orders",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("created_by", "created_by"),
            ("title", "title"),
            ("description", "description"),
            ("location", "location"),
            ("status", "status"),
            ("executor_type", "executor_type"),
            ("executor_name", "executor_name"),
            ("execution_notes", "execution_notes"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("priority", "priority"),
            ("is_emergency", "is_emergency"),
            ("emergency_justification", "emergency_justification"),
            ("started_at", "started_at"),
            ("finished_at", "finished_at"),
            ("provider_id", "provider_id"),
            ("os_number", "os_number"),
            ("final_pdf_url", "final_pdf_url"),
            ("chamado_id", "chamado_id"),
        ],
    },
    "service_order_activities": {
        "target": "service_order_activities",
        "columns": [
            ("id", "id"),
            ("service_order_id", "service_order_id"),
            ("user_id", "user_id"),
            ("activity_type", "activity_type"),
            ("description", "description"),
            ("metadata", "metadata"),
            ("created_at", "created_at"),
        ],
    },
    "service_order_approvals": {
        "target": "service_order_approvals",
        "columns": [
            ("id", "id"),
            ("service_order_id", "service_order_id"),
            ("approved_by", "approved_by"),
            ("approver_role", "approver_role"),
            ("decision", "decision"),
            ("notes", "notes"),
            ("created_at", "created_at"),
            ("response_status", "response_status"),
            ("due_at", "due_at"),
            ("responded_at", "responded_at"),
            ("justification", "justification"),
            ("approval_type", "approval_type"),
        ],
    },
    "service_order_documents": {
        "target": "service_order_documents",
        "columns": [
            ("id", "id"),
            ("service_order_id", "service_order_id"),
            ("fiscal_document_id", "fiscal_document_id"),
            ("document_kind", "document_kind"),
            ("notes", "notes"),
            ("created_at", "created_at"),
        ],
    },
    "service_order_materials": {
        "target": "service_order_materials",
        "columns": [
            ("id", "id"),
            ("service_order_id", "service_order_id"),
            ("stock_item_id", "stock_item_id"),
            ("quantity", "quantity"),
            ("unit", "unit"),
            ("notes", "notes"),
            ("created_at", "created_at"),
        ],
    },
    "service_order_photos": {
        "target": "service_order_photos",
        "columns": [
            ("id", "id"),
            ("service_order_id", "service_order_id"),
            ("photo_type", "photo_type"),
            ("file_url", "file_url"),
            ("created_at", "created_at"),
            ("observation", "observation"),
        ],
    },
    "service_order_quotes": {
        "target": "service_order_quotes",
        "columns": [
            ("id", "id"),
            ("service_order_id", "service_order_id"),
            ("provider_name", "provider_name"),
            ("value", "value"),
            ("description", "description"),
            ("file_url", "file_url"),
            ("created_by", "created_by"),
            ("created_at", "created_at"),
        ],
    },
    "service_order_votes": {
        "target": "service_order_votes",
        "columns": [
            ("id", "id"),
            ("service_order_id", "service_order_id"),
            ("user_id", "user_id"),
            ("role", "role"),
            ("vote", "vote"),
            ("justification", "justification"),
            ("created_at", "created_at"),
        ],
    },
    "approvals": {
        "target": "approvals",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("actor_user_id", "actor_user_id"),
            ("action", "action"),
            ("approved_budget_id", "approved_budget_id"),
            ("review_reason", "review_reason"),
            ("review_details", "review_details"),
            ("created_at", "created_at"),
            ("service_order_id", "service_order_id"),
            ("budget_id", "budget_id"),
            ("approver_role", "approver_role"),
            ("decision", "decision"),
            ("responded_at", "responded_at"),
            ("expires_at", "expires_at"),
            ("is_minerva", "is_minerva"),
            ("minerva_justification", "minerva_justification"),
            ("approval_type", "approval_type"),
            ("approver_id", "approver_id"),
        ],
    },
    "budgets": {
        "target": "budgets",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("provider_id", "provider_id"),
            ("amount_cents", "amount_cents"),
            ("file_id", "file_id"),
            ("created_by_user_id", "created_by_user_id"),
            ("created_at", "created_at"),
            ("deleted_at", "deleted_at"),
            ("service_order_id", "service_order_id"),
            ("status", "status"),
            ("description", "description"),
            ("valid_until", "valid_until"),
            ("alcada_nivel", "alcada_nivel"),
            ("total_value", "total_value"),
            ("expires_at", "expires_at"),
        ],
    },
    "dossiers": {
        "target": "dossiers",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("work_order_id", "work_order_id"),
            ("file_id", "file_id"),
            ("hash_algorithm", "hash_algorithm"),
            ("hash_hex", "hash_hex"),
            ("generated_at", "generated_at"),
            ("generated_by_user_id", "generated_by_user_id"),
        ],
    },
    "work_orders": {
        "target": "work_orders",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("ticket_id", "ticket_id"),
            ("created_by_user_id", "created_by_user_id"),
            ("os_number", "os_number"),
            ("os_type", "os_type"),
            ("is_emergency", "is_emergency"),
            ("emergency_justification", "emergency_justification"),
            ("status", "status"),
            ("provider_id", "provider_id"),
            ("started_at", "started_at"),
            ("finished_at", "finished_at"),
            ("created_at", "created_at"),
            ("updated_at", "updated_at"),
            ("deleted_at", "deleted_at"),
        ],
    },
    "work_order_evidence": {
        "target": "work_order_evidence",
        "columns": [
            ("work_order_id", "work_order_id"),
            ("file_id", "file_id"),
            ("phase", "phase"),
        ],
    },
    "sindico_transfer_logs": {
        "target": "sindico_transfer_logs",
        "columns": [
            ("id", "id"),
            ("condo_id", "condo_id"),
            ("old_user_id", "old_user_id"),
            ("new_user_id", "new_user_id"),
            ("changed_by", "changed_by"),
            ("old_role", "old_role"),
            ("new_role", "new_role"),
            ("old_user_deactivated", "old_user_deactivated"),
            ("created_at", "created_at"),
        ],
    },
    "user_units": {
        "target": "user_units",
        "columns": [
            ("user_id", "user_id"),
            ("unit_id", "unit_id"),
            ("created_at", "created_at"),
        ],
    },
}

# Import order: parent tables first, then dependent tables
IMPORT_ORDER = [
    "condos",
    "users",
    "user_condos",
    "user_sessions",
    "units",
    "user_units",
    "condo_financial_config",
    "condo_approval_policies",
    "residents",
    "providers",
    "provider_risk_analysis",
    "contracts",
    "files",
    "subscriptions",
    "sindico_transfer_logs",
    "chamados",
    "tickets",
    "ticket_files",
    "fiscal_documents",
    "fiscal_document_approvals",
    "fiscal_document_items",
    "invoices",
    "stock_categories",
    "stock_items",
    "stock_movements",
    "service_orders",
    "service_order_activities",
    "service_order_approvals",
    "service_order_documents",
    "service_order_materials",
    "service_order_photos",
    "service_order_quotes",
    "service_order_votes",
    "approvals",
    "budgets",
    "dossiers",
    "work_orders",
    "work_order_evidence",
]


class Command(BaseCommand):
    help = "Import data from Supabase backup SQL file into Django tables"

    def add_arguments(self, parser):
        parser.add_argument(
            "sql_file",
            help="Path to the backup SQL file (backup_supabse.sql)",
        )
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Only parse and show what would be imported",
        )

    def handle(self, *args, **options):
        sql_file = options["sql_file"]
        dry_run = options["dry_run"]

        self.stdout.write(f"Reading backup file: {sql_file}")
        with open(sql_file, "r", encoding="utf-8") as f:
            content = f.read()

        # Parse all COPY blocks from the backup
        copy_blocks = self._parse_copy_blocks(content)
        self.stdout.write(f"Found {len(copy_blocks)} COPY blocks in backup")

        for table_name, info in copy_blocks.items():
            self.stdout.write(
                f"  {table_name}: {len(info['data_lines'])} rows, "
                f"columns: {info['columns']}"
            )

        if dry_run:
            self.stdout.write(self.style.WARNING("\nDry run — no data imported."))
            return

        # Import data in dependency order
        total_imported = 0
        for table_name in IMPORT_ORDER:
            if table_name not in copy_blocks:
                self.stdout.write(f"  Skipping {table_name} (no data in backup)")
                continue

            if table_name not in TABLE_MAPPINGS:
                self.stdout.write(f"  Skipping {table_name} (no mapping defined)")
                continue

            if TABLE_MAPPINGS[table_name] is None:
                self.stdout.write(f"  Skipping {table_name} (explicitly excluded)")
                continue

            count = self._import_table(
                table_name,
                copy_blocks[table_name],
                TABLE_MAPPINGS[table_name],
            )
            total_imported += count

        # Also import audit_events if present (not in mappings since structure differs)
        self.stdout.write(self.style.SUCCESS(
            f"\nImport complete! {total_imported} total rows imported."
        ))

    def _parse_copy_blocks(self, content):
        """Parse COPY ... FROM stdin blocks and extract data."""
        blocks = {}
        lines = content.split("\n")
        i = 0

        while i < len(lines):
            line = lines[i]

            # Match COPY nfe_vigia.tablename (col1, col2, ...) FROM stdin;
            match = re.match(
                r"^COPY nfe_vigia\.(\w+)\s*\(([^)]+)\)\s*FROM stdin;",
                line,
            )
            if match:
                table_name = match.group(1)
                columns = [c.strip() for c in match.group(2).split(",")]

                # Read data lines until \. terminator
                data_lines = []
                i += 1
                while i < len(lines) and lines[i] != "\\.":
                    if lines[i].strip():  # skip empty lines
                        data_lines.append(lines[i])
                    i += 1

                blocks[table_name] = {
                    "columns": columns,
                    "data_lines": data_lines,
                }

            i += 1

        return blocks

    def _import_table(self, source_table, copy_info, mapping):
        """Import data from a parsed COPY block into the Django table."""
        target_table = mapping["target"]
        column_map = mapping["columns"]
        source_columns = copy_info["columns"]
        data_lines = copy_info["data_lines"]

        if not data_lines:
            self.stdout.write(f"  {source_table} → {target_table}: 0 rows (empty)")
            return 0

        # Build column index map: source_col_name → index in COPY data
        source_idx = {col: idx for idx, col in enumerate(source_columns)}

        # Build target columns and their source indices
        target_cols = []
        source_indices = []
        for src_col, tgt_col in column_map:
            if tgt_col is None:
                continue  # skip this column
            if src_col not in source_idx:
                self.stdout.write(
                    self.style.WARNING(
                        f"  Warning: column '{src_col}' not found in "
                        f"backup for {source_table}, skipping"
                    )
                )
                continue
            target_cols.append(tgt_col)
            source_indices.append(source_idx[src_col])

        if not target_cols:
            self.stdout.write(f"  {source_table}: no mappable columns, skipping")
            return 0

        # Parse data rows
        rows = []
        for line in data_lines:
            fields = line.split("\t")
            row = []
            for idx in source_indices:
                if idx < len(fields):
                    val = fields[idx]
                    # Convert \N to None (PostgreSQL NULL)
                    if val == "\\N":
                        row.append(None)
                    else:
                        row.append(val)
                else:
                    row.append(None)
            rows.append(row)

        # Build and execute INSERT
        col_list = ", ".join(f'"{c}"' for c in target_cols)
        placeholders = ", ".join(["%s"] * len(target_cols))
        insert_sql = (
            f'INSERT INTO "{target_table}" ({col_list}) '
            f"VALUES ({placeholders}) "
            f"ON CONFLICT DO NOTHING"
        )

        with connection.cursor() as cursor:
            # Disable triggers temporarily to avoid auto_now issues
            cursor.execute(f'ALTER TABLE "{target_table}" DISABLE TRIGGER ALL')

            inserted = 0
            for row in rows:
                try:
                    cursor.execute(insert_sql, row)
                    inserted += cursor.rowcount
                except Exception as e:
                    self.stdout.write(
                        self.style.ERROR(
                            f"  Error inserting into {target_table}: {e}"
                        )
                    )
                    self.stdout.write(f"  Row data: {row[:5]}...")

            # Re-enable triggers
            cursor.execute(f'ALTER TABLE "{target_table}" ENABLE TRIGGER ALL')

        self.stdout.write(
            f"  {source_table} → {target_table}: {inserted}/{len(rows)} rows imported"
        )
        return inserted
