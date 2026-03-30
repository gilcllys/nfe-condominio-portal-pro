from django.urls import include, path
from rest_framework.routers import DefaultRouter

from estoque import views

router = DefaultRouter(trailing_slash=True)
router.register(r"itens-estoque", views.ItemEstoqueViewSet, basename="itens-estoque")
router.register(r"categorias-estoque", views.CategoriaEstoqueViewSet, basename="categorias-estoque")
router.register(r"movimentacoes-estoque", views.MovimentacaoEstoqueViewSet, basename="movimentacoes-estoque")

urlpatterns = [
    path("", include(router.urls)),
]
