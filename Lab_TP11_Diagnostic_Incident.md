# Lab TP11 : diagnostic d'incident sur l'OpenTelemetry Demo

Statut : objectifs, contenu et concepts rédigés. Les commandes et les résultats attendus restent à écrire.

# Objectifs

À la fin du lab, vous saurez :

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

Prérequis : [TP1](Lab_TP01_Socle.md) recommandé. Plusieurs TP d'instrumentation sont utiles mais non obligatoires.

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## Ce que ce TP introduit, suppose et laisse

- Introduit : une méthode de diagnostic sur une application que l'on n'a pas écrite, le croisement des trois signaux, et la rédaction d'un compte rendu d'incident.
- Suppose vu : la lecture d'une trace et d'un log relié à sa trace. Aucun TP n'est exigé : la Demo embarque sa propre pile de collecte et de backends.
- Laisse : l'instrumentation, la collecte et la corrélation, déjà traitées ([TP5](Lab_TP05_NodeJS_Nginx.md) à [TP7](Lab_TP07_Instrumentation_Manuelle.md), [TP10](Lab_TP10_Exploitation.md)). Ce TP les utilise, il ne les réexplique pas.

## 1. Déployer la Demo et se repérer

Concepts : une architecture inconnue et instrumentée ; la distinction entre ce que la télémétrie montre et ce que l'on suppose ; la lecture d'une carte de services à partir des traces et des métriques.

Démonstration : la Demo tourne et se visite ; le participant cartographie ses services, son **collector** et ses backends, puis vérifie cette carte par une première requête suivie de bout en bout.

Hors périmètre : modifier la Demo, son image ou son instrumentation.

## 2. Premier incident : une panne franche

Concepts : symptôme, hypothèse, preuve ; le chemin d'une erreur visible côté utilisateur vers le service fautif ; le rôle des logs reliés à la trace pour nommer la cause.

Démonstration : activer un feature flag qui provoque des erreurs, constater le symptôme, remonter des métriques aux traces puis aux logs, et nommer la cause sans aide.

Hors périmètre : corriger le code de la Demo ; le feature flag est le seul levier d'injection.

## 3. Deuxième incident : une dégradation

Concepts : l'absence d'erreur comme symptôme ; lenteur, saturation et consommation de ressources ; la comparaison entre un service sain et un service dégradé ; le choix du signal le plus rapide à lire selon la question posée.

Démonstration : activer un flag qui dégrade les performances, identifier le service responsable par les latences et les métriques de ressources, puis confirmer par une trace et un log.

Hors périmètre : l'optimisation de la Demo ; on cherche la cause, pas le correctif.

## 4. Troisième incident : cas libre

Concepts : transposer la méthode sans guide ; choisir soi-même ses preuves et l'ordre de lecture ; assumer un diagnostic incomplet et dire ce qui manque.

Démonstration : choisir un scénario parmi ceux de la version retenue, le résoudre seul et rédiger le compte rendu sans aide.

Hors périmètre : la liste des scénarios, à vérifier avec la version de la Demo au moment de la rédaction.

## 5. Synthèse : la méthode

Concepts : une démarche réutilisable (symptôme, périmètre, preuve, cause, correctif proposé) ; ses limites, notamment les trous de collecte et l'échantillonnage (sampling), qui peuvent faire disparaître la preuve attendue.

Démonstration : comparer les chemins suivis par les participants, formaliser la méthode en quelques étapes, et la confronter à un cas où la télémétrie manque.

Hors périmètre : la mise en place d'alertes ou de tableaux de bord, qui relèvent du backend.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : rejouer l'incident avec les logs du SDK (`OTEL_LOG_LEVEL=debug`) puis revenir au niveau `info`, et comparer ce que chacun apporte au diagnostic.
