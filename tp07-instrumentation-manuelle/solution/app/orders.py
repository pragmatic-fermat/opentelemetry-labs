import logging

from opentelemetry.propagate import extract
from opentelemetry.trace import SpanKind, Status, StatusCode

import inventory_client

logger = logging.getLogger("shop.orders")

PRICES = {"coffee": 4.5, "tea": 3.0, "mug": 12.0}


def create_order(tracer, payload, headers):
    # Si l'appelant a envoyé un en-tête traceparent, le span rejoint sa trace.
    parent = extract(headers)
    with tracer.start_as_current_span("POST /orders", context=parent, kind=SpanKind.SERVER) as span:
        sku = payload.get("sku")
        qty = int(payload.get("qty", 1))
        customer = payload.get("customer", "anonymous")
        span.set_attribute("http.request.method", "POST")
        span.set_attribute("http.route", "/orders")
        span.set_attribute("order.sku", sku)
        span.set_attribute("order.qty", qty)
        span.set_attribute("customer.id", customer)
        logger.info("order received sku=%s qty=%s customer=%s", sku, qty, customer)

        if sku not in PRICES:
            span.set_status(Status(StatusCode.ERROR, "unknown sku"))
            logger.warning("unknown sku=%s", sku)
            return {"error": "unknown sku"}, 404

        try:
            stock = inventory_client.get_stock(tracer, sku)
        except Exception as exc:
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, "inventory unavailable"))
            logger.error("inventory unavailable: %s", exc)
            return {"error": "inventory unavailable"}, 502

        span.set_attribute("inventory.stock", stock)
        if stock < qty:
            span.add_event("stock.insufficient", {"stock": stock, "requested": qty})
            span.set_status(Status(StatusCode.ERROR, "insufficient stock"))
            logger.warning("insufficient stock sku=%s stock=%s requested=%s", sku, stock, qty)
            return {"error": "insufficient stock", "stock": stock}, 409

        with tracer.start_as_current_span("compute_price") as price_span:
            total = round(PRICES[sku] * qty, 2)
            price_span.set_attribute("order.total", total)
        span.set_attribute("order.total", total)
        logger.info("order accepted sku=%s total=%s", sku, total)
        return {"status": "accepted", "total": total}, 201
