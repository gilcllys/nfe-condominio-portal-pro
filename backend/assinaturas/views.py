"""Views de assinaturas — criar assinatura, webhook Pagar.me, status."""

import hashlib
import hmac
import json
import logging
from datetime import timedelta

from django.conf import settings
from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from condominios.models import Assinatura, Condominio
from servicos.pagarme_service import (
    PagarmeError,
    create_customer,
    create_subscription,
    map_pagarme_status,
)

logger = logging.getLogger(__name__)


class CriarAssinaturaView(APIView):
    """
    POST /api/assinaturas/criar/

    Cria assinatura no Pagar.me e atualiza o condominio.

    Body:
    {
        "condominio_id": "uuid",
        "card_token": "token_xxx",
        "plano": "mensal" | "anual",
        "customer": {
            "name": "Joao da Silva",
            "email": "joao@email.com",
            "document": "12345678900",
            "phone": "11999999999"
        }
    }
    """

    permission_classes = [IsAuthenticated]

    def post(self, request):
        condominio_id = request.data.get("condominio_id")
        card_token = request.data.get("card_token")
        customer_data = request.data.get("customer", {})
        plano = request.data.get("plano", "mensal")

        if not condominio_id or not card_token:
            return Response(
                {"error": "condominio_id e card_token sao obrigatorios"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if plano not in ("mensal", "anual"):
            return Response(
                {"error": "plano deve ser 'mensal' ou 'anual'"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not customer_data.get("name") or not customer_data.get("email") or not customer_data.get("document"):
            return Response(
                {"error": "customer.name, customer.email e customer.document sao obrigatorios"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            condominio = Condominio.objects.get(id=condominio_id)
        except Condominio.DoesNotExist:
            return Response(
                {"error": "Condominio nao encontrado"},
                status=status.HTTP_404_NOT_FOUND,
            )

        try:
            # 1. Criar ou reutilizar customer no Pagar.me
            if condominio.pagarme_customer_id:
                customer_id = condominio.pagarme_customer_id
            else:
                customer_resp = create_customer(customer_data)
                customer_id = customer_resp["id"]
                condominio.pagarme_customer_id = customer_id
                condominio.save(update_fields=["pagarme_customer_id", "atualizado_em"])

            # 2. Criar assinatura no Pagar.me
            sub_resp = create_subscription(
                customer_id=customer_id,
                card_token=card_token,
                condo_id=str(condominio.id),
                condo_name=condominio.nome,
                plano=plano,
            )

            # 3. Atualizar condominio
            pagarme_status = sub_resp.get("status", "active")
            condominio.status_assinatura = map_pagarme_status(pagarme_status)
            condominio.assinatura_id = sub_resp.get("id", "")

            # Calcular proxima cobranca
            next_billing = sub_resp.get("next_billing_at") or sub_resp.get("current_cycle", {}).get("end_at")
            if next_billing:
                from django.utils.dateparse import parse_datetime
                parsed = parse_datetime(next_billing)
                if parsed:
                    condominio.assinatura_expira_em = parsed
            else:
                # Fallback: 30 dias para mensal, 365 para anual
                days = 365 if plano == "anual" else 30
                condominio.assinatura_expira_em = timezone.now() + timedelta(days=days)

            condominio.save(update_fields=[
                "status_assinatura",
                "assinatura_id",
                "assinatura_expira_em",
                "atualizado_em",
            ])

            # 4. Criar registro Assinatura
            Assinatura.objects.create(
                condominio=condominio,
                provedor="PAGARME",
                id_cliente_externo=customer_id,
                id_assinatura_externa=sub_resp.get("id", ""),
                status=condominio.status_assinatura.upper(),
            )

            return Response({
                "success": True,
                "status": condominio.status_assinatura,
                "assinatura_id": condominio.assinatura_id,
            })

        except PagarmeError as e:
            logger.error("Erro Pagar.me ao criar assinatura: %s — %s", str(e), e.detail)
            detail_msg = "Erro ao processar pagamento"
            if e.detail and isinstance(e.detail, dict):
                errors = e.detail.get("errors", [])
                if errors:
                    detail_msg = "; ".join(err.get("message", "") for err in errors if err.get("message"))
            return Response(
                {"error": detail_msg},
                status=status.HTTP_422_UNPROCESSABLE_ENTITY,
            )
        except Exception as e:
            logger.exception("Erro inesperado ao criar assinatura: %s", str(e))
            return Response(
                {"error": "Erro interno ao processar pagamento"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class StatusAssinaturaView(APIView):
    """
    GET /api/assinaturas/status/?condominio_id=...

    Retorna status da assinatura do condominio.

    Response:
    {
        "status": "trial" | "active" | "past_due" | "canceled",
        "expira_em": "2026-04-05T12:00:00Z",
        "dias_restantes": 5,
        "assinatura_id": "sub_xxx",
        "trial_expirado": false
    }
    """

    permission_classes = [IsAuthenticated]

    def get(self, request):
        condominio_id = request.query_params.get("condominio_id")
        if not condominio_id:
            return Response(
                {"error": "condominio_id e obrigatorio"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            condominio = Condominio.objects.get(id=condominio_id)
        except Condominio.DoesNotExist:
            return Response(
                {"error": "Condominio nao encontrado"},
                status=status.HTTP_404_NOT_FOUND,
            )

        expira_em = condominio.assinatura_expira_em
        dias_restantes = None
        trial_expirado = False

        if expira_em:
            delta = expira_em - timezone.now()
            dias_restantes = max(0, delta.days)

            if condominio.status_assinatura == "trial" and delta.total_seconds() <= 0:
                trial_expirado = True

        return Response({
            "status": condominio.status_assinatura or "trial",
            "expira_em": expira_em.isoformat() if expira_em else None,
            "dias_restantes": dias_restantes,
            "assinatura_id": condominio.assinatura_id,
            "trial_expirado": trial_expirado,
        })


class WebhookPagarmeView(APIView):
    """
    POST /api/assinaturas/webhook/

    Recebe webhooks do Pagar.me para atualizar status de assinaturas.
    Eventos tratados:
    - subscription.created
    - subscription.canceled
    - invoice.paid
    - invoice.payment_failed
    - charge.paid
    - charge.payment_failed
    """

    authentication_classes = []
    permission_classes = [AllowAny]

    def post(self, request):
        # Validar assinatura HMAC
        signature = request.headers.get("x-hub-signature", "")
        webhook_secret = settings.PAGARME_WEBHOOK_SECRET

        if webhook_secret:
            raw_body = request.body
            expected = hmac.new(
                webhook_secret.encode(),
                raw_body,
                hashlib.sha256,
            ).hexdigest()

            received_hash = signature.replace("sha256=", "").replace("sha1=", "")
            if not hmac.compare_digest(expected, received_hash):
                logger.warning("Webhook Pagar.me: assinatura invalida")
                return Response(
                    {"error": "Assinatura invalida"},
                    status=status.HTTP_401_UNAUTHORIZED,
                )

        body = request.data
        event_type = body.get("type", "")
        data = body.get("data", {})

        logger.info("Webhook Pagar.me recebido: %s", event_type)

        if not event_type or not data:
            return Response({"received": True})

        # Extrair condo_id dos metadados
        condo_id = None
        subscription_id = None

        if "subscription" in data:
            sub = data["subscription"]
            subscription_id = sub.get("id")
            metadata = sub.get("metadata", {})
            condo_id = metadata.get("condo_id")
        elif "metadata" in data:
            condo_id = data["metadata"].get("condo_id")
            subscription_id = data.get("id")

        if not condo_id and subscription_id:
            # Tentar buscar pelo assinatura_id
            try:
                condo = Condominio.objects.get(assinatura_id=subscription_id)
                condo_id = str(condo.id)
            except Condominio.DoesNotExist:
                pass

        if not condo_id:
            logger.warning("Webhook Pagar.me: condo_id nao encontrado no evento %s", event_type)
            return Response({"received": True})

        try:
            condominio = Condominio.objects.get(id=condo_id)
        except Condominio.DoesNotExist:
            logger.warning("Webhook Pagar.me: condominio %s nao encontrado", condo_id)
            return Response({"received": True})

        # Processar eventos
        if event_type == "subscription.canceled":
            condominio.status_assinatura = "canceled"
            condominio.save(update_fields=["status_assinatura", "atualizado_em"])
            logger.info("Assinatura cancelada para condominio %s", condo_id)

        elif event_type in ("invoice.paid", "charge.paid"):
            condominio.status_assinatura = "active"
            # Atualizar proxima expiracao se disponivel
            invoice = data if event_type == "invoice.paid" else data.get("invoice", {})
            next_billing = invoice.get("next_billing_at")
            if next_billing:
                from django.utils.dateparse import parse_datetime
                parsed = parse_datetime(next_billing)
                if parsed:
                    condominio.assinatura_expira_em = parsed
            condominio.save(update_fields=["status_assinatura", "assinatura_expira_em", "atualizado_em"])
            logger.info("Pagamento confirmado para condominio %s", condo_id)

        elif event_type in ("invoice.payment_failed", "charge.payment_failed"):
            condominio.status_assinatura = "past_due"
            condominio.save(update_fields=["status_assinatura", "atualizado_em"])
            logger.info("Pagamento falhou para condominio %s", condo_id)

        elif event_type == "subscription.created":
            sub_status = data.get("status", "active")
            condominio.status_assinatura = map_pagarme_status(sub_status)
            if subscription_id and not condominio.assinatura_id:
                condominio.assinatura_id = subscription_id
            condominio.save(update_fields=["status_assinatura", "assinatura_id", "atualizado_em"])
            logger.info("Assinatura criada para condominio %s", condo_id)

        # Atualizar registro Assinatura se existir
        if subscription_id:
            Assinatura.objects.filter(
                id_assinatura_externa=subscription_id
            ).update(
                status=condominio.status_assinatura.upper()
            )

        return Response({"received": True})
