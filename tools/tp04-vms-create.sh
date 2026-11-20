#!/bin/bash
# Cree les machines ephemeres TP4 pour chaque groupe d'apprenants.
#
# Usage :
#   ./tools/tp04-vms-create.sh [nombre_de_groupes]
#
# Exemple pour 3 groupes (0, 1 et 2) :
#   ./tools/tp04-vms-create.sh 3
#
# Par defaut, cree les machines pour 1 groupe (groupe 0).
# Prerequis : doctl authentifie dans le compte DigitalOcean.
set -euo pipefail

NB_GROUPES="${1:-1}"

if ! [[ "$NB_GROUPES" =~ ^[0-9]+$ ]] || [ "$NB_GROUPES" -lt 1 ]; then
  echo "Usage : $0 [nombre_de_groupes (entier >= 1, defaut : 1)]" >&2
  exit 1
fi

KEY_NAME="otel-lab-ephemere"
echo "Recherche de la cle SSH '$KEY_NAME'..."
KEY_ID=$(doctl compute ssh-key list --format ID,Name --no-header | awk -v k="$KEY_NAME" '$2==k {print $1; exit}')

if [ -z "$KEY_ID" ]; then
  echo "Erreur : la cle SSH '$KEY_NAME' n'a pas ete trouvee dans DigitalOcean." >&2
  echo "Importez-la d'abord avec :" >&2
  echo "  doctl compute ssh-key import $KEY_NAME --public-key-file <chemin>" >&2
  exit 1
fi
echo "Cle SSH detectee (ID : $KEY_ID)."

echo "Creation de 2 machines ephemeres (srv2 et srv3) pour $NB_GROUPES groupe(s)..."

for ((g=0; g<NB_GROUPES; g++)); do
  VPC_NAME="vpc-$g"
  VPC_INFO=$(doctl vpcs list --format ID,Name,Region --no-header | awk -v name="$VPC_NAME" '$2==name {print $1, $3; exit}')

  if [ -z "$VPC_INFO" ]; then
    echo "Erreur : le VPC '$VPC_NAME' n'a pas ete trouve dans DigitalOcean." >&2
    exit 1
  fi

  read -r VPC_ID VPC_REGION <<< "$VPC_INFO"

  echo "Groupe $g : creation de srv2-$g et srv3-$g dans $VPC_NAME ($VPC_REGION)..."
  doctl compute droplet create "srv2-$g" "srv3-$g" \
    --region "$VPC_REGION" \
    --size "s-1vcpu-1gb" \
    --image "ubuntu-24-04-x64" \
    --vpc-uuid "$VPC_ID" \
    --ssh-keys "$KEY_ID" \
    --tag-names "tp04-ephemere,tp04-groupe-$g" \
    --wait
done

echo ""
echo "=== Machines ephemeres TP4 pretes ==="
for ((g=0; g<NB_GROUPES; g++)); do
  echo "Groupe $g (VPC vpc-$g) :"
  doctl compute droplet list --tag-name "tp04-groupe-$g" --format Name,PrivateIPv4,Status --no-header | while read -r name ip status; do
    echo "  - $name : $ip ($status)"
  done
done

echo ""
echo "Pour supprimer ces machines a la fin du TP :"
echo "  ./tools/tp04-vms-destroy.sh"
