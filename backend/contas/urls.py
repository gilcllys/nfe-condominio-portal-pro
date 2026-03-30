from django.urls import path

from contas import views

urlpatterns = [
    # ── JWT Auth ────────────────────────────────────────────────────────────
    path("login/", views.LoginView.as_view(), name="login"),
    path("refresh/", views.RefreshTokenView.as_view(), name="token-refresh"),
    path("logout/", views.LogoutView.as_view(), name="logout"),

    # ── Cadastro ────────────────────────────────────────────────────────────
    path("cadastro/", views.CadastroView.as_view(), name="cadastro"),
    path("onboarding/", views.OnboardingView.as_view(), name="onboarding"),
    path("recuperar-senha/", views.RecuperarSenhaView.as_view(), name="recuperar-senha"),

    # ── Usuario autenticado ─────────────────────────────────────────────────
    path("atualizar-usuario/", views.AtualizarUsuarioView.as_view(), name="atualizar-usuario"),
    path("usuario/", views.UsuarioAtualView.as_view(), name="usuario-atual"),
    path("sessao/", views.SessaoView.as_view(), name="sessao"),
]
