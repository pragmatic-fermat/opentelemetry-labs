# Service Python minimal : Flask pour l'entree, requests pour l'appel sortant.
import requests
from flask import Flask, jsonify

app = Flask(__name__)


@app.get("/stock")
def stock():
    price = None
    try:
        price = requests.get("http://localhost:8082/price", timeout=3).json()
    except Exception as exc:
        price = {"error": type(exc).__name__}
    return jsonify({"sku": "1 mug", "price": price})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
