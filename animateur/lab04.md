# Lab 4 - Notes pour l'animateur

## Minutage indicatif

| Partie | Durée |
|---|---|
| 1. Préparer le poste de contrôle | 15 min |
| 2. Installer le collector | 30 min |
| 3. Template Jinja2 | 35 min |
| 4. Déploiements successifs | 35 min |

La partie 3 est la plus longue : le template contient une cinquantaine de lignes. L'énoncé le donne en entier, un participant en retard peut donc le recopier depuis le texte (il n'y a plus de dossier `solution/`) et passer le temps gagné sur la lecture du rendu et du diff.

### Partie 5, rejouée le 21 novembre 2026

Les trois machines éphémères ont été créées avec `animateur/scripts/lab04-vms-create.sh 1` puis détruites après le rejeu. Le script vérifie désormais que les trois droplets sont dans le VPC du groupe, par l'UUID du VPC et par le préfixe de leur adresse privée : c'est ce sous-réseau que la découverte des participants balaie.

- `ansible all -m ping` répond `SUCCESS` sur les quatre machines, et `setup` confirme Debian sur les trois éphémères ;
- le résumé du playbook donne `srv-0.monlab.top changed=2` (métriques réactivées en début de partie) et `changed=4` sur les trois éphémères ;
- les configurations sont bien distinctes : `timeout` à 2, 1, 5 et 10 s, `hostmetrics` présent partout sauf sur le frontend, et `deployment.environment.name` à `lab4`, `frontend`, `backend`, `database`.

Deux constats à retenir :

- les adresses privées changent d'une session à l'autre, et leur ordre ne suit pas celui des noms : trois créations successives ont donné `.4` à `.6`, puis `.7` à `.9`, puis `.10` à `.12`. Le lab ne peut donc pas les écrire en dur, et l'animateur n'a rien à transmettre. Le dossier fournit `discover-ephemere.sh`, que le participant lance sur `clt-N` : il balaie le sous-réseau privé sur le port SSH, reconnaît les machines à leur nom (`srv2-`, `srv3-`, `srv4-`) et écrit les trois alias dans `ephemeres.ini`. Comptez une dizaine de secondes, et jusqu'à une minute juste après la création : le script réessaie quatre fois, le temps que SSH réponde sur les machines neuves.
- avec l'export OTLP vers Prometheus, les attributs de ressource ne deviennent pas des labels par défaut : les quatre collectors produisaient une seule série `system_cpu_load_average_1m`, sans label. Le fichier `config/lab04/prometheus/prometheus.yml` porte maintenant un bloc `otlp.promote_resource_attributes`, et la requête s'appuie sur `host_name` et `deployment_environment_name`. Le lab 1 n'est pas concerné : il scrape l'exporter `prometheus` du collector, qui convertit les attributs de ressource en labels sans configuration.

## Rejeux du 21 et du 23 novembre 2026

Le lab a été rejoué intégralement le 23 novembre 2026 sur les machines reconstruites (`clt-0` et `srv-0`) :
- **Partie 1** : démarrage des backends Docker Jaeger (4317, 16686) et Prometheus (9090), génération d'inventaire, ping Ansible `SUCCESS`.
- **Partie 2** : installation du paquet `.deb` officiel de `otelcol-contrib` 0.165.0, validation de l'idempotence (`ok=4 changed=0` au second passage), ports OTLP et diagnostic actifs sur `srv-0`.
- **Partie 3** : template Jinja2, rendu local et validation Docker `code retour : 0`, déploiement de la configuration (`changed=2` avec handler), émission de 5 traces via `telemetrygen` reçues dans Jaeger (`ansible-demo`, 10 spans).
- **Partie 4** : activation de `hostmetrics` via `host_vars`, diff Ansible, collecte de 12 séries `system_cpu` dans Prometheus, passage sans changement (`changed=0`), retour en arrière avec diff inverse, correction automatique de dérive manuelle, rejet de durée invalide par `validate` (`failed=1`, service maintenu en fonctionnement).
- **Partie 5** : création des 3 machines éphémères Debian (`srv2-0`, `srv3-0`, `srv4-0`) dans le VPC DigitalOcean via `animateur/scripts/lab04-vms-create.sh 1`, découverte automatique par `discover-ephemere.sh`, déploiement simultané des 4 configurations différenciées (`changed=4` sur les 3 Debian, `changed=2` sur le serveur principal), vérification des séries Prometheus (`lab4`, `backend`, `database`), puis destruction via `animateur/scripts/lab04-vms-destroy.sh`.
- **Cleanup** : désinstallation d'`otelcol-contrib` via APT, suppression des backends Docker et des répertoires de travail. Machines remises à l'état initial.

La partie 4 réécrite avait également été déroulée le 21 novembre 2026 :

- ajout de `hostmetrics` : diff lu, application, `RUNNING HANDLER [Redémarrer otelcol-contrib]` visible, `grep -c hostmetrics` vaut 2, et Prometheus renvoie 12 séries `system_cpu` ;
- passage suivant : `changed=0`, sans redémarrage ;
- retour en arrière : diff de suppression, application, `grep -c` vaut 0 ;
- dérive : ligne ajoutée à la main sur `srv-0`, le `--check --diff` la montre retirée, le passage suivant la supprime et le fichier se termine de nouveau par `exporters: [otlp_grpc/jaeger]` ;
- changement refusé : `failed=1`, service `active`, `timeout: 2s` intact, puis correction et `changed=0` ;
- descente de version : `0.165.0` puis `0.164.0` après `allow_downgrade`, service actif, `dpkg-query` affiche `0.164.0`, et 5 traces arrivent encore dans Jaeger.

Pièges constatés pendant le rejeu :

- `ansible -a` utilise le module `command`, pas un shell : `|| true` est alors passé à `grep` comme un nom de fichier. Pour un opérateur shell, préciser `-m ansible.builtin.shell`. La commande de contrôle du retour en arrière est écrite ainsi.
- `ansible-playbook` lancé depuis un terminal sans `CLT_HOST` produit un endpoint `:4317` : le collector se contacte lui-même. Une remarque le signale dans la partie 3.
- Le dossier `host_vars/` doit exister : la partie 4 commence par `mkdir -p host_vars`.

## Ce qui a été testé à la rédaction

Avec ansible-core 2.22.0 et le binaire `otelcol-contrib` 0.165.0 (dont la somme sha256 a été comparée à celle de la page de publication) :

- la syntaxe du playbook (`ansible-playbook --syntax-check`) ;
- le rendu du template avec et sans `otelcol_hostmetrics_enabled` : 39 lignes sans, 51 avec, et dans les deux cas la commande `otelcol-contrib validate` accepte le résultat ;
- le rejet par `validate` d'une durée invalide (`deux secondes`, code de sortie 1) ;
- les chemins du paquet (`/usr/bin/otelcol-contrib`, `/etc/otelcol-contrib/config.yaml`, utilisateur `otelcol-contrib`, unité systemd) et le comportement du `postinstall`, lus dans le dépôt des publications à la version v0.165.0 ;
- l'option `--web.enable-otlp-receiver` de Prometheus v3.16.0, lue dans son code.

## Ce qui n'a pas été exécuté

Aucune tâche n'a été jouée contre un serveur. À vérifier sur un pod :

- le module `apt` avec `deb` sur Ubuntu 24.04 minimal (présence de `python3-apt`, installation automatique par Ansible sinon) ;
- l'écriture du fichier avec `validate` sous `become` (chemin temporaire, droits) ;
- le comportement de `--check --diff` avec `validate` et avec le handler ;
- le nom des métriques dans Prometheus (`system_cpu.*` attendu) et la réception OTLP sur `/api/v1/otlp/v1/metrics` ;
- l'accès réseau de `srv-N` vers les ports 4317 et 9090 de `clt-N` (ports ouverts d'après les conventions) ;
- la présence de `ss` sur `srv-N` pour la vérification de la partie 2 ;
- le résumé exact (`ok=5`, `changed=0`) du `PLAY RECAP`.

## Points d'attention

- Le piège de la chaîne `"false"` passée par `-e variable=false` a été constaté sur le rendu : la chaîne est vraie en Jinja2. Il est décrit dans le NB de la partie 4.
- La version et les sommes de contrôle sont liées : un participant qui change `otelcol_version` doit aussi changer les sommes.
- Prometheus et Jaeger de `clt-N` acceptent des données sans authentification sur des ports ouverts d'Internet (4317 et 9090), ce qui est acceptable pour un environnement pédagogique de courte durée mais pas au-delà.
- Le collector du paquet écoute par défaut sur toutes les interfaces, pprof et zpages compris (visible avec `ss` à la partie 2). La configuration du lab les supprime : bon moment pour discuter de la surface d'exposition d'un collector.
- Les types de composants du collector ont été renommés : l'exporter `otlp` est devenu `otlp_grpc` et `otlphttp` est devenu `otlp_http`. Le template utilise les noms actuels.
- Le processor `resourcedetection` (détecteur `system`) a été ajouté à la partie 3 : il pose `host.name` et `os.type` sur les données du collector, ce qui rend visible en partie 5 que le même template déploie des serveurs différents. La configuration rendue valide avec `otelcol-contrib validate` (0.165.0), mais le détecteur n'a pas été exécuté en conditions réelles : vérifier sur `srv-N` que `host.name` vaut bien le nom du serveur et non celui de `clt-N`.

## Machines éphémères additionnelles (multi-serveurs)

Pour illustrer le déploiement sur plusieurs cibles avec des configurations Jinja2 différenciées (`frontend`, `backend`, `database`), l'animateur dispose de deux scripts auto-portants dans `animateur/scripts/` :

1. **Avant la séance ou au début du lab 4** : lancer la création des machines éphémères en indiquant le nombre de groupes :
   ```bash
   ./animateur/scripts/lab04-vms-create.sh <nombre_de_groupes>
   ```
   Exemple pour 3 groupes (0, 1 et 2) : `./animateur/scripts/lab04-vms-create.sh 3` (par défaut : 1 groupe).
   Le script :
   - s'exécute avec le contexte `doctl` courant sans paramètre d'authentification ;
   - retrouve automatiquement l'ID de la clé SSH `otel-lab-ephemere` enregistrée dans DigitalOcean ;
   - crée trois machines Debian 13 par groupe (`srv2-N`, `srv3-N` et `srv4-N`) dans le VPC privé correspondant (`vpc-N`) ;
   - les machines reçoivent les adresses IP privées consécutives dans le sous-réseau `10.20.N.0/24` : `.4` pour `srv2-N`, `.5` pour `srv3-N` et `.6` pour `srv4-N` (ou suivantes selon l'état DHCP) ;
   - chaque groupe dispose alors de 4 machines à manager avec Ansible : le serveur principal `srv-N` sous Ubuntu (.3) et 3 serveurs éphémères sous Debian (.4, .5, .6) ;
   - `clt-N` s'y connecte de façon transparente via la clé SSH inter-machines du lab intégrée dans le cloud-init.

2. **À la fin du lab 4 ou de la séance** : supprimer toutes les machines éphémères en une seule commande :
   ```bash
   ./animateur/scripts/lab04-vms-destroy.sh
   ```
   Le script supprime toutes les droplets portant le tag `lab04-ephemere`.

## Rejeu du 24 novembre 2026, groupe 2 (clt-2 et srv-2)

Rejeu intégral sur un environnement neuf (`clt-2`, `srv-2` sous Ubuntu 24.04, trois serveurs Debian `srv2-2`, `srv3-2`, `srv4-2` dans `vpc-2`). Les parties 1 à 5 se déroulent comme prévu : inventaire, `ping`, première exécution en `changed=2` puis `changed=0`, rendu du template avec `endpoint: clt-2.monlab.top:4317`, cinq traces reçues avec `lab.id=2` et `host.name=srv-2`, activation des métriques en `changed=2`, dérive manuelle détectée puis corrigée, valeur `"deux secondes"` refusée par `validate`, découverte des trois Debian en onze secondes, quatre configurations déployées, séries Prometheus par serveur.

Écarts constatés et corrigés dans l'énoncé :

- après la correction de la dérive, le fichier se termine par `exporters: [otlp_http/prometheus]` et non par le pipeline `traces`, puisque les métriques système sont encore activées à ce stade ;
- après la suppression de la ligne `otelcol_batch_timeout` fautive, le playbook renvoie `changed=2` et non `changed=0` : la valeur `hostmetrics` repasse à `false`, la configuration change et le service redémarre ;
- la commande de contrôle du Cleanup utilisait `command -v` sans `-m ansible.builtin.shell` : Ansible échouait sur `No such file or directory: b'command'`. La partie 1 utilise déjà le module `shell`, le Cleanup est aligné ;
- le dossier `~/lab04` n'est pas réutilisé par le lab suivant, la phrase qui l'affirmait est retirée ;
- la sortie de la comparaison des quatre configurations est produite avec `-o`, qui remplace les retours à la ligne par `\n` : l'exemple est réécrit tel qu'il s'affiche.

Deux points d'exploitation pour l'animateur :

- **DNS interne en retard sur un environnement neuf.** Pendant une dizaine de minutes, `srv-2` et les serveurs Debian n'ont pas résolu `clt-2.monlab.top`, alors que les serveurs autoritaires de DigitalOcean et le résolveur public répondaient correctement : les résolveurs internes conservaient la réponse négative émise avant la création de l'enregistrement. Les exporters du **collector** échouaient sur `dial tcp: lookup clt-2.monlab.top: no such host`, donc plus aucune métrique ni trace. Contournement utilisé et documenté dans le lab : exporter `CLT_HOST` avec l'adresse privée de `clt-N` avant `ansible-playbook`.
- **Labels `job` et `instance`.** Ils n'apparaissent que si la ressource porte `service.name` et `service.instance.id`. Le template les pose désormais (`otelcol_environment` et `ansible_hostname`), ce qui rend l'écran du participant conforme à la capture du lab : `instance=srv2-2 job=backend`, `instance=srv4-2 job=database`, `instance=srv-2 job=lab4`.
