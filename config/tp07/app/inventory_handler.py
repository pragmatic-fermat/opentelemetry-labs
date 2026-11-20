"""Point d'entrée de GET /stock/<sku>. Version de départ : sans instrumentation."""
import logging

import stock

logger = logging.getLogger("inventory.handler")


def lookup(sku, headers):
    quantity = stock.load_stock(sku)
    if quantity is None:
        logger.warning("unknown sku=%s", sku)
        return {"error": "unknown sku"}, 404
    logger.info("stock lookup sku=%s stock=%s", sku, quantity)
    return {"sku": sku, "stock": quantity}, 200
