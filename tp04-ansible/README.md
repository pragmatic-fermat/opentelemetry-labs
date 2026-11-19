# TP4 - Ansible et Jinja2

Durée : environ 2 heures (1/4 de journée)

Machines : `clt-N` (poste de contrôle Ansible et backends) et `srv-N` (serveur cible), où N est votre numéro, disponible dans la variable `LAB_ID`

Dans ce TP, vous déployez le Collector OpenTelemetry sur un serveur Linux avec Ansible, sans Docker. Le fichier de configuration du Collector est produit par un template Jinja2 à partir de variables : vous le déployez, puis vous le modifiez en changeant seulement ces variables, comme on le ferait pour un parc de serveurs. Le Collector tourne sur `srv-N` et envoie ses données à Jaeger et à Prometheus, qui tournent sur `clt-N`.

## Objectifs

À la fin du TP, vous saurez :

- décrire un serveur dans un inventaire Ansible et vérifier la connexion avec un module ad hoc ;
- écrire un playbook idempotent qui installe le Collector à partir d'un paquet `.deb`, dont le téléchargement est vérifié par une somme de contrôle ;
- générer la configuration du Collector avec un template Jinja2 (variables, boucle, condition) ;
- modifier la configuration par les variables, la comparer avant déploiement avec `--check --diff`, et protéger le service d'une configuration invalide avec le paramètre `validate` ;
- vérifier que les traces et les métriques de `srv-N` arrivent dans Jaeger et dans Prometheus.

## Prérequis

Ansible, Docker et SSH sont installés sur `clt-N`. La clé SSH de l'utilisateur `stagiaire` permet de se connecter à `srv-N` sans mot de passe, et cet utilisateur dispose de `sudo` sans mot de passe sur `srv-N`. Les commandes utilisent les noms complets des modules (`ansible.builtin.…`), qui fonctionnent avec toutes les versions récentes d'Ansible.

Versions utilisées, vérifiées le 2026-11-18 :

| Composant | Version |
|---|---|
| OpenTelemetry Collector (paquet `otelcol-contrib`) | 0.165.0 |
| telemetrygen | v0.165.0 |
| Jaeger | 2.23.0 |
| Prometheus | v3.16.0 |

Les interfaces web sont accessibles depuis votre navigateur (remplacez `$CLT_HOST` par sa valeur, affichée par `echo $CLT_HOST`) : Jaeger sur `http://$CLT_HOST:16686` et Prometheus sur `http://$CLT_HOST:9090`.

## Partie 1 : préparer le poste de contrôle (15 min)

Copiez les fichiers de départ dans un dossier de travail, puis démarrez les deux backends sur `clt-N` :

```bash
mkdir -p ~/tp04
cp -r ~/opentelemetry-labs/tp04-ansible/files/. ~/tp04/
cd ~/tp04
docker compose up -d
```

Lisez `group_vars/all.yml` avec `cat`. Il contient les variables que vous utiliserez dans tout le TP : la version du Collector, les sommes de contrôle des paquets, l'adresse de `clt-N` (lue dans la variable d'environnement `CLT_HOST` de la machine qui lance Ansible) et des réglages du Collector. Le fichier `ansible.cfg` indique à Ansible où se trouve l'inventaire.

Créez l'inventaire. Cette fois, le mot `EOF` n'est pas entre guillemets : le shell remplace donc `$SRV_HOST` par sa valeur avant d'écrire le fichier. C'est ce que vous voulez ici, alors que dans les autres commandes du TP vous écrirez des `{{ ... }}` Jinja2 qui doivent rester tels quels.

```bash
cat > inventory.ini <<EOF
[otel]
$SRV_HOST
EOF
cat inventory.ini
```

**Vérifier**

```bash
ansible otel -m ansible.builtin.ping
ansible otel -m ansible.builtin.setup -a 'filter=ansible_distribution*'
ansible otel -m ansible.builtin.shell -a 'command -v otelcol-contrib || echo absent'
curl -s http://localhost:9090/-/ready
```

La première commande affiche `SUCCESS` et `"ping": "pong"`. La deuxième indique `"ansible_distribution": "Ubuntu"` et la version `24.04`. La troisième affiche `absent` : le Collector n'est pas encore installé. La dernière affiche `Prometheus Server is Ready.`.

## Partie 2 : installer le Collector (30 min)

Écrivez le playbook `playbook.yml`, qui s'exécute sur le groupe `otel` avec les droits administrateur (`become: true`). Il contient :

- un handler nommé `Redémarrer otelcol-contrib`, qui redémarre le service `otelcol-contrib` avec le module `ansible.builtin.systemd_service` ;
- trois tâches : télécharger le paquet avec `ansible.builtin.get_url`, l'installer avec `ansible.builtin.apt` (paramètre `deb`), puis activer et démarrer le service avec `ansible.builtin.systemd_service`.

Quelques précisions sur les tâches. Le téléchargement utilise la variable `otelcol_deb_url`, vers le fichier `/tmp/otelcol-contrib_<version>.deb`, avec le paramètre `checksum` : la somme attendue dépend de l'architecture du serveur. Le fait `ansible_architecture` vaut `x86_64` ou `aarch64`, et la variable `otelcol_arch_map` fait la correspondance avec les clés de `otelcol_checksums`. Les valeurs de ces variables s'écrivent entre `"{{ ... }}"`.

Placez le handler avant la liste `tasks:` et terminez le fichier par cette liste : le fichier sera complété à la partie suivante, en ajoutant des tâches à la fin. L'ordre des clés d'un play est sans importance pour Ansible.

```bash
cat > playbook.yml <<'EOF'
```

Lancez le playbook, puis relancez-le immédiatement :

```bash
ansible-playbook playbook.yml
ansible-playbook playbook.yml
```

Comparez le résumé (`PLAY RECAP`) des deux exécutions. Pourquoi le deuxième lancement ne modifie-t-il plus rien ? Chaque module compare l'état souhaité à l'état réel et n'agit que s'ils diffèrent : c'est ce qu'on appelle l'idempotence.

**Vérifier**

```bash
ansible otel -a '/usr/bin/otelcol-contrib --version'
ansible otel -a 'systemctl is-active otelcol-contrib'
ansible otel -m ansible.builtin.shell -a "ss -ltn | grep -E ':(4317|4318|1777|55679) '"
```

Les sorties sont `otelcol-contrib version 0.165.0`, `active`, puis plusieurs lignes d'écoute. Le paquet démarre le service avec sa propre configuration par défaut, qui ouvre notamment les ports 4317 et 4318 (OTLP), mais aussi 1777 et 55679 (pprof et zpages, des interfaces de diagnostic) sur toutes les interfaces. Vous allez la remplacer par une configuration que vous maîtrisez.

## Partie 3 : générer la configuration avec Jinja2 (35 min)

Jinja2 est le langage de template d'Ansible. Trois constructions suffisent pour ce TP :

| Syntaxe | Rôle |
|---|---|
| `{{ variable }}` | insère la valeur d'une variable ; on peut lui appliquer un filtre (`{{ valeur \| to_json }}`) |
| `{% if condition %} ... {% endif %}` | n'inclut le bloc que si la condition est vraie |
| `{% for cle, valeur in dictionnaire.items() %} ... {% endfor %}` | répète le bloc pour chaque entrée d'un dictionnaire |

Ansible supprime le saut de ligne qui suit une balise `{% ... %}` : les balises peuvent donc commencer en colonne 0 sans laisser de ligne vide dans le résultat.

Écrivez le template `templates/config.yaml.j2`. Il produit une configuration de Collector qui contient :

- une première ligne de commentaire `{{ ansible_managed | comment }}`, qui indique que le fichier est géré par Ansible ;
- un receiver `otlp` (gRPC et HTTP) qui écoute sur toutes les interfaces, ports 4317 et 4318 ;
- si la variable `otelcol_hostmetrics_enabled` est vraie, un receiver `hostmetrics` avec `collection_interval: 30s` et les scrapers `cpu`, `load` et `memory` (écrits `cpu: {}`, etc.) ;
- les processors `memory_limiter` (1 s, 256 MiB, marge de 64 MiB), `resource` et `batch`. Le processor `resource` reçoit, par une boucle sur le dictionnaire `otelcol_resource_attributes`, une entrée `upsert` par attribut (clé `key`, valeur `value` écrite avec le filtre `to_json`, qui ajoute les guillemets nécessaires à une chaîne YAML). Le `batch` utilise la valeur de `otelcol_batch_timeout` ;
- l'exporter `otlp_grpc/jaeger`, vers `otelcol_backend_host` sur le port 4317 sans TLS ;
- si `otelcol_hostmetrics_enabled` est vraie, un exporter `otlp_http/prometheus` dont le paramètre `metrics_endpoint` vaut `http://<otelcol_backend_host>:9090/api/v1/otlp/v1/metrics` ;
- un pipeline `traces` (receiver `otlp`, processors `memory_limiter`, `resource` puis `batch`, exporter `otlp_grpc/jaeger`) et, si `otelcol_hostmetrics_enabled` est vraie, un pipeline `metrics` (receiver `hostmetrics`, mêmes processors, exporter `otlp_http/prometheus`).

La structure reprend celle des TP précédents. Seules changent les valeurs, qui viennent désormais des variables, et les blocs conditionnels.

```bash
mkdir -p templates
cat > templates/config.yaml.j2 <<'EOF'
```

Avant de déployer, produisez le rendu en local et vérifiez-le avec la commande `validate` du Collector, lancée dans un conteneur :

```bash
ansible localhost -m ansible.builtin.template \
  -a "src=templates/config.yaml.j2 dest=/tmp/config-preview.yaml" -e @group_vars/all.yml
cat /tmp/config-preview.yaml
docker run --rm -v /tmp/config-preview.yaml:/config.yaml:ro \
  ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.165.0 \
  validate --config=/config.yaml
```

Le fichier affiché ne contient aucune accolade Jinja2 et la commande `validate` ne renvoie rien. Avec la valeur par défaut `otelcol_hostmetrics_enabled: false`, le rendu ne contient aucune mention de `hostmetrics`.

Complétez maintenant le playbook avec une dernière tâche, ajoutée à la fin du fichier. Elle utilise le module `ansible.builtin.template` avec les paramètres suivants :

- `src` : `config.yaml.j2` et `dest` : `/etc/otelcol-contrib/config.yaml` ;
- `owner` : `root`, `group` : `otelcol-contrib` et `mode` : `"0640"` : le service tourne sous l'utilisateur `otelcol-contrib`, qui doit pouvoir lire le fichier, et personne d'autre ne doit pouvoir l'écrire ;
- `validate` : `/usr/bin/otelcol-contrib validate --config=%s` : Ansible écrit d'abord le résultat dans un fichier temporaire, lance cette commande dessus (`%s` est remplacé par le chemin du fichier temporaire) et ne remplace le fichier réel que si elle réussit ;
- `notify` : le nom du handler, pour que le service redémarre uniquement quand le fichier change.

Nommez la tâche `Déployer la configuration`. Elle doit être indentée comme les autres tâches de la liste.

```bash
cat >> playbook.yml <<'EOF'
```

Déployez, puis envoyez cinq traces à travers le Collector de `srv-N`, avec `telemetrygen` lancé depuis `clt-N` :

```bash
ansible-playbook playbook.yml
docker run --rm ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 \
  traces --otlp-endpoint $SRV_HOST:4317 --otlp-insecure --rate 10 --traces 5 --service ansible-demo
```

**Vérifier**

Dans le résumé du playbook, la tâche `Déployer la configuration` est en `changed` et le handler s'est exécuté. Le fichier déployé porte l'en-tête de gestion Ansible :

```bash
ansible otel -a 'head -n 3 /etc/otelcol-contrib/config.yaml'
curl -s 'http://localhost:16686/api/traces?service=ansible-demo&limit=20' | jq '.data | length'
curl -s 'http://localhost:16686/api/traces?service=ansible-demo&limit=1' \
  | jq -r '.data[0].processes[].tags[] | select(.key=="lab.id" or .key=="deployment.environment.name") | "\(.key)=\(.value)"'
```

La première commande affiche des lignes de commentaire dont `Ansible managed`. La deuxième affiche `5`. La troisième affiche `deployment.environment.name=tp4` et `lab.id=` suivi de votre numéro : ils viennent de la boucle du template.

## Partie 4 : modifier la configuration (25 min)

Vous allez activer la collecte des métriques du serveur sans modifier ni le playbook, ni le template : seules les variables changent. Une variable définie pour un hôte précis, dans `host_vars/<nom de l'hôte>.yml`, l'emporte sur celle de `group_vars/all.yml`.

```bash
mkdir -p host_vars
cat > host_vars/$SRV_HOST.yml <<'EOF'
otelcol_hostmetrics_enabled: true
EOF
```

Regardez d'abord ce que ce changement ferait, sans l'appliquer :

```bash
ansible-playbook playbook.yml --check --diff
```

Le diff montre les lignes que le template ajouterait au fichier de configuration du serveur : le receiver `hostmetrics`, l'exporter `otlp_http/prometheus` et le pipeline `metrics`. Appliquez le changement, puis attendez une minute le temps d'une collecte :

```bash
ansible-playbook playbook.yml
sleep 60
curl -s http://localhost:9090/api/v1/query --data-urlencode 'query=count({__name__=~"system_cpu.*"})' \
  | jq -r '.data.result[0].value[1]'
```

La commande affiche un nombre supérieur à 0 : Prometheus a reçu les métriques de `srv-N`. Le nom exact des métriques dépend de la conversion appliquée par Prometheus, d'où l'expression régulière.

Relancez le playbook une troisième fois, et lisez le résumé :

```bash
ansible-playbook playbook.yml | grep -A2 'PLAY RECAP'
```

Rien n'a changé (`changed=0`) et le handler n'a pas redémarré le service : un redémarrage inutile aurait coupé le Collector sans raison.

Simulez enfin une erreur de saisie. La valeur de `otelcol_batch_timeout` est invalide, et le paramètre `validate` doit empêcher son déploiement :

```bash
cat > host_vars/$SRV_HOST.yml <<'EOF'
otelcol_hostmetrics_enabled: true
otelcol_batch_timeout: "deux secondes"
EOF
ansible-playbook playbook.yml
```

**Vérifier**

Le playbook échoue sur la tâche `Déployer la configuration`, avec un message du Collector qui cite `timeout` et une durée invalide. Le serveur n'a pas été touché : le service tourne toujours avec la dernière configuration valide.

```bash
ansible otel -a 'systemctl is-active otelcol-contrib'
ansible otel -a 'grep -n timeout /etc/otelcol-contrib/config.yaml'
```

Les commandes affichent `active` et une ligne `timeout: 2s`. Corrigez l'erreur en supprimant la ligne fautive, puis relancez :

```bash
sed -i '/otelcol_batch_timeout/d' host_vars/$SRV_HOST.yml
ansible-playbook playbook.yml | grep -A2 'PLAY RECAP'
```

Le résumé indique `failed=0` et `changed=0` : le fichier déployé correspond déjà au résultat du template.

## Dépannage

**`UNREACHABLE` : Ansible ne peut pas joindre le serveur.** Affichez `cat inventory.ini` : le nom du serveur doit apparaître sous `[otel]`. S'il est vide, la variable `SRV_HOST` n'est pas définie dans votre terminal. Testez ensuite la connexion avec `ssh $SRV_HOST hostname`.

**`Could not import the apt python module` ou verrou apt.** Un processus apt est en cours sur le serveur, ou le module Python d'apt est absent. Attendez une minute et relancez : Ansible installe lui-même le module manquant. Si le problème persiste, lisez le message complet de la tâche.

**`TemplateSyntaxError` à l'écriture du template.** Le message donne un numéro de ligne. Cherchez une balise `{% if %}` sans `{% endif %}`, ou un `{% for %}` sans `{% endfor %}`. Le rendu local de la partie 3 détecte ces erreurs avant le déploiement.

**La variable booléenne est ignorée quand elle est passée avec `-e`.** `-e otelcol_hostmetrics_enabled=false` envoie la chaîne `false`, que Jinja2 considère comme vraie. Pour passer un booléen, utilisez la forme JSON : `-e '{"otelcol_hostmetrics_enabled": false}'`, ou écrivez la variable dans un fichier YAML.

**`checksum` invalide au téléchargement.** Si vous avez changé `otelcol_version`, mettez aussi à jour les sommes de contrôle dans `group_vars/all.yml`. Elles figurent sur la page de publication du Collector.

**Le service ne démarre pas après le déploiement.** Lisez son journal : `ansible otel -b -a 'journalctl -u otelcol-contrib -n 20 --no-pager'`.

**Vous êtes bloqué sur un fichier.** Le dossier `solution/` du dépôt contient le playbook et le template complets. Copiez-les, par exemple `cp ~/opentelemetry-labs/tp04-ansible/solution/playbook.yml ~/tp04/` et `mkdir -p ~/tp04/templates && cp ~/opentelemetry-labs/tp04-ansible/solution/templates/config.yaml.j2 ~/tp04/templates/`.

## Pour aller plus loin

- Transformez le playbook en rôle (`ansible-galaxy role init otelcol`) : les tâches, le handler, le template et les variables par défaut s'y rangent chacun dans leur dossier.
- Ajoutez au template un receiver `filelog` sur `/var/log/syslog` et un pipeline de logs vers l'exporter de votre choix. Pensez aux droits de lecture de l'utilisateur `otelcol-contrib`.
- Ajoutez le paramètre `backup: true` à la tâche de configuration et observez les copies conservées sur le serveur à chaque modification.
- Déclarez un deuxième serveur dans l'inventaire (même fictif) et utilisez `host_vars` pour lui donner un `otelcol_environment` différent.
