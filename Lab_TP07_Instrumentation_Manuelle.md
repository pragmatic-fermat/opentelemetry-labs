# Lab TP7 : instrumentation manuelle

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger. Une première rédaction détaillée existe dans la branche `tp07-instrumentation-manuelle`, à convertir au format des labs.

# Objectifs

À la fin du lab, vous saurez :

- configurer le SDK OpenTelemetry pour Python (ressource, provider, processor, exporter OTLP) ;
- créer des spans avec un type (`SpanKind`), des attributs métier, des événements et un statut d'erreur ;
- propager le contexte entre deux services par l'en-tête W3C `traceparent`, avec `inject` et `extract` ;
- joindre l'identifiant de trace aux logs et suivre un log vers sa trace dans Grafana ;
- repérer dans Jaeger les défauts d'une instrumentation incomplète (traces coupées, spans sans erreur visible).

# Contenu

- [Environnement](#environnement)
- [1. Démarrer l'application sans instrumentation](#1-démarrer-lapplication-sans-instrumentation) : deux services, un Collector, Jaeger et Grafana.
- [2. Configurer le SDK](#2-configurer-le-sdk) : ressource, provider, processor et exporter OTLP.
- [3. Créer des spans dans le service métier](#3-créer-des-spans-dans-le-service-métier) : types de spans, attributs, événements et statut d'erreur.
- [4. Propager le contexte entre les services](#4-propager-le-contexte-entre-les-services) : `inject` et `extract` de l'en-tête `traceparent`.
- [5. Relier les logs aux traces](#5-relier-les-logs-aux-traces) : ajouter l'identifiant de trace aux logs et naviguer entre les deux dans Grafana.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `clt-N`.

Prérequis : TP1 recommandé. Le langage retenu est Python.

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Démarrer l'application sans instrumentation

À compléter. Points couverts :

- Démarrer la stack et lire le code métier, séparé des modules d'instrumentation.
- Constater qu'aucune trace n'arrive.

## 2. Configurer le SDK

À compléter. Points couverts :

- Écrire le module qui configure le SDK.
- Obtenir un premier span de bout en bout.

## 3. Créer des spans dans le service métier

À compléter. Points couverts :

- Ajouter des spans enfants avec des attributs métier.
- Enregistrer une exception et un statut d'erreur lisibles dans Jaeger.

## 4. Propager le contexte entre les services

À compléter. Points couverts :

- Injecter le contexte côté client et l'extraire côté serveur.
- Obtenir une trace unique sur les deux services.

## 5. Relier les logs aux traces

À compléter. Points couverts :

- Configurer l'export des logs avec le SDK.
- Retrouver la trace à partir d'un log.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : ajouter une métrique custom, envoyer sa propre valeur de `traceparent`, ou régler l'échantillonnage à 10 %.
