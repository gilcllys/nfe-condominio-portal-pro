"""Auth views — local authentication (email + password via Django)."""

import hashlib
import logging
import secrets
from datetime import datetime, timedelta, timezone

from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from core.models import User, UserSession

logger = logging.getLogger(__name__)


def _hash_password(password: str) -> str:
    """Simple SHA-256 hash. For production, consider bcrypt/argon2."""
    return hashlib.sha256(password.encode()).hexdigest()


def _create_session(user: User, expires_hours: int = 24 * 7) -> dict:
    """Create a session token for the user."""
    token = secrets.token_urlsafe(64)
    expires_at = datetime.now(timezone.utc) + timedelta(hours=expires_hours)
    UserSession.objects.create(
        user=user,
        session_token=token,
        expires_at=expires_at,
    )
    return {
        "access_token": token,
        "expires_at": expires_at.isoformat(),
        "user": {
            "id": str(user.id),
            "email": user.email,
            "full_name": user.full_name,
        },
    }


class LoginView(APIView):
    """POST /api/auth/login/"""
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password", "")
        if not email or not password:
            return Response(
                {"error": "Email e senha sao obrigatorios"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            return Response(
                {"error": "Credenciais invalidas"},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if not user.password_hash or user.password_hash != _hash_password(password):
            return Response(
                {"error": "Credenciais invalidas"},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        if user.status and user.status not in ("ativo", "active"):
            return Response(
                {"error": "Conta pendente de aprovacao"},
                status=status.HTTP_403_FORBIDDEN,
            )

        session_data = _create_session(user)
        return Response(session_data)


class SignUpView(APIView):
    """POST /api/auth/signup/"""
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get("email", "").strip().lower()
        password = request.data.get("password", "")
        if not email or not password:
            return Response(
                {"error": "Email e senha sao obrigatorios"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if User.objects.filter(email__iexact=email).exists():
            return Response(
                {"error": "Email ja cadastrado"},
                status=status.HTTP_409_CONFLICT,
            )

        user = User.objects.create(
            email=email,
            password_hash=_hash_password(password),
            status="pendente",
        )

        return Response(
            {
                "user": {
                    "id": str(user.id),
                    "email": user.email,
                },
            },
            status=status.HTTP_201_CREATED,
        )


class LogoutView(APIView):
    """POST /api/auth/logout/"""
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        token = request.META.get("HTTP_AUTHORIZATION", "").replace("Bearer ", "")
        if token:
            UserSession.objects.filter(session_token=token).delete()
        return Response({"success": True})


class RefreshTokenView(APIView):
    """POST /api/auth/refresh/"""
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        old_token = request.data.get("refresh_token", "") or request.data.get("access_token", "")
        if not old_token:
            return Response(
                {"error": "Token e obrigatorio"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            session = UserSession.objects.select_related("user").get(session_token=old_token)
        except UserSession.DoesNotExist:
            return Response(
                {"error": "Sessao invalida"},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # Delete old session and create new one
        user = session.user
        session.delete()
        session_data = _create_session(user)
        return Response(session_data)


class ForgotPasswordView(APIView):
    """POST /api/auth/forgot-password/"""
    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        # Placeholder — implement email sending later
        return Response({"message": "Se o email existir, enviaremos instrucoes de recuperacao."})


class UpdateUserView(APIView):
    """PUT /api/auth/update-user/"""

    def put(self, request):
        user_obj = getattr(request, "user", None)
        if not user_obj or not getattr(user_obj, "is_authenticated", False):
            return Response({"error": "Nao autenticado"}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            db_user = User.objects.get(id=user_obj.id)
        except User.DoesNotExist:
            return Response({"error": "Usuario nao encontrado"}, status=status.HTTP_404_NOT_FOUND)

        allowed = ["full_name", "email"]
        for field in allowed:
            if field in request.data:
                setattr(db_user, field, request.data[field])

        # Handle password update
        new_password = request.data.get("password")
        if new_password:
            db_user.password_hash = _hash_password(new_password)

        db_user.save()
        return Response({"id": str(db_user.id), "email": db_user.email})


class GetUserView(APIView):
    """GET /api/auth/user/"""

    def get(self, request):
        user_obj = getattr(request, "user", None)
        if not user_obj or not getattr(user_obj, "is_authenticated", False):
            return Response({"error": "Nao autenticado"}, status=status.HTTP_401_UNAUTHORIZED)

        try:
            db_user = User.objects.get(id=user_obj.id)
        except User.DoesNotExist:
            return Response({"error": "Usuario nao encontrado"}, status=status.HTTP_404_NOT_FOUND)

        return Response({
            "id": str(db_user.id),
            "email": db_user.email,
            "full_name": db_user.full_name,
        })


class SessionView(APIView):
    """GET /api/auth/session/"""
    authentication_classes = []
    permission_classes = [AllowAny]

    def get(self, request):
        token = request.META.get("HTTP_AUTHORIZATION", "").replace("Bearer ", "")
        if not token:
            return Response({"session": None})

        try:
            session = UserSession.objects.select_related("user").get(
                session_token=token,
            )
        except UserSession.DoesNotExist:
            return Response({"session": None})

        if session.expires_at and session.expires_at < datetime.now(timezone.utc):
            return Response({"session": None})

        user = session.user
        return Response({
            "session": {
                "user": {
                    "id": str(user.id),
                    "email": user.email,
                    "full_name": user.full_name,
                },
                "access_token": token,
            },
        })
