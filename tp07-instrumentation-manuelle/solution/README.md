# TP7 - Corrigé

Le dossier `app/` contient les cinq modules que les participants écrivent : `telemetry.py`, `shop_handler.py`, `inventory_handler.py`, `inventory_client.py` et `logs.py`. Pour les utiliser directement :

```bash
cp ~/opentelemetry-labs/tp07-instrumentation-manuelle/solution/app/*.py ~/tp07/app/
cd ~/tp07 && docker compose restart shop inventory
```

## Partie 2 : SDK

- Le SDK se compose de trois éléments : un `TracerProvider` qui porte la ressource, un processor qui reçoit les spans terminés, et un exporter qui les envoie. `BatchSpanProcessor` les regroupe et les envoie en arrière-plan, ce qui évite de ralentir l'application. Son équivalent `SimpleSpanProcessor` envoie chaque span immédiatement et sert surtout pour les tests.
- `OTLPSpanExporter()` sans argument lit `OTEL_EXPORTER_OTLP_ENDPOINT` et y ajoute lui-même le chemin `/v1/traces`. Il n'y a donc aucune adresse dans le code : on change de destination en modifiant l'environnement.
- Le module `telemetry.py` ne renvoie rien. Les autres modules récupèrent un tracer avec `trace.get_tracer("nom")`, y compris avant l'appel à `setup` : l'API renvoie alors un tracer mandataire qui bascule sur le provider global dès qu'il est enregistré.
- Le test avec le service `smoke-test` montre que le SDK fonctionne : sans span créé par le code, un SDK correctement configuré n'envoie rien.

## Partie 3 : spans dans shop

Voir `app/shop_handler.py`.

- `SpanKind.SERVER` indique que le span représente le traitement d'une requête reçue. Les backends s'en servent pour construire la carte des services et calculer les métriques par type de span.
- L'événement porte un instant précis (« à ce moment, le stock était insuffisant ») alors qu'un attribut décrit le span entier. Les deux sont visibles dans Jaeger, les événements dans la section Logs du span.
- Un code HTTP 4xx n'est pas une erreur pour un span serveur d'après les conventions HTTP d'OpenTelemetry, mais ici l'application traite un stock insuffisant ou un article inconnu comme un échec de la commande, d'où le statut `ERROR`. C'est un choix métier à discuter avec les participants.
- `set_status` ne doit pas être appelé avec `OK` par défaut : l'absence de statut (`UNSET`) signifie « pas d'erreur détectée ».
- L'attribut `order.sku` est converti avec `str()` pour éviter un avertissement du SDK si le champ est absent de la requête (la valeur serait `None`).

## Partie 4 : propagation

Voir `app/inventory_handler.py` et `app/inventory_client.py`.

- Le format W3C `traceparent` s'écrit `00-<trace-id sur 32 caractères hexadécimaux>-<span-id sur 16>-<indicateurs>`. `inject` le calcule à partir du span actif au moment de l'appel : il doit donc être appelé à l'intérieur du bloc `with` du span client, pour que le span serveur d'`inventory` ait le span client comme parent (et non le span serveur de `shop`).
- `extract` prend un porteur qui se comporte comme un dictionnaire. Les en-têtes de Flask conviennent directement, avec une recherche insensible à la casse.
- Tant que `inject` est absent, `extract` ne trouve rien et renvoie un contexte vide : le span est alors racine d'une nouvelle trace. C'est la raison pour laquelle les deux traces sont distinctes à la fin de la première étape.
- `start_as_current_span` enregistre par défaut toute exception qui traverse le bloc (`record_exception=True`) et positionne le statut `ERROR` (`set_status_on_exception=True`). Dans la panne d'`inventory`, c'est ce comportement qui produit l'événement `exception` sur le span client.

## Partie 5 : logs

Voir `app/logs.py`.

- `LoggingHandler` convertit chaque enregistrement `logging` en enregistrement de log OpenTelemetry. Il y ajoute l'identifiant de trace et de span du contexte courant : la corrélation est automatique tant que le log est écrit pendant qu'un span est actif.
- Les messages écrits hors d'un span (démarrage du serveur, lignes d'accès de Werkzeug) ont des identifiants nuls : Loki ne crée pas de métadonnée `trace_id` pour eux, c'est pourquoi le filtre `trace_id != ""` les écarte.
- Dans Loki, `service.name` devient le label `service_name`, utilisé dans la requête `{service_name="shop"}`. `trace_id` et `span_id` sont des métadonnées structurées, non indexées, que Grafana expose comme des champs de la ligne.
- Le champ dérivé de la source de données Loki (`derivedFields` dans `files/grafana/provisioning/datasources/datasources.yaml`) utilise `matcherType: label` pour lire `trace_id` dans les métadonnées et construit le lien vers la source de données Jaeger.
