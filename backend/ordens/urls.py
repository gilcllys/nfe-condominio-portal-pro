from django.urls import include, path
from rest_framework.routers import DefaultRouter

from ordens import views

router = DefaultRouter(trailing_slash=True)
router.register(r"ordens-servico", views.OrdemServicoViewSet, basename="ordens-servico")
router.register(r"materiais-os", views.MaterialOrdemServicoViewSet, basename="materiais-os")
router.register(r"aprovacoes", views.AprovacaoViewSet, basename="aprovacoes")
router.register(r"orcamentos", views.OrcamentoViewSet, basename="orcamentos")

urlpatterns = [
    # Nested routes para fotos e atividades
    path(
        "ordens-servico/<uuid:os_id>/fotos/",
        views.FotoOrdemServicoViewSet.as_view({"get": "list", "post": "create"}),
    ),
    path(
        "ordens-servico/<uuid:os_id>/atividades/",
        views.AtividadeOrdemServicoViewSet.as_view({"get": "list", "post": "create"}),
    ),
    path("", include(router.urls)),
]
