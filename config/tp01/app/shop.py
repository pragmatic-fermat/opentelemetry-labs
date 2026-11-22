"""Service shop : reçoit les commandes (POST /orders) et interroge le service inventory."""
from flask import Flask, jsonify, request

import logs
import shop_handler
import telemetry
from opentelemetry import trace

SERVICE = "shop"
telemetry.setup(SERVICE)
logs.setup(SERVICE)
tracer = trace.get_tracer("shop")

app = Flask(__name__)


@app.get("/health")
def health():
    # Route de sonde : les spans qu'elle produit sont du bruit volontaire,
    # retiré par le processor filter à la partie 1C.
    with tracer.start_as_current_span("handle_request") as span:
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("http.route", "/health")
        return "ok", 200


@app.post("/orders")
def post_orders():
    body, status = shop_handler.create_order(request.get_json(silent=True) or {}, request.headers)
    return jsonify(body), status


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
