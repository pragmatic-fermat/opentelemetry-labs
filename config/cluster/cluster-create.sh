#!/bin/bash
# Lance le cluster KinD des TP Kubernetes.
#
# Le cluster porte toujours le même nom, « cluster », quel que soit le TP :
# une machine n'en héberge qu'un. Le script supprime donc les clusters
# existants avant de le recréer, y compris ceux d'un ancien nom, ce qui
# efface releases Helm, espaces de noms et données qu'ils contenaient.
set -eu

cd "$(dirname "$0")"

for existing in $(kind get clusters 2>/dev/null); do
  echo "Suppression du cluster $existing"
  kind delete cluster --name "$existing"
done

kind create cluster --config kind-config.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes
