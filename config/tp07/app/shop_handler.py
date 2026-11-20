"""Point d'entrée de POST /orders. Version de départ : sans instrumentation."""
import orders


def create_order(payload, headers):
    return orders.create_order(payload)
