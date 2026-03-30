from django.urls import include, path
from rest_framework.routers import DefaultRouter

from condominios import views

router = DefaultRouter(trailing_slash=True)
router.register(r"condominios", views.CondominioViewSet, basename="condominios")
router.register(r"membros", views.MembroCondominioViewSet, basename="membros-condominio")
router.register(r"logs-atividade", views.LogAtividadeViewSet, basename="logs-atividade")

urlpatterns = [
    path("", include(router.urls)),
]
