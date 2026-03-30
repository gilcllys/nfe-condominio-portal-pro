from django.contrib.auth.backends import ModelBackend

from contas.models import Usuario


class EmailBackend(ModelBackend):
    """
    Backend de autenticacao que usa email ao inves de username.
    """

    def authenticate(self, request, email=None, password=None, **kwargs):
        # Suporte a username= para compatibilidade com admin
        if email is None:
            email = kwargs.get("username")
        if email is None:
            return None

        try:
            user = Usuario.objects.get(email__iexact=email)
        except Usuario.DoesNotExist:
            return None

        if user.check_password(password) and self.user_can_authenticate(user):
            return user
        return None

    def get_user(self, user_id):
        try:
            return Usuario.objects.get(pk=user_id)
        except Usuario.DoesNotExist:
            return None
