"""Configuration des logs. Version de départ : logs sur la sortie standard uniquement."""
import logging


def setup(service_name):
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
