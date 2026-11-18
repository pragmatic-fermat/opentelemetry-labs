#!/usr/bin/env bash
# Envoie de la télémétrie de test vers le Collector (service "otelcol" du compose).
#
# Usage : ./tg.sh traces|metrics|logs [options de telemetrygen]
# Exemple : ./tg.sh traces --traces 5 --service demo
#
# Les valeurs de chaîne des attributs doivent conserver leurs guillemets doubles :
#   --telemetry-attributes 'http.route="/health"'
set -euo pipefail
cd "$(dirname "$0")"

signal="${1:?Usage : ./tg.sh traces|metrics|logs [options]}"
shift

exec docker compose run --rm telemetrygen "$signal" \
  --otlp-endpoint otelcol:4317 --otlp-insecure --rate 10 "$@"
