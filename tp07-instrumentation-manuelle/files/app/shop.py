"""Service shop : reçoit les commandes (POST /orders) et interroge le service inventory."""
from flask import Flask, jsonify, request

import logs
import orders
import telemetry

SERVICE = "shop"
tracer = telemetry.setup(SERVICE)
logs.setup(SERVICE)

app = Flask(__name__)


@app.post("/orders")
def post_orders():
    body, status = orders.create_order(tracer, request.get_json(silent=True) or {}, request.headers)
    return jsonify(body), status


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
