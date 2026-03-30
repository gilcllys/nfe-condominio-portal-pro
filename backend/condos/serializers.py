from rest_framework import serializers

from condos.models import (
    Approval,
    Budget,
    ServiceOrder,
    ServiceOrderActivity,
    ServiceOrderMaterial,
    ServiceOrderPhoto,
    Ticket,
)


class GenerateInviteSerializer(serializers.Serializer):
    condoId = serializers.UUIDField()
    action = serializers.ChoiceField(choices=["deactivate"], required=False, allow_null=True)


class TicketSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ticket
        fields = [
            "id", "condo_id", "title", "description",
            "category", "priority", "status",
            "opened_by_user_id", "unit_id", "rejection_reason",
            "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class ServiceOrderSerializer(serializers.ModelSerializer):
    photo_count = serializers.IntegerField(read_only=True, default=0)

    class Meta:
        model = ServiceOrder
        fields = [
            "id", "condo_id", "title", "description",
            "location", "status", "priority", "is_emergency",
            "executor_type", "provider_id", "chamado_id",
            "final_pdf_url", "created_by", "created_at",
            "photo_count", "os_number",
        ]
        read_only_fields = ["id", "created_at"]


class ServiceOrderPhotoSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceOrderPhoto
        fields = [
            "id", "service_order_id", "photo_type",
            "file_url", "observation", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class ServiceOrderMaterialSerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceOrderMaterial
        fields = [
            "id", "service_order_id", "stock_item_id",
            "quantity", "unit", "notes", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class ServiceOrderActivitySerializer(serializers.ModelSerializer):
    class Meta:
        model = ServiceOrderActivity
        fields = [
            "id", "service_order_id", "user_id",
            "activity_type", "description", "metadata", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class ApprovalSerializer(serializers.ModelSerializer):
    class Meta:
        model = Approval
        fields = [
            "id", "service_order_id", "condo_id",
            "approver_id", "approver_role", "approval_type",
            "decision", "review_reason", "review_details",
            "expires_at", "responded_at", "is_minerva",
            "minerva_justification", "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class BudgetSerializer(serializers.ModelSerializer):
    class Meta:
        model = Budget
        fields = [
            "id", "service_order_id", "condo_id",
            "provider_id", "description", "total_value",
            "status", "valid_until", "created_by_user_id",
            "alcada_nivel", "amount_cents", "created_at",
        ]
        read_only_fields = ["id", "created_at"]
