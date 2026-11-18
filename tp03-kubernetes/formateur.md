# TP3 - Notes pour le formateur

## Minutage indicatif

| Partie | Durée |
|---|---|
| 1. Préparer le cluster | 15 min |
| 2. Gateway | 30 min |
| 3. Agent | 25 min |
| 4. Operator et auto-instrumentation | 30 min |

Si le groupe est en retard, la partie 4 reste la plus démonstrative : conservez-lui au moins 30 minutes et abrégez la lecture du rendu `helm template` de la partie 2.

## Ce qui n'a pas été exécuté

Le TP a été rédigé sans cluster. Ont été contrôlés : la syntaxe des manifestes, `helm template` des deux charts avec les fichiers de valeurs du corrigé (le chart du Collector valide les valeurs contre son schéma), la conformité du manifeste `Instrumentation` au schéma du CRD de l'Operator 0.162.0, l'existence de chaque tag d'image dans son registre, et le code de l'application Node.js (exécuté localement avec deux processus). À vérifier sur un pod :

- l'appel à l'ingress par `localhost:8080` avec l'en-tête `Host` (fonctions de `helpers.sh`) et la réponse de l'API de Jaeger 2.23.0 sur `/api/services` et `/api/traces` ;
- le démarrage de l'Operator avec le certificat généré par le chart et l'enregistrement du webhook ;
- le nom du conteneur d'initialisation injecté (`opentelemetry-auto-instrumentation-nodejs`) ;
- le fonctionnement de l'image d'auto-instrumentation `0.82.0-1` avec Node.js 22.23.5 ;
- les attributs `k8s.*` effectivement présents sur les traces de l'agent (l'association se fait par l'adresse IP de la connexion) ;
- le comportement de `kubectl run --rm -i` avec l'image `telemetrygen`, qui est construite `FROM scratch` (pas de shell).

## Points d'attention

- Les valeurs du chart sont validées pour la version 0.179.1, dont l'image par défaut est la 0.163.2. Ne pas changer `image.tag` sans reprendre cette validation.
- Le chart de l'Operator contient deux pods de test avec l'image `busybox:latest` (hook Helm `test`). Ils ne sont pas déployés à l'installation : ne pas lancer `helm test`.
- L'agent n'est planifié que sur les nœuds qui acceptent ses pods. Le nœud control-plane de KinD porte une taint, donc le DaemonSet a un pod sur le worker uniquement. Les applications de démonstration tournent aussi sur le worker, ce qui est nécessaire avec `internalTrafficPolicy: Local` : un pod placé sur un nœud sans agent n'aurait aucune destination.
- Les types de composants ont été renommés : `otlp` est devenu `otlp_grpc` pour l'exporter et `k8sattributes` est devenu `k8s_attributes`. Les anciens noms restent des alias dépréciés, que les participants peuvent rencontrer dans d'anciennes configurations.
- Si une `Instrumentation` est créée après les pods, rien ne se passe : il faut redémarrer les pods (`kubectl -n demo rollout restart deployment/frontend`).
- Les ports 80 et 443 de la VM sont pris par le terminal web : les interfaces web passent par l'ingress du cluster sur le port 8080.
