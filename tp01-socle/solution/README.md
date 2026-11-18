# TP1 - Corrigé

Les fichiers de `otelcol/` sont cumulatifs : `partie3.yaml` contient tout `partie2.yaml` plus les processors de base, et ainsi de suite. Pour tester une étape, copiez le fichier voulu à la place de `~/tp01/otelcol/config.yaml` puis redémarrez le Collector.

```bash
cp ~/opentelemetry-labs/tp01-socle/solution/otelcol/partie6.yaml ~/tp01/otelcol/config.yaml
cd ~/tp01 && docker compose restart otelcol
```

## Partie 2 : premier Collector

Voir `otelcol/partie2.yaml`.

- Le receiver `otlp` doit écouter sur `0.0.0.0`. Sans cette précision, il n'écoute que sur `localhost` à l'intérieur du conteneur et le port publié par Docker ne répond pas.
- L'exporter `otlp/jaeger` vise `jaeger:4317`. Le suffixe `/jaeger` est un nom d'instance : il permet de déclarer plusieurs exporters du même type. `tls.insecure: true` est nécessaire car Jaeger écoute en clair.
- L'exporter `debug` est ajouté à côté de `otlp/jaeger` dans le même pipeline : un pipeline peut avoir plusieurs exporters, chacun reçoit toutes les données.

## Partie 3 : memory_limiter, resource, batch

Voir `otelcol/partie3.yaml`.

- Ordre : `memory_limiter` en premier, pour refuser les données avant tout traitement lorsque la mémoire est saturée, et `batch` en dernier, pour regrouper des données qui ne changeront plus.
- Pour `resource`, l'action `upsert` crée l'attribut s'il n'existe pas et le remplace sinon. `insert` ne touche pas à une valeur existante, `update` ne crée rien.
- `${env:LAB_ID}` est remplacé au chargement de la configuration par la variable d'environnement du conteneur.
- Avec `timeout: 15s`, un lot incomplet n'est envoyé qu'au bout de quinze secondes : c'est le comportement observé dans les logs.

## Partie 4 : filter

Voir `otelcol/partie4.yaml`.

- Chaque ligne de `trace_conditions` est une condition OTTL. Si l'une d'elles est vraie pour un span, le span est supprimé.
- La comparaison avec `==` renvoie simplement faux lorsque l'attribut est absent : les spans sans `http.route` ne sont pas touchés et il n'y a pas d'erreur.
- Une variante plus compacte est `IsMatch(span.attributes["http.route"], "^/(health|ready)$")`. Elle convient bien lorsque la liste des chemins est longue.
- Le filtre est placé avant `batch` pour ne pas regrouper de données qui seront supprimées.

## Partie 5 : transform et OTTL

Voir `otelcol/partie5.yaml`.

- Les chemins sont préfixés par le contexte (`span.`), le processor déduit lui-même qu'il travaille sur les spans.
- `replace_pattern(span.attributes["user.email"], "^[^@]+", "***")` remplace tout ce qui précède le premier `@`. `alice@example.com` devient `***@example.com`.
- `replace_pattern(span.attributes["url.path"], "/[0-9]+", "/{id}")` remplace chaque segment composé de chiffres. L'expression utilise `[0-9]` plutôt que `\d` pour éviter le double échappement dans YAML.
- Le renommage vient après la normalisation, sinon le nom contiendrait l'identifiant brut. La clause `where span.name == "lets-go"` limite l'effet au span parent.
- Les clauses `!= nil` évitent les erreurs de `Concat` lorsqu'un attribut est absent.
- La dernière instruction correspond à la piste « pour aller plus loin » : avec `--status-code Error`, les spans reçoivent `slo.violation=true`.

## Partie 6 : métriques

Voir `otelcol/partie6.yaml`.

- Le pipeline `metrics` réutilise les mêmes types de processors que le pipeline `traces`. Chaque pipeline a ses propres instances, il n'y a pas de partage d'état.
- Sans `resource_to_telemetry_conversion`, les attributs de ressource (`service.name`, `lab.id`) ne sont exposés que sur la série `target_info`. Avec l'option, ils deviennent des labels (`service_name`, `lab_id`) de chaque série.
- Le port 8889 n'est pas publié sur l'hôte : seul Prometheus, sur le réseau du compose, a besoin d'y accéder.
