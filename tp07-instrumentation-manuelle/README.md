# TP7 - Instrumentation manuelle

Durée : environ 2 heures (1/4 de journée)

Machine : `clt-N` (N est votre numéro, disponible dans la variable `LAB_ID`)

Dans ce TP, vous instrumentez à la main une petite application Python composée de deux services : `shop` reçoit des commandes et interroge `inventory` pour connaître le stock. Aucune bibliothèque d'auto-instrumentation n'est utilisée. Vous configurez le SDK OpenTelemetry, vous créez vous-même les spans et leurs attributs, vous propagez le contexte d'un service à l'autre, puis vous reliez les logs aux traces.

## Objectifs

À la fin du TP, vous saurez :

- configurer le SDK OpenTelemetry pour Python (ressource, provider, processor, exporter OTLP) ;
- créer des spans avec un type (`SpanKind`), des attributs métier, des événements et un statut d'erreur ;
- propager le contexte entre deux services par l'en-tête W3C `traceparent`, avec `inject` et `extract` ;
- joindre l'identifiant de trace aux logs et suivre un log vers sa trace dans Grafana ;
- repérer dans Jaeger les défauts d'une instrumentation incomplète (traces coupées, spans sans erreur visible).

## Prérequis

Le TP1 est conseillé pour le rôle du Collector. Aucune connaissance de Python au-delà de la lecture d'un script n'est nécessaire : le code utile est court et commenté.

Versions utilisées, vérifiées le 2026-11-18 :

| Composant | Version |
|---|---|
| Python (image de l'application) | 3.13.18 |
| API, SDK et exporter OTLP/HTTP OpenTelemetry pour Python | 1.45.2 |
| Flask, requests | 3.1.3, 2.34.2 |
| OpenTelemetry Collector (distribution `otelcol-contrib`) | 0.165.0 |
| Jaeger | 2.23.0 |
| Loki | 3.7.10 |
| Grafana | 13.3.1 |

Les interfaces web sont accessibles depuis votre navigateur (remplacez `$CLT_HOST` par sa valeur, affichée par `echo $CLT_HOST`) :

- Jaeger : `http://$CLT_HOST:16686`
- Grafana : `http://$CLT_HOST:3000` (compte `admin`, mot de passe `formation`)

## Partie 1 : démarrer l'application sans instrumentation (15 min)

Copiez les fichiers de départ dans un dossier de travail, puis construisez et démarrez la stack :

```bash
mkdir -p ~/tp07
cp -r ~/opentelemetry-labs/tp07-instrumentation-manuelle/files/. ~/tp07/
cd ~/tp07
docker compose up -d --build
docker compose ps
```

La stack comprend l'application (`shop` et `inventory`), un Collector, Jaeger pour les traces, Loki pour les logs et Grafana pour les consulter. La configuration du Collector, fournie dans `otelcol/config.yaml`, reçoit l'OTLP/HTTP, envoie les traces à Jaeger et les logs à Loki.

Le dossier `app/` contient le code Python. Lisez-le avec `cat`, en commençant par `app/shop.py` et `app/orders.py`. Les modules `orders.py` et `stock.py` portent la logique métier et ne sont jamais modifiés. Vous écrirez au fil du TP cinq petits modules : `telemetry.py`, `shop_handler.py`, `inventory_handler.py`, `inventory_client.py` et `logs.py`. Leurs versions de départ ne produisent aucune télémétrie. Le dossier `app/` est monté dans les conteneurs : après chaque modification, `docker compose restart shop inventory` suffit, sans reconstruire l'image.

Passez trois commandes, avec le script `order.sh` (articles connus : `coffee` en stock à 12, `mug` à 3 et `tea` à 0) :

```bash
./order.sh coffee 2 alice
./order.sh mug 5 bob
./order.sh pizza
```

**Vérifier**

Les trois commandes affichent `{"status":"accepted","total":9.0} [201]`, `{"error":"insufficient stock","stock":3} [409]` et `{"error":"unknown sku"} [404]`. Le code HTTP est affiché entre crochets. Jaeger ne connaît encore aucun service :

```bash
curl -s http://localhost:16686/api/services | jq -r '(.data // [])[]'
```

La commande n'affiche rien.

## Partie 2 : configurer le SDK (25 min)

Pour produire des spans, un programme a besoin d'un `TracerProvider`. Il décrit qui émet les données (la ressource), traite les spans terminés (le processor) et les envoie quelque part (l'exporter). Vous allez écrire le module `telemetry.py`, que `shop.py` et `inventory.py` appellent au démarrage avec le nom du service.

La fonction `setup(service_name)` doit :

- créer une `Resource` avec les attributs `service.name` (le nom reçu en paramètre), `service.version` à `1.0.0` et `deployment.environment.name` à `tp7` ;
- créer un `TracerProvider` avec cette ressource ;
- lui ajouter un `BatchSpanProcessor` qui s'appuie sur un `OTLPSpanExporter` créé sans argument : il lit l'adresse du Collector dans la variable `OTEL_EXPORTER_OTLP_ENDPOINT`, que `compose.yaml` définit ;
- enregistrer ce provider comme provider global avec `trace.set_tracer_provider`.

Les classes se trouvent dans les modules suivants :

| Classe | Module |
|---|---|
| `Resource` | `opentelemetry.sdk.resources` |
| `TracerProvider` | `opentelemetry.sdk.trace` |
| `BatchSpanProcessor` | `opentelemetry.sdk.trace.export` |
| `OTLPSpanExporter` | `opentelemetry.exporter.otlp.proto.http.trace_exporter` |
| `trace` | `opentelemetry` |

Écrivez le module avec la commande suivante : le shell attend ensuite votre saisie, que vous terminez par une ligne `EOF` seule. L'indentation du Python se fait avec quatre espaces.

```bash
cat > app/telemetry.py <<'EOF'
```

Redémarrez l'application, puis vérifiez que le SDK fonctionne en créant un span de test depuis un des conteneurs :

```bash
docker compose restart shop inventory
docker compose exec -T shop python - <<'EOF'
import telemetry
from opentelemetry import trace

telemetry.setup("smoke-test")
tracer = trace.get_tracer("smoke-test")
with tracer.start_as_current_span("hello"):
    pass
trace.get_tracer_provider().shutdown()
EOF
```

L'appel à `shutdown()` force l'envoi des spans en attente : le processor les regroupe normalement par lots.

**Vérifier**

```bash
curl -s http://localhost:16686/api/services | jq -c '.data'
```

La liste contient `smoke-test`. Passez une commande avec `./order.sh coffee 2 alice` : elle fonctionne toujours, mais ni `shop` ni `inventory` n'apparaissent dans Jaeger. Configurer le SDK ne produit aucune donnée par lui-même : c'est le code qui crée les spans.

## Partie 3 : créer des spans dans shop (30 min)

Le module `shop_handler.py` est le point d'entrée de `POST /orders` : il appelle la logique métier de `orders.py`. Vous allez l'entourer d'un span. Consultez d'abord sa version de départ avec `cat app/shop_handler.py`, puis réécrivez-le pour qu'il :

1. extraie le contexte éventuel des en-têtes de la requête (`opentelemetry.propagate.extract`) : si l'appelant envoie un en-tête `traceparent`, le span rejoint sa trace ;
2. crée avec `start_as_current_span` un span nommé `POST /orders`, de type `SpanKind.SERVER`, dont le parent est ce contexte ;
3. y ajoute les attributs `http.request.method` (`POST`), `http.route` (`/orders`), `order.sku`, `order.qty` et `customer.id`, à partir du contenu de la commande ;
4. appelle `orders.create_order(payload)`, qui renvoie le corps de la réponse et le code HTTP ;
5. ajoute l'attribut `http.response.status_code` ;
6. pour un code 201, ajoute l'attribut `order.total` (valeur de `total` dans la réponse) ;
7. pour un code 409, ajoute l'événement `stock.insufficient` avec l'attribut `stock` ;
8. pour tout code supérieur ou égal à 400, positionne le statut du span à `ERROR`, avec la valeur de `error` dans la réponse comme description.

Les noms d'attributs suivent les conventions sémantiques d'OpenTelemetry pour HTTP (`http.*`). Les attributs métier portent un préfixe qui décrit leur domaine (`order.`). Le module récupère son tracer avec `trace.get_tracer("shop")`, au niveau du module. Les types `SpanKind`, `Status` et `StatusCode` se trouvent dans `opentelemetry.trace`.

```bash
cat > app/shop_handler.py <<'EOF'
```

Redémarrez et passez trois commandes :

```bash
docker compose restart shop inventory
./order.sh coffee 2 alice
./order.sh mug 5 bob
./order.sh pizza
```

**Vérifier**

Dans Jaeger, le service `shop` est apparu. La dernière trace (la commande `pizza`) contient un seul span, puisque l'appel à `inventory` n'est pas encore instrumenté. Affichez ses attributs :

```bash
curl -s 'http://localhost:16686/api/traces?service=shop&limit=1' \
  | jq -r '.data[0].spans[0].tags[] | "\(.key)=\(.value)"'
```

La liste contient notamment `order.sku=pizza`, `http.response.status_code=404` et `error=true` (Jaeger traduit le statut `ERROR` en balise `error`). Cherchez ensuite la trace de la commande `mug`, dans l'interface de Jaeger : son span porte l'événement `stock.insufficient`, visible dans la section Logs du span. En ligne de commande, filtrez sur `order.sku=mug` avec le paramètre `tags` de l'API :

```bash
curl -s -G 'http://localhost:16686/api/traces' --data-urlencode 'service=shop' \
  --data-urlencode 'tags={"order.sku":"mug"}' --data-urlencode 'limit=1' \
  | jq -r '.data[0].spans[0].logs[].fields[] | select(.key=="event") | .value'
```

La commande affiche `stock.insufficient`.

## Partie 4 : propager le contexte entre les services (30 min)

Jusqu'ici, `inventory` n'est pas instrumenté. Vous allez l'instrumenter, puis constater ce qui manque pour relier ses spans à ceux de `shop`.

**Côté inventory.** Le module `inventory_handler.py` est le point d'entrée de `GET /stock/<sku>`. Consultez sa version de départ avec `cat app/inventory_handler.py`, puis réécrivez-le pour qu'il :

1. extraie le contexte des en-têtes de la requête et crée un span `GET /stock/{sku}` de type `SERVER` qui en est l'enfant ;
2. y ajoute les attributs `http.request.method`, `http.route` (`/stock/{sku}`) et `inventory.sku` ;
3. entoure l'appel à `stock.load_stock(sku)` d'un span enfant `load_stock` (type interne, par défaut), avec l'attribut booléen `inventory.found` ;
4. ajoute l'attribut `inventory.stock` lorsque l'article existe, et positionne le statut `ERROR` lorsqu'il est inconnu.

Conservez les appels au logger et les valeurs de retour de la version de départ.

```bash
cat > app/inventory_handler.py <<'EOF'
```

Redémarrez, passez une commande, puis comparez les identifiants de trace des deux services :

```bash
docker compose restart shop inventory
./order.sh coffee 2 alice
for s in shop inventory; do
  curl -s "http://localhost:16686/api/traces?service=$s&limit=1" | jq -r '.data[0].traceID'
done
```

Les deux identifiants sont différents : `inventory` a créé sa propre trace, car `shop` ne lui transmet pas encore le contexte, et l'extraction ne trouve donc rien à reprendre. C'est le défaut classique d'une propagation incomplète, qui fragmente une même requête en plusieurs traces.

**Côté shop.** Le module `inventory_client.py` envoie la requête HTTP vers `inventory`. Réécrivez-le pour qu'il :

1. entoure la requête d'un span `GET inventory` de type `SpanKind.CLIENT` ;
2. y ajoute les attributs `http.request.method`, `url.full`, `server.address` (`inventory`) et, après la réponse, `http.response.status_code` ;
3. crée un dictionnaire `headers`, y écrit le contexte du span actif avec `opentelemetry.propagate.inject`, puis le passe à `requests.get` avec l'argument `headers=`.

L'appel `inject` ajoute au dictionnaire l'en-tête `traceparent`, au format W3C : version, identifiant de trace, identifiant du span parent et indicateurs. L'argument de la fonction, ici un dictionnaire, s'appelle le porteur (carrier) du contexte.

```bash
cat > app/inventory_client.py <<'EOF'
```

Redémarrez et repassez la commande :

```bash
docker compose restart shop inventory
./order.sh coffee 2 alice
```

**Vérifier**

Les deux services partagent maintenant la même trace, qui contient quatre spans :

```bash
curl -s 'http://localhost:16686/api/traces?service=shop&limit=1' \
  | jq -c '([.data[0].processes[].serviceName] | sort), (.data[0].spans | length)'
```

La commande affiche `["inventory","shop"]` puis `4`. Ouvrez la trace dans Jaeger : le span client `GET inventory` de `shop` a pour enfant le span serveur `GET /stock/{sku}` d'`inventory`, lequel contient `load_stock`.

Testez enfin une panne. Arrêtez `inventory`, passez une commande et redémarrez-le :

```bash
docker compose stop inventory
./order.sh coffee 1 carol
docker compose start inventory
```

La réponse est `{"error":"inventory unavailable"} [502]`. Dans Jaeger, le span `GET inventory` est en erreur et porte un événement `exception`, que `start_as_current_span` enregistre automatiquement lorsqu'une exception traverse le bloc `with`. Vous n'avez pas eu besoin de l'écrire.

## Partie 5 : relier les logs aux traces (20 min)

Le SDK sait envoyer les logs Python en OTLP et y joindre le contexte du span actif. Vous allez écrire le module `logs.py`, que les deux services appellent au démarrage. La fonction `setup(service_name)` doit :

- conserver la configuration de départ (`logging.basicConfig`), qui garde les logs sur la sortie standard ;
- créer un `LoggerProvider` avec une `Resource` portant `service.name` ;
- lui ajouter un `BatchLogRecordProcessor` qui s'appuie sur un `OTLPLogExporter` créé sans argument ;
- enregistrer le provider avec `set_logger_provider` ;
- ajouter au logger racine un `LoggingHandler` de niveau `INFO` qui utilise ce provider.

Modules à utiliser : `opentelemetry._logs` (`set_logger_provider`), `opentelemetry.sdk._logs` (`LoggerProvider`, `LoggingHandler`), `opentelemetry.sdk._logs.export` (`BatchLogRecordProcessor`) et `opentelemetry.exporter.otlp.proto.http._log_exporter` (`OTLPLogExporter`). Le préfixe `_` est normal : ces modules du SDK Python sont encore marqués comme évolutifs.

```bash
cat > app/logs.py <<'EOF'
```

Redémarrez, passez des commandes, puis interrogez Loki par l'API de Grafana :

```bash
docker compose restart shop inventory
./order.sh coffee 2 alice
./order.sh mug 5 bob
sleep 5
curl -s -G -u admin:formation \
  http://localhost:3000/api/datasources/proxy/uid/loki/loki/api/v1/query_range \
  --data-urlencode 'query={service_name="shop"} | trace_id != ""' \
  --data-urlencode 'limit=5' | jq -r '.data.result[].values[][1]'
```

**Vérifier**

La commande affiche des lignes comme `order received sku=coffee qty=2 customer=alice` et `insufficient stock sku=mug stock=3 requested=5`. Le filtre `trace_id != ""` ne garde que les logs qui portent un identifiant de trace : Loki le stocke comme métadonnée structurée, à côté de `span_id`.

Suivez maintenant un log jusqu'à sa trace dans Grafana. Ouvrez Explore, choisissez la source de données Loki et exécutez la requête `{service_name="shop"}`. Dépliez une ligne, par exemple `insufficient stock`, repérez le champ `trace_id` et cliquez sur le lien Voir la trace : Grafana ouvre la trace dans Jaeger. Vérifiez que c'est bien celle de la commande `mug`, avec l'événement `stock.insufficient`.

Observez aussi les lignes qui n'ont pas de lien : les messages de démarrage du serveur Flask et les lignes d'accès sont émis hors de tout span, et n'ont donc pas d'identifiant de trace. Seuls les logs écrits pendant qu'un span est actif sont reliés à une trace.

## Dépannage

**Après une modification, rien ne change ou le service redémarre en boucle.** Lisez `docker compose logs shop --tail 30` (ou `inventory`). Une erreur de syntaxe, un import erroné ou une indentation incorrecte apparaît dans la trace Python. Pensez à `docker compose restart shop inventory` : le code est lu au démarrage.

**Le terminal affiche une invite `>` qui ne revient pas.** Le shell attend toujours la ligne `EOF` d'un `cat` : tapez-la, ou interrompez avec Ctrl+C et recommencez la commande. Contrôlez le fichier écrit avec `cat app/telemetry.py`.

**Aucune trace dans Jaeger alors que le service répond.** Vérifiez que `telemetry.py` appelle `trace.set_tracer_provider`, que les modules appellent `trace.get_tracer` et que l'exporter n'a pas reçu d'adresse explicite : `docker compose logs otelcol | tail` montre si le Collector reçoit des données. Rappelez-vous que le `BatchSpanProcessor` envoie par lots : attendez quelques secondes.

**Les spans de `shop` et d'`inventory` restent dans deux traces distinctes.** Contrôlez que `inventory_client.py` appelle `inject` sur le dictionnaire qu'il passe réellement à `requests.get`, et que `inventory_handler.py` passe le résultat de `extract` à `start_as_current_span` par l'argument `context=`.

**Aucun log dans Loki.** Loki met une quinzaine de secondes à être prêt après le démarrage de la stack : `docker compose logs loki | tail`. Vérifiez aussi que `logs.py` ajoute le `LoggingHandler` au logger racine.

**Vous êtes bloqué sur un module.** Le dossier `solution/app` du dépôt contient une version complète des cinq modules. Copiez celui qu'il vous faut, par exemple `cp ~/opentelemetry-labs/tp07-instrumentation-manuelle/solution/app/telemetry.py ~/tp07/app/`.

## Pour aller plus loin

- Ajoutez à `shop_handler.py` un compteur de commandes avec l'API des métriques (`get_meter`, `create_counter`) et un `MeterProvider` dans `telemetry.py`.
- Envoyez une requête avec votre propre en-tête `traceparent` (`curl -H 'traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'`) et retrouvez dans Jaeger la trace `0af7651916cd43dd8448eb211c80319c`.
- Réglez l'échantillonnage à 10 % avec la variable `OTEL_TRACES_SAMPLER=parentbased_traceidratio` et `OTEL_TRACES_SAMPLER_ARG=0.1` dans `compose.yaml`, et observez ce qui change dans Jaeger et dans la corrélation avec les logs.
