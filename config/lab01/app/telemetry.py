"""Initialisation de la télémétrie du lab 1.

Sans variable OTEL_EXPORTER_OTLP_ENDPOINT (1A) : chaque span est écrit sur la
sortie standard, un objet JSON par ligne, lisible avec jq.
Avec OTEL_EXPORTER_OTLP_ENDPOINT (1B) : les spans partent en OTLP/HTTP vers
l'endpoint indiqué.
"""
import json
import os

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor, SimpleSpanProcessor, SpanExporter, SpanExportResult


class ConsoleJsonSpanExporter(SpanExporter):
    """Écrit chaque span sur la sortie standard, un objet JSON par ligne."""

    def export(self, spans):
        for span in spans:
            ctx = span.get_span_context()
            record = {
                "name": span.name,
                "service": span.resource.attributes.get("service.name"),
                "trace_id": format(ctx.trace_id, "032x"),
                "span_id": format(ctx.span_id, "016x"),
                "parent_span_id": format(span.parent.span_id, "016x") if span.parent else None,
                "duration_ms": round((span.end_time - span.start_time) / 1e6, 2),
                "status": span.status.status_code.name,
                "attributes": dict(span.attributes),
                "events": [
                    {"name": e.name, "attributes": dict(e.attributes)} for e in span.events
                ],
            }
            print(json.dumps(record, ensure_ascii=False), flush=True)
        return SpanExportResult.SUCCESS

    def shutdown(self):
        return SpanExportResult.SUCCESS

    def force_flush(self, timeout_millis=30000):
        return True


def setup(service_name):
    provider = TracerProvider(resource=Resource.create({"service.name": service_name}))
    endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
    if endpoint:
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

        provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    else:
        provider.add_span_processor(SimpleSpanProcessor(ConsoleJsonSpanExporter()))
    trace.set_tracer_provider(provider)
