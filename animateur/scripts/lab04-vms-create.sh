#!/bin/bash
# Cree les machines ephemeres lab 4 pour chaque groupe de participants.
#
# Usage :
#   ./animateur/scripts/lab04-vms-create.sh [nombre_de_groupes]
#
# Exemple pour 3 groupes (0, 1 et 2) :
#   ./animateur/scripts/lab04-vms-create.sh 3
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
  echo "Erreur fatale : la cle SSH '$KEY_NAME' est introuvable dans ce compte DigitalOcean." >&2
  echo "Cela signifie que vous n'etes probablement pas sur le bon profil doctl." >&2
  echo "Verifiez votre profil actif avec : doctl auth list" >&2
  echo "Basculez sur le bon profil avec : doctl auth switch --context <nom_du_profil>" >&2
  exit 1
fi
echo "Cle SSH detectee (ID : $KEY_ID)."

echo "Creation de 3 machines ephemeres Debian (srv2, srv3, srv4) pour $NB_GROUPES groupe(s)..."

for ((g=0; g<NB_GROUPES; g++)); do
  VPC_NAME="vpc-$g"
  VPC_INFO=$(doctl vpcs list --format ID,Name,Region,IPRange --no-header | awk -v name="$VPC_NAME" '$2==name {print $1, $3, $4; exit}')

  if [ -z "$VPC_INFO" ]; then
    echo "Erreur : le VPC '$VPC_NAME' n'a pas ete trouve dans DigitalOcean." >&2
    exit 1
  fi

  read -r VPC_ID VPC_REGION VPC_RANGE <<< "$VPC_INFO"

  echo "Groupe $g : creation de srv2-$g, srv3-$g et srv4-$g (Debian 13) dans $VPC_NAME ($VPC_REGION)..."
  doctl compute droplet create "srv2-$g" "srv3-$g" "srv4-$g" \
    --region "$VPC_REGION" \
    --size "s-1vcpu-1gb" \
    --image "debian-13-x64" \
    --vpc-uuid "$VPC_ID" \
    --ssh-keys "$KEY_ID" \
    --tag-names "lab04-ephemere,lab04-groupe-$g" \
    --wait

  # Verifie que les machines sont bien dans le VPC du groupe : c'est ce
  # sous-reseau que le script de decouverte des participants balaie.
  VPC_PREFIX=$(echo "$VPC_RANGE" | cut -d. -f1-3)
  BAD=0
  while read -r name droplet_vpc ip; do
    if [ "$droplet_vpc" != "$VPC_ID" ]; then
      echo "ERREUR : $name n'est pas dans $VPC_NAME ($VPC_ID)." >&2
      BAD=1
    fi
    case "$ip" in
      "$VPC_PREFIX".*) ;;
      *) echo "ERREUR : $name a l'adresse $ip, hors de $VPC_RANGE." >&2; BAD=1 ;;
    esac
  done < <(doctl compute droplet list --tag-name "lab04-groupe-$g" \
    --format Name,VPCUUID,PrivateIPv4 --no-header)
  if [ "$BAD" -ne 0 ]; then
    echo "Groupe $g : machines hors du VPC attendu, verifiez avant la seance." >&2
    exit 1
  fi
  echo "Groupe $g : les trois machines sont dans $VPC_NAME ($VPC_RANGE)."
done

echo ""
echo "=== Machines ephemeres lab 4 pretes ==="
for ((g=0; g<NB_GROUPES; g++)); do
  echo "Groupe $g (VPC vpc-$g) :"
  doctl compute droplet list --tag-name "lab04-groupe-$g" --format Name,PrivateIPv4,Status --no-header | while read -r name ip status; do
    echo "  - $name : $ip ($status)"
  done
done

echo ""
echo "Pour supprimer ces machines a la fin du lab :"
echo "  ./animateur/scripts/lab04-vms-destroy.sh"
