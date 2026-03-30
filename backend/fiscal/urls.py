from django.urls import include, path
from rest_framework.routers import DefaultRouter

from fiscal import views

router = DefaultRouter(trailing_slash=True)
router.register(r"documentos-fiscais", views.DocumentoFiscalViewSet, basename="documentos-fiscais")
router.register(r"aprovacoes-doc-fiscal", views.AprovacaoDocFiscalViewSet, basename="aprovacoes-doc-fiscal")
router.register(r"itens-doc-fiscal", views.ItemDocFiscalViewSet, basename="itens-doc-fiscal")

urlpatterns = [
    path("", include(router.urls)),
]
