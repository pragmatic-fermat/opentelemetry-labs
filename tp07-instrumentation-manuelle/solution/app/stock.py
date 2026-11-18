import logging
import random
import time

from opentelemetry.propagate import extract
from opentelemetry.trace import SpanKind, Status, StatusCode

logger = logging.getLogger("inventory.stock")

STOCK = {"coffee": 12, "tea": 0, "mug": 3}


def lookup(tracer, sku, headers):
    # Reprend le contexte envoyé par le service shop dans l'en-tête traceparent.
    parent = extract(headers)
    with tracer.start_as_current_span("GET /stock/{sku}", context=parent, kind=SpanKind.SERVER) as span:
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("http.route", "/stock/{sku}")
        span.set_attribute("inventory.sku", sku)

        with tracer.start_as_current_span("load_stock") as load:
            # Simule le temps d'une requête vers une base de données.
            time.sleep(random.uniform(0.01, 0.08))
            quantity = STOCK.get(sku)
            load.set_attribute("inventory.found", quantity is not None)

        if quantity is None:
            span.set_status(Status(StatusCode.ERROR, "unknown sku"))
            logger.warning("unknown sku=%s", sku)
            return {"error": "unknown sku"}, 404

        span.set_attribute("inventory.stock", quantity)
        logger.info("stock lookup sku=%s stock=%s", sku, quantity)
        return {"sku": sku, "stock": quantity}, 200
