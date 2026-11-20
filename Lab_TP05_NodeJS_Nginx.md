# Lab TP5 : Node.js et Nginx, une trace de bout en bout

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger.

# Objectifs

À la fin du lab, vous saurez :

- démarrer une application de microservices (deux services Node.js, RabbitMQ, PostgreSQL, Nginx) et suivre un message de bout en bout, sans télémétrie ;
- auto-instrumenter deux services Node.js et exporter leurs données en OTLP vers un **collector**, puis Jaeger ;
- nommer les services avec des attributs de ressource et lire un waterfall dans Jaeger ;
- instrumenter Nginx avec le module OpenTelemetry et obtenir une trace unique de Nginx jusqu'au second service, à travers RabbitMQ ;
- enrichir des spans avec des données applicatives, reconnaître le risque pour les données sensibles et le corriger avec un processor de masquage.

# Contenu

- [Environnement](#environnement)
- [1. L'application et le parcours d'un message](#1-lapplication-et-le-parcours-dun-message) : démarrer la stack et envoyer un message sans télémétrie.
- [2. Auto-instrumenter le premier service](#2-auto-instrumenter-le-premier-service) : ajouter le SDK et l'auto-instrumentation, voir les spans en console.
- [3. Exporter vers le **collector** et Jaeger](#3-exporter-vers-le-collector-et-jaeger) : passer à l'export OTLP et nommer le service.
- [4. Instrumenter le second service](#4-instrumenter-le-second-service) : obtenir une trace qui traverse RabbitMQ.
- [5. Nginx devant l'application](#5-nginx-devant-lapplication) : instrumenter Nginx avec le module OpenTelemetry.
- [6. Données custom dans les spans et masquage](#6-données-custom-dans-les-spans-et-masquage) : ajouter le corps des requêtes comme contre-exemple, puis le masquer.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `clt-N`.

Prérequis : TP1 recommandé. Environnement pré-provisionné (images construites, dépendances installées) : sans cela, le TP double de durée et passe à 1/2 j.

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

**Note** : Le lab de référence date de 2023 (SDK Node.js 0.36, Node 19 en fin de vie) : le TP5 sera réécrit avec des versions actuelles, épinglées, et non repris tel quel.

## 1. L'application et le parcours d'un message

À compléter. Points couverts :

- Démarrer l'application dans l'environnement pré-provisionné.
- Créer une conversation et envoyer un message, puis lire les logs des services.

## 2. Auto-instrumenter le premier service

À compléter. Points couverts :

- Ajouter les paquets d'auto-instrumentation à des versions épinglées.
- Lire les spans affichés en console pour une requête.

## 3. Exporter vers le **collector** et Jaeger

À compléter. Points couverts :

- Envoyer les spans à un **collector** qui les transmet à Jaeger.
- Définir `service.name` et retrouver le service dans Jaeger.

## 4. Instrumenter le second service

À compléter. Points couverts :

- Appliquer la même démarche au second service.
- Vérifier que les deux services apparaissent dans la même trace.

## 5. Nginx devant l'application

À compléter. Points couverts :

- Construire l'image Nginx avec le module et une configuration dédiée.
- Observer le nouveau span racine de Nginx dans la trace de bout en bout.

## 6. Données custom dans les spans et masquage

À compléter. Points couverts :

- Ajouter des données de requête dans un événement de span.
- Masquer les valeurs sensibles avec un processor, comme au TP1.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : remplacer la configuration dans le code par des variables `OTEL_*` et comparer les deux approches.
