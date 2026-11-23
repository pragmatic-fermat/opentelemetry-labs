"""Configuration des logs : sortie standard, avec l'identifiant de trace
courant ajouté à chaque enregistrement quand il y en a un."""
import logging

from opentelemetry import trace


class TraceContextFilter(logging.Filter):
    def filter(self, record):
        span = trace.get_current_span()
        ctx = span.get_span_context()
        record.trace_id = format(ctx.trace_id, "032x") if ctx.is_valid else "-"
        record.span_id = format(ctx.span_id, "016x") if ctx.is_valid else "-"
        return True


def setup(service_name):
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s [%(trace_id)s] %(message)s",
    )
    # Le filtre se pose sur les handlers : les enregistrements des loggers
    # enfants leur parviennent par propagation, sans passer par le logger
    # racine, donc un filtre posé sur ce logger ne les toucherait pas.
    for handler in logging.getLogger().handlers:
        handler.addFilter(TraceContextFilter())
