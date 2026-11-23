"""Appel HTTP du service shop vers le service inventory. Version instrumentée."""
import os

import requests
from opentelemetry import propagate, trace
from opentelemetry.trace import SpanKind, Status, StatusCode

INVENTORY_URL = os.environ.get("INVENTORY_URL", "http://inventory:8081")

tracer = trace.get_tracer("shop.client")


def get_stock(sku):
    headers = {}
    propagate.inject(headers)
    with tracer.start_as_current_span("GET inventory", kind=SpanKind.CLIENT) as span:
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("server.address", "inventory")
        try:
            resp = requests.get(f"{INVENTORY_URL}/stock/{sku}", timeout=30, headers=headers)
            span.set_attribute("http.response.status_code", resp.status_code)
            resp.raise_for_status()
            return resp.json()["stock"]
        except Exception as exc:
            span.set_status(Status(StatusCode.ERROR, str(exc)))
            raise
