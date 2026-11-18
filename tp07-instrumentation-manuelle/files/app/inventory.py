"""Service inventory : renvoie le stock d'un article (GET /stock/<sku>)."""
from flask import Flask, jsonify, request

import logs
import stock
import telemetry

SERVICE = "inventory"
tracer = telemetry.setup(SERVICE)
logs.setup(SERVICE)

app = Flask(__name__)


@app.get("/stock/<sku>")
def get_stock(sku):
    body, status = stock.lookup(tracer, sku, request.headers)
    return jsonify(body), status


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8081)
