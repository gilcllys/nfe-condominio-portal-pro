from rest_framework import serializers

from providers.models import Contract, Provider


class AnalyzeRiskSerializer(serializers.Serializer):
    cnpjData = serializers.DictField()


class ProviderSerializer(serializers.ModelSerializer):
    class Meta:
        model = Provider
        fields = [
            "id", "condo_id", "document", "legal_name",
            "trade_name", "phone", "email", "address",
            "neighborhood", "cidade", "estado", "zip_code",
            "tipo_servico", "observacoes", "status", "risk_score",
            "deleted_at", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class ContractSerializer(serializers.ModelSerializer):
    class Meta:
        model = Contract
        fields = [
            "id", "condo_id", "provider_id", "title",
            "description", "contract_type", "value",
            "start_date", "end_date", "file_url", "status",
            "created_by", "created_at", "updated_at",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]
