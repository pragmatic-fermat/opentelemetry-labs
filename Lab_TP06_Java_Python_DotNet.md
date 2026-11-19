# Lab TP6 : Java, Python et .NET, auto-instrumentation sur Linux

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger.

# Objectifs

À la fin du lab, vous saurez :

- activer l'auto-instrumentation d'une application Java avec l'agent Java, sans modifier son code ;
- faire de même pour une application Python avec `opentelemetry-instrument` ;
- faire de même pour une application .NET sur Linux ;
- régler les trois uniquement par des variables `OTEL_*` (nom de service, adresse du Collector, attributs de ressource) ;
- obtenir une trace unique qui traverse les trois services et comparer ce que chaque agent produit.

# Contenu

- [Environnement](#environnement)
- [1. Applications de départ et backends](#1-applications-de-départ-et-backends) : trois services simples qui s'appellent, un Collector et Jaeger.
- [2. Java](#2-java) : attacher l'agent Java à l'application.
- [3. Python](#3-python) : lancer l'application avec `opentelemetry-instrument`.
- [4. .NET](#4-net) : activer l'auto-instrumentation .NET sur Linux.
- [5. Trace multi-langages et comparaison](#5-trace-multi-langages-et-comparaison) : suivre une requête à travers les trois services.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `srv-N` (hôte Linux sans Docker) pour les applications, `clt-N` pour le Collector et les backends.

Prérequis : TP1 recommandé (le Collector et Jaeger du TP1 reçoivent les données).

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Applications de départ et backends

À compléter. Points couverts :

- Présenter l'application : une API par langage, chacune appelant la suivante.
- Démarrer le Collector et Jaeger sur `clt-N`.

## 2. Java

À compléter. Points couverts :

- Télécharger l'agent à une version épinglée.
- Configurer par variables d'environnement et voir les spans.

## 3. Python

À compléter. Points couverts :

- Installer les paquets et le bootstrap d'instrumentation à des versions épinglées.
- Configurer par variables d'environnement et voir les spans.

## 4. .NET

À compléter. Points couverts :

- Installer l'auto-instrumentation à une version épinglée.
- Configurer par variables d'environnement et voir les spans.

## 5. Trace multi-langages et comparaison

À compléter. Points couverts :

- Lire la trace unique et la propagation entre langages.
- Comparer attributs, conventions sémantiques et métriques de runtime produits par chaque agent.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : désactiver une instrumentation précise, ou exclure un endpoint du traçage, par variable d'environnement.
