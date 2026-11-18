#!/usr/bin/env bash
# Passe une commande au service shop et affiche la réponse suivie du code HTTP.
# Usage : ./order.sh <sku> [quantité] [client]
# Articles connus : coffee (stock 12), tea (stock 0), mug (stock 3)
# Exemple : ./order.sh coffee 2 alice
set -euo pipefail
sku="${1:?Usage : ./order.sh <sku> [quantité] [client]}"
qty="${2:-1}"
customer="${3:-anonymous}"
curl -s -w ' [%{http_code}]\n' -H 'content-type: application/json' \
  -d "{\"sku\":\"$sku\",\"qty\":$qty,\"customer\":\"$customer\"}" \
  http://localhost:8080/orders
