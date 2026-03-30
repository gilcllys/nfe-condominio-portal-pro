"""Views de autenticacao - login (JWT), cadastro, logout, refresh, etc."""

import logging
from datetime import timedelta

from django.contrib.auth import authenticate
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from contas.models import Usuario
from contas.serializers import (
    CadastroSerializer,
    LoginSerializer,
    OnboardingSerializer,
    TokenObtainPairCustomSerializer,
    UsuarioSerializer,
)

logger = logging.getLogger(__name__)


# ── JWT Token Views ──────────────────────────────────────────────────────────


class LoginView(TokenObtainPairView):
    """
    POST /api/auth/login/

    Recebe email + senha, retorna access + refresh tokens + dados do usuario.
    Usa o SimpleJWT com serializer customizado.

    Request:  { "email": "...", "password": "..." }
    Response: { "access": "...", "refresh": "...", "usuario": {...} }
    """

    serializer_class = TokenObtainPairCustomSerializer


class RefreshTokenView(TokenRefreshView):
    """
    POST /api/auth/refresh/

    Recebe refresh token, retorna novo access token (e novo refresh se ROTATE=True).

    Request:  { "refresh": "..." }
    Response: { "access": "...", "refresh": "..." }
    """

    pass


class LogoutView(APIView):
    """
    POST /api/auth/logout/

    Recebe o refresh token e o invalida (blacklist).
    O access token expira naturalmente apos ACCESS_TOKEN_LIFETIME.

    Request: { "refresh": "..." }
    """

    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if not refresh_token:
            return Response({"success": True})

        try:
            token = RefreshToken(refresh_token)
            token.blacklist()
        except (TokenError, AttributeError):
            # AttributeError se blacklist nao estiver habilitado
            # TokenError se o token for invalido/expirado
            pass

        return Response({"success": True})


# ── Cadastro ──────────────────────────────────────────────────────────────────


class CadastroView(APIView):
    """
    POST /api/auth/cadastro/

    Cria usuario, membro do condominio e morador.
    Retorna tokens JWT para login automatico apos cadastro.
    """

    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = CadastroSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        dados = serializer.validated_data

        email = dados["email"].strip().lower()

        if Usuario.objects.filter(email__iexact=email).exists():
            return Response(
                {"error": "Email ja cadastrado"},
                status=status.HTTP_409_CONFLICT,
            )

        user = Usuario.objects.create_user(
            email=email,
            password=dados["senha"],
            first_name=dados["primeiro_nome"],
            last_name=dados["sobrenome"],
            cpf=dados.get("cpf") or None,
            telefone=dados.get("telefone") or None,
            data_nascimento=dados.get("data_nascimento"),
            is_active=True,
        )

        # Criar membro do condominio (pendente de aprovacao)
        from condominios.models import MembroCondominio

        MembroCondominio.objects.create(
            usuario=user,
            condominio_id=dados["condominio_id"],
            papel=MembroCondominio.Papel.MORADOR,
            status=MembroCondominio.Status.PENDENTE,
            padrao=True,
        )

        # Criar morador
        from moradores.models import Morador

        Morador.objects.create(
            condominio_id=dados["condominio_id"],
            nome_completo=user.nome_completo,
            email=email,
            documento=dados.get("cpf") or None,
            bloco=dados.get("bloco") or None,
            unidade_label=dados.get("unidade") or None,
        )

        # Gerar tokens JWT para login automatico
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "usuario": {
                    "id": str(user.id),
                    "email": user.email,
                    "nome_completo": user.nome_completo,
                },
            },
            status=status.HTTP_201_CREATED,
        )


# ── Recuperar senha ──────────────────────────────────────────────────────────


class RecuperarSenhaView(APIView):
    """POST /api/auth/recuperar-senha/"""

    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        return Response(
            {"message": "Se o email existir, enviaremos instrucoes de recuperacao."}
        )


# ── Views autenticadas ───────────────────────────────────────────────────────


class AtualizarUsuarioView(APIView):
    """PUT /api/auth/atualizar-usuario/"""

    permission_classes = [IsAuthenticated]

    def put(self, request):
        user = request.user
        campos_permitidos = ["first_name", "last_name", "email", "telefone", "cpf"]
        for campo in campos_permitidos:
            if campo in request.data:
                setattr(user, campo, request.data[campo])

        nova_senha = request.data.get("senha")
        if nova_senha:
            user.set_password(nova_senha)

        user.save()
        return Response({"id": str(user.id), "email": user.email})


class UsuarioAtualView(APIView):
    """GET /api/auth/usuario/"""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        serializer = UsuarioSerializer(user)
        return Response(serializer.data)


class OnboardingView(APIView):
    """
    POST /api/auth/onboarding/

    Cadastro inicial: cria condominio + sindico de uma vez.
    Usado quando um novo sindico quer comecar a usar a plataforma.
    Cria: Usuario, Condominio, MembroCondominio(SINDICO), ConfiguracaoFinanceira.
    Retorna tokens JWT para login automatico.
    """

    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = OnboardingSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        dados = serializer.validated_data

        email = dados["email"].strip().lower()

        if Usuario.objects.filter(email__iexact=email).exists():
            return Response(
                {"error": "Email ja cadastrado"},
                status=status.HTTP_409_CONFLICT,
            )

        # 1. Criar usuario
        user = Usuario.objects.create_user(
            email=email,
            password=dados["senha"],
            first_name=dados["primeiro_nome"],
            last_name=dados["sobrenome"],
            cpf=dados.get("cpf") or None,
            telefone=dados.get("telefone") or None,
            is_active=True,
        )

        # 2. Criar condominio
        from condominios.models import (
            Condominio,
            ConfiguracaoFinanceira,
            MembroCondominio,
        )

        condominio = Condominio.objects.create(
            nome=dados["condominio_nome"].strip(),
            documento=dados.get("condominio_documento") or None,
            endereco=dados.get("condominio_endereco") or None,
            cidade=dados.get("condominio_cidade") or None,
            estado=dados.get("condominio_estado") or None,
            cep=dados.get("condominio_cep") or None,
            status_assinatura="trial",
            assinatura_expira_em=timezone.now() + timedelta(days=7),
        )

        # 3. Vincular usuario como SINDICO (ativo)
        MembroCondominio.objects.create(
            usuario=user,
            condominio=condominio,
            papel=MembroCondominio.Papel.SINDICO,
            status=MembroCondominio.Status.ATIVO,
            padrao=True,
        )

        # 4. Criar config financeira padrao
        ConfiguracaoFinanceira.objects.create(condominio=condominio)

        # 5. Gerar tokens JWT
        refresh = RefreshToken.for_user(user)

        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "usuario": {
                    "id": str(user.id),
                    "email": user.email,
                    "nome_completo": user.nome_completo,
                },
                "condominio": {
                    "id": str(condominio.id),
                    "nome": condominio.nome,
                },
            },
            status=status.HTTP_201_CREATED,
        )


class SessaoView(APIView):
    """
    GET /api/auth/sessao/

    Verifica se o token JWT do header Authorization e valido.
    Se sim, retorna dados do usuario; se nao, retorna sessao: null.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        if request.user and request.user.is_authenticated:
            user = request.user
            return Response(
                {
                    "sessao": {
                        "usuario": {
                            "id": str(user.id),
                            "email": user.email,
                            "nome_completo": user.nome_completo,
                        },
                    },
                }
            )
        return Response({"sessao": None})
