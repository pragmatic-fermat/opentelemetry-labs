import logging

from opentelemetry import trace
from opentelemetry.propagate import extract
from opentelemetry.trace import SpanKind, Status, StatusCode

import stock

logger = logging.getLogger("inventory.handler")
tracer = trace.get_tracer("inventory")


def lookup(sku, headers):
    # Reprend le contexte envoyé par le service shop dans l'en-tête traceparent.
    parent = extract(headers)
    with tracer.start_as_current_span("GET /stock/{sku}", context=parent, kind=SpanKind.SERVER) as span:
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("http.route", "/stock/{sku}")
        span.set_attribute("inventory.sku", sku)

        with tracer.start_as_current_span("load_stock") as load:
            quantity = stock.load_stock(sku)
            load.set_attribute("inventory.found", quantity is not None)

        if quantity is None:
            span.set_status(Status(StatusCode.ERROR, "unknown sku"))
            logger.warning("unknown sku=%s", sku)
            return {"error": "unknown sku"}, 404

        span.set_attribute("inventory.stock", quantity)
        logger.info("stock lookup sku=%s stock=%s", sku, quantity)
        return {"sku": sku, "stock": quantity}, 200
