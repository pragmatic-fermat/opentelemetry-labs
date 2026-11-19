# Lab TP4 : Ansible et Jinja2, déployer le Collector sur VM

Statut : objectifs et contenu de haut niveau (HLD) rédigés, détail à rédiger. Une première rédaction détaillée existe dans la branche `tp04-ansible`, à convertir au format des labs.

# Objectifs

À la fin du lab, vous saurez :

- décrire un serveur dans un inventaire Ansible et vérifier la connexion avec un module ad hoc ;
- écrire un playbook idempotent qui installe le Collector à partir d'un paquet, dont le téléchargement est vérifié par une somme de contrôle ;
- générer la configuration du Collector avec un template Jinja2 (variables, boucle, condition) ;
- modifier la configuration par les variables, la comparer avant déploiement avec `--check --diff`, et protéger le service d'une configuration invalide ;
- vérifier que les traces et les métriques de `srv-N` arrivent dans Jaeger et dans Prometheus.

# Contenu

- [Environnement](#environnement)
- [1. Préparer le poste de contrôle](#1-préparer-le-poste-de-contrôle) : inventaire, accès SSH et module ad hoc.
- [2. Installer le Collector](#2-installer-le-collector) : un playbook idempotent avec paquet, somme de contrôle, service systemd et handler.
- [3. Générer la configuration avec Jinja2](#3-générer-la-configuration-avec-jinja2) : un template avec variables, boucle et condition.
- [4. Modifier la configuration et redéployer](#4-modifier-la-configuration-et-redéployer) : changer les variables, comparer avec `--check --diff`, vérifier les données.
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Machine(s) : `clt-N` (poste de contrôle Ansible et backends) et `srv-N` (serveur cible).

Prérequis : TP1 recommandé. Aucune connaissance préalable d'Ansible n'est supposée.

Durée prévue : 1/4 j (environ 2 heures de manipulation).

Versions : à vérifier dans les registres et à dater au moment de la rédaction détaillée.

## 1. Préparer le poste de contrôle

À compléter. Points couverts :

- Écrire l'inventaire et la configuration Ansible.
- Tester la connexion vers `srv-N`.

## 2. Installer le Collector

À compléter. Points couverts :

- Télécharger et installer le paquet à une version épinglée.
- Activer le service et vérifier l'idempotence en relançant le playbook.

## 3. Générer la configuration avec Jinja2

À compléter. Points couverts :

- Écrire le template de configuration du Collector.
- Valider la configuration avant remplacement du fichier réel et redémarrer le service seulement si elle change.

## 4. Modifier la configuration et redéployer

À compléter. Points couverts :

- Changer un exporter ou un processor par les variables, par environnement.
- Retrouver les traces et les métriques de `srv-N` dans les backends.

## Cleanup

À compléter : commandes qui défont ce que le lab a démarré.

## Extra

À compléter. Idée : transformer le playbook en rôle, ajouter un receiver de logs, ou déclarer un second serveur avec ses propres variables.
