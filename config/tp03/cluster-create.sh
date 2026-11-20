#!/bin/bash
# Lance le cluster KinD des TP Kubernetes.
#
# Le cluster porte toujours le même nom, « cluster », quel que soit le TP :
# une machine n'en héberge qu'un. Le script supprime donc le cluster
# précédent avant de le recréer, ce qui efface releases Helm, espaces de
# noms et données qu'il contenait.
set -eu

cd "$(dirname "$0")"

if kind get clusters | grep -qx cluster; then
  echo "Suppression du cluster existant"
  kind delete cluster --name cluster
fi

kind create cluster --config kind-config.yaml
kubectl wait --for=condition=Ready nodes --all --timeout=180s
kubectl get nodes
