# TP3 - Kubernetes

Durée : environ 2 heures (1/4 de journée)

Machine : `k8s-N` (N est votre numéro, disponible dans la variable `LAB_ID`)

Dans ce TP, vous déployez sur le cluster KinD de votre environnement une chaîne de collecte complète. Un Collector en mode gateway envoie les traces à Jaeger, un Collector en mode agent (un par nœud) enrichit les données avec les métadonnées Kubernetes et les transmet à la gateway, puis l'OpenTelemetry Operator instrumente automatiquement une application Node.js sans modifier son code ni son image.

## Objectifs

À la fin du TP, vous saurez :

- déployer un Collector en mode gateway et en mode agent avec le chart Helm officiel, et adapter sa configuration par un fichier de valeurs ;
- expliquer comment le chart fusionne votre configuration avec ses valeurs par défaut et ce que fait un preset ;
- enrichir les traces avec les métadonnées Kubernetes grâce au processor `k8s_attributes` ;
- installer l'OpenTelemetry Operator et décrire une auto-instrumentation avec une ressource `Instrumentation` ;
- activer l'instrumentation d'un déploiement par une annotation et retrouver la trace de bout en bout dans Jaeger.

## Prérequis

Le TP1 est conseillé : il présente les receivers, processors et exporters du Collector, qui ne sont pas réexpliqués ici. Les outils (`kubectl`, `helm`, `curl`, `jq`) sont installés sur `k8s-N`, et le cluster est opérationnel (un nœud control-plane et un worker, avec ingress-nginx).

Versions utilisées, vérifiées le 2026-11-18 :

| Composant | Version |
|---|---|
| Chart Helm `opentelemetry-collector` | 0.179.1 |
| Image du Collector (distribution `otelcol-contrib`) | 0.163.2 (version du chart) |
| Chart Helm `opentelemetry-operator` | 0.129.1 |
| Image de l'Operator | 0.162.0 |
| Image d'auto-instrumentation Node.js | 0.82.0-1 |
| Jaeger | 2.23.0 |
| Node.js (application de démonstration) | 22.23.5 |
| telemetrygen | v0.165.0 |

Les interfaces web sont accessibles depuis votre navigateur par l'ingress du cluster, sur le port 8080 : `http://jaeger.$INGRESS_HOST:8080` pour Jaeger et `http://app.$INGRESS_HOST:8080` pour l'application (affichez la valeur de `$INGRESS_HOST` avec `echo $INGRESS_HOST`).

## Partie 1 : préparer le cluster (15 min)

Copiez les fichiers de départ dans un dossier de travail et chargez les fonctions d'aide :

```bash
mkdir -p ~/tp03
cp -r ~/opentelemetry-labs/tp03-kubernetes/files/. ~/tp03/
cd ~/tp03
source helpers.sh
kubectl get nodes
```

Les fonctions `app` et `jaeger` appellent l'application et l'API de Jaeger par l'ingress. Rechargez-les avec `source ~/tp03/helpers.sh` dans chaque nouveau terminal.

Le dossier contient trois manifestes : `namespaces.yaml` (les espaces de noms `observability` et `demo`), `jaeger.yaml` (Jaeger avec stockage en mémoire) et `demo-app.yaml` (une application Node.js en deux services, `frontend` et `backend`, dont le code est dans un ConfigMap). Parcourez-les, puis déployez-les. Les deux manifestes qui déclarent un Ingress contiennent le texte `INGRESS_HOST`, que `sed` remplace par votre nom de domaine avant l'envoi au cluster :

```bash
kubectl apply -f namespaces.yaml
sed "s/INGRESS_HOST/$INGRESS_HOST/g" jaeger.yaml | kubectl apply -f -
sed "s/INGRESS_HOST/$INGRESS_HOST/g" demo-app.yaml | kubectl apply -f -
kubectl -n observability rollout status deployment/jaeger
kubectl -n demo rollout status deployment/frontend deployment/backend
```

**Vérifier**

```bash
app /api/orders
jaeger /api/services
```

La première commande affiche une réponse JSON du frontend qui contient la réponse du backend : `{"from":"frontend","backend":{"from":"backend","path":"/api/orders"}}`. La seconde affiche un objet JSON dont la liste `data` est vide (ou `null`) : Jaeger répond, mais ne contient encore aucune trace, car l'application n'est pas instrumentée. Ouvrez aussi `http://jaeger.$INGRESS_HOST:8080` dans votre navigateur.

## Partie 2 : le Collector en mode gateway (30 min)

Une gateway est un Collector central, déployé comme un Deployment, qui reçoit les données de plusieurs sources et les envoie au backend. Vous allez la déployer avec le chart Helm officiel.

Ajoutez le dépôt de charts :

```bash
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
```

Le chart se configure par un fichier de valeurs. Créez-en un avec les réglages du déploiement. Le chart n'impose pas d'image par défaut : il faut indiquer la distribution `contrib`, et le nom de son exécutable.

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
EOF
```

La configuration du Collector lui-même se place sous la clé `config:` de ce fichier. Le chart la fusionne avec sa configuration par défaut : les dictionnaires sont fusionnés, les listes sont remplacées. Ajoutez à la fin du fichier, avec la commande suivante, un bloc `config:` (au niveau le plus à gauche) qui contient :

- un exporter `otlp_grpc/jaeger` vers `jaeger.observability.svc.cluster.local`, port 4317, sans TLS ;
- un pipeline `traces` qui relie le receiver `otlp`, les processors `memory_limiter` puis `batch`, et cet exporter.

```bash
cat >> gateway-values.yaml <<'EOF'
```

Avant d'installer, regardez ce que le chart génère à partir de vos valeurs :

```bash
helm template otel-gateway open-telemetry/opentelemetry-collector --version 0.179.1 \
  -n observability -f gateway-values.yaml | grep -B2 -A60 'relay:'
```

Repérez ce que vous n'avez pas écrit : l'extension `health_check`, les receivers par défaut, et les pipelines `metrics` et `logs`. Installez ensuite la gateway :

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

**Vérifier**

```bash
kubectl -n observability get pods -l app.kubernetes.io/instance=otel-gateway
jaeger '/api/traces?service=k8s-gateway&limit=20' | jq '.data | length'
```

La première commande affiche un pod `otel-gateway-...` à l'état `Running`. La seconde affiche `5`.

## Partie 3 : le Collector en mode agent (25 min)

Un agent est un Collector déployé comme un DaemonSet : un pod par nœud, proche des applications. Il enrichit les données avec les métadonnées Kubernetes puis les transmet à la gateway. Le processor `k8s_attributes` interroge l'API Kubernetes pour retrouver, à partir de l'adresse IP du pod émetteur, son nom, son espace de noms, son déploiement et son nœud.

Créez le fichier de valeurs de l'agent. Deux réglages méritent d'être expliqués. Le preset `kubernetesAttributes` ajoute au chart le processor `k8s_attributes` et les droits RBAC dont il a besoin pour lire l'API Kubernetes. Le réglage `service.enabled` crée un Service, que le chart ne crée pas par défaut pour un DaemonSet : en mode agent, ce Service est configuré avec `internalTrafficPolicy: Local`, de sorte qu'une application atteint toujours l'agent de son propre nœud.

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
EOF
```

Comme pour la gateway, ajoutez à la fin du fichier un bloc `config:` avec la commande suivante. Il contient :

- un exporter `otlp_grpc/gateway` vers `otel-gateway.observability.svc.cluster.local`, port 4317, sans TLS ;
- un pipeline `traces` avec le receiver `otlp`, les processors `memory_limiter`, `k8s_attributes` puis `batch`, et cet exporter. Listez vous-même `k8s_attributes` à cet endroit : sans cela, le preset l'ajoute en première position, avant `memory_limiter`.

```bash
cat >> agent-values.yaml <<'EOF'
```

Installez l'agent :

```bash
helm upgrade --install otel-agent open-telemetry/opentelemetry-collector \
  --version 0.179.1 -n observability -f agent-values.yaml --wait
kubectl -n observability get daemonset otel-agent-agent
```

Envoyez des traces de test à l'agent, cette fois, et non à la gateway :

```bash
kubectl -n demo run tg-agent --restart=Never --rm -i \
  --image=ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 -- \
  traces --otlp-endpoint otel-agent.observability.svc.cluster.local:4317 \
  --otlp-insecure --rate 10 --traces 5 --service k8s-agent
```

**Vérifier**

Le DaemonSet se nomme `otel-agent-agent` : le chart ajoute le suffixe `-agent` en mode daemonset, alors que le Service garde le nom `otel-agent`. Les colonnes `DESIRED` et `READY` du DaemonSet sont égales. Les traces envoyées à l'agent portent maintenant des attributs Kubernetes que `telemetrygen` ne connaît pas :

```bash
jaeger '/api/traces?service=k8s-agent&limit=1' \
  | jq -r '.data[0].processes[].tags[] | select(.key | startswith("k8s.")) | "\(.key)=\(.value)"'
```

La commande affiche notamment `k8s.pod.name=tg-agent`, `k8s.namespace.name=demo` et `k8s.node.name=` suivi du nom du worker. Comparez avec les traces `k8s-gateway` de la partie 2, qui n'ont pas ces attributs.

## Partie 4 : l'Operator et l'auto-instrumentation (30 min)

L'OpenTelemetry Operator injecte un agent d'instrumentation dans les pods qui portent une annotation, au moment de leur création, sans modifier l'image de l'application. Pour Node.js, il ajoute un conteneur d'initialisation qui copie la bibliothèque d'instrumentation dans le pod, et il définit les variables d'environnement qui l'activent.

Installez l'Operator. Le chart propose par défaut d'utiliser cert-manager pour les certificats de son webhook, ce qui n'est pas installé ici : les deux premières options demandent au chart de générer lui-même un certificat.

```bash
helm upgrade --install operator open-telemetry/opentelemetry-operator \
  --version 0.129.1 -n opentelemetry-operator-system --create-namespace \
  --set admissionWebhooks.certManager.enabled=false \
  --set admissionWebhooks.autoGenerateCert.enabled=true \
  --set manager.image.tag=0.162.0 --wait
kubectl get crd | grep opentelemetry.io
```

Les ressources `instrumentations.opentelemetry.io` et `opentelemetrycollectors.opentelemetry.io` apparaissent dans la liste. N'exécutez pas `helm test` sur ce chart : ses pods de test utilisent une image qui n'est pas épinglée.

La ressource `Instrumentation` décrit comment instrumenter : où envoyer les données, quels propagators utiliser, quel échantillonnage appliquer et quelle image d'instrumentation injecter. Créez-la dans l'espace de noms `demo`, avec la commande suivante. Elle doit contenir :

- `apiVersion: opentelemetry.io/v1alpha1`, `kind: Instrumentation`, le nom `demo` et l'espace de noms `demo` ;
- un exporter qui envoie à l'agent, par OTLP HTTP (`http://otel-agent.observability.svc.cluster.local:4318`) : le SDK Node.js utilise ce protocole par défaut ;
- les propagators `tracecontext` et `baggage` ;
- un échantillonneur `parentbased_traceidratio` avec l'argument `"1"` (guillemets obligatoires, c'est une chaîne) ;
- pour Node.js, l'image `ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:0.82.0-1`.

```bash
cat > instrumentation.yaml <<'EOF'
```

Appliquez-la, puis activez l'instrumentation des deux déploiements avec l'annotation `instrumentation.opentelemetry.io/inject-nodejs: "true"`. L'annotation doit se trouver sur le modèle de pod, et non sur le Deployment : `kubectl patch` la place au bon endroit et déclenche le remplacement des pods.

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

**Vérifier**

Les pods contiennent un conteneur d'initialisation ajouté par l'Operator, que vos manifestes ne déclarent pas :

```bash
kubectl -n demo get pod -l app=frontend -o jsonpath='{.items[*].spec.initContainers[*].name}{"\n"}'
```

La commande affiche `opentelemetry-auto-instrumentation-nodejs`. Dans Jaeger, les services `frontend` et `backend` sont apparus :

```bash
jaeger '/api/services' | jq -c '.data'
jaeger '/api/traces?service=frontend&limit=1' \
  | jq -c '[.data[0].processes[].serviceName] | unique'
```

La première commande contient `frontend` et `backend`, la seconde affiche `["backend","frontend"]` : une même trace traverse les deux services. Ouvrez-la dans l'interface de Jaeger : vous voyez le span serveur du frontend, le span client de son appel au backend, puis le span serveur du backend. Le lien entre les deux services repose sur le propagator `tracecontext`. Regardez enfin les attributs de ressource de cette trace : `k8s.pod.name`, `k8s.namespace.name` et `k8s.node.name` y figurent, ajoutés par l'agent.

## Dépannage

**Le pod du Collector redémarre en boucle (`CrashLoopBackOff`).** Lisez `kubectl -n observability logs deployment/otel-gateway` (ou `daemonset/otel-agent-agent`). Le message cite le composant en erreur, souvent une faute d'indentation dans la clé `config:` ou un composant déclaré mais absent de `service.pipelines`. Corrigez le fichier de valeurs puis relancez la commande `helm upgrade --install`.

**`helm` signale que le chart `opentelemetry-collector` est introuvable.** Le dépôt n'est pas enregistré ou n'est pas à jour : relancez `helm repo add` puis `helm repo update`, et contrôlez avec `helm search repo open-telemetry/opentelemetry-collector --versions | head -n 3`.

**L'`Instrumentation` est refusée avec une erreur de webhook (`failed calling webhook`).** L'Operator n'est pas encore prêt. Attendez que `kubectl -n opentelemetry-operator-system get pods` affiche le pod à l'état `Running` avec `1/1`, puis recommencez.

**Les pods redémarrent mais aucune trace n'apparaît.** Vérifiez d'abord que le conteneur d'initialisation a été injecté (commande de la partie 4). S'il est absent, l'annotation n'est pas sur le modèle de pod ou l'`Instrumentation` a été créée après les pods : `kubectl -n demo describe pod -l app=frontend` affiche les événements. S'il est présent, contrôlez l'adresse de l'exporter dans l'`Instrumentation` et les logs de l'agent.

**La commande `kubectl run` d'une partie reste bloquée.** Le pod n'arrive pas à télécharger l'image ou à joindre le Collector. Interrompez avec Ctrl+C, supprimez le pod (`kubectl -n demo delete pod tg-agent --ignore-not-found`) et regardez `kubectl -n demo describe pod tg-agent`.

**Vous êtes bloqué sur un fichier.** Le dossier `solution/` du dépôt contient chaque fichier complet. Copiez-le, par exemple `cp ~/opentelemetry-labs/tp03-kubernetes/solution/agent-values.yaml ~/tp03/`.

## Pour aller plus loin

- Ajoutez au chart de l'agent le preset `logsCollection` et observez les logs des conteneurs arriver dans le pipeline `logs`.
- Ajoutez dans l'`Instrumentation` un attribut de ressource, par exemple `deployment.environment.name`, avec la section `resource.resourceAttributes`.
- Déployez le Collector avec la ressource `OpenTelemetryCollector` de l'Operator plutôt qu'avec Helm, et comparez les deux approches.
