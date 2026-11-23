# Lab 5 - Notes pour l'animateur

## Minutage indicatif

| Partie | Durée |
|---|---|
| 1. La pile et le parcours d'un message | 30 min |
| 2. Auto-instrumenter messenger | 25 min |
| 3. Nommer le service et lire le waterfall | 20 min |
| 4. Instrumenter notifier | 25 min |
| 5. Nginx devant l'application | 25 min |
| 6. Données applicatives et masquage | 20 min |
| Cleanup + Extra | 15 min |

Total indicatif : environ 2 h 40. La partie 1 inclut l'installation de Node.js via `asdf` et le build de l'infrastructure Docker.

## Architecture du lab

Le lab se déroule intégralement sur la machine cliente `clt-N` :
- L'infrastructure Docker Compose comprend Nginx (`ingress`, port 8080), RabbitMQ (port 5672/15672), deux bases PostgreSQL (`messenger-db` sur 5432, `notifier-db` sur 5433) et Jaeger (ports 16686, 4317, 4318).
- Les deux microservices Node.js (`messenger` sur le port 4000 et `notifier` sur le port 5000) sont exécutés nativement sur l'hôte avec Node.js 22.23.5 géré par `asdf`.
- À la partie 6, un **collector** éphémère est déployé dans le réseau Docker sur le port 4319 pour filtrer et masquer les données sensibles avant envoi vers Jaeger.

## Rejeu du 23 novembre 2026 (clt-0)

Le rejeu complet a été validé sur `clt-0` :
- **Partie 1** : installation d'`asdf` et de Node.js 22.23.5, clone des 3 dépôts (`messenger`, `notifier`, `platform`), lancement de la stack Compose, initialisation des deux bases PostgreSQL (`npm run refresh-db`), démarrage des deux services. La création de conversation et l'envoi de message fonctionnent à travers Nginx.
- **Partie 2** : installation des paquets `@opentelemetry/*` dans `messenger`, création de `tracing.mjs`, démarrage avec `--import ./tracing.mjs`. Le service `messenger` s'enregistre dans Jaeger et émet une trace par requête HTTP.
- **Partie 3** : enrichissement de la ressource (`deployment.environment.name: "lab5"`, `lab.id: "0"`). Inspection des attributs standardisés et des spans internes Express et PostgreSQL.
- **Partie 4** : auto-instrumentation de `notifier` (consommateur RabbitMQ). Envoi d'un message : une trace unique distribuée de 11 spans traverse `messenger`, RabbitMQ et `notifier`.
- **Partie 5** : mise à jour du Dockerfile Nginx avec `nginx:1.30.7-otel` et chargement du module `ngx_otel_module.so`. Envoi d'un message : trace complète de 12 spans commençant par le span racine Nginx (`messenger-lb`), relié au messenger puis au notifier.
- **Partie 6** : ajout du middleware `request-logger.mjs` capturant le corps JSON dans un événement `request.body`. Premier envoi : le numéro de téléphone apparaît en clair dans Jaeger. Déploiement du **collector** sur le port 4319 avec le processor `transform/redact` (expression régulière masquant les numéros). Deuxième envoi : le numéro est remplacé par `[numero masque]`.
- **Cleanup** : arrêt des processus Node.js, suppression du conteneur `otelcol` et de la stack Compose avec suppression des volumes. Tous les ports sont vérifiés libres.

## Points d'attention

- **Compatibilité RabbitMQ 4 et amqplib** : RabbitMQ 4 exige une taille minimale de trame AMQP (`frame_max`) de 8192 octets. La version `amqplib@0.10.9` résout ce point par rapport aux versions plus anciennes.
- **Port 4319 pour le collector de masquage** : le **collector** de la partie 6 écoute sur le port 4319 pour ne pas entrer en conflit avec le port OTLP 4318 déjà utilisé par Jaeger sur `clt-N`.
- **Gestion des processus en arrière-plan** : en formation, les participants utilisent plusieurs onglets du terminal web ou des fenêtres tmux pour suivre les logs de `messenger` et `notifier`.
