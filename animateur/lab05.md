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
- **Gestion des processus en arrière-plan** : en séance, les participants utilisent plusieurs onglets du terminal web ou des fenêtres tmux pour suivre les logs de `messenger` et `notifier`.
- **Version d'asdf** : rester sur la branche `v0.15.0`. La branche `v0.16.x` conserve l'ancien `asdf.sh` et un binaire intermédiaire, si bien que chaque appel à `node` ou `npm` imprime un avertissement de migration d'une vingtaine de lignes, qui rend les sorties du lab illisibles.
- **Attributs HTTP** : les conventions `http.*` se lisent sur le span serveur (`POST /conversations/:conversationId/messages`), pas sur les spans Express (`router - ...`, `middleware - ...`), qui portent `express.name` et `express.type`.
- **Requête de la partie 3** : utiliser une requête qui envoie un message. `GET /health` ne traverse aucune requête PostgreSQL et ne montre donc pas les spans `pg.*`.

## Rejeu du 24 novembre 2026 (clt-0)

Second rejeu complet sur une machine reconstruite par cloud-init, sans cluster KinD résiduel après suppression préalable (`kind delete cluster --name cluster`, qui libère le port 8080).

- **Partie 1** : `asdf` en `v0.15.0`, Node.js 22.23.5 et npm 10.9.9 conformes. Dépôts clonés aux commits épinglés (`d20437a`, `0c27d64`, `56aa89e`), les deux `.tool-versions` demandant bien 19.3.0 avant le `asdf local`. `docker compose ps` affiche les cinq conteneurs, `amqplib` passe en 0.10.9, les deux bases s'initialisent, les deux services écoutent sur 4000 et 5000, et les deux requêtes `curl` renvoient les réponses attendues.
- **Partie 2** : le service `messenger` apparaît dans Jaeger avec une trace par requête.
- **Partie 3** : ressource enrichie (`service.name`, `deployment.environment.name=lab5`, `lab.id=0`). Spans observés : `middleware - query`, `middleware - corsMiddleware`, `middleware - jsonParser`, `router - /conversations`, `pg-pool.connect`, `pg.query:SELECT messenger_dev`, `publish <default>`.
- **Partie 4** : la trace `f4065dd830a247fc` porte `messenger : publish <default>` et `notifier : chat_queue process`. La propagation par en-têtes AMQP est confirmée.
- **Partie 5** : image `nginx:1.30.7-otel` récupérée, module chargé. La trace `aa741ae4cca08afe` porte les trois services `messenger-lb`, `messenger` et `notifier`.
- **Partie 6** : l'événement `request.body` apparaît avec `0612345678` en clair, puis `[numero masque]` après passage par le **collector** sur 4319. Les deux événements coexistent dans Jaeger.
- **Cleanup** : `docker rm -f otelcol` puis `docker compose down -v`, plus aucun conteneur du lab.

Constats de ce rejeu, corrigés dans l'énoncé : l'avertissement `asdf` en `v0.16.7`, la note de la partie 2 qui affirmait que RabbitMQ n'était pas instrumenté, l'attribution erronée des attributs `http.*` aux spans Express, l'emploi de `GET /health` à la partie 3 alors que la trace décrite contient des spans PostgreSQL, et la mention d'un `~/lab05` réutilisé au lab 7, qui ne le référence pas.
