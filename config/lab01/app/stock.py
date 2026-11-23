"""Accès aux données de stock du service inventory (ne pas modifier)."""
import random
import time

STOCK = {"coffee": 12, "tea": 0, "mug": 3}


def load_stock(sku):
    # Simule le temps d'une requête vers une base de données.
    time.sleep(random.uniform(0.01, 0.08))
    return STOCK.get(sku)
