from django.urls import include, path
from rest_framework.routers import DefaultRouter

from chamados import views

router = DefaultRouter(trailing_slash=True)
router.register(r"chamados", views.ChamadoViewSet, basename="chamados")

urlpatterns = [
    path("", include(router.urls)),
]
