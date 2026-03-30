from django.conf import settings
from django.conf.urls.static import static
from django.urls import include, path

urlpatterns = [
    # ── Auth (contas) ────────────────────────────────────────────────────
    path("api/auth/", include("contas.urls")),

    # ── Condominios ──────────────────────────────────────────────────────
    path("api/", include("condominios.urls")),

    # ── Moradores ────────────────────────────────────────────────────────
    path("api/", include("moradores.urls")),

    # ── Chamados ─────────────────────────────────────────────────────────
    path("api/", include("chamados.urls")),

    # ── Ordens de Servico ────────────────────────────────────────────────
    path("api/", include("ordens.urls")),

    # ── Fiscal ───────────────────────────────────────────────────────────
    path("api/", include("fiscal.urls")),

    # ── Estoque ──────────────────────────────────────────────────────────
    path("api/", include("estoque.urls")),

    # ── Fornecedores ─────────────────────────────────────────────────────
    path("api/", include("fornecedores.urls")),

    # ── Notificacoes ─────────────────────────────────────────────────────
    path("api/notificacoes/", include("notificacoes.urls")),

    # ── Assinaturas ──────────────────────────────────────────────────────
    path("api/assinaturas/", include("assinaturas.urls")),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
