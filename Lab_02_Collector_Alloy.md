# Lab 2 : **collector** sur mesure et Alloy

<sub>1</sub> Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger. Hors périmètre actuel : le lab est conservé pour mémoire.

# Objectifs

À la fin du lab, vous saurez :

- expliquer pourquoi la distribution `contrib` n'est pas adaptée à la production (taille, surface d'attaque, mises à jour subies en bloc) et dans quels cas `core` suffit ;
- décrire un **collector** sur mesure dans un manifeste OCB (OpenTelemetry **collector** Builder), en ne retenant que les receivers, processors et exporters nécessaires ;
- construire le binaire puis une image Docker, et comparer taille et liste de composants avec `contrib` ;
- faire tourner la configuration du [lab 1](Lab_01_Socle.md) sur ce **collector** et constater qu'un composant absent est refusé dès la validation ;
- reproduire un pipeline OTLP vers Jaeger avec Grafana Alloy, puis citer ses gains et ses limites.

# Contenu

- [Environnement](#environnement)
- [1. Comparer les distributions core et contrib](#1-comparer-les-distributions-core-et-contrib) : lister les composants de chaque distribution et mesurer leur image.
- [2. Décrire le **collector** voulu dans un manifeste OCB](#2-décrire-le-collector-voulu-dans-un-manifeste-ocb) : choisir les composants et épingler leurs versions.
- [3. Construire le binaire et l'image](#3-construire-le-binaire-et-limage) : compiler avec `ocb`, puis produire une image Docker.
- [4. Valider avec la configuration du lab 1](#4-valider-avec-la-configuration-du-lab-1) : exécuter le **collector** sur mesure et constater l'effet d'un composant absent.
- [5. Grafana Alloy : le même pipeline](#5-grafana-alloy--le-même-pipeline) : reproduire OTLP vers Jaeger avec Alloy.
- [6. Gains et limites](#6-gains-et-limites) : remplir une grille de comparaison **collector** sur mesure et Alloy.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

<sub>2</sub> Machine(s) : `clt-N`.

Prérequis : [lab 1](Lab_01_Socle.md) recommandé : les backends et la configuration du **collector** du lab 1 sont réutilisés pour valider le **collector** sur mesure.

<sub>3</sub> Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Comparer les distributions core et contrib

À compléter. Points couverts :

- Lister les composants disponibles dans chaque distribution.
- Mesurer la taille des images et en tirer les conséquences en production.

## 2. Décrire le **collector** voulu dans un manifeste OCB

<sub>4</sub> À compléter. Points couverts :

- Partir de la configuration du [lab 1](Lab_01_Socle.md) pour déduire la liste minimale de composants.
- Écrire le manifeste OCB avec des versions exactes.

## 3. Construire le binaire et l'image

À compléter. Points couverts :

- Installer `ocb` à une version épinglée.
- Construire le binaire, puis l'image, et comparer les tailles avec `contrib`.

## 4. Valider avec la configuration du lab 1

<sub>5</sub> À compléter. Points couverts :

- Valider et démarrer le **collector** avec la configuration du [lab 1](Lab_01_Socle.md).
- Ajouter un composant absent du manifeste et lire l'erreur de validation.

## 5. Grafana Alloy : le même pipeline

À compléter. Points couverts :

- Installer Alloy et écrire l'équivalent du pipeline dans sa syntaxe.
- Utiliser l'interface de debug d'Alloy pour suivre le pipeline.

## 6. Gains et limites

<sub>6</sub> À compléter. Points couverts :

- Comparer la portabilité des configurations, les composants disponibles, le support et le périmètre fonctionnel.
- Conclure par des critères de choix et non par une recommandation unique. Les points sur Alloy sont à revérifier sur la version retenue.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

<sub>7</sub> À compléter. Idée : ajouter un second exporter au manifeste, reconstruire et mesurer l'écart de taille.
