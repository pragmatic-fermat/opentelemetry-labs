"""Point d'entrée de POST /orders. Version instrumentée du lab 1.

Le span racine porte un nom générique (handle_request) et des attributs qui
seront traités par les processors à la partie 1C : adresse électronique en
clair et chemin avec un identifiant.
"""
import logging
import random

import orders
from opentelemetry import propagate, trace
from opentelemetry.trace import SpanKind, Status, StatusCode

tracer = trace.get_tracer("shop")


def create_order(payload, headers):
    parent = propagate.extract(headers)
    with tracer.start_as_current_span("handle_request", context=parent, kind=SpanKind.SERVER) as span:
        span.set_attribute("http.request.method", "POST")
        span.set_attribute("http.route", "/orders")
        span.set_attribute("url.path", f"/orders/{random.randint(10000, 99999)}")
        customer = payload.get("customer", "anonymous")
        span.set_attribute("order.sku", str(payload.get("sku")))
        span.set_attribute("order.qty", int(payload.get("qty", 1)))
        span.set_attribute("user.email", f"{customer}@example.com")

        body, status = orders.create_order(payload)

        span.set_attribute("http.response.status_code", status)
        if status == 201:
            span.set_attribute("order.total", body["total"])
        elif status == 409:
            span.add_event("stock.insufficient", {"stock": body["stock"]})
        if status >= 400:
            span.set_status(Status(StatusCode.ERROR, body["error"]))
        return body, status
