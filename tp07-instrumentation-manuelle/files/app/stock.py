"""Logique métier du service inventory. Version de départ : sans instrumentation."""
import logging
import random
import time

logger = logging.getLogger("inventory.stock")

STOCK = {"coffee": 12, "tea": 0, "mug": 3}


def lookup(tracer, sku, headers):
    # Simule le temps d'une requête vers une base de données.
    time.sleep(random.uniform(0.01, 0.08))
    quantity = STOCK.get(sku)
    if quantity is None:
        logger.warning("unknown sku=%s", sku)
        return {"error": "unknown sku"}, 404
    logger.info("stock lookup sku=%s stock=%s", sku, quantity)
    return {"sku": sku, "stock": quantity}, 200
