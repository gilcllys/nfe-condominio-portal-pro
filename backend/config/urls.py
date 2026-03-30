from django.conf import settings
from django.conf.urls.static import static
from django.urls import include, path

from common.upload import FileUploadView

urlpatterns = [
    # ── Upload de arquivos ─────────────────────────────────────────────
    path("api/upload/", FileUploadView.as_view(), name="file-upload"),

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

# Serve media files (uploads)
# In production, nginx/reverse proxy should handle this path directly.
# Keeping it here as fallback for container environments.
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
