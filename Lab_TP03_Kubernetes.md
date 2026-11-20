# Lab TP3 : collector sur Kubernetes, gateway, agent et Operator

# Objectifs

À la fin du lab, vous saurez :

- déployer un **collector** en mode gateway puis en mode agent (DaemonSet) avec le chart Helm officiel, et adapter sa configuration par un fichier de valeurs ;
- expliquer comment le chart fusionne votre configuration avec ses valeurs par défaut et ce que fait un preset ;
- enrichir les traces avec les métadonnées Kubernetes grâce au processor `k8s_attributes` ;
- installer l'OpenTelemetry Operator et décrire une auto-instrumentation avec une ressource `Instrumentation` ;
- activer l'instrumentation d'un déploiement par une annotation et retrouver la trace de bout en bout dans Jaeger.

# Contenu

- [Environnement](#environnement)
- [1. Préparer le cluster](#1-préparer-le-cluster)
- [2. Le collector en mode gateway](#2-le-collector-en-mode-gateway)
- [3. Le collector en mode agent](#3-le-collector-en-mode-agent)
- [4. L'Operator et l'auto-instrumentation](#4-loperator-et-lauto-instrumentation)
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Ce lab se déroule sur la machine cliente `clt-N` (N est votre numéro de participant), qui héberge un cluster Kubernetes local créé avec KinD : un nœud control-plane et un worker.

Vous travaillez depuis le terminal web de cette machine, dans `/root`, et le dépôt des labs y est déjà cloné dans `/root/opentelemetry-labs`.

Le TP1 est conseillé : il présente les **receiver**, **processor** et **exporter** du collector, qui ne sont pas réexpliqués ici.

Versions utilisées dans ce lab :

| Composant | Version |
|---|---|
| Chart Helm `opentelemetry-collector` | 0.179.1 |
| Image du collector (distribution `otelcol-contrib`) | 0.163.2 (version du chart) |
| Chart Helm `opentelemetry-operator` | 0.129.1 |
| Image de l'Operator | 0.162.0 |
| Image d'auto-instrumentation Node.js | 0.82.0-1 |
| Jaeger | 2.23.0 |
| Node.js (application de démonstration) | 22.23.5 |
| telemetrygen | v0.165.0 |

Les interfaces web passent par l'ingress du cluster, publié sur le port `TCP/8080` de la machine `clt-N` :

- Jaeger : `http://jaeger.$INGRESS_HOST:8080` ;
- application : `http://app.$INGRESS_HOST:8080`.

La variable `INGRESS_HOST` contient le nom qui pointe vers la machine (`echo $INGRESS_HOST`).

## 1. Préparer le cluster

Copiez les fichiers fournis dans un dossier de travail et chargez les fonctions d'aide :

```bash
mkdir -p ~/tp03
cp -r ~/opentelemetry-labs/config/tp03/. ~/tp03/
cd ~/tp03
source helpers.sh
kubectl get nodes
```

On obtient deux nœuds, le control-plane et le worker, à l'état `Ready` :

```text
NAME                 STATUS   ROLES           AGE   VERSION
tp03-control-plane   Ready    control-plane   5m    v1.37.0
tp03-worker          Ready    <none>          4m    v1.37.0
```

Les fonctions `app` et `jaeger` appellent l'application et l'API de Jaeger par l'ingress. Rechargez-les avec `source ~/tp03/helpers.sh` dans chaque nouveau terminal.

Le dossier contient trois manifestes : `namespaces.yaml` (les espaces de noms `observability` et `demo`), `jaeger.yaml` (Jaeger avec stockage en mémoire) et `demo-app.yaml` (une application Node.js en deux services, `frontend` et `backend`, dont le code est dans un ConfigMap).

Les deux manifestes qui déclarent un Ingress contiennent le texte `INGRESS_HOST`, que `sed` remplace par votre nom avant l'envoi au cluster :

```bash
kubectl apply -f namespaces.yaml
sed "s/INGRESS_HOST/$INGRESS_HOST/g" jaeger.yaml | kubectl apply -f -
sed "s/INGRESS_HOST/$INGRESS_HOST/g" demo-app.yaml | kubectl apply -f -
kubectl -n observability rollout status deployment/jaeger
kubectl -n demo rollout status deployment/frontend deployment/backend
```

Contrôlez que l'application répond et que Jaeger est vide :

```bash
app /api/orders
jaeger /api/services
```

La première commande affiche une réponse JSON du frontend qui contient celle du backend :

```text
{"from":"frontend","backend":{"from":"backend","path":"/api/orders"}}
```

La seconde affiche un objet dont la liste `data` est vide (ou `null`) : Jaeger répond, mais ne contient encore aucune trace, car l'application n'est pas instrumentée. Ouvrez aussi `http://jaeger.$INGRESS_HOST:8080` dans votre navigateur.

## 2. Le collector en mode gateway

Une gateway est un collector central, déployé comme un Deployment, qui reçoit les données de plusieurs sources et les envoie au backend. Vous allez la déployer avec le chart Helm officiel.

Ajoutez le dépôt de charts :

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

Le chart se configure par un fichier de valeurs. Le chart n'impose pas d'image par défaut : il faut indiquer la distribution `contrib` et le nom de son exécutable.

La configuration du collector se place sous la clé `config:` de ce fichier. Le chart la fusionne avec sa configuration par défaut : les dictionnaires sont fusionnés, les listes sont remplacées.

Créez le fichier complet, avec l'exporter `otlp_grpc/jaeger` vers `jaeger.observability.svc.cluster.local` (port `TCP/4317`, sans TLS) et un pipeline `traces` qui relie le receiver `otlp`, les processors `memory_limiter` puis `batch`, et cet exporter :

```bash
cat > gateway-values.yaml <<'EOF'
mode: deployment
fullnameOverride: otel-gateway
replicaCount: 1
image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib
  tag: "0.163.2"
command:
  name: otelcol-contrib
resources:
  limits:
    cpu: 250m
    memory: 256Mi
config:
  exporters:
    otlp_grpc/jaeger:
      endpoint: jaeger.observability.svc.cluster.local:4317
      tls:
        insecure: true
  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, batch]
        exporters: [otlp_grpc/jaeger]
EOF
```

Avant d'installer, regardez ce que le chart génère à partir de vos valeurs :

```bash
helm template otel-gateway open-telemetry/opentelemetry-collector --version 0.179.1 \
  -n observability -f gateway-values.yaml | grep -B2 -A60 'relay:'
```

Repérez ce que vous n'avez pas écrit : l'extension `health_check`, les receivers par défaut, et les pipelines `metrics` et `logs`. C'est la fusion du chart avec ses propres valeurs.

Installez ensuite la gateway :

```bash
helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector \
  --version 0.179.1 -n observability -f gateway-values.yaml --wait
```

Envoyez cinq traces de test depuis un pod temporaire, avec `telemetrygen` :

```bash
kubectl -n demo run tg-gateway --restart=Never --rm -i \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 -- \
  traces --otlp-endpoint otel-gateway.observability.svc.cluster.local:4317 \
  --otlp-insecure --rate 10 --traces 5 --service k8s-gateway
```

Contrôlez le pod et le nombre de traces reçues par Jaeger :

```bash
kubectl -n observability get pods -l app.kubernetes.io/instance=otel-gateway
jaeger '/api/traces?service=k8s-gateway&limit=20' | jq '.data | length'
```

La première commande affiche un pod `otel-gateway-...` à l'état `Running`, la seconde affiche :

```text
5
```

## 3. Le collector en mode agent

Un agent est un collector déployé comme un DaemonSet : un pod par nœud, proche des applications. Il enrichit les données avec les métadonnées Kubernetes puis les transmet à la gateway.

Le processor `k8s_attributes` interroge l'API Kubernetes pour retrouver, à partir de l'adresse IP du pod émetteur, son nom, son espace de noms, son déploiement et son nœud.

Deux réglages du fichier de valeurs méritent une explication. Le preset `kubernetesAttributes` ajoute au chart le processor `k8s_attributes` et les droits RBAC dont il a besoin pour lire l'API Kubernetes. Le réglage `service.enabled` crée un Service, que le chart ne crée pas par défaut pour un DaemonSet : en mode agent, ce Service est configuré avec `internalTrafficPolicy: Local`, de sorte qu'une application atteint toujours l'agent de son propre nœud.

Listez vous-même `k8s_attributes` dans le pipeline : sans cela, le preset l'ajoute en première position, avant `memory_limiter`.

```bash
cat > agent-values.yaml <<'EOF'
mode: daemonset
fullnameOverride: otel-agent
image:
  repository: ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib
  tag: "0.163.2"
command:
  name: otelcol-contrib
resources:
  limits:
    cpu: 250m
    memory: 256Mi
service:
  enabled: true
presets:
  kubernetesAttributes:
    enabled: true
config:
  exporters:
    otlp_grpc/gateway:
      endpoint: otel-gateway.observability.svc.cluster.local:4317
      tls:
        insecure: true
  service:
    pipelines:
      traces:
        receivers: [otlp]
        processors: [memory_limiter, k8s_attributes, batch]
        exporters: [otlp_grpc/gateway]
EOF
```

Installez l'agent :

```bash
helm upgrade --install otel-agent open-telemetry/opentelemetry-collector \
  --version 0.179.1 -n observability -f agent-values.yaml --wait
kubectl -n observability get daemonset otel-agent-agent
```

Le DaemonSet se nomme `otel-agent-agent` : le chart ajoute le suffixe `-agent` en mode daemonset, alors que le Service garde le nom `otel-agent`. Les colonnes `DESIRED` et `READY` sont égales.

Envoyez des traces de test à l'agent, cette fois, et non à la gateway :

```bash
kubectl -n demo run tg-agent --restart=Never --rm -i \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 -- \
  traces --otlp-endpoint otel-agent.observability.svc.cluster.local:4317 \
  --otlp-insecure --rate 10 --traces 5 --service k8s-agent
```

Les traces portent maintenant des attributs Kubernetes que `telemetrygen` ne connaît pas :

```bash
jaeger '/api/traces?service=k8s-agent&limit=1' \
  | jq -r '.data[0].processes[].tags[] | select(.key | startswith("k8s.")) | "\(.key)=\(.value)"'
```

La commande affiche notamment :

```text
k8s.pod.name=tg-agent
k8s.namespace.name=demo
k8s.node.name=<nom du worker>
```

Comparez avec les traces `k8s-gateway` de la partie 2, qui n'ont pas ces attributs : l'enrichissement vient de l'agent.

## 4. L'Operator et l'auto-instrumentation

L'OpenTelemetry Operator injecte un agent d'instrumentation dans les pods qui portent une annotation, au moment de leur création, sans modifier l'image de l'application.

Pour Node.js, il ajoute un conteneur d'initialisation qui copie la bibliothèque d'instrumentation dans le pod, et il définit les variables d'environnement qui l'activent.

Installez l'Operator. Le chart propose par défaut d'utiliser cert-manager pour les certificats de son webhook, ce qui n'est pas installé ici : les deux options suivantes demandent au chart de générer lui-même un certificat.

```bash
helm upgrade --install operator open-telemetry/opentelemetry-operator \
  --version 0.129.1 -n opentelemetry-operator-system --create-namespace \
  --set admissionWebhooks.certManager.enabled=false \
  --set admissionWebhooks.autoGenerateCert.enabled=true \
  --set manager.image.tag=0.162.0 --wait
kubectl get crd | grep opentelemetry.io
```

Les ressources `instrumentations.opentelemetry.io` et `opentelemetrycollectors.opentelemetry.io` apparaissent dans la liste. N'exécutez pas `helm test` sur ce chart : ses pods de test utilisent une image qui n'est pas épinglée.

La ressource `Instrumentation` décrit comment instrumenter : où envoyer les données, quels propagators utiliser, quel échantillonnage appliquer et quelle image d'instrumentation injecter.

Créez-la dans l'espace de noms `demo`. L'exporter vise l'agent en OTLP HTTP (`http://otel-agent.observability.svc.cluster.local:4318`), protocole par défaut du SDK Node.js :

```bash
cat > instrumentation.yaml <<'EOF'
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: demo
  namespace: demo
spec:
  exporter:
    endpoint: http://otel-agent.observability.svc.cluster.local:4318
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1"
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:0.82.0-1
EOF
```

L'argument du sampler est entre guillemets : c'est une chaîne.

Appliquez-la, puis activez l'instrumentation des deux déploiements avec l'annotation `instrumentation.opentelemetry.io/inject-nodejs: "true"`.

L'annotation doit se trouver sur le modèle de pod, et non sur le Deployment : `kubectl patch` la place au bon endroit et déclenche le remplacement des pods.

```bash
kubectl apply -f instrumentation.yaml
for d in frontend backend; do
  kubectl -n demo patch deployment $d -p \
    '{"spec":{"template":{"metadata":{"annotations":{"instrumentation.opentelemetry.io/inject-nodejs":"true"}}}}}'
done
kubectl -n demo rollout status deployment/frontend deployment/backend
```

L'`Instrumentation` doit exister avant la création des pods : l'Operator ne modifie pas un pod déjà démarré.

Générez du trafic :

```bash
for i in $(seq 20); do app /api/orders > /dev/null; done
```

Les pods contiennent maintenant un conteneur d'initialisation que vos manifestes ne déclarent pas :

```bash
kubectl -n demo get pod -l app=frontend -o jsonpath='{.items[*].spec.initContainers[*].name}{"\n"}'
```

On obtient :

```text
opentelemetry-auto-instrumentation-nodejs
```

Dans Jaeger, les services `frontend` et `backend` sont apparus :

```bash
jaeger '/api/services' | jq -c '.data'
jaeger '/api/traces?service=frontend&limit=1' \
  | jq -c '[.data[0].processes[].serviceName] | unique'
```

La première commande contient `frontend` et `backend`, la seconde affiche :

```text
["backend","frontend"]
```

Une même trace traverse donc les deux services. Ouvrez-la dans l'interface de Jaeger (`http://jaeger.$INGRESS_HOST:8080`) : vous voyez le span serveur du frontend, le span client de son appel au backend, puis le span serveur du backend. Le lien entre les deux services repose sur le propagator `tracecontext`.

Regardez enfin les attributs de ressource de cette trace : `k8s.pod.name`, `k8s.namespace.name` et `k8s.node.name` y figurent, ajoutés par l'agent.

**NB** : si les pods redémarrent mais qu'aucune trace n'apparaît, vérifiez que le conteneur d'initialisation est présent (`kubectl -n demo describe pod -l app=frontend`). S'il manque, l'annotation n'est pas sur le modèle de pod ou l'`Instrumentation` a été créée après les pods : dans ce second cas, redémarrez-les avec `kubectl -n demo rollout restart deployment/frontend`.

## Cleanup

Supprimez les releases Helm et les espaces de noms du lab :

```bash
helm uninstall otel-agent otel-gateway -n observability
helm uninstall operator -n opentelemetry-operator-system
kubectl delete namespace demo observability opentelemetry-operator-system
```

Le cluster KinD lui-même peut être conservé : il sert aux TP suivants.

## Extra

À vous de jouer, si le temps le permet.

- Ajoutez au chart de l'agent le preset `logsCollection` et observez les logs des conteneurs arriver dans le pipeline `logs`.
- Ajoutez dans l'`Instrumentation` un attribut de ressource, par exemple `deployment.environment.name`, avec la section `resource.resourceAttributes`.
- Déployez le collector avec la ressource `OpenTelemetryCollector` de l'Operator plutôt qu'avec Helm, et comparez les deux approches.
