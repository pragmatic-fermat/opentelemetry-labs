# Lab 1 - Notes pour l'animateur

Le lab 1 se déroule en trois labs qui s'enchaînent sur les mêmes machines : 1A (console), 1B (collector vers Jaeger), 1C (processors). Un seul Cleanup, à la fin de 1C. Uniquement le signal traces.

## Minutage observé (rejeu du 22 novembre 2026, groupe 0)

| Lab | Durée observée |
|---|---|
| Mise en place (commune, page d'entrée) | 10 min, dont 5 de téléchargements déjà en cache |
| 1A. Voir la valeur | 35 min |
| 1B. Collector vers Jaeger | 65 min |
| 1C. Affiner le pipeline | 70 min |
| Cleanup + extra | 15 min |

Total observé : environ 3 h 15 avec l'extra, 3 h sans. Cible de 3 h tenable si l'extra est laissé en autonomie.

## Décisions prises à la rédaction

- **Sortie console en JSON une ligne** : l'exporter console du SDK produit du JSON indenté, illisible par `jq` ligne à ligne. L'application fournie embarque donc un petit exporter maison (`ConsoleJsonSpanExporter` dans `app/telemetry.py`) qui écrit un objet JSON par span. C'est du code fourni, jamais écrit par les participants. Sans la variable `OTEL_EXPORTER_OTLP_ENDPOINT`, les spans sortent sur la console ; avec, ils partent en OTLP. Le basculement 1A vers 1B ne change que cette variable, dans le fichier `.env`.
- **Variable d'environnement et `.env`** : le compose lit `OTEL_EXPORTER_OTLP_ENDPOINT` dans `.env`. Un `docker compose up -d` sans `.env` recrée les conteneurs en mode console : insister auprès des participants pour que le `.env` reste en place à partir de 1B. De même, `INVENTORY_DELAY_MS` se règle en préfixant la commande `docker compose up -d inventory` ; un `up -d` sans la variable remet le délai à zéro.
- **Timeout du client HTTP porté à 30 s** (contre 2 s dans le lab 7) : avec un délai de 3 000 ms côté inventory, un timeout de 2 s provoquait un 502 au lieu d'une lenteur visible. Avec 30 s, la trace lente est cohérente (racine ≈ 3 062 ms).
- **OTTL du renommage adaptée** : l'instruction qui renomme les spans vise `span.name == "handle_request"` (nom du span racine de l'application) au lieu de `lets-go` (nom des spans de telemetrygen). Revalidée avec `otelcol-contrib validate` 0.165.0 et vérifiée dans Jaeger (`POST /orders/{id}`).
- **Sondes de santé** : service `probe` du compose (profil `health`, image `curlimages/curl:8.11.0`), une requête sur `/health` toutes les cinq secondes. La route `/health` de `shop` crée un span nommé `handle_request` portant `http.route=/health`, que le `filter` de la partie 3 supprime.
- **Ordre Extra puis Cleanup** : écart par rapport au prompt initial de la refonte, qui plaçait le Cleanup avant l'Extra et demandait une reconstruction de la stack pour l'Extra. L'Extra s'exécute sur la stack encore en place : pas de reconstruction, et le `transform/slo` s'ajoute à la configuration finale de la partie 4 (pipeline `memory_limiter`, `resource`, `filter/healthchecks`, `transform/normalize`, `transform/slo`, `batch`). Si le formateur préfère l'ordre inverse, l'Extra devra de nouveau inclure un bloc de remontée de la stack.
- **Application du lab 1 et lab 7** : l'application du lab 1 reproduit l'instrumentation que le [lab 7](../Lab_07_Instrumentation_Manuelle.md) demande d'écrire (mêmes noms de spans, même événement `stock.insufficient`). Les participants du lab 7 qui ont fait le lab 1 ont déjà vu la télémétrie attendue, mais pas le code : le lab 7 part de modules sans télémétrie, comme prévu.
- **Jaeger sur srv-N** : même répartition que le lab 3. Le compose de `srv-N` (`compose-srv.yaml`) ne contient que Jaeger, ports 16686 et 4318. Démarré depuis `clt-N` par SSH.
- **Fenêtres de recherche** : les vérifications dans Jaeger utilisent des fenêtres temporelles courtes (1 minute, 30 secondes) car les traces antérieures à un redémarrage du **collector** restent dans Jaeger. La partie 3 attend 60 secondes après le redémarrage pour que la fenêtre d'une minute exclue les traces d'ancien pipeline.
- `config/lab01/grafana/` supprimé : aucun autre lab ne le référençait (lab 4 et lab 7 ont leur propre provisioning). Une copie reste dans `archive/TP01-avant-refonte/`.

## Ce qui a été testé (rejeu complet, 22 novembre 2026, clt-0 et srv-0)

- Mise en place sur machines nettoyées : build de l'application, pulls des quatre images, SSH sans mot de passe vers `srv-0` ;
- 1A : spans JSON une ligne mêlés aux logs Flask dans `docker compose logs --no-log-prefix shop inventory` ; les trois filtres `jq` (liste, erreurs, tri par durée) sur cette sortie mêlée ; reconstitution d'une trace par `trace_id` ; panne (`docker compose stop inventory`, 502, spans en erreur, logs applicatifs retrouvés par `grep "$TRACE" | grep -E ' (INFO|ERROR) '` : la cause est une résolution de nom impossible, pas un 502 renvoyé par un serveur) ; lenteur (`INVENTORY_DELAY_MS=3000`, tri par durée : `load_stock` 3 050 ms) ;
- 1B : les quatre fichiers du **collector**, `check.sh`, `Everything is ready`, `tg.sh traces` (10 spans), bascule de l'application par `.env` (console 0 span, collector 3 spans), span `curl` (200, visible dans les logs), Jaeger sur `srv-0` (UI 200, OTLP 200), exporter `otlp_http/jaeger` avec `$SRV_HOST` développé par le shell, traces `shop` et span `manuel` dans l'API v3 appelée depuis `clt-0`, diagnostic à distance des deux scénarios (span en erreur par statut, lenteur par `minDuration=2s`) ; tri de la lenteur rejoué après correction : durée en tête de ligne, arrondie, puis `sort -rn` (`3022ms handle_request`, `3022ms GET inventory`, `3016ms load_stock`) ;
- 1C : redémarrage de Jaeger pour repartir de zéro, bruit visible (11 spans de sonde en une minute), `memory_limiter`/`resource`/`batch` (attributs de ressource dans Jaeger), expérience du `timeout: 15s` (export bloqué une quinzaine de secondes, observé sur les horodatages des exports), `filter` (0 sonde, 1 commande dans la fenêtre), `transform` (e-mail `***@example.com`, chemin `/orders/{id}`, span renommé `POST /orders/{id}`) ;
- Extra `slo.violation` : rejoué avec le pipeline complet de la partie 4 (y compris `filter/healthchecks`), sondes actives : 0 sonde sur la fenêtre de deux minutes, et `true` sur les deux spans en erreur (`POST /orders/{id}` et `GET inventory`) ;
- Cleanup des deux machines : plus aucun conteneur `lab01`, ports 4318 et 16686 libres sur `srv-0`.

## Ce qui n'a pas été exécuté

- Le filtre par attribut dans l'Extra depuis l'interface de Jaeger : vérifié par l'API v3 uniquement. Les captures, elles, ont été prises dans le navigateur (Playwright et Chromium) sur le service `shop` : waterfall d'une trace, détail de span avec ses attributs, et le même span avant puis après le processor `transform`.

## Points d'attention

- `docker compose run` (utilisé par `check.sh` et `tg.sh`) et les commandes `ssh` consomment l'entrée standard : dans un script pipé, protéger par `</dev/null`. Sans conséquence pour les participants, qui tapent les commandes.
- Après un redémarrage de Jaeger, le **collector** met quelques dizaines de secondes à rétablir l'export : les traces passées pendant ce trou sont perdues (exporter HTTP sans file d'attente). C'est le prix du Jaeger en mémoire, assumé dans ce lab ; le lab 9 traite les files d'attente.
- La fenêtre de recherche compte : des traces d'ancien pipeline restent dans Jaeger après chaque changement de configuration du **collector**. Les vérifications du lab resserrent les fenêtres pour cette raison.
- L'ordre des processors est porté par `service.yaml`, réécrit en entier à chaque partie : un participant en retard peut recopier le fichier depuis l'énoncé.
- La partie 3 attend 60 secondes : bon moment pour la discussion sur le coût du bruit.
- Le span racine s'appelle `handle_request` avant le transform : c'est voulu (nom peu parlant, thème de la partie 4). Ne pas « corriger » le nom dans l'application.
- Les logs applicatifs portent le `trace_id` entre crochets : c'est ce qui permet le `grep <trace_id>` facultatif de la partie 3 de 1A et qui préfigure la corrélation logs/traces du lab 7.

## Pour la discussion

- La frontière application / collector / backend : l'application ne connaît que l'adresse du **collector** ; changer de backend ne la concerne pas.
- Le filtrage et le masquage se font sur `clt-N`, avant l'envoi : les données sensibles ne quittent pas la machine applicative.
- Les limites de l'export console présentées en fin de 1A (volume élevé, services multiples) trouvent leur réponse en 1B : recherche centralisée, vue arborescente, rétention.
