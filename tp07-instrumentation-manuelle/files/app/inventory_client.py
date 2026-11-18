"""Appel HTTP du service shop vers le service inventory. Version de départ : sans instrumentation."""
import os

import requests

INVENTORY_URL = os.environ.get("INVENTORY_URL", "http://inventory:8081")


def get_stock(tracer, sku):
    resp = requests.get(f"{INVENTORY_URL}/stock/{sku}", timeout=2)
    resp.raise_for_status()
    return resp.json()["stock"]
