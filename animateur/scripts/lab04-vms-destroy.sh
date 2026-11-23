#!/bin/bash
# Supprime toutes les machines ephemeres du lab 4 (tous groupes confondus).
#
# Usage :
#   ./animateur/scripts/lab04-vms-destroy.sh
#
# Prerequis : doctl authentifie dans le compte DigitalOcean.
set -euo pipefail

TAG="lab04-ephemere"

echo "Recherche des machines portant le tag '$TAG'..."
DROPLETS=$(doctl compute droplet list --tag-name "$TAG" --format ID,Name,PrivateIPv4 --no-header)

if [ -z "$DROPLETS" ]; then
  echo "Aucune machine ephemere lab 4 n'est en cours d'execution."
  exit 0
fi

COUNT=$(echo "$DROPLETS" | wc -l)
echo "$COUNT machine(s) trouvee(s) :"
echo "$DROPLETS" | while read -r id name ip; do
  echo "  - $name (ID: $id, IP privee: $ip)"
done

echo ""
echo "Suppression en cours..."
doctl compute droplet delete --tag-name "$TAG" --force
echo "Toutes les machines ephemeres du lab 4 ont ete supprimees."
