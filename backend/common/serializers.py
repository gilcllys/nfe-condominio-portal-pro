from rest_framework import serializers


class SerializerBase(serializers.ModelSerializer):
    """
    Serializer base que garante que id, criado_em e atualizado_em
    sao sempre read_only em todos os serializers filhos.
    """

    class Meta:
        abstract = True

    def get_fields(self):
        fields = super().get_fields()
        for campo in ("id", "criado_em", "atualizado_em"):
            if campo in fields:
                fields[campo].read_only = True
        return fields
