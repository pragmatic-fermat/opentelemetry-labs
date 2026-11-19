# TP4 - Corrigé

Fichiers de ce dossier : `playbook.yml` (le playbook complet à la fin de la partie 3) et `templates/config.yaml.j2` (le template de configuration). Pour les utiliser directement :

```bash
cp ~/opentelemetry-labs/tp04-ansible/solution/playbook.yml ~/tp04/
mkdir -p ~/tp04/templates
cp ~/opentelemetry-labs/tp04-ansible/solution/templates/config.yaml.j2 ~/tp04/templates/
```

## Partie 2 : installation

- Le handler est placé avant `tasks:` pour que le fichier puisse être complété en ajoutant des tâches à la fin. Ansible ne tient pas compte de l'ordre des clés d'un play.
- La somme de contrôle s'obtient par `otelcol_checksums[otelcol_arch_map[ansible_architecture]]` : le fait `ansible_architecture` (`x86_64` ou `aarch64`) donne la clé de `otelcol_arch_map`, qui donne celle de `otelcol_checksums`. Avec `checksum`, `get_url` refuse un fichier altéré, et au second lancement il ne retélécharge pas un fichier dont la somme est déjà correcte.
- Le module `apt` avec `deb` n'installe le paquet que s'il est absent ou dans une autre version : c'est ce qui rend la tâche idempotente.
- Le script `postinstall` du paquet active le service et le redémarre dès qu'un fichier `/etc/otelcol-contrib/config.yaml` existe. Juste après l'installation, le Collector tourne donc avec la configuration par défaut du paquet, qui écoute sur toutes les interfaces (OTLP sur 4317 et 4318, mais aussi pprof sur 1777 et zpages sur 55679). C'est un point de sécurité à commenter : cette configuration n'est pas faite pour être exposée.
- La tâche `Activer et démarrer le service` est utile surtout pour `enabled: true`. Le service est déjà démarré par le paquet, la tâche ne change donc rien au premier lancement sauf si l'activation a échoué.

## Partie 3 : template

Voir `templates/config.yaml.j2`.

- `{{ ansible_managed | comment }}` produit un en-tête de commentaire. Sa valeur par défaut est `Ansible managed`. Elle sert à prévenir qu'une modification manuelle sera écrasée au prochain déploiement.
- Le module `template` active `trim_blocks` : le saut de ligne qui suit `{% ... %}` est supprimé. Sans cela, chaque balise laisserait une ligne vide dans le fichier produit.
- Le filtre `to_json` écrit une chaîne entre guillemets doubles, ce qui est valide en YAML. Sans lui, une valeur comme `1` (le numéro `LAB_ID`) serait lue comme un entier par le Collector, alors qu'un attribut de ressource doit être une chaîne.
- Les blocs conditionnels sont répétés dans trois sections du fichier (receivers, exporters, pipelines) : si une seule manque, la configuration est invalide, car un composant déclaré sans pipeline est accepté mais un pipeline qui référence un composant absent est refusé.
- Le paramètre `validate` exécute `otelcol-contrib validate` sur un fichier temporaire avant de remplacer le fichier réel. Si la commande échoue, la tâche échoue et le service n'est pas touché.
- Les droits `root:otelcol-contrib` et `0640` permettent au service de lire sa configuration sans la rendre lisible par tous les utilisateurs.

## Partie 4 : modification par les variables

- La précédence des variables : `host_vars/<hôte>.yml` l'emporte sur `group_vars/all.yml`. Le template et le playbook restent identiques pour tous les serveurs, seules les variables par hôte les distinguent.
- `--check --diff` exécute les tâches en simulation et affiche, pour les fichiers modifiés par `template`, les différences. Rien n'est changé sur le serveur.
- Troisième exécution : `changed=0`, car le fichier rendu est identique au fichier déployé, et le handler `Redémarrer otelcol-contrib` n'est pas notifié. Un handler ne s'exécute que lorsqu'une tâche qui le notifie a changé quelque chose, et une seule fois, à la fin du play.
- Avec la valeur `"deux secondes"` pour `otelcol_batch_timeout`, la commande `validate` du Collector échoue (`invalid duration`). Le fichier du serveur n'est pas remplacé, et le service continue avec l'ancienne configuration.
