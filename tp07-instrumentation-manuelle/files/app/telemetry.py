"""Initialisation de la télémétrie. Version de départ : sans SDK, aucune donnée n'est produite."""
from opentelemetry import trace


def setup(service_name):
    # Sans SDK configuré, l'API OpenTelemetry fournit un tracer qui ne fait rien.
    return trace.get_tracer(service_name)
