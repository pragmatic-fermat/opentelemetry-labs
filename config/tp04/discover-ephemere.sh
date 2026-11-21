#!/bin/bash
# Découvre les serveurs éphémères du TP4 dans le VPC et imprime un bloc
# d'inventaire Ansible : trois alias, reliés aux adresses privées trouvées.
#
# Usage : ./discover-ephemere.sh > ephemeres.ini
#
# Le script balaie le sous-réseau privé de clt-N sur le port SSH, interroge
# chaque machine qui répond, et ne garde que celles dont le nom commence par
# srv2-, srv3- ou srv4-. Les adresses privées changent d'une session à
# l'autre : les alias, eux, ne changent pas.
set -euo pipefail

# Adresse privée de cette machine dans le VPC (eth1 sur clt-N, en /24 ;
# l'autre adresse 10.x de eth0 est en /16 et ne correspond pas au VPC).
MY_IP=$(ip -4 -o addr show \
  | awk '$2 ~ /^eth/ && $4 ~ /^10\./ && $4 ~ /\/24$/ {split($4, a, "/"); print a[1]; exit}')
if [ -z "$MY_IP" ]; then
  echo "Adresse privée introuvable : ce script se lance sur clt-N." >&2
  exit 1
fi
PREFIX=$(echo "$MY_IP" | cut -d. -f1-3)

# Les machines viennent d'être créées : SSH peut mettre une minute à répondre.
for attempt in 1 2 3 4; do
  # Machines qui répondent sur le port SSH, en parallèle.
  CANDIDATES=$(seq -f "$PREFIX.%g" 1 254 | grep -vx "$MY_IP" \
    | xargs -P32 -I{} sh -c 'nc -z -w1 {} 22 >/dev/null 2>&1 && echo {} || true' \
    | sort -V)

  # Parmi elles, les serveurs éphémères du TP4, reconnus à leur nom.
  IPS=()
  for ip in $CANDIDATES; do
    name=$(ssh -n -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
      "root@$ip" hostname 2>/dev/null || true)
    case "$name" in
      srv2-* | srv3-* | srv4-*) IPS+=("$ip") ;;
    esac
  done

  if [ "${#IPS[@]}" -eq 3 ]; then
    break
  fi

  if [ "$attempt" -eq 4 ]; then
    echo "Attendu 3 serveurs éphémères, trouvé ${#IPS[@]}." >&2
    echo "Vérifiez que l'animateur les a créés et qu'ils sont démarrés." >&2
    exit 1
  fi
  echo "Trouvé ${#IPS[@]} serveur(s) éphémère(s), nouvelle tentative dans 15 s..." >&2
  sleep 15
done

echo "[ephemere]"
echo "srv-frontend ansible_host=${IPS[0]}"
echo "srv-backend ansible_host=${IPS[1]}"
echo "srv-database ansible_host=${IPS[2]}"
