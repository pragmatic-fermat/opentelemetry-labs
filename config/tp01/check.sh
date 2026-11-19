#!/usr/bin/env bash
# Valide la configuration du Collector (les quatre fichiers de otelcol/)
# sans démarrer le Collector. N'affiche rien si la configuration est correcte.
set -euo pipefail
cd "$(dirname "$0")"

exec docker compose run --rm otelcol validate \
  --config=/etc/otelcol/receivers.yaml \
  --config=/etc/otelcol/processors.yaml \
  --config=/etc/otelcol/exporters.yaml \
  --config=/etc/otelcol/service.yaml
