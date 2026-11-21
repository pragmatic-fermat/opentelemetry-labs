# Lab TP7 : instrumenter une application Python à la main

# Objectifs

À la fin du lab, vous saurez :

- configurer le SDK OpenTelemetry pour Python (ressource, provider, processor, exporter OTLP) ;
- créer des spans avec un type (`SpanKind`), des attributs métier, des événements et un statut d'erreur ;
- propager le contexte entre deux services par l'en-tête W3C `traceparent`, avec `inject` et `extract` ;
- joindre l'identifiant de trace aux logs et suivre un log vers sa trace dans Grafana ;
- repérer dans Jaeger les défauts d'une instrumentation incomplète (traces coupées, spans sans erreur visible).

# Contenu

- [Environnement](#environnement)
- [1. Démarrer l'application sans instrumentation](#1-démarrer-lapplication-sans-instrumentation)
- [2. Configurer le SDK](#2-configurer-le-sdk)
- [3. Créer des spans dans shop](#3-créer-des-spans-dans-shop)
- [4. Propager le contexte entre les services](#4-propager-le-contexte-entre-les-services)
- [5. Relier les logs aux traces](#5-relier-les-logs-aux-traces)
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Ce lab se déroule sur la machine cliente `clt-N` (N est votre numéro de participant).

Vous travaillez depuis son terminal web, dans `/root`, où le dépôt des labs est déjà cloné dans `/root/opentelemetry-labs`.

Vous instrumentez à la main une petite application Python composée de deux services : `shop` reçoit des commandes et interroge `inventory` pour connaître le stock. Aucune bibliothèque d'auto-instrumentation n'est utilisée.

Le [TP1](Lab_TP01_Socle.md) est conseillé pour le rôle du **collector**. Aucune connaissance de Python au-delà de la lecture d'un script n'est nécessaire : le code utile est court et commenté.

Versions utilisées dans ce lab :

| Composant | Version |
|---|---|
| Python (image de l'application) | 3.13.18 |
| API, SDK et exporter OTLP/HTTP OpenTelemetry pour Python | 1.45.2 |
| Flask, requests | 3.1.3, 2.34.2 |
| **collector** OpenTelemetry (distribution `otelcol-contrib`) | 0.165.0 |
| Jaeger | 2.23.0 |
| Loki | 3.7.10 |
| Grafana | 13.3.1 |

Les interfaces web sont accessibles depuis votre navigateur, sur `clt-N` (`$CLT_HOST`) :

- Jaeger : `http://$CLT_HOST:16686` (TCP/16686) ;
- Grafana : `http://$CLT_HOST:3000` (TCP/3000, compte `admin`, mot de passe `formation`).

## 1. Démarrer l'application sans instrumentation

Copiez les fichiers fournis dans un dossier de travail, puis construisez et démarrez la stack :

```bash
mkdir -p ~/tp07
cp -r ~/opentelemetry-labs/config/tp07/. ~/tp07/
cd ~/tp07
docker compose up -d --build
docker compose ps
```

La stack comprend l'application (`shop` et `inventory`), un **collector**, Jaeger pour les traces, Loki pour les logs et Grafana pour les consulter.

La configuration du **collector**, fournie dans `otelcol/config.yaml`, reçoit l'OTLP/HTTP, envoie les traces à Jaeger et les logs à Loki.

Le dossier `app/` contient le code Python. Lisez-le avec `cat`, en commençant par `app/shop.py` et `app/orders.py`. Les modules `orders.py` et `stock.py` portent la logique métier et ne sont jamais modifiés.

Vous écrirez au fil du TP cinq petits modules : `telemetry.py`, `shop_handler.py`, `inventory_handler.py`, `inventory_client.py` et `logs.py`. Leurs versions de départ ne produisent aucune télémétrie.

Le dossier `app/` est monté dans les conteneurs : après chaque modification, `docker compose restart shop inventory` suffit, sans reconstruire l'image.

Passez trois commandes, avec le script `order.sh` (articles connus : `coffee` en stock à 12, `mug` à 3 et `tea` à 0) :

```bash
./order.sh coffee 2 alice
./order.sh mug 5 bob
./order.sh pizza
```

On obtient, le code HTTP étant affiché entre crochets :

```text
{"status":"accepted","total":9.0} [201]
{"error":"insufficient stock","stock":3} [409]
{"error":"unknown sku"} [404]
```

Jaeger ne connaît encore aucun service :

```bash
curl -s http://localhost:16686/api/v3/services | jq -r '.services[]'
```

La commande n'affiche que `jaeger`.

## 2. Configurer le SDK

Pour produire des spans, un programme a besoin d'un `TracerProvider`. Il décrit qui émet les données (la ressource), traite les spans terminés (le processor) et les envoie quelque part (l'exporter).

Vous allez écrire le module `telemetry.py`, que `shop.py` et `inventory.py` appellent au démarrage avec le nom du service.

La fonction `setup(service_name)` doit créer une `Resource` avec les attributs `service.name`, `service.version` et `deployment.environment.name`, un `TracerProvider` avec cette ressource, lui ajouter un `BatchSpanProcessor` qui s'appuie sur un `OTLPSpanExporter` créé sans argument, et enregistrer ce provider comme provider global avec `trace.set_tracer_provider`.

L'exporter sans argument lit l'adresse du **collector** dans la variable `OTEL_EXPORTER_OTLP_ENDPOINT`, que `compose.yaml` définit.

Les classes se trouvent dans les modules suivants :

| Classe | Module |
|---|---|
| `Resource` | `opentelemetry.sdk.resources` |
| `TracerProvider` | `opentelemetry.sdk.trace` |
| `BatchSpanProcessor` | `opentelemetry.sdk.trace.export` |
| `OTLPSpanExporter` | `opentelemetry.exporter.otlp.proto.http.trace_exporter` |
| `trace` | `opentelemetry` |

```bash
cat > app/telemetry.py <<'EOF'
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

def setup(service_name):
    resource = Resource.create(
        {
            "service.name": service_name,
            "service.version": "1.0.0",
            "deployment.environment.name": "tp7",
        }
    )
    provider = TracerProvider(resource=resource)
    # L'exporter lit OTEL_EXPORTER_OTLP_ENDPOINT (définie dans compose.yaml).
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
    trace.set_tracer_provider(provider)
EOF
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

```bash
curl -s http://localhost:16686/api/v3/services | jq -c '.services'
```

La liste contient `smoke-test`.

Passez une commande avec `./order.sh coffee 2 alice` : elle fonctionne toujours, mais ni `shop` ni `inventory` n'apparaissent dans Jaeger. Configurer le SDK ne produit aucune donnée par lui-même : c'est le code qui crée les spans.

## 3. Créer des spans dans shop

Le module `shop_handler.py` est le point d'entrée de `POST /orders` : il appelle la logique métier de `orders.py`. Vous allez l'entourer d'un span.

Consultez d'abord sa version de départ avec `cat app/shop_handler.py`, puis réécrivez-le pour qu'il :

1. extraie le contexte éventuel des en-têtes de la requête (`opentelemetry.propagate.extract`) : si l'appelant envoie un en-tête `traceparent`, le span rejoint sa trace ;
2. crée avec `start_as_current_span` un span nommé `POST /orders`, de type `SpanKind.SERVER`, dont le parent est ce contexte ;
3. y ajoute les attributs `http.request.method`, `http.route`, `order.sku`, `order.qty`, `customer.id` et `enduser.id` ;
4. appelle `orders.create_order(payload)`, qui renvoie le corps de la réponse et le code HTTP ;
5. ajoute l'attribut `http.response.status_code` ;
6. pour un code 201, ajoute l'attribut `order.total` ;
7. pour un code 409, ajoute l'événement `stock.insufficient` avec l'attribut `stock` ;
8. pour tout code supérieur ou égal à 400, positionne le statut du span à `ERROR`, avec la valeur de `error` dans la réponse comme description.

Les noms d'attributs suivent les conventions sémantiques d'OpenTelemetry pour HTTP (`http.*`). Les attributs métier portent un préfixe qui décrit leur domaine (`order.`). Le module récupère son tracer avec `trace.get_tracer("shop")`, au niveau du module.

```bash
cat > app/shop_handler.py <<'EOF'
from opentelemetry import trace
from opentelemetry.propagate import extract
from opentelemetry.trace import SpanKind, Status, StatusCode

import orders

tracer = trace.get_tracer("shop")

def create_order(payload, headers):
    # Si l'appelant a envoyé un en-tête traceparent, le span rejoint sa trace.
    parent = extract(headers)
    with tracer.start_as_current_span("POST /orders", context=parent, kind=SpanKind.SERVER) as span:
        span.set_attribute("http.request.method", "POST")
        span.set_attribute("http.route", "/orders")
        span.set_attribute("order.sku", str(payload.get("sku")))
        span.set_attribute("order.qty", int(payload.get("qty", 1)))
        span.set_attribute("customer.id", payload.get("customer", "anonymous"))
        span.set_attribute("enduser.id", payload.get("customer", "anonymous"))

        body, status = orders.create_order(payload)

        span.set_attribute("http.response.status_code", status)
        if status == 201:
            span.set_attribute("order.total", body["total"])
        elif status == 409:
            span.add_event("stock.insufficient", {"stock": body["stock"]})
        if status >= 400:
            span.set_status(Status(StatusCode.ERROR, body["error"]))
        return body, status
EOF
```

Redémarrez et passez trois commandes :

```bash
docker compose restart shop inventory
./order.sh coffee 2 alice
./order.sh mug 5 bob
./order.sh pizza
```

Dans Jaeger (`http://$CLT_HOST:16686`), le service `shop` est apparu. La dernière trace (la commande `pizza`) contient un seul span, puisque l'appel à `inventory` n'est pas encore instrumenté. Affichez ses attributs :

```bash
Q='http://localhost:16686/api/v3/traces?query.service_name=shop&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z'
curl -s "$Q" | jq -r '.result.resourceSpans[0].scopeSpans[0].spans[0].attributes[] | "\(.key)=\(.value | (.stringValue // .intValue // .boolValue))"'
```

La liste contient notamment :

```text
order.sku=pizza
http.response.status_code=404
```

Jaeger traduit le statut `ERROR` en balise `error` :

```bash
curl -s "$Q" | jq -c '.result.resourceSpans[0].scopeSpans[0].spans[0].status'
```

```text
{"message":"unknown sku","code":2}
```

Le code `2` correspond au statut d'erreur OTLP.

Cherchez ensuite la trace de la commande `mug` : son span porte l'événement `stock.insufficient`, visible dans la section Logs du span dans l'interface. En ligne de commande, l'événement figure dans les événements du span :

```bash
for i in 0 1 2 3 4 5 6 7 8 9; do
  curl -s "$Q" | jq -r --argjson i $i '.result.resourceSpans[$i].scopeSpans[0].spans[0] | select(.attributes[]? | select(.key=="order.sku" and .value.stringValue=="mug")) | .events[].name'
done
```

La commande affiche `stock.insufficient`.

### Hacher l'identité avant l'export

L'attribut `enduser.id` désigne une personne. Une valeur en clair, conservée des mois dans un backend, est une donnée personnelle exposée. Le masquage du [TP1](Lab_TP01_Socle.md) remplace la valeur par `***` ; ici, vous gardez la corrélation en la remplaçant par l'empreinte de sa valeur : deux commandes du même client portent la même empreinte, sans que son identité apparaisse.

Le **collector** de la pile lit `otelcol/config.yaml`. Ajoutez-lui un second fichier, que le **collector** fusionne avec le premier : les dictionnaires se complètent, et une liste, comme celle des processors d'un pipeline, est remplacée par la dernière lue.

```bash
cat > otelcol/anonymize.yaml <<'EOF'
processors:
  transform/anonymize:
    error_mode: ignore
    trace_statements:
      - context: span
        statements:
          - set(attributes["enduser.id"], Substring(SHA256(attributes["enduser.id"]), 0, 8)) where attributes["enduser.id"] != nil

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [transform/anonymize, batch]
      exporters: [otlp_grpc/jaeger, debug]
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp_http/loki, debug]
EOF
```

Trois points sur cette instruction :

- `SHA256` calcule l'empreinte de la valeur en hexadécimal, et `Substring(..., 0, 8)` n'en garde que huit caractères : assez pour corréler, trop peu pour remonter au nom ;
- la clause `where` limite le calcul aux spans qui portent l'attribut, et `error_mode: ignore` laisse passer le span si l'expression échoue ;
- le pipeline `logs` est répété à l'identique, parce que la liste des pipelines du second fichier remplace celle du premier. Oubliez-le, et les logs cessent d'arriver dans Loki.

Déclarez le second fichier dans le compose, puis recréez le **collector** :

```bash
sed -i 's|command: \["--config=/etc/otelcol/config.yaml"\]|command: ["--config=/etc/otelcol/config.yaml", "--config=/etc/otelcol/anonymize.yaml"]|' compose.yaml
docker compose up -d otelcol
```

Passez une commande, puis lisez les deux attributs sur le span :

```bash
./order.sh coffee 2 alice
Q='http://localhost:16686/api/v3/traces?query.service_name=shop&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z'
curl -s "$Q" | jq -r '.result.resourceSpans[0].scopeSpans[0].spans[0].attributes[] | select(.key=="customer.id" or .key=="enduser.id") | "\(.key)=\(.value.stringValue)"'
```

```text
enduser.id=2bd806c9
customer.id=alice
```

L'identité est toujours là, sous forme d'empreinte, et `customer.id` rappelle qui a commandé. En production, la même instruction s'applique à toute donnée personnelle que vous devez conserver sans l'exposer : adresse électronique, numéro de téléphone, identifiant de session.

## 4. Propager le contexte entre les services

Jusqu'ici, `inventory` n'est pas instrumenté. Vous allez l'instrumenter, puis constater ce qui manque pour relier ses spans à ceux de `shop`.

### Côté inventory

Le module `inventory_handler.py` est le point d'entrée de `GET /stock/<sku>`. Consultez sa version de départ avec `cat app/inventory_handler.py`, puis réécrivez-le pour qu'il :

1. extraie le contexte des en-têtes de la requête et crée un span `GET /stock/{sku}` de type `SERVER` qui en est l'enfant ;
2. y ajoute les attributs `http.request.method`, `http.route` et `inventory.sku` ;
3. entoure l'appel à `stock.load_stock(sku)` d'un span enfant `load_stock`, avec l'attribut booléen `inventory.found` ;
4. ajoute l'attribut `inventory.stock` lorsque l'article existe, et positionne le statut `ERROR` lorsqu'il est inconnu.

Conservez les appels au logger et les valeurs de retour de la version de départ.

```bash
cat > app/inventory_handler.py <<'EOF'
import logging

from opentelemetry import trace
from opentelemetry.propagate import extract
from opentelemetry.trace import SpanKind, Status, StatusCode

import stock

logger = logging.getLogger("inventory.handler")
tracer = trace.get_tracer("inventory")

def lookup(sku, headers):
    # Reprend le contexte envoyé par le service shop dans l'en-tête traceparent.
    parent = extract(headers)
    with tracer.start_as_current_span("GET /stock/{sku}", context=parent, kind=SpanKind.SERVER) as span:
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("http.route", "/stock/{sku}")
        span.set_attribute("inventory.sku", sku)

        with tracer.start_as_current_span("load_stock") as load:
            quantity = stock.load_stock(sku)
            load.set_attribute("inventory.found", quantity is not None)

        if quantity is None:
            span.set_status(Status(StatusCode.ERROR, "unknown sku"))
            logger.warning("unknown sku=%s", sku)
            return {"error": "unknown sku"}, 404

        span.set_attribute("inventory.stock", quantity)
        logger.info("stock lookup sku=%s stock=%s", sku, quantity)
        return {"sku": sku, "stock": quantity}, 200
EOF
```

Redémarrez, passez une commande, puis comparez les identifiants de trace des deux services :

```bash
docker compose restart shop inventory
./order.sh coffee 2 alice
for s in shop inventory; do
  curl -s "http://localhost:16686/api/v3/traces?query.service_name=$s&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z" \
    | jq -r '.result.resourceSpans[0].scopeSpans[0].spans[0].traceId'
done
```

Les deux identifiants sont différents : `inventory` a créé sa propre trace, car `shop` ne lui transmet pas encore le contexte, et l'extraction ne trouve donc rien à reprendre. C'est le défaut classique d'une propagation incomplète, qui fragmente une même requête en plusieurs traces.

### Côté shop

Le module `inventory_client.py` envoie la requête HTTP vers `inventory`. Réécrivez-le pour qu'il :

1. entoure la requête d'un span `GET inventory` de type `SpanKind.CLIENT` ;
2. y ajoute les attributs `http.request.method`, `url.full`, `server.address` et, après la réponse, `http.response.status_code` ;
3. crée un dictionnaire `headers`, y écrive le contexte du span actif avec `opentelemetry.propagate.inject`, puis le passe à `requests.get` avec l'argument `headers=`.

L'appel `inject` ajoute au dictionnaire l'en-tête `traceparent`, au format W3C : version, identifiant de trace, identifiant du span parent et indicateurs. L'argument de la fonction, ici un dictionnaire, s'appelle le porteur (carrier) du contexte.

```bash
cat > app/inventory_client.py <<'EOF'
import os

import requests
from opentelemetry import trace
from opentelemetry.propagate import inject
from opentelemetry.trace import SpanKind

INVENTORY_URL = os.environ.get("INVENTORY_URL", "http://inventory:8081")

tracer = trace.get_tracer("shop.inventory_client")

def get_stock(sku):
    url = f"{INVENTORY_URL}/stock/{sku}"
    with tracer.start_as_current_span("GET inventory", kind=SpanKind.CLIENT) as span:
        span.set_attribute("http.request.method", "GET")
        span.set_attribute("url.full", url)
        span.set_attribute("server.address", "inventory")

        # inject écrit l'en-tête traceparent du span actif dans le dictionnaire.
        headers = {}
        inject(headers)

        resp = requests.get(url, headers=headers, timeout=2)
        span.set_attribute("http.response.status_code", resp.status_code)
        resp.raise_for_status()
        return resp.json()["stock"]
EOF
```

Redémarrez et repassez la commande :

```bash
docker compose restart shop inventory
./order.sh coffee 2 alice
```

Les deux services partagent maintenant la même trace, qui contient quatre spans :

```bash
curl -s 'http://localhost:16686/api/v3/traces?query.service_name=shop&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z' \
  | jq -c '[.result.resourceSpans[].resource.attributes[] | select(.key=="service.name") | .value.stringValue] | sort, ([.result.resourceSpans[].scopeSpans[].spans[]] | length)'
```

La commande affiche :

```text
["inventory","shop"]
4
```

Ouvrez la trace dans Jaeger : le span client `GET inventory` de `shop` a pour enfant le span serveur `GET /stock/{sku}` d'`inventory`, lequel contient `load_stock`.

Testez enfin une panne. Arrêtez `inventory`, passez une commande et redémarrez-le :

```bash
docker compose stop inventory
./order.sh coffee 1 carol
docker compose start inventory
```

La réponse est `{"error":"inventory unavailable"} [502]`. Dans Jaeger, le span `GET inventory` est en erreur et porte un événement `exception`, que `start_as_current_span` enregistre automatiquement lorsqu'une exception traverse le bloc `with`. Vous n'avez pas eu besoin de l'écrire.

## 5. Relier les logs aux traces

Le SDK sait envoyer les logs Python en OTLP et y joindre le contexte du span actif. Vous allez écrire le module `logs.py`, que les deux services appellent au démarrage.

La fonction `setup(service_name)` doit conserver la configuration de départ (`logging.basicConfig`), créer un `LoggerProvider` avec une `Resource` portant `service.name`, lui ajouter un `BatchLogRecordProcessor` qui s'appuie sur un `OTLPLogExporter` créé sans argument, enregistrer le provider avec `set_logger_provider`, puis ajouter au logger racine un `LoggingHandler` de niveau `INFO` qui utilise ce provider.

Modules à utiliser : `opentelemetry._logs` (`set_logger_provider`), `opentelemetry.sdk._logs` (`LoggerProvider`, `LoggingHandler`), `opentelemetry.sdk._logs.export` (`BatchLogRecordProcessor`) et `opentelemetry.exporter.otlp.proto.http._log_exporter` (`OTLPLogExporter`). Le préfixe `_` est normal : ces modules du SDK Python sont encore marqués comme évolutifs.

```bash
cat > app/logs.py <<'EOF'
import logging

from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.resources import Resource

def setup(service_name):
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")

    provider = LoggerProvider(resource=Resource.create({"service.name": service_name}))
    provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
    set_logger_provider(provider)

    # Ce handler envoie chaque enregistrement au collector et y joint le trace_id
    # et le span_id du span actif au moment de l'appel.
    logging.getLogger().addHandler(LoggingHandler(level=logging.INFO, logger_provider=provider))
EOF
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

On obtient des lignes comme :

```text
order received sku=coffee qty=2 customer=alice
insufficient stock sku=mug stock=3 requested=5
```

Le filtre `trace_id != ""` ne garde que les logs qui portent un identifiant de trace : Loki le stocke comme métadonnée structurée, à côté de `span_id`.

Suivez maintenant un log jusqu'à sa trace dans Grafana. Ouvrez Explore (`http://$CLT_HOST:3000`), choisissez la source de données Loki et exécutez la requête `{service_name="shop"}`. Dépliez une ligne, par exemple `insufficient stock`, repérez le champ `trace_id` et cliquez sur le lien vers la trace : Grafana ouvre la trace dans Jaeger. Vérifiez que c'est bien celle de la commande `mug`, avec l'événement `stock.insufficient`.

Observez aussi les lignes qui n'ont pas de lien : les messages de démarrage du serveur Flask et les lignes d'accès sont émis hors de tout span, et n'ont donc pas d'identifiant de trace. Seuls les logs écrits pendant qu'un span est actif sont reliés à une trace.

> [!NOTE]
>
> Si une modification semble sans effet ou si un service redémarre en boucle, lisez `docker compose logs shop --tail 30` (ou `inventory`) : une erreur de syntaxe, un import erroné ou une indentation incorrecte apparaît dans la trace Python. Pensez à `docker compose restart shop inventory`, le code est lu au démarrage.

Si le terminal affiche une invite `>` qui ne revient pas, le shell attend la ligne `EOF` d'un `cat` : tapez-la, ou interrompez avec Ctrl+C.

## Cleanup

Arrêtez la stack, supprimez son réseau et l'image applicative construite par le compose :

```bash
cd ~/tp07
docker compose down --rmi local
docker compose ps
```

`--rmi local` supprime l'image `tp07-app:local`, construite depuis `./app` et non téléchargée : sans cette option, elle reste sur la machine et se réutilise silencieusement d'une session à l'autre avec un code qui n'est plus celui du dépôt. La seconde commande n'affiche plus rien.

Le dossier `~/tp07` peut être conservé : les modules écrits servent de point de départ aux TP suivants.

## Extra

À vous de jouer, si le temps le permet.

- Ajoutez à `shop_handler.py` un compteur de commandes avec l'API des métriques (`get_meter`, `create_counter`) et un `MeterProvider` dans `telemetry.py`.
- Envoyez une requête avec votre propre en-tête `traceparent` (`curl -H 'traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01'`) et retrouvez dans Jaeger la trace `0af7651916cd43dd8448eb211c80319c`.
- Réglez l'échantillonnage à 10 % avec la variable `OTEL_TRACES_SAMPLER=parentbased_traceidratio` et `OTEL_TRACES_SAMPLER_ARG=0.1` dans `compose.yaml`, et observez ce qui change dans Jaeger et dans la corrélation avec les logs.
