from opentelemetry import trace
from opentelemetry.propagate import extract
from opentelemetry.trace import SpanKind, Status, StatusCode

import orders

tracer = trace.get_tracer("shop")


def create_order(payload, headers):
    # Si l'appelant a envoyé un en-tête traceparent, le span rejoint sa trace.
    parent = extract(headers)
    with tracer.start_as_current_span("POST /orders", context=parent, kind=SpanKind.SERVER) as span:
        span.set_attribute("http.request.method", "POST")
        span.set_attribute("http.route", "/orders")
        span.set_attribute("order.sku", str(payload.get("sku")))
        span.set_attribute("order.qty", int(payload.get("qty", 1)))
        span.set_attribute("customer.id", payload.get("customer", "anonymous"))

        body, status = orders.create_order(payload)

        span.set_attribute("http.response.status_code", status)
        if status == 201:
            span.set_attribute("order.total", body["total"])
        elif status == 409:
            span.add_event("stock.insufficient", {"stock": body["stock"]})
        if status >= 400:
            span.set_status(Status(StatusCode.ERROR, body["error"]))
        return body, status
