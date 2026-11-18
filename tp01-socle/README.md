# TP1 - Socle

Durée : environ 2 heures (1/4 de journée)

Machine : `clt-N` (N est votre numéro, disponible dans la variable `LAB_ID`)

Dans ce TP, vous démarrez un backend d'observabilité (Jaeger, Prometheus et Grafana), puis vous écrivez pas à pas la configuration d'un premier Collector. Les données sont produites par `telemetrygen`, un générateur de télémétrie fourni avec le projet OpenTelemetry, ce qui permet de se concentrer sur le Collector sans avoir besoin d'une application.

## Objectifs

À la fin du TP, vous saurez :

- démarrer une stack backend avec Docker Compose et vérifier que chaque service répond ;
- écrire une configuration de Collector composée d'un receiver OTLP, d'un exporter vers Jaeger et d'un pipeline de traces ;
- ajouter les processors `memory_limiter`, `batch` et `resource`, et expliquer pourquoi leur ordre compte ;
- supprimer des spans avec le processor `filter`, puis masquer et normaliser des attributs avec le processor `transform` et le langage OTTL ;
- envoyer des métriques vers Prometheus et les consulter dans Grafana.

## Prérequis

Aucun TP précédent. Les outils nécessaires (Docker, Docker Compose, `curl`, `jq`) sont déjà installés sur `clt-N`.

Versions utilisées, vérifiées le 2026-11-18 :

| Composant | Version |
|---|---|
| OpenTelemetry Collector (distribution `otelcol-contrib`) | 0.165.0 |
| telemetrygen | v0.165.0 |
| Jaeger | 2.23.0 |
| Prometheus | v3.16.0 |
| Grafana | 13.3.1 |

Les interfaces web sont accessibles depuis votre navigateur aux adresses suivantes (remplacez `$CLT_HOST` par sa valeur, affichée par `echo $CLT_HOST`) :

- Jaeger : `http://$CLT_HOST:16686`
- Prometheus : `http://$CLT_HOST:9090`
- Grafana : `http://$CLT_HOST:3000` (compte `admin`, mot de passe `formation`)

## Partie 1 : démarrer les backends (15 min)

Copiez les fichiers de départ dans un dossier de travail, afin de ne pas modifier le dépôt des labs :

```bash
mkdir -p ~/tp01
cp -r ~/opentelemetry-labs/tp01-socle/files/. ~/tp01/
cd ~/tp01
```

Prenez le temps de lire `compose.yaml`. Il décrit quatre services : Jaeger, Prometheus et Grafana, qui démarrent maintenant, et le Collector, que vous démarrerez à la partie 2. Jaeger stocke les traces en mémoire : elles disparaissent si le conteneur redémarre.

Démarrez les trois backends :

```bash
docker compose up -d jaeger prometheus grafana
docker compose ps
```

**Vérifier**

Les trois services doivent apparaître avec l'état `running`. Contrôlez ensuite que chacun répond :

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:16686/
curl -s http://localhost:9090/-/ready
curl -s http://localhost:3000/api/health | jq -r .database
curl -s -u admin:formation http://localhost:3000/api/datasources | jq -r '.[].name'
```

Les sorties attendues sont `200`, `Prometheus Server is Ready.`, `ok`, puis les deux noms `Jaeger` et `Prometheus`. Ouvrez aussi l'interface de Jaeger dans votre navigateur : elle s'affiche avec une liste de services vide.

## Partie 2 : un premier Collector (30 min)

Un Collector se décrit dans un fichier YAML. Les receivers reçoivent les données, les exporters les envoient ailleurs, et la section `service.pipelines` relie les deux pour chaque type de signal. Un composant déclaré mais absent d'un pipeline n'est pas utilisé.

Éditez `otelcol/config.yaml`, qui est pour l'instant vide, pour obtenir la configuration suivante :

- un receiver `otlp` qui accepte le gRPC (port 4317) et le HTTP (port 4318) sur toutes les interfaces du conteneur ;
- un exporter `debug` avec le niveau de détail `detailed`, qui écrit les données reçues dans les logs du Collector ;
- un exporter `otlp` nommé `otlp/jaeger`, qui envoie vers le service `jaeger` du compose, port 4317, sans TLS ;
- un pipeline `traces` qui relie le receiver aux deux exporters.

Pour retrouver les options de chaque composant, consultez le README du composant dans le dépôt `opentelemetry-collector-contrib` (les exporters `debug` et `otlp` sont dans le dépôt `opentelemetry-collector`). Gardez à l'esprit que le Collector tourne dans un conteneur : `localhost` désigne le conteneur lui-même, pas Jaeger.

Validez le fichier avant de démarrer :

```bash
docker compose run --rm otelcol validate --config=/etc/otelcol/config.yaml
```

La commande n'affiche rien et se termine sans erreur si la configuration est correcte. Démarrez ensuite le Collector et lisez ses logs :

```bash
docker compose up -d otelcol
docker compose logs otelcol | tail -n 5
```

Le dernier message doit indiquer `Everything is ready. Begin running and processing data.`

Envoyez cinq traces avec `./tg.sh`, un petit script qui lance `telemetrygen` vers le Collector :

```bash
./tg.sh traces --traces 5 --service demo
```

Chaque trace contient deux spans : un span parent `lets-go` et un span enfant `okey-dokey-0`.

**Vérifier**

Juste après ce premier envoi, le Collector a affiché dix spans :

```bash
docker compose logs otelcol | grep -c 'Span #'
```

La commande affiche `10`. Contrôlez ensuite que Jaeger a reçu les traces :

```bash
curl -s 'http://localhost:16686/api/traces?service=demo&limit=20' | jq '.data | length'
```

La commande affiche `5`. Dans l'interface de Jaeger, choisissez le service `demo` puis cliquez sur Find Traces : vous retrouvez les cinq traces. Faites la même recherche dans Grafana, via Explore et la source de données Jaeger.

## Partie 3 : les premiers processors (25 min)

Les processors transforment les données entre le receiver et les exporters. Ils s'exécutent dans l'ordre où ils sont listés dans le pipeline, et cet ordre a des conséquences.

Ajoutez trois processors à votre configuration :

- `memory_limiter`, qui protège le Collector d'un dépassement de mémoire. Réglez-le avec un intervalle de vérification de 1 s, une limite de 256 MiB et une marge de pic de 64 MiB ;
- `resource`, qui ajoute deux attributs de ressource à toutes les données : `deployment.environment.name` avec la valeur `tp1`, et `lab.id` avec le numéro de votre environnement. Le compose transmet déjà `LAB_ID` au conteneur : utilisez la syntaxe de substitution `${env:LAB_ID}` du Collector ;
- `batch`, qui regroupe les données avant l'envoi. Réglez-le avec `timeout: 2s`.

Placez-les dans le pipeline `traces`. Posez-vous la question de l'ordre : le `memory_limiter` doit-il passer avant ou après `batch` ? Le README du `batch` processor donne la réponse.

Redémarrez le Collector et envoyez des traces avec un nouveau nom de service :

```bash
docker compose restart otelcol
./tg.sh traces --traces 5 --service shop
```

**Vérifier**

Les attributs de ressource apparaissent dans Jaeger, sur chaque trace du service `shop`, dans la section Process des détails d'un span. En ligne de commande :

```bash
curl -s 'http://localhost:16686/api/traces?service=shop&limit=1' \
  | jq -r '.data[0].processes[].tags[] | select(.key=="lab.id") | .value'
```

La commande affiche votre numéro (la valeur de `$LAB_ID`).

Observez maintenant l'effet du `batch`. Passez `timeout` à `15s`, redémarrez le Collector, puis envoyez trois traces avec le service `shop-delay` pendant que vous suivez les logs avec `docker compose logs -f otelcol`. Les spans n'apparaissent qu'après environ quinze secondes, le temps que le lot soit envoyé. Remettez ensuite `timeout: 2s` et redémarrez.

## Partie 4 : supprimer du bruit avec le filter (20 min)

Les sondes de santé (`/health`, `/ready`) produisent beaucoup de spans qui n'apportent rien à l'analyse. Le processor `filter` supprime les données qui vérifient une condition écrite en OTTL, le langage de transformation d'OpenTelemetry. Si une des conditions de la liste est vraie, la donnée est supprimée.

Dans cette version du Collector, le processor `filter` attend une liste `trace_conditions`, et les chemins OTTL commencent par le nom du contexte, par exemple `span.attributes["clé"]`. Le README du processor `filter` détaille la syntaxe.

Ajoutez un processor `filter/healthchecks` qui supprime les spans dont l'attribut `http.route` vaut `/health` ou `/ready`. Placez-le dans le pipeline après `resource` et avant `batch` : il est inutile de grouper des données que l'on va supprimer.

Redémarrez le Collector, puis envoyez deux séries de traces, l'une qui doit être filtrée et l'autre non :

```bash
./tg.sh traces --traces 10 --service shop-filter --telemetry-attributes 'http.route="/health"'
./tg.sh traces --traces 10 --service shop-filter --telemetry-attributes 'http.route="/api/orders"'
```

Les guillemets doubles à l'intérieur des guillemets simples sont nécessaires : `telemetrygen` s'en sert pour savoir que la valeur est une chaîne.

**Vérifier**

Seules les dix traces de `/api/orders` doivent exister dans Jaeger :

```bash
curl -s 'http://localhost:16686/api/traces?service=shop-filter&limit=50' | jq '.data | length'
curl -s 'http://localhost:16686/api/traces?service=shop-filter&limit=50' \
  | jq -c '[.data[].spans[].tags[] | select(.key=="http.route") | .value] | unique'
```

La première commande affiche `10`, la seconde `["/api/orders"]`.

## Partie 5 : masquer et normaliser avec transform et OTTL (25 min)

Le processor `transform` modifie les données avec des instructions OTTL. Pour chaque signal, il attend une liste d'instructions (`trace_statements` pour les traces) exécutées dans l'ordre. Une instruction peut se terminer par une clause `where`, qui limite son application aux données qui vérifient la condition.

Envoyez d'abord des données qui contiennent une adresse e-mail et un chemin avec un identifiant :

```bash
./tg.sh traces --traces 5 --service accounts \
  --telemetry-attributes 'http.request.method="GET"' \
  --telemetry-attributes 'url.path="/api/orders/48151"' \
  --telemetry-attributes 'user.email="alice@example.com"'
```

Dans Jaeger, ouvrez une de ces traces : l'adresse e-mail apparaît en clair, ce qui pose un problème de confidentialité, et chaque identifiant de commande crée un chemin distinct, ce qui rend les regroupements impossibles. Ajoutez un processor `transform/normalize` qui règle ces trois points :

1. remplacer la partie locale de `user.email` (ce qui précède le `@`) par `***` ;
2. remplacer, dans `url.path`, chaque segment numérique par `{id}` ;
3. renommer les spans appelés `lets-go` en `<méthode> <chemin>`, avec la valeur de `http.request.method` suivie d'une espace et de celle de `url.path`.

Quelques indications. Les fonctions utiles se trouvent dans la référence des fonctions OTTL (dépôt `opentelemetry-collector-contrib`, dossier `pkg/ottl/ottlfuncs`) : cherchez `replace_pattern`, `set` et `Concat`. Les instructions s'exécutent dans l'ordre, ce qui compte pour la troisième : le nom doit être construit avec le chemin déjà normalisé. Ajoutez enfin à chaque instruction une clause `where` qui vérifie que l'attribut utilisé existe (`!= nil`), pour que les données qui ne portent pas ces attributs ne produisent pas d'erreur.

Placez ce processor après `filter/healthchecks` et avant `batch`. Redémarrez le Collector, renvoyez la même commande `./tg.sh`, puis consultez les logs du Collector : l'exporter `debug` affiche les spans tels qu'ils sont après le traitement.

**Vérifier**

```bash
curl -s 'http://localhost:16686/api/traces?service=accounts&limit=1' | jq -r '.data[0].spans[].operationName'
curl -s 'http://localhost:16686/api/traces?service=accounts&limit=1' \
  | jq -r '.data[0].spans[0].tags[] | select(.key=="user.email" or .key=="url.path") | "\(.key)=\(.value)"'
```

La première commande affiche `GET /api/orders/{id}` et `okey-dokey-0` (le span enfant n'est pas renommé). La seconde affiche `url.path=/api/orders/{id}` et `user.email=***@example.com`, dans un ordre quelconque.

## Partie 6 : les métriques vers Prometheus et Grafana (15 min)

Le même Collector peut traiter plusieurs types de signaux. Prometheus récupère les métriques en interrogeant un point d'accès, il faut donc que le Collector en expose un. Le fichier `prometheus/prometheus.yml` fournit déjà un job qui interroge `otelcol:8889`.

Ajoutez à votre configuration :

- un exporter `prometheus` qui écoute sur `0.0.0.0:8889` et qui convertit les attributs de ressource en labels (option `resource_to_telemetry_conversion`) ;
- un pipeline `metrics` avec le receiver `otlp`, les processors `memory_limiter`, `resource` et `batch`, et les exporters `debug` et `prometheus`.

Redémarrez le Collector et vérifiez dans Prometheus, page Status puis Targets, que la cible `otelcol:8889` est `UP`. Envoyez ensuite des métriques pendant trente secondes :

```bash
./tg.sh metrics --duration 30s --rate 1 --service billing --otlp-metric-name tp1_demo
```

**Vérifier**

```bash
curl -s http://localhost:9090/api/v1/query --data-urlencode 'query={__name__=~"tp1_demo.*"}' \
  | jq -r '.data.result[0].metric | "\(.service_name) \(.lab_id)"'
```

La commande affiche `billing` suivi de votre numéro. Le nom de la métrique peut porter un suffixe ajouté par le convertisseur selon l'unité, d'où l'expression régulière. Retrouvez la même série dans Grafana, via Explore et la source de données Prometheus.

## Dépannage

**Le Collector s'arrête juste après le démarrage.** Lisez `docker compose logs otelcol`. Le message cite presque toujours la clé ou le composant fautif : erreur d'indentation, composant déclaré mais absent de `service.pipelines`, ou l'inverse. La commande `validate` de la partie 2 détecte ces erreurs avant le démarrage.

**`connection refused` vers Jaeger dans les logs du Collector.** L'adresse de l'exporter doit utiliser le nom du service du compose (`jaeger`), pas `localhost`.

**`telemetrygen` ne se connecte pas.** Le Collector doit tourner (`docker compose ps`) et son receiver doit écouter sur `0.0.0.0`. Avec `localhost` ou sans précision, le receiver n'est joignable que depuis l'intérieur de son propre conteneur.

**Rien n'apparaît dans Jaeger.** Vérifiez le nom du service choisi dans la liste, la période de recherche (Lookback) et la valeur de `timeout` du `batch` : avec une valeur élevée, les données arrivent avec du retard.

**L'attribut `lab.id` est vide ou vaut `0`.** La variable `LAB_ID` n'est pas définie dans votre terminal. Contrôlez `echo $LAB_ID`, puis relancez `docker compose up -d otelcol` pour recréer le conteneur avec la valeur.

**Une valeur d'attribut est refusée par `telemetrygen`.** Les valeurs de chaîne doivent garder leurs guillemets doubles, d'où la forme `'clé="valeur"'`.

## Pour aller plus loin

- Envoyez un span en JSON avec `curl` directement sur le port 4318 (`/v1/traces`) pour comprendre ce que fait un SDK.
- Ajoutez à la partie 5 une instruction qui positionne un attribut `slo.violation` à `true` sur les spans dont le statut est `Error` (option `--status-code Error` de `telemetrygen`).
- Supprimez le `batch` du pipeline et comparez le nombre de requêtes que reçoit Jaeger.
