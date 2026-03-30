import uuid

from django.contrib.auth.models import AbstractUser
from django.db import models

from contas.managers import UsuarioManager


class Usuario(AbstractUser):
    """
    Usuario da plataforma. Herda AbstractUser do Django.
    - Login por email (nao usa username)
    - Senha gerenciada pelo Django (bcrypt/PBKDF2)
    - UUID como chave primaria
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField("email", unique=True)
    cpf = models.CharField("CPF", max_length=14, blank=True, null=True)
    telefone = models.CharField("telefone", max_length=20, blank=True, null=True)
    data_nascimento = models.DateField("data de nascimento", blank=True, null=True)
    criado_em = models.DateTimeField(auto_now_add=True)
    atualizado_em = models.DateTimeField(auto_now=True)

    # Desabilitar username (login por email)
    username = None

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["first_name", "last_name"]

    objects = UsuarioManager()

    class Meta:
        db_table = "usuarios"
        verbose_name = "Usuario"
        verbose_name_plural = "Usuarios"

    def __str__(self):
        nome = f"{self.first_name} {self.last_name}".strip()
        return nome or self.email

    @property
    def nome_completo(self):
        return f"{self.first_name} {self.last_name}".strip()
