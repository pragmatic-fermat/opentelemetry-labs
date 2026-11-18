# TP1 - Notes pour le formateur

## Minutage indicatif

| Partie | Durée |
|---|---|
| 1. Backends | 15 min |
| 2. Premier Collector | 30 min |
| 3. memory_limiter, resource, batch | 25 min |
| 4. filter | 20 min |
| 5. transform et OTTL | 25 min |
| 6. Métriques | 15 min |

Si le groupe est en retard, la partie 6 peut être donnée en démonstration.

## Ce qui n'a pas été exécuté

Le TP a été rédigé sans démarrer la stack. Les points suivants sont à vérifier lors d'une première passe sur un pod :

- la présence des chemins `/api/traces` de Jaeger 2.23.0, utilisés dans les commandes **Vérifier** (l'interface les utilise elle-même, mais ils ne sont pas documentés comme stables) ;
- le provisioning de la source de données Jaeger sur Grafana 13.3.1 ;
- le nombre exact de lignes `Span #` affiché par l'exporter `debug` (dix pour cinq traces de deux spans) ;
- le nom final de la métrique dans Prometheus, qui dépend de l'unité émise par `telemetrygen` ;
- le comportement des instructions OTTL de la partie 5 sur la version 0.165.0.

## Points d'attention

- Le tag de l'image du Collector est `0.165.0` mais celui de `telemetrygen` est `v0.165.0` (avec le `v`). C'est vérifié dans le registre ghcr.io.
- `telemetrygen` émet un débit de 1 span par seconde et par worker par défaut, et les spans enfants comptent aussi. Le script `tg.sh` impose `--rate 10` pour que les commandes restent rapides.
- Le filtrage supprime ici le span parent et le span enfant, car `telemetrygen` pose les attributs sur les deux. Sur une vraie application, supprimer seulement le span racine laisserait des spans enfants orphelins : c'est un bon point de discussion sur le filtrage par trace (échantillonnage par la queue) plutôt que par span.
- L'ordre des instructions de la partie 5 est le piège le plus fréquent : renommer avant de normaliser donne un nom avec l'identifiant brut.
- Le mot de passe Grafana par défaut est `formation`, et le port 3000 est ouvert sur Internet d'après les conventions. À changer via la variable `GRAFANA_ADMIN_PASSWORD` si l'environnement est exposé à des tiers.
- Jaeger stocke en mémoire (`max_traces` de 100 000 dans sa configuration par défaut) : un redémarrage du conteneur efface tout.

## Pour la discussion

- Dans le README du composant, `queuebatch` est présenté comme le remplaçant du processor `batch`. Les deux sont présents dans la distribution contrib 0.165.0 et `batch` reste en statut beta : ce TP garde `batch` parce qu'il est le plus répandu dans les configurations existantes.
- Les composants du Collector ont des noms de type et des noms d'instance (`otlp/jaeger`). La distinction revient dans les TP suivants.
