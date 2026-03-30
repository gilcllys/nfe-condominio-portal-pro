from django.urls import include, path
from rest_framework.routers import DefaultRouter

from fornecedores import views

router = DefaultRouter(trailing_slash=True)
router.register(r"fornecedores", views.FornecedorViewSet, basename="fornecedores")
router.register(r"contratos", views.ContratoViewSet, basename="contratos")

urlpatterns = [
    path("", include(router.urls)),
]
