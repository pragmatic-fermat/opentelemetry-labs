"""Point d'entrée de GET /stock/<sku>. Version instrumentée du TP1.

Le mode lent est activé par la variable INVENTORY_DELAY_MS (millisecondes,
défaut 0) : le temps est passé à l'intérieur du span, ce qui le rend visible
dans la durée du span.
"""
import logging
import os
import time

import stock
from opentelemetry import propagate, trace
from opentelemetry.trace import SpanKind, Status, StatusCode

tracer = trace.get_tracer("inventory")


def lookup(sku, headers):
    parent = propagate.extract(headers)
    with tracer.start_as_current_span("load_stock", context=parent, kind=SpanKind.SERVER) as span:
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("http.route", f"/stock/{sku}")
        span.set_attribute("inventory.sku", sku)

        delay_ms = int(os.environ.get("INVENTORY_DELAY_MS", "0"))
        if delay_ms > 0:
            time.sleep(delay_ms / 1000)

        quantity = stock.load_stock(sku)
        if quantity is None:
            logger = logging.getLogger("inventory.handler")
            logger.warning("unknown sku=%s", sku)
            span.set_status(Status(StatusCode.ERROR, "unknown sku"))
            return {"error": "unknown sku"}, 404
        span.set_attribute("inventory.stock", quantity)
        return {"sku": sku, "stock": quantity}, 200
