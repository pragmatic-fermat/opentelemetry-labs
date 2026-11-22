# Lab TP9 : **gateway** et production, échantillonnage, sécurité et fiabilité

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger. Hors périmètre actuel : le TP est conservé pour mémoire.

# Objectifs

À la fin du lab, vous saurez :

- comparer l'échantillonnage (sampling) en tête et en queue, puis configurer un tail sampling sur la **gateway** ;
- expliquer les contraintes du tail sampling sur plusieurs répliques de **gateway** et les choix de répartition qui en découlent ;
- sécuriser le lien entre l'**agent** et la **gateway** avec TLS puis mTLS ;
- ajouter une authentification sur le receiver de la **gateway** ;
- configurer les nouvelles tentatives (retry) et une file d'attente, et observer la reprise après une panne du backend.

# Contenu

- [Environnement](#environnement)
- [1. Topologie **agent** et **gateway** de départ](#1-topologie-agent-et-gateway-de-départ) : partir d'une chaîne **agent** vers **gateway** vers Jaeger.
- [2. Échantillonnage : head et tail](#2-échantillonnage--head-et-tail) : garder les traces en erreur et les traces lentes.
- [3. TLS et mTLS entre **agent** et **gateway**](#3-tls-et-mtls-entre-agent-et-gateway) : chiffrer puis authentifier mutuellement.
- [4. Authentification](#4-authentification) : exiger une identité sur le receiver.
- [5. Retry et file d'attente](#5-retry-et-file-dattente) : résister à l'indisponibilité du backend.
- [6. Limites du tail sampling et répartition sur plusieurs répliques](#6-limites-du-tail-sampling-et-répartition-sur-plusieurs-répliques) : pourquoi une trace doit rester sur une seule **gateway**.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `clt-N` (Docker Compose) ou `k8s-N`, à confirmer à la rédaction.

Prérequis : [TP1](Lab_TP01_Socle.md) et [TP3](Lab_TP03_Kubernetes.md) recommandés (topologie **agent** et **gateway**).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Topologie **agent** et **gateway** de départ

À compléter. Points couverts :

- Démarrer la topologie et envoyer du trafic de test.
- Repérer les points de défaillance.

## 2. Échantillonnage : head et tail

À compléter. Points couverts :

- Configurer un échantillonnage probabiliste en tête.
- Configurer des politiques de tail sampling et comparer. Point de discussion : tous les spans d'une trace doivent arriver sur la même **gateway**, ce que détaille [la partie 6](#6-limites-du-tail-sampling-et-répartition-sur-plusieurs-répliques).

## 3. TLS et mTLS entre **agent** et **gateway**

À compléter. Points couverts :

- Générer des certificats de test.
- Activer TLS puis mTLS et constater le refus d'un client sans certificat.

## 4. Authentification

À compléter. Points couverts :

- Activer une extension d'authentification sur la **gateway**.
- Tester un client autorisé et un client refusé.

## 5. Retry et file d'attente

À compléter. Points couverts :

- Configurer retry et file d'attente sur l'exporter.
- Arrêter puis relancer Jaeger et mesurer la reprise.

## 6. Limites du tail sampling et répartition sur plusieurs répliques

À compléter. Points couverts, sans entrer dans la configuration :

- le tail sampling impose un traitement **par trace** : la **gateway** doit recevoir tous les spans d'une trace, attendre la fin de la trace, puis décider. Ce que cela coûte en mémoire (état des traces en cours) et en latence de décision ;
- le piège d'un Service Kubernetes ordinaire : avec plusieurs répliques de **gateway**, le load balancer répartit les connexions sans tenir compte des traces, et les spans d'une même trace se dispersent. Chaque réplique décide alors seule, avec une vue partielle : traces tronquées, décisions incohérentes ;
- les réponses possibles, citées sans être détaillées : l'exporter `loadbalancing` dans l'**agent**, qui route par identifiant de trace ; une seule réplique de **gateway** pour le tail sampling ; ou des répliques partitionnées par trace (`StatefulSet` avec `routing_key`) ;
- la perte d'état : les décisions en cours vivent en mémoire de chaque réplique, et un redémarrage les perd ;
- le compromis d'exploitation : head sampling peu coûteux mais aveugle aux erreurs et aux lenteurs, tail sampling plus juste mais plus lourd à dimensionner.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : mettre en place l'exporter `loadbalancing` entre deux **gateways** et vérifier qu'une trace reste entière, pour illustrer [la partie 6](#6-limites-du-tail-sampling-et-répartition-sur-plusieurs-répliques).
