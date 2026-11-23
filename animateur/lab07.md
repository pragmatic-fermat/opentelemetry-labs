# Lab 7 - Notes pour l'animateur

## Minutage indicatif

| Partie | Durée |
|---|---|
| 1. Démarrer sans instrumentation | 15 min |
| 2. SDK | 25 min |
| 3. Spans dans shop (avec hachage OTTL) | 35 min |
| 4. Propagation (client, serveur, panne) | 35 min |
| Cleanup + Extra | 15 min |

Total indicatif : environ 2 h.

## Architecture du lab

Le lab se déroule entièrement sur la machine cliente `clt-N` :
- `shop` (port 8080) et `inventory` (port 8081) forment l'application e-commerce en microservices Python ;
- Le **collector** local (port 4318) reçoit les traces en OTLP/HTTP et les achemine vers Jaeger ;
- Jaeger (port 16686) stocke les traces en mémoire vive et fournit l'interface de visualisation.

Les composants Loki et Grafana ont été retirés de la stack pour concentrer le lab 7 exclusivement sur le signal traces (spans, attributs, événements, erreurs, propagation de contexte W3C et hachage OTTL), conformément aux objectifs du cours.

## Rejeu du 22 novembre 2026 (clt-0)

Le rejeu complet a été validé sur `clt-0` :

- **Partie 1 (Démarrage)** : build de l'image Python et démarrage des conteneurs. Les commandes `./order.sh` retournent 201 (coffee), 409 (mug, stock insuffisant) et 404 (pizza, inconnu). Seul le service `jaeger` est enregistré dans Jaeger.
- **Partie 2 (SDK)** : écriture de `app/telemetry.py`. Le smoke test exécuté via `docker compose exec -T shop python -` produit un span dans Jaeger sous le service `smoke-test`. Les commandes applicatives fonctionnent sans émettre de traces.
- **Partie 3 (Spans dans shop)** : écriture de `app/shop_handler.py`. Les commandes génèrent des spans avec attributs HTTP et métier (`order.sku`, `order.qty`, `order.total`, `customer.id`, `enduser.id`). La commande `pizza` produit le statut d'erreur OTLP `code: 2`, et `mug` génère l'événement `stock.insufficient`.
- **Hachage OTTL** : ajout de `otelcol/anonymize.yaml` avec `Substring(SHA256(...), 0, 8)` sur `enduser.id`. Après recréation du **collector**, `enduser.id` vaut `2bd806c9` pour l'utilisateur `alice`, tandis que `customer.id` reste `alice`.
- **Partie 4 (Propagation)** :
  - Côté inventory (`app/inventory_handler.py`) : sans injection client, `shop` et `inventory` génèrent deux `traceId` distincts.
  - Côté shop (`app/inventory_client.py`) : l'appel `inject(headers)` insère l'en-tête W3C `traceparent`. La trace distribuée relie les deux services et totalise 4 spans (`POST /orders` -> `GET inventory` -> `GET /stock/{sku}` -> `load_stock`).
  - Test de panne (`docker compose stop inventory`) : la commande retourne 502, et le span client `GET inventory` passe en erreur avec l'événement `exception` capturé automatiquement par le bloc `with`.
- **Captures d'écran** : les trois captures d'écran réelles du lab ont été prises avec Playwright sur l'interface Jaeger (`img/lab07-jaeger-shop-attributes.png`, `img/lab07-jaeger-trace-complete.png`, `img/lab07-jaeger-panne-exception.png`).
- **Cleanup** : `docker compose down -v --rmi local` et suppression de `~/lab07`. Tous les ports sont vérifiés libres.

## Pièges constatés et corrections appliquées

- **Directive command manquante pour shop** : dans `compose.yaml`, le service `shop` ne définissait pas de commande, retombant sur le `CMD ["python3"]` du conteneur qui s'arrêtait immédiatement lors des redémarrages. La directive `command: ["python", "shop.py"]` a été ajoutée.
- **Suppression de Loki et Grafana** : simplification de la stack (`compose.yaml` et `otelcol/config.yaml`), suppression des références correspondantes dans le lab et dans le dossier de configuration.
- **Pédagogie Python renforcée** : ajout de commentaires pas-à-pas dans chaque bloc de code (`telemetry.py`, `shop_handler.py`, `inventory_handler.py`, `inventory_client.py`) et encarts explicatifs sur le gestionnaire de contexte `with`, l'extraction/injection W3C, et la manipulation des dictionnaires pour les participants non-développeurs.
