from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from contas.models import Usuario


class TokenObtainPairCustomSerializer(TokenObtainPairSerializer):
    """
    Customiza o JWT para incluir dados do usuario no token e na resposta.
    O frontend recebe access, refresh e dados do usuario em uma unica chamada.
    """

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        # Claims customizados dentro do JWT
        token["email"] = user.email
        token["nome"] = user.nome_completo
        return token

    def validate(self, attrs):
        data = super().validate(attrs)
        # Adiciona dados do usuario na resposta JSON (fora do token)
        data["usuario"] = {
            "id": str(self.user.id),
            "email": self.user.email,
            "nome_completo": self.user.nome_completo,
        }
        return data


class UsuarioSerializer(serializers.ModelSerializer):
    nome_completo = serializers.CharField(source="nome_completo", read_only=True)

    class Meta:
        model = Usuario
        fields = [
            "id",
            "email",
            "first_name",
            "last_name",
            "nome_completo",
            "cpf",
            "telefone",
            "data_nascimento",
            "is_active",
            "criado_em",
            "atualizado_em",
        ]
        read_only_fields = ["id", "criado_em", "atualizado_em"]


class UsuarioResumoSerializer(serializers.ModelSerializer):
    """Serializer resumido para uso em listagens."""

    nome_completo = serializers.CharField(source="nome_completo", read_only=True)

    class Meta:
        model = Usuario
        fields = ["id", "email", "nome_completo"]
        read_only_fields = ["id"]


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    senha = serializers.CharField(write_only=True)


class CadastroSerializer(serializers.Serializer):
    email = serializers.EmailField()
    senha = serializers.CharField(write_only=True)
    primeiro_nome = serializers.CharField()
    sobrenome = serializers.CharField()
    cpf = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    telefone = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    data_nascimento = serializers.DateField(required=False, allow_null=True)
    condominio_id = serializers.UUIDField()
    bloco = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    unidade = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    unidade_label = serializers.CharField(required=False, allow_blank=True, allow_null=True)


class OnboardingSerializer(serializers.Serializer):
    """Serializer para cadastro inicial: condominio + sindico de uma vez."""

    # Dados do sindico
    email = serializers.EmailField()
    senha = serializers.CharField(write_only=True)
    primeiro_nome = serializers.CharField()
    sobrenome = serializers.CharField()
    cpf = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    telefone = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    # Dados do condominio
    condominio_nome = serializers.CharField()
    condominio_documento = serializers.CharField(
        required=False, allow_blank=True, allow_null=True
    )
    condominio_endereco = serializers.CharField(
        required=False, allow_blank=True, allow_null=True
    )
    condominio_cidade = serializers.CharField(
        required=False, allow_blank=True, allow_null=True
    )
    condominio_estado = serializers.CharField(
        required=False, allow_blank=True, allow_null=True, max_length=2
    )
    condominio_cep = serializers.CharField(
        required=False, allow_blank=True, allow_null=True, max_length=10
    )


class AlterarSenhaSerializer(serializers.Serializer):
    senha_atual = serializers.CharField(write_only=True, required=False)
    nova_senha = serializers.CharField(write_only=True)
