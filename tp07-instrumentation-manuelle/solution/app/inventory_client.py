import os

import requests
from opentelemetry.propagate import inject
from opentelemetry.trace import SpanKind

INVENTORY_URL = os.environ.get("INVENTORY_URL", "http://inventory:8081")


def get_stock(tracer, sku):
    url = f"{INVENTORY_URL}/stock/{sku}"
    with tracer.start_as_current_span("GET inventory", kind=SpanKind.CLIENT) as span:
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("url.full", url)
        span.set_attribute("server.address", "inventory")

        # inject écrit l'en-tête traceparent du span actif dans le dictionnaire.
        headers = {}
        inject(headers)

        resp = requests.get(url, headers=headers, timeout=2)
        span.set_attribute("http.response.status_code", resp.status_code)
        resp.raise_for_status()
        return resp.json()["stock"]
