from django.urls import include, path
from rest_framework.routers import DefaultRouter

from moradores import views

router = DefaultRouter(trailing_slash=True)
router.register(r"moradores", views.MoradorViewSet, basename="moradores")
router.register(r"unidades", views.UnidadeViewSet, basename="unidades")

urlpatterns = [
    path("", include(router.urls)),
]
