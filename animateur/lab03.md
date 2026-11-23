# Lab 3 - Notes pour l'animateur

## Minutage indicatif

| Partie | Durée |
|---|---|
| 1. Préparer le cluster et les applications | 20 min |
| 2. Backends sur srv-N et gateway | 35 min |
| 3. Agent | 20 min |
| 4. Logs avec Fluent Bit | 25 min |
| 5. Operator et auto-instrumentation | 30 min |

Si le groupe est en retard, les parties 2 et 5 sont les plus démonstratives : conservez-leur au moins 20 minutes chacune et abrégez la lecture du rendu `helm template` de la partie 2.

## Architecture retenue

- Les backends (Jaeger 2.23.0 et VictoriaLogs v1.54.0) tournent sur `srv-N`, avec Docker Compose (`config/lab03/compose.yaml`), et non dans le cluster. Les traces et les logs quittent le cluster par la gateway, sur les ports 4318 et 9428 de `srv-N`, et les interfaces web sont jointes directement sur ces ports (16686 et 9428).
- Fluent Bit (chart 0.58.3, image 5.1.3) lit les logs des nœuds et les envoie en OTLP/HTTP à la gateway. Le preset `logsCollection` du chart du collector n'est pas utilisé : l'agent ne collecte que les traces.
- La gateway joint `srv-N` par son nom DNS public. En production, on passerait par le réseau privé du VPC et par TLS.

## Rejeux du 21 et du 23 novembre 2026

Le lab a été rejoué intégralement le 23 novembre 2026 sur les machines reconstruites (`clt-0` et `srv-0`), confirmant le rejeu initial du 21 novembre. Tout le parcours a été déroulé : création du cluster KinD (1 control-plane, 3 workers), Gateway API et Traefik (DaemonSet), déploiement des deux applications, backends en Compose sur `srv-0` (Jaeger et VictoriaLogs), gateway, agent, Fluent Bit, requêtes LogsQL, operator, auto-instrumentation, puis cleanup.

Deux corrections ont été apportées lors de ce rejeu :
- **URL du dépôt Helm open-telemetry** : ajout du trait d'union manquant (`https://open-telemetry.github.io/opentelemetry-helm-charts`), l'ancienne URL sans trait d'union renvoyant une erreur HTTP 404.
- **Fonction vlogs dans helpers.sh** : la fonction transmet désormais la requête LogsQL à l'endpoint `/select/logsql/query` de VictoriaLogs (`curl -s -G "http://${SRV_HOST}:9428/select/logsql/query" --data-urlencode "query=$1"`), rendant fonctionnelles les commandes `vlogs "_msg: ..."` du lab.

Résultats conformes au texte :

- capture `img/lab03-vlogs-logsql.png` refaite sur la nouvelle chaîne de collecte ;
- `crd=10`, Traefik sur les quatre nœuds, `Gateway` programmée ;
- traces `k8s-gateway` comptées à 5 dans Jaeger, attributs `k8s.*` présents sur `k8s-agent` et absents sur `k8s-gateway` ;
- un pod Fluent Bit par worker, messages `GET /api/orders` dans VictoriaLogs, requêtes LogsQL et `stats` conformes ;
- init container et variables `OTEL_*` conformes, services `frontend` et `backend` dans Jaeger, deux namespaces dans les traces, `deployment.environment.name=lab3` après l'extra 1 ;
- ressource `OpenTelemetryCollector` prête, un Deployment et trois Services créés ;
- cleanup : releases, espaces de noms et cluster supprimés, `docker compose down -v` sur `srv-0`, ports 8080, 4318, 9428 et 16686 libres sur les deux machines.

## Points d'attention

- Gateway API : le mot « gateway » désigne deux choses dans le lab. Le lab distingue explicitement la `Gateway` de Kubernetes (trafic web) de la gateway OpenTelemetry (télémétrie). Cette distinction est une remarque de revue, à ne pas perdre.
- Traefik met quelques secondes à voir une `HTTPRoute` : la première requête peut répondre `no available server`. Le lab le signale.
- Fluent Bit collecte tous les pods par défaut, y compris lui-même : ses propres lignes étaient relues en boucle et noyaient les messages des applications. L'input `tail` du lab est donc restreint à `*_application-*_*.log`, et le texte explique pourquoi. Ne pas retirer cette restriction sans vérifier le résultat.
- Fluent Bit : `modify` ne sait renommer que des clés de premier niveau. D'où le filtre `nest` (`Operation lift`, `Nested_under kubernetes`) avant les `Rename` ; sans lui, les clés restent imbriquées et les requêtes LogsQL du lab ne trouvent rien.
- Fluent Bit : `logs_body_key log` place la ligne applicative dans le corps OTLP, et `logs_body_key_attributes true` est indispensable pour que les autres champs deviennent des attributs.
- Fluent Bit : l'input `tail` du chart ne relit pas le passé. Les lignes de démarrage des pods ne sont pas collectées, et `k8s.pod.name` change à chaque redémarrage.
- Les métadonnées du filtre `kubernetes` autres que les quatre renommées restent visibles, préfixées par `kubernetes.` : c'est normal, et dit dans le lab.
- VictoriaLogs n'affiche aucune étiquette de flux avec cette chaîne : le panneau « Stream fields » de vmui est vide, et `_stream` vaut `{}`. Les champs `k8s.*` sont des attributs d'enregistrement, ne pas les présenter comme des étiquettes.
- `severity_text` vaut `Unspecified` : Fluent Bit n'analyse pas le niveau de sévérité d'une ligne de texte. La requête sur `ERROR` du lab ne renvoie rien, et le texte l'explique.
- Les variables `OTEL_*` injectées contiennent des variables vides, remplies par Kubernetes (`fieldRef`), et des `$(...)` dans `OTEL_RESOURCE_ATTRIBUTES`, remplacés au démarrage : `service.instance.id` devient par exemple `application-a.frontend-755c565478-h8dnl.frontend`.
- `docker compose ls` affiche l'en-tête de ses colonnes même sans projet : le lab parle d'absence de projet, pas d'absence de ligne.
- Traefik tourne en DaemonSet avec `hostPort: 80` : toute mise à jour du chart peut bloquer, le nouveau pod du control-plane ne pouvant prendre le port tant que l'ancien le détient. Si cela arrive, supprimer les pods (`kubectl -n traefik delete pods --all`).
- L'agent se planifie sur les workers seulement (le control-plane garde sa taint). Les applications de démonstration sont donc toujours colocalisées avec un agent, condition nécessaire avec `internalTrafficPolicy: Local`.
- Le cluster s'appelle toujours `cluster` et `config/cluster/cluster-create.sh` supprime le précédent avant de le recréer : règle consignée dans `CONVENTIONS.md`, pas réexpliquée dans le lab.
- Le chart de l'operator contient deux pods de test avec `busybox:latest` : ne pas lancer `helm test`.
- Les valeurs du chart du collector sont validées pour la version 0.179.1, dont l'image par défaut est la 0.163.2.
- L'authentification des backends est absente : c'est assumé pour la démonstration, et dit dans le lab.

## Pour la discussion

- Gateway et agent répondent à deux besoins différents : la gateway centralise les traitements coûteux et l'export vers plusieurs backends, l'agent reste proche des applications pour enrichir avec les métadonnées locales.
- Fluent Bit ou le receiver `file_log` du collector : les deux lisent les fichiers des nœuds. Fluent Bit est souvent déjà là et parle OTLP ; le receiver évite un second agent mais reste plus jeune. Le lab tranche pour Fluent Bit et le justifie.
- Helm ou ressource `OpenTelemetryCollector` en GitOps : le lab donne les deux arguments (couche supprimée avec la ressource, indépendance vis-à-vis de l'operator avec le chart), sans trancher à la place des participants.
- L'injection par l'operator ne touche pas l'image de l'application : c'est ce qui la distingue d'une instrumentation par le SDK.
