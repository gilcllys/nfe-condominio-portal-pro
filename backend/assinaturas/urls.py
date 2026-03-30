from django.urls import path

from assinaturas import views

urlpatterns = [
    path("criar/", views.CriarAssinaturaView.as_view(), name="criar-assinatura"),
    path("status/", views.StatusAssinaturaView.as_view(), name="status-assinatura"),
    path("webhook/", views.WebhookPagarmeView.as_view(), name="webhook-pagarme"),
]
