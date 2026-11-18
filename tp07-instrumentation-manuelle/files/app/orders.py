"""Logique métier du service shop. Version de départ : sans instrumentation."""
import logging

import inventory_client

logger = logging.getLogger("shop.orders")

PRICES = {"coffee": 4.5, "tea": 3.0, "mug": 12.0}


def create_order(tracer, payload, headers):
    sku = payload.get("sku")
    qty = int(payload.get("qty", 1))
    customer = payload.get("customer", "anonymous")
    logger.info("order received sku=%s qty=%s customer=%s", sku, qty, customer)

    if sku not in PRICES:
        logger.warning("unknown sku=%s", sku)
        return {"error": "unknown sku"}, 404

    try:
        stock = inventory_client.get_stock(tracer, sku)
    except Exception as exc:
        logger.error("inventory unavailable: %s", exc)
        return {"error": "inventory unavailable"}, 502

    if stock < qty:
        logger.warning("insufficient stock sku=%s stock=%s requested=%s", sku, stock, qty)
        return {"error": "insufficient stock", "stock": stock}, 409

    total = round(PRICES[sku] * qty, 2)
    logger.info("order accepted sku=%s total=%s", sku, total)
    return {"status": "accepted", "total": total}, 201
