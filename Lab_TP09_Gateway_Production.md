# Lab TP9 : gateway et production, échantillonnage, sécurité et fiabilité

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger. Hors périmètre actuel : le TP est conservé pour mémoire.

# Objectifs

À la fin du lab, nous saurons :

- comparer l'échantillonnage en tête (head) et en queue (tail) et configurer un tail sampling sur la gateway ;
- sécuriser le lien entre l'agent et la gateway avec TLS puis mTLS ;
- ajouter une authentification sur le receiver de la gateway ;
- configurer les nouvelles tentatives (retry) et une file d'attente, et observer la reprise après une panne du backend.

# Contenu

- [Environnement](#environnement)
- [1. Topologie agent et gateway de départ](#1-topologie-agent-et-gateway-de-départ) : partir d'une chaîne agent vers gateway vers Jaeger.
- [2. Échantillonnage : head et tail](#2-échantillonnage--head-et-tail) : garder les traces en erreur et les traces lentes.
- [3. TLS et mTLS entre agent et gateway](#3-tls-et-mtls-entre-agent-et-gateway) : chiffrer puis authentifier mutuellement.
- [4. Authentification](#4-authentification) : exiger une identité sur le receiver.
- [5. Retry et file d'attente](#5-retry-et-file-dattente) : résister à l'indisponibilité du backend.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `clt-N` (Docker Compose) ou `k8s-N`, à confirmer à la rédaction.

Prérequis : TP1 et TP3 recommandés (topologie agent et gateway).

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Topologie agent et gateway de départ

À compléter. Points couverts :

- Démarrer la topologie et envoyer du trafic de test.
- Repérer les points de défaillance.

## 2. Échantillonnage : head et tail

À compléter. Points couverts :

- Configurer un échantillonnage probabiliste en tête.
- Configurer des politiques de tail sampling et comparer. Point de discussion : tous les spans d'une trace doivent arriver sur la même gateway.

## 3. TLS et mTLS entre agent et gateway

À compléter. Points couverts :

- Générer des certificats de test.
- Activer TLS puis mTLS et constater le refus d'un client sans certificat.

## 4. Authentification

À compléter. Points couverts :

- Activer une extension d'authentification sur la gateway.
- Tester un client autorisé et un client refusé.

## 5. Retry et file d'attente

À compléter. Points couverts :

- Configurer retry et file d'attente sur l'exporter.
- Arrêter puis relancer Jaeger et mesurer la reprise.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : répartir la charge entre plusieurs gateways avec l'exporter de répartition par trace.
