# TP3 - Corrigé

Fichiers de ce dossier : `gateway-values.yaml`, `agent-values.yaml` et `instrumentation.yaml`. Ce sont les fichiers complets que les participants obtiennent à la fin des parties 2, 3 et 4. Pour les utiliser directement :

```bash
cp ~/opentelemetry-labs/tp03-kubernetes/solution/*.yaml ~/tp03/
```

## Partie 2 : gateway

- Le chart n'a pas d'image par défaut (`image.repository` est vide) : sans la distribution `contrib` et `command.name: otelcol-contrib`, le pod ne démarre pas ou lance un autre binaire.
- Le bloc `config:` est fusionné avec la configuration par défaut du chart. Les dictionnaires (`exporters`, `processors`) sont fusionnés : `debug`, `batch` et `memory_limiter` restent déclarés. Les listes sont remplacées : la liste des processors du pipeline `traces` est exactement celle écrite par le participant.
- Le chart ajoute des éléments que le participant n'a pas écrits : l'extension `health_check` (obligatoire pour les sondes), les receivers `jaeger`, `zipkin` et `prometheus`, et les pipelines `metrics` et `logs` qui envoient vers `debug`. Ils sont inoffensifs ici.
- Dans la configuration générée, le chart écrit le type de l'exporter `otlp_grpc` (nom actuel du composant). L'ancien nom `otlp` fonctionne encore comme alias déprécié.
- Le `memory_limiter` du chart règle ses seuils en pourcentage (80 % et 25 %) de la limite mémoire du conteneur, d'où la section `resources.limits` du fichier de valeurs.

## Partie 3 : agent

- Le DaemonSet se nomme `otel-agent-agent` et le Service `otel-agent`.
- Le preset `kubernetesAttributes` ajoute le processor `k8s_attributes` (nom actuel, l'ancien `k8sattributes` est un alias), un ClusterRole qui autorise la lecture des pods, namespaces et ReplicaSets, et la variable `K8S_NODE_NAME` utilisée pour que l'agent ne surveille que les pods de son nœud.
- Quand le processor est listé explicitement dans le pipeline (`memory_limiter, k8s_attributes, batch`), le chart le conserve à cette position. Sans cela, il l'insère en tête, avant `memory_limiter`.
- L'association entre une donnée et un pod se fait, dans l'ordre, par l'attribut `k8s.pod.ip`, par `k8s.pod.uid`, puis par l'adresse IP de la connexion. Les pods de démonstration sont associés par l'adresse IP de la connexion, d'où l'intérêt du Service en `internalTrafficPolicy: Local` : la connexion vient directement du pod, sans passer par un autre nœud.
- Les traces envoyées directement à la gateway (partie 2) n'ont pas ces attributs, car la gateway n'a pas le processor `k8s_attributes`. C'est la comparaison attendue.

## Partie 4 : Operator

- Les options `admissionWebhooks.certManager.enabled=false` et `admissionWebhooks.autoGenerateCert.enabled=true` évitent d'installer cert-manager. Avec les valeurs par défaut du chart, l'installation échoue faute de CRD `Certificate`.
- L'annotation `instrumentation.opentelemetry.io/inject-nodejs: "true"` utilise l'`Instrumentation` de l'espace de noms du pod. Il est aussi possible de viser une ressource précise avec son nom, ou une ressource d'un autre espace de noms avec `espace/nom`.
- Le nom de service des traces est déduit par l'Operator : label `app.kubernetes.io/name` s'il existe, sinon nom du Deployment. Les déploiements de la démonstration n'ayant que le label `app`, le nom du Deployment (`frontend`, `backend`) est utilisé.
- L'argument de l'échantillonneur est une chaîne (`"1"`). Sans guillemets, la ressource est refusée à la validation.
- Pour la réponse « pourquoi l'agent plutôt que la gateway comme destination de l'`Instrumentation` ? » : l'agent est sur le même nœud (latence faible, trafic qui ne sort pas du nœud), enrichit les données avec les métadonnées du pod, et laisse à la gateway le rôle de point de sortie unique vers le backend.
