# Lab TP8 : eBPF et OBI, instrumenter sans toucher au code

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger. Hors périmètre actuel : le TP est conservé pour mémoire.

# Objectifs

À la fin du lab, vous saurez :

- expliquer le principe de l'instrumentation par eBPF, ses prérequis (noyau, privilèges) et ce qu'elle observe ;
- déployer OBI (OpenTelemetry eBPF Instrumentation) à côté d'une application existante, sans la modifier ni la redémarrer ;
- lire les traces et les métriques obtenues sans aucun SDK dans l'application ;
- comparer avec l'auto-instrumentation (profondeur des spans, attributs, surcoût, langages couverts) ;
- identifier les limites et les cas d'usage où OBI est pertinent.

# Contenu

- [Environnement](#environnement)
- [1. Principe et prérequis](#1-principe-et-prérequis) : comprendre eBPF et contrôler le noyau de la machine.
- [2. Déployer OBI à côté d'une application](#2-déployer-obi-à-côté-dune-application) : lancer OBI et l'application, sans modifier le code.
- [3. Lire ce qu'OBI produit](#3-lire-ce-quobi-produit) : traces et métriques envoyées au **collector**.
- [4. Comparer avec l'auto-instrumentation](#4-comparer-avec-lauto-instrumentation) : même application, deux approches.
- [5. Limites et cas d'usage](#5-limites-et-cas-dusage) : dire quand choisir OBI.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `srv-N` (hôte Linux, noyau compatible à vérifier) et éventuellement `k8s-N`.

Prérequis : TP5 ou TP6 recommandé, pour comparer avec l'auto-instrumentation.

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Principe et prérequis

À compléter. Points couverts :

- Vérifier la version du noyau et les privilèges nécessaires.
- Situer eBPF par rapport aux SDK et aux **agents**.

## 2. Déployer OBI à côté d'une application

À compléter. Points couverts :

- Installer OBI à une version épinglée.
- Désigner l'application à observer.

## 3. Lire ce qu'OBI produit

À compléter. Points couverts :

- Retrouver les spans dans Jaeger et les métriques dans Prometheus.
- Repérer les attributs disponibles.

## 4. Comparer avec l'auto-instrumentation

À compléter. Points couverts :

- Comparer profondeur des spans, attributs et surcoût.
- Dresser un tableau des écarts.

## 5. Limites et cas d'usage

À compléter. Points couverts :

- Examiner la propagation du contexte et l'absence de spans métier.
- Citer les cas où OBI est adapté (application non modifiable, langage sans **agent**).

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : déployer OBI sur Kubernetes en DaemonSet.
