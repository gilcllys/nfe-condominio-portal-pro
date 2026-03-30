import logging
import re
from base64 import b64encode

import requests
from django.conf import settings

logger = logging.getLogger(__name__)

PAGARME_BASE = "https://api.pagar.me/core/v5"

# Plan pricing constants
PLAN_MENSAL_CENTS = 35600       # R$ 356,00/mes
PLAN_ANUAL_CENTS = 384480       # R$ 3.844,80/ano (R$ 320,40/mes — 10% desconto)
PLAN_DESCRIPTION_MENSAL = "NFe Vigia — Assinatura Mensal"
PLAN_DESCRIPTION_ANUAL = "NFe Vigia — Assinatura Anual"


def _auth_header() -> str:
    token = b64encode(f"{settings.PAGARME_API_KEY}:".encode()).decode()
    return f"Basic {token}"


def _format_phone(raw: str) -> dict:
    digits = re.sub(r"\D", "", raw)
    if len(digits) >= 11:
        digits = digits[-11:]
    return {"country_code": "55", "number": digits}


def _clean_document(doc: str) -> str:
    return re.sub(r"\D", "", doc)


def create_customer(customer_data: dict) -> dict:
    """Create a Pagar.me customer and return the full response dict."""
    phone = _format_phone(customer_data.get("phone", ""))
    document = _clean_document(customer_data["document"])

    payload = {
        "name": customer_data["name"].strip(),
        "email": customer_data["email"].strip().lower(),
        "type": "company" if len(document) == 14 else "individual",
        "document": document,
        "phones": {
            "mobile_phone": {
                "country_code": phone["country_code"],
                "area_code": phone["number"][:2],
                "number": phone["number"][2:],
            },
        },
    }

    resp = requests.post(
        f"{PAGARME_BASE}/customers",
        json=payload,
        headers={"Authorization": _auth_header(), "Content-Type": "application/json"},
        timeout=30,
    )

    if not resp.ok:
        logger.error("Pagar.me customer creation failed: %s", resp.text)
        raise PagarmeError(f"Erro ao criar cliente no Pagar.me", resp.json())

    return resp.json()


def create_subscription(
    customer_id: str,
    card_token: str,
    condo_id: str,
    condo_name: str,
    plano: str = "mensal",
) -> dict:
    """Create a credit_card subscription on Pagar.me and return the response.

    Args:
        plano: "mensal" or "anual"
    """
    if plano == "anual":
        amount = PLAN_ANUAL_CENTS
        interval = "year"
        interval_count = 1
        description = PLAN_DESCRIPTION_ANUAL
    else:
        amount = PLAN_MENSAL_CENTS
        interval = "month"
        interval_count = 1
        description = PLAN_DESCRIPTION_MENSAL

    payload = {
        "payment_method": "credit_card",
        "interval": interval,
        "interval_count": interval_count,
        "billing_type": "prepaid",
        "installments": 1,
        "currency": "BRL",
        "customer_id": customer_id,
        "card_token": card_token,
        "items": [
            {
                "description": description,
                "quantity": 1,
                "pricing_scheme": {
                    "scheme_type": "unit",
                    "price": amount,
                },
            },
        ],
        "metadata": {
            "condo_id": condo_id,
            "condo_name": condo_name,
        },
    }

    resp = requests.post(
        f"{PAGARME_BASE}/subscriptions",
        json=payload,
        headers={"Authorization": _auth_header(), "Content-Type": "application/json"},
        timeout=30,
    )

    if not resp.ok:
        logger.error("Pagar.me subscription creation failed: %s", resp.text)
        raise PagarmeError("Erro ao criar assinatura no Pagar.me", resp.json())

    return resp.json()


def map_pagarme_status(pagarme_status: str) -> str:
    """Map a Pagar.me subscription status to the internal subscription_status value."""
    mapping = {
        "active": "active",
        "trialing": "active",
        "pending": "active",
        "past_due": "past_due",
        "canceled": "canceled",
        "ended": "canceled",
    }
    return mapping.get(pagarme_status, "active")


class PagarmeError(Exception):
    def __init__(self, message: str, detail=None):
        super().__init__(message)
        self.detail = detail
