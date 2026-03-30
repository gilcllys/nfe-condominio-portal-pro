"""Simple session-token authentication.

Replaces the former Supabase JWT authentication.
The frontend sends a session token in the Authorization header:
    Authorization: Bearer <session_token>

We look up the token in the user_sessions table and resolve the user.
"""

import logging
from datetime import datetime, timezone

from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed

from core.models import User, UserSession

logger = logging.getLogger(__name__)


class AuthenticatedUser:
    """Lightweight user object attached to ``request.user``."""

    def __init__(self, db_user: User):
        self.id = db_user.id
        self.auth_user_id = getattr(db_user, "auth_user_id", None)
        self.name = db_user.full_name
        self.email = db_user.email
        self.is_authenticated = True


class SessionTokenAuthentication(BaseAuthentication):
    """Validates session tokens from the user_sessions table."""

    def authenticate(self, request):
        auth_header = request.META.get("HTTP_AUTHORIZATION", "")
        if not auth_header.startswith("Bearer "):
            return None

        token = auth_header[7:]
        if not token:
            return None

        try:
            session = UserSession.objects.select_related("user").get(
                session_token=token,
                expires_at__gt=datetime.now(timezone.utc),
            )
        except UserSession.DoesNotExist:
            raise AuthenticationFailed("Sessão inválida ou expirada.")

        return (AuthenticatedUser(session.user), token)
