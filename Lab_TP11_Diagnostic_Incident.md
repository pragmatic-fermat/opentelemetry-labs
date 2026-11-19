# Lab TP11 : diagnostic d'incident sur l'OpenTelemetry Demo

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger.

# Objectifs

À la fin du lab, nous saurons :

- déployer l'OpenTelemetry Demo (Astronomy Shop) et se repérer dans son architecture et ses backends ;
- activer des pannes préconfigurées par feature flags et observer leurs symptômes ;
- mener un diagnostic du symptôme à la cause racine, en croisant métriques, traces et logs ;
- rédiger un compte rendu court (symptôme, preuves, cause) pour chaque incident ;
- retenir une méthode de diagnostic réutilisable sur une application réelle.

# Contenu

- [Environnement](#environnement)
- [1. Déployer la Demo et se repérer](#1-déployer-la-demo-et-se-repérer) : installer la Demo et situer ses composants.
- [2. Premier incident : une panne franche](#2-premier-incident--une-panne-franche) : des erreurs visibles côté utilisateur.
- [3. Deuxième incident : une dégradation](#3-deuxième-incident--une-dégradation) : lenteur ou consommation de ressources anormale.
- [4. Troisième incident : cas libre](#4-troisième-incident--cas-libre) : le participant choisit un scénario et le résout seul.
- [5. Synthèse : la méthode](#5-synthèse--la-méthode) : mettre en commun les démarches.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `clt-N` (Docker Compose) ou `k8s-N` (Helm), à confirmer à la rédaction.

Prérequis : TP1 recommandé. Plusieurs TP d'instrumentation sont utiles mais non obligatoires.

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Déployer la Demo et se repérer

À compléter. Points couverts :

- Déployer la Demo à une version épinglée.
- Repérer les services, le Collector et les backends.

## 2. Premier incident : une panne franche

À compléter. Points couverts :

- Activer le feature flag correspondant.
- Remonter des métriques aux traces, puis aux logs, jusqu'à la cause.

## 3. Deuxième incident : une dégradation

À compléter. Points couverts :

- Activer le feature flag correspondant.
- Identifier le service responsable par les latences et les métriques de ressources.

## 4. Troisième incident : cas libre

À compléter. Points couverts :

- Choisir un feature flag dans la liste de la version retenue, à vérifier à la rédaction.
- Rédiger le compte rendu sans aide.

## 5. Synthèse : la méthode

À compléter. Points couverts :

- Comparer les chemins suivis.
- Formaliser une méthode de diagnostic en quelques étapes.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : écrire une règle d'alerte qui aurait détecté le premier incident.
