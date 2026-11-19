# Lab TP3 : Kubernetes, Collector et auto-instrumentation

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger. Une première rédaction détaillée existe dans la branche `tp03-kubernetes`, à convertir au format des labs.

# Objectifs

À la fin du lab, nous saurons :

- déployer un Collector en mode gateway puis en mode agent (DaemonSet) avec le chart Helm officiel, et adapter sa configuration par un fichier de valeurs ;
- expliquer comment le chart fusionne la configuration fournie avec ses valeurs par défaut et ce que fait un preset ;
- enrichir les traces avec les métadonnées Kubernetes grâce au processor `k8s_attributes` ;
- installer l'OpenTelemetry Operator et décrire une auto-instrumentation avec une ressource `Instrumentation` ;
- activer l'instrumentation d'un déploiement par une annotation et retrouver la trace de bout en bout dans Jaeger.

# Contenu

- [Environnement](#environnement)
- [1. Préparer le cluster](#1-préparer-le-cluster) : vérifier le cluster, installer Jaeger et une application de test.
- [2. Le Collector en mode gateway](#2-le-collector-en-mode-gateway) : déployer le Collector avec Helm et un fichier de valeurs.
- [3. Le Collector en mode agent](#3-le-collector-en-mode-agent) : déployer un DaemonSet qui enrichit les données et les envoie à la gateway.
- [4. L'Operator et l'auto-instrumentation](#4-loperator-et-lauto-instrumentation) : installer l'Operator, décrire une ressource `Instrumentation` et l'activer par annotation.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `k8s-N`.

Prérequis : TP1 recommandé (notions de pipeline). Outils `kubectl` et `helm` disponibles sur `k8s-N`.

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Préparer le cluster

À compléter. Points couverts :

- Contrôler l'accès au cluster KinD.
- Déployer le backend et l'application de test dans leurs espaces de noms.

## 2. Le Collector en mode gateway

À compléter. Points couverts :

- Écrire le fichier de valeurs (receiver, processors, exporter vers Jaeger).
- Comprendre la fusion des valeurs et le rôle des presets.

## 3. Le Collector en mode agent

À compléter. Points couverts :

- Configurer `k8s_attributes` et l'ordre des processors.
- Vérifier les attributs Kubernetes dans les traces.

## 4. L'Operator et l'auto-instrumentation

À compléter. Points couverts :

- Installer l'Operator avec une version de chart épinglée.
- Annoter un déploiement et retrouver la trace de bout en bout.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : activer le preset `logsCollection`, ou déployer le Collector avec la ressource `OpenTelemetryCollector` de l'Operator et comparer avec Helm.
