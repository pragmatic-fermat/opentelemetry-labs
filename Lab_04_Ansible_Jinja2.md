# Lab 4 : Déploiement et gestion de la configuration du **collector** via Ansible et Jinja2

# Objectifs

À la fin du lab, vous saurez :

- décrire des serveurs dans un inventaire Ansible et vérifier la connexion avec un module ad hoc ;
- écrire un playbook idempotent qui installe le **collector** à partir d'un paquet `.deb`, dont le téléchargement est vérifié par une somme de contrôle ;
- générer la configuration du **collector** avec un template Jinja2 (variables, boucle, condition) ;
- déployer des configurations **différentes** sur plusieurs serveurs à partir d'un seul playbook et de variables par hôte ;
- vérifier que les traces et les métriques des serveurs arrivent dans Jaeger et dans Prometheus.

# Contenu

- [Environnement](#environnement)
- [1. Préparer le poste de contrôle](#1-préparer-le-poste-de-contrôle)
- [2. Installer le **collector**](#2-installer-le-collector)
- [3. Générer la configuration avec Jinja2](#3-générer-la-configuration-avec-jinja2)
- [4. Déploiements successifs](#4-déploiements-successifs)
- [5. Étendre le parc : 4 serveurs, 4 configurations](#5-étendre-le-parc--4-serveurs-4-configurations)
- [Cleanup](#cleanup)
- [Extra](#extra)

# Détail

## Environnement

Ce lab se déroule sur plusieurs machines : `clt-N`, la machine cliente qui porte Ansible et les backends, `srv-N`, la machine serveur Ubuntu où le **collector** est installé, et, à partir de la partie 5, trois serveurs éphémères Debian `srv2-N`, `srv3-N` et `srv4-N` provisionnés par l'animateur (N est votre numéro de participant).

Vous travaillez depuis le terminal web de `clt-N`, dans `/root`, où le dépôt des labs est déjà cloné dans `/root/opentelemetry-labs`. Sauf mention contraire, toutes les commandes du lab se lancent sur `clt-N` : celles qui visent les serveurs passent par Ansible, qui s'y connecte en SSH.

Ansible, Docker et SSH sont installés sur `clt-N`. La clé SSH de `root` permet de se joindre à `srv-N` sans mot de passe, et le compte dispose de `sudo` sans mot de passe sur cette machine.

Le [lab 1](Lab_01_Socle.md) est conseillé : il présente les **receiver**, **processor** et **exporter** du **collector**, qui ne sont pas réexpliqués ici. Les commandes utilisent les noms complets des modules (`ansible.builtin.…`), qui fonctionnent avec toutes les versions récentes d'Ansible.

Versions utilisées dans ce lab :

| Composant | Version |
|---|---|
| **collector** OpenTelemetry (paquet `otelcol-contrib`) | 0.165.0 |
| telemetrygen | v0.165.0 |
| Jaeger | 2.23.0 |
| Prometheus | v3.16.0 |
| OS serveur principal | Ubuntu 24.04 |
| OS serveurs éphémères | Debian 13 |

Les interfaces web sont accessibles depuis votre navigateur, sur `clt-N` (`$CLT_HOST`) : Jaeger sur `http://$CLT_HOST:16686` (TCP/16686) et Prometheus sur `http://$CLT_HOST:9090` (TCP/9090).

## 1. Préparer le poste de contrôle

Deux machines entrent en jeu, et il faut savoir où se trouve quoi avant de taper la première commande. Le schéma suivant les montre, avec les deux moteurs logiciels : le moteur Ansible, installé sur `clt-N`, qui exécute les playbooks, et le moteur Docker, qui héberge les backends sur `clt-N`.

```mermaid
---
title: lab 4, où se trouve chaque composant
---
flowchart LR
  subgraph CLT["Machine cliente clt-N"]
    direction TB
    AN["Ansible, moteur d'exécution<br/>nœud de contrôle : inventaire,<br/>playbook, template"]
    DK["Docker, moteur"]
    J[("Jaeger<br/>TCP/16686 et 4317")]
    P[("Prometheus<br/>TCP/9090")]
    DK --- J
    DK --- P
  end

  subgraph SRV["Machine serveur srv-N"]
    direction TB
    SY["systemd<br/>service otelcol-contrib"]
    CO["collector<br/>config générée par Jinja2<br/>OTLP 4317 et 4318"]
    SY --- CO
  end

  AN ==>|SSH, become| SY
  CO ==> J
  CO ==> P
```

Trois points à retenir de ce schéma :

- **le moteur Ansible ne tourne que sur `clt-N`** : c'est le nœud de contrôle. Il se connecte en SSH à `srv-N` et y exécute les tâches ; aucun playbook n'est lancé sur le serveur, et `srv-N` n'a pas besoin d'Ansible ;
- **le collector tourne sur `srv-N`**, comme service `otelcol-contrib` géré par systemd. C'est la seule machine qui reçoit le paquet `.deb` et la configuration générée ;
- **les backends tournent sur `clt-N`**, dans Docker : Jaeger écoute sur `TCP/16686` (interface web) et `TCP/4317` (OTLP des traces), Prometheus sur `TCP/9090`. Le collector de `srv-N` leur envoie ses données par le réseau privé du VPC.

Copiez les fichiers fournis dans un dossier de travail, puis démarrez les deux backends sur `clt-N` :

```bash
mkdir -p ~/lab04
```

```bash
cp -r ~/opentelemetry-labs/config/lab04/. ~/lab04/
```

```bash
cd ~/lab04
```

```bash
docker compose up -d
```

Lisez les fichiers de configuration fournis :

```bash
cat group_vars/all.yml
```

```bash
cat ansible.cfg
```

`group_vars/all.yml` contient les variables utilisées dans tout le lab : la version du **collector**, les sommes de contrôle des paquets, l'adresse de `clt-N` (lue dans la variable d'environnement `CLT_HOST` de la machine qui lance Ansible) et les réglages du **collector**.

`ansible.cfg` indique à Ansible où se trouve l'inventaire, et désactive la vérification des clés d'hôte (`host_key_checking = False`), adaptée à un environnement de lab.

Créez l'inventaire. Cette fois, le mot `EOF` n'est pas entre guillemets : le shell remplace donc `$SRV_HOST` par sa valeur avant d'écrire le fichier. C'est ce que vous voulez ici, alors que dans les autres commandes du lab vous écrirez des `{{ ... }}` Jinja2 qui doivent rester tels quels.

Le groupe s'appelle `[otel]` : c'est une convention courante pour désigner les machines qui reçoivent le **collector** OpenTelemetry. La commande `ansible otel ...` cible donc tous les hôtes de ce groupe.

```bash
cat > inventory.ini <<EOF
[otel]
$SRV_HOST
EOF
```

```bash
cat inventory.ini
```

Contrôlez la connexion et l'état du serveur :

```bash
ansible otel -m ansible.builtin.ping
```

```bash
ansible otel -m ansible.builtin.setup -a 'filter=ansible_distribution*'
```

```bash
ansible otel -m ansible.builtin.shell -a 'command -v otelcol-contrib || echo absent'
```

```bash
curl -s http://localhost:9090/-/ready
```

La première commande affiche `SUCCESS` et `"ping": "pong"` :

```json
srv-0.monlab.top | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

La deuxième indique `"ansible_distribution": "Ubuntu"` et la version `24.04`. La troisième affiche `absent` : le **collector** n'est pas encore installé. La dernière affiche `Prometheus Server is Ready.`.

Si votre animateur a provisionné des machines éphémères pour votre groupe (voir [la partie 5](#5-étendre-le-parc--4-serveurs-4-configurations)), elles ne sont pas encore déclarées dans l'inventaire : vous les ajouterez à ce moment-là.

## 2. Installer le **collector**

Toutes les commandes de cette partie se lancent dans le terminal de `clt-N`, dans `~/lab04`. Les commandes `ansible` et `ansible-playbook` agissent ensuite sur `srv-N` par SSH : c'est là que le paquet est téléchargé, installé, et que le service démarre. Rien n'est tapé sur `srv-N`, qui n'a ni Ansible ni le dépôt des labs.

Le schéma suivant résume l'enchaînement des trois tâches du playbook :

```mermaid
---
title: Installation du collector sur srv-N pilotee par Ansible
---
flowchart LR
  subgraph CLT["clt-N (noeud de controle)"]
    PB["playbook.yml<br/>group_vars/all.yml"]
  end

  GH[("GitHub Releases<br/>otelcol-contrib .deb")]

  subgraph SRV["srv-N (serveur cible)"]
    direction TB
    T1["1. get_url<br/>telechargement + verification SHA256"]
    T2["2. apt (deb)<br/>installation du paquet .deb"]
    T3["3. systemd_service<br/>activation et demarrage"]
    T1 --> T2 --> T3
  end

  PB -->|"SSH (become)"| T1
  GH -.->|"paquet .deb"| T1

  classDef ctrl fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
  classDef task fill:#fef3c7,stroke:#b45309,color:#78350f
  classDef ext fill:#f1f5f9,stroke:#475569,color:#0f172a

  class PB ctrl
  class T1,T2,T3 task
  class GH ext
```

Écrivez le playbook `playbook.yml`, qui s'exécute sur le groupe `otel` avec les droits administrateur (`become: true`).

Il contient un handler nommé `Redémarrer otelcol-contrib`, qui redémarre le service avec le module `ansible.builtin.systemd_service`, puis trois tâches : télécharger le paquet avec `ansible.builtin.get_url`, l'installer avec `ansible.builtin.apt` (paramètre `deb`), et activer puis démarrer le service avec `ansible.builtin.systemd_service`.

Quelques précisions sur le téléchargement. Il utilise la variable `otelcol_deb_url`, vers le fichier `/tmp/otelcol-contrib_<version>.deb`, avec le paramètre `checksum` : la somme attendue dépend de l'architecture du serveur. Le fait `ansible_architecture` vaut `x86_64` ou `aarch64`, et la variable `otelcol_arch_map` fait la correspondance avec les clés de `otelcol_checksums`.

> [!NOTE]
>
> D'où vient le paquet ? L'URL est déjà assemblée dans `group_vars/all.yml` (ne la recopiez pas) via la variable `otelcol_deb_url`, qui construit le lien GitHub Releases à partir de `otelcol_version` et de `otelcol_arch_map[ansible_architecture]` (par exemple `otelcol-contrib_0.165.0_linux_amd64.deb`). Elle pointe vers les publications GitHub du projet, canal officiel du **collector**. Il n'existe pas encore de dépôt APT officiel pour le **collector** : le projet y travaille, mais à ce jour les paquets ne vivent que sur GitHub Releases.

Ansible évalue cette URL au moment de la tâche, sur chaque cible, en y insérant la version et l'architecture lues dans les facts du serveur : chaque hôte télécharge donc son propre paquet, dans son propre `/tmp`. Ce choix a deux conséquences que le playbook compense :

- un fichier téléchargé hors dépôt n'a pas la chaîne de confiance d'un dépôt signé : le paramètre `checksum` la remplace, en comparant le SHA256 du fichier à la somme épinglée dans `group_vars/all.yml` ;
- le module `apt` est utilisé en mode fichier local (paramètre `deb`) : le paquet est quand même enregistré dans `dpkg`, avec ses dépendances, ce qui rend la désinstallation propre du [Cleanup](#cleanup) possible.

En production, on remplace souvent ce téléchargement par cible par un miroir unique (dépôt APT interne, Nexus, Artifactory) : le fichier est téléchargé une fois puis distribué, et les serveurs cloisonnés n'ont plus besoin d'accéder à Internet.

Le handler se place avant la liste `tasks:`, et le fichier sera complété à la partie 3 en ajoutant une tâche à la fin. L'ordre des clés d'un play est sans importance pour Ansible.

```bash
cat > playbook.yml <<'EOF'
- name: Déployer le collector OpenTelemetry
  hosts: otel
  become: true
  handlers:
    - name: Redémarrer otelcol-contrib
      ansible.builtin.systemd_service:
        name: otelcol-contrib
        state: restarted
  tasks:
    - name: Télécharger le paquet du collector
      ansible.builtin.get_url:
        url: "{{ otelcol_deb_url }}"
        dest: "/tmp/otelcol-contrib_{{ otelcol_version }}.deb"
        checksum: "{{ otelcol_checksums[otelcol_arch_map[ansible_architecture]] }}"
        mode: "0644"
    - name: Installer le paquet
      ansible.builtin.apt:
        deb: "/tmp/otelcol-contrib_{{ otelcol_version }}.deb"
        state: present
    - name: Activer et démarrer le service
      ansible.builtin.systemd_service:
        name: otelcol-contrib
        state: started
        enabled: true
EOF
```

Lancez le playbook, puis relancez-le immédiatement :

```bash
ansible-playbook playbook.yml
```

```bash
ansible-playbook playbook.yml
```

Comparez le résumé (`PLAY RECAP`) des deux exécutions. Le premier lancement modifie deux choses, le téléchargement et l'installation :

```text
PLAY RECAP *********************************************************************
srv-N.monlab.top           : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Le second lancement ne modifie plus rien que l'état du service, qui a été redémarré par le paquet lors de l'installation (`changed=1`) : chaque module compare l'état souhaité à l'état réel et n'agit que s'ils diffèrent. C'est l'idempotence.

Contrôlez ce qui est installé et ce qui écoute :

```bash
ansible otel -a '/usr/bin/otelcol-contrib --version'
```

```bash
ansible otel -a 'systemctl is-active otelcol-contrib'
```

```bash
ansible otel -m ansible.builtin.shell -a "ss -ltn | grep -E ':(4317|4318|1777|55679) '"
```

On obtient `otelcol-contrib version 0.165.0`, puis `active`, puis plusieurs lignes d'écoute :

```text
LISTEN 0      4096               *:1777             *:*
LISTEN 0      4096               *:4318             *:*
LISTEN 0      4096               *:4317             *:*
LISTEN 0      4096               *:55679            *:*
```

Le paquet démarre le service avec sa propre configuration par défaut, qui ouvre les ports 4317 et 4318 (OTLP) mais aussi 1777 et 55679 (pprof et zpages, des interfaces de diagnostic) sur toutes les interfaces. Vous allez la remplacer par une configuration que vous maîtrisez.

## 3. Générer la configuration avec Jinja2

Le schéma suivant montre le parcours de la configuration (génération par Ansible, validation puis déploiement sur `srv-N`) et celui des traces de test (émises par `telemetrygen` depuis `clt-N` vers le **collector** de `srv-N`, puis renvoyées vers Jaeger sur `clt-N`) :

```mermaid
---
title: Generation Jinja2, deploiement et flux des traces de test
---
flowchart LR
  subgraph CLT["clt-N"]
    direction TB
    TPL["templates/config.yaml.j2<br/>+ group_vars/all.yml"]
    TG["telemetrygen<br/>(--service ansible-demo)"]
    JG[("Jaeger<br/>TCP/4317 et 16686")]
  end

  subgraph SRV["srv-N"]
    direction TB
    VAL["validate --config=%s"]
    CFG["/etc/otelcol-contrib/config.yaml"]
    COL["collector<br/>(otelcol-contrib:4317)"]
    VAL -->|valide| CFG
    CFG -->|restart| COL
  end

  TPL -->|"Ansible template"| VAL
  TG -->|"OTLP gRPC :4317"| COL
  COL -->|"OTLP gRPC :4317"| JG

  classDef ctrl fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
  classDef col fill:#fef3c7,stroke:#b45309,color:#78350f
  classDef back fill:#ede9fe,stroke:#6d28d9,color:#4c1d95

  class TPL,TG ctrl
  class VAL,CFG,COL col
  class JG back
```

Jinja2 est le langage de template d'Ansible. Trois constructions suffisent pour ce lab :

| Syntaxe | Rôle |
|---|---|
| `{{ variable }}` | insère la valeur d'une variable ; on peut lui appliquer un filtre (`{{ valeur \| to_json }}`) |
| `{% if condition %} ... {% endif %}` | n'inclut le bloc que si la condition est vraie |
| `{% for cle, valeur in dictionnaire.items() %} ... {% endfor %}` | répète le bloc pour chaque entrée d'un dictionnaire |

Ansible supprime le saut de ligne qui suit une balise `{% ... %}` : les balises peuvent donc commencer en colonne 0 sans laisser de ligne vide dans le résultat.

Le template produit une configuration de **collector** qui contient :

- une première ligne de commentaire `{{ ansible_managed | comment }}`, qui indique que le fichier est géré par Ansible ;
- un receiver `otlp` (gRPC et HTTP) qui écoute sur toutes les interfaces, ports 4317 et 4318 ;
- si la variable `otelcol_hostmetrics_enabled` est vraie, un receiver `hostmetrics` avec `collection_interval: 30s` et les scrapers `cpu`, `load` et `memory` (écrits `cpu: {}`, etc.) ;
- les processors `memory_limiter` (1 s, 256 MiB, marge de 64 MiB), `resourcedetection`, `resource` et `batch`. Le processor `resourcedetection` interroge la machine elle-même (détecteur `system` : nom d'hôte, système, identifiant machine) et complète la ressource avec ce qu'il trouve. Le processor `resource` reçoit, par une boucle sur le dictionnaire `otelcol_resource_attributes`, une entrée `upsert` par attribut (clé `key`, valeur écrite avec le filtre `to_json`, qui ajoute les guillemets nécessaires à une chaîne YAML), suivie de `service.name` et `service.instance.id` avec `action: insert`. L'action `insert` est essentielle : elle ajoute la clé uniquement si elle est absente. Ainsi, elle ne remplace pas le `service.name` déjà posé par une application ou par `telemetrygen` (`ansible-demo`), mais elle renseigne `service.name` et `service.instance.id` sur les métriques `hostmetrics` qui n'en ont pas (afin d'alimenter les labels `job` et `instance` dans Prometheus). Le processor `batch` regroupe les données avant envoi ; sa valeur `timeout` (2 s par défaut) est fournie par la variable `otelcol_batch_timeout` ;
- l'exporter `otlp_grpc/jaeger`, vers `otelcol_backend_host` sur le port 4317 sans TLS ;
- si `otelcol_hostmetrics_enabled` est vraie, un exporter `otlp_http/prometheus` dont le paramètre `metrics_endpoint` vaut `http://<otelcol_backend_host>:9090/api/v1/otlp/v1/metrics` ;
- un pipeline `traces` (receiver `otlp`, processors `memory_limiter`, `resourcedetection`, `resource` puis `batch`, exporter `otlp_grpc/jaeger`) et, si `otelcol_hostmetrics_enabled` est vraie, un pipeline `metrics` (receiver `hostmetrics`, mêmes processors, exporter `otlp_http/prometheus`).

La structure reprend celle des labs précédents. Seules changent les valeurs, qui viennent désormais des variables, et les blocs conditionnels.

Le processor `resourcedetection` mérite un mot avant d'écrire le template. Deux façons de renseigner la ressource se complètent ici :

- `resource` pose ce que vous décidez : `deployment.environment.name`, `lab.id`, un attribut de parc commun à tous les serveurs ;
- `resourcedetection` lit ce que la machine sait d'elle-même : son nom, son système, son identifiant. Rien à déclarer, et chaque serveur reçoit sa propre valeur.

C'est ce qui rendra la partie 5 lisible : le même template déployé sur quatre serveurs produira quatre `host.name` différents, sans une variable de plus. Le réglage `override: false` laisse la priorité aux attributs déjà posés, par `resource` ou par l'application : la détection complète la ressource, elle ne l'écrase pas. Le détecteur `env` existe aussi et lit `OTEL_RESOURCE_ATTRIBUTES` dans l'environnement du service ; il n'est pas utilisé ici, pour ne pas multiplier les mécanismes dans ce lab.

Dans le processor `resource`, le choix entre `upsert` et `insert` répond à deux comportements distincts :

- **`action: upsert`** insère l'attribut s'il est absent, et **écrase** sa valeur s'il existe déjà. Il sert aux attributs imposés par la plateforme (`deployment.environment.name`, `lab.id`), qui doivent rester uniformes quel que soit l'émetteur.
- **`action: insert`** insère l'attribut uniquement s'il est absent, et **ne modifie pas** une valeur déjà présente. Il est indispensable ici pour `service.name` et `service.instance.id` : les traces émises par `telemetrygen` (ou par une application) portent déjà leur propre `service.name` (`ansible-demo`), qu'un `upsert` écraserait par `lab4`, alors que les métriques système de `hostmetrics` n'en ont pas et reçoivent donc `service.name=lab4` et `service.instance.id=srv-N`.

> [!NOTE]
>
> `otelcol_backend_host` est lue dans l'environnement du terminal qui lance `ansible-playbook`, par `lookup('ansible.builtin.env', 'CLT_HOST')`. Si `CLT_HOST` est vide, l'endpoint de l'exporter devient `:4317` et le **collector** tente de joindre sa propre machine : les traces n'arrivent pas dans Jaeger, et les logs du service citent `127.0.0.1:4317`. Contrôlez `echo $CLT_HOST` avant de lancer le playbook ; s'il est vide, ouvrez un nouveau terminal web, où la variable est définie.

> [!NOTE]
>
> Sur un environnement fraîchement créé, il arrive que `srv-N` ne résolve pas encore le nom de `clt-N` : les résolveurs internes du fournisseur gardent quelques minutes une réponse négative émise avant la création de l'enregistrement DNS. Les logs du **collector** citent alors `dial tcp: lookup clt-N...: no such host`, et ni les traces ni les métriques n'arrivent. Contrôlez avec `ssh root@$SRV_HOST getent hosts $CLT_HOST`. Si le nom ne résout pas, relancez le playbook en donnant l'adresse privée de `clt-N` à la place du nom, le temps que le DNS se propage (`export CLT_HOST=<adresse privée de clt-N>` avant `ansible-playbook`).

```bash
mkdir -p templates
```

```bash
cat > templates/config.yaml.j2 <<'EOF'
{{ ansible_managed | comment }}
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
{% if otelcol_hostmetrics_enabled %}
  hostmetrics:
    collection_interval: 30s
    scrapers:
      cpu: {}
      load: {}
      memory: {}
      # network: {}  # optionnel, voir section Extra
{% endif %}

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 256
    spike_limit_mib: 64
  resourcedetection:
    detectors: [system]
    timeout: 2s
    override: false
  resource:
    attributes:
{% for key, value in otelcol_resource_attributes.items() %}
      - key: {{ key }}
        value: {{ value | to_json }}
        action: upsert
{% endfor %}
      - key: service.name
        value: {{ otelcol_environment | to_json }}
        action: insert
      - key: service.instance.id
        value: {{ ansible_hostname | to_json }}
        action: insert
  batch:
    timeout: {{ otelcol_batch_timeout }}

exporters:
  otlp_grpc/jaeger:
    endpoint: {{ otelcol_backend_host }}:4317
    tls:
      insecure: true
{% if otelcol_hostmetrics_enabled %}
  otlp_http/prometheus:
    metrics_endpoint: http://{{ otelcol_backend_host }}:9090/api/v1/otlp/v1/metrics
{% endif %}

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, resource, batch]
      exporters: [otlp_grpc/jaeger]
{% if otelcol_hostmetrics_enabled %}
    metrics:
      receivers: [hostmetrics]
      processors: [memory_limiter, resourcedetection, resource, batch]
      exporters: [otlp_http/prometheus]
{% endif %}
EOF
```

Avant de déployer, produisez d'abord le rendu du template sur `clt-N`, sans toucher au serveur. Le module `ansible.builtin.template` est exécuté sur `localhost`, avec les variables de `group_vars/all.yml` :

```bash
cat > preview.yml <<'EOF'
- hosts: localhost
  connection: local
  gather_facts: true
  tasks:
    - name: Rendu de la configuration
      ansible.builtin.template:
        src: templates/config.yaml.j2
        dest: /tmp/config-preview.yaml
EOF
```

```bash
ansible-playbook preview.yml -e @group_vars/all.yml
```

```bash
cat /tmp/config-preview.yaml
```

On obtient la configuration telle que le serveur la recevra, sans aucune accolade Jinja2. En tête le commentaire de gestion Ansible, plus bas les attributs produits par la boucle :

```yaml
#
# Ansible managed
#
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 256
    spike_limit_mib: 64
  resourcedetection:
    detectors: [system]
    timeout: 2s
    override: false
  resource:
    attributes:
      - key: deployment.environment.name
        value: "lab4"
        action: upsert
      - key: lab.id
        value: "<votre numéro>"
        action: upsert
      - key: service.name
        value: "lab4"
        action: insert
      - key: service.instance.id
        value: "clt-N"
        action: insert
  batch:
    timeout: 2s

exporters:
  otlp_grpc/jaeger:
    endpoint: <CLT_HOST>:4317
    tls:
      insecure: true

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, resource, batch]
      exporters: [otlp_grpc/jaeger]
```

`<CLT_HOST>` vaut la valeur de la variable `CLT_HOST` de `clt-N` et `<votre numéro>` celle de `LAB_ID`. Lors de cette prévisualisation locale sur `localhost`, le fact `ansible_hostname` vaut `clt-N` ; au déploiement sur le serveur cible, il prendra automatiquement la valeur `srv-N`. Avec la valeur par défaut `otelcol_hostmetrics_enabled: false`, le rendu ne contient aucune mention de `hostmetrics`.

Vérifiez maintenant cette configuration avec la commande `validate` du **collector**, dans un conteneur lancé sur `clt-N` :

```bash
docker run --rm -v /tmp/config-preview.yaml:/config.yaml:ro \
  ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.165.0 \
  validate --config=/config.yaml
```

```bash
echo "code retour : $?"
```

La commande `validate` n'affiche rien, et le code retour vaut 0 :

```text
code retour : 0
```

Pas de message veut dire configuration valide. Au premier lancement, Docker montre d'abord le téléchargement de l'image, puis revient au silence. Le conteneur ne sert qu'à valider : il ne tourne pas, et `--rm` le supprime à la sortie.

Complétez maintenant le playbook avec une dernière tâche, ajoutée à la fin du fichier. Elle utilise le module `ansible.builtin.template` avec les paramètres suivants :

- `src` : `config.yaml.j2` et `dest` : `/etc/otelcol-contrib/config.yaml` ;
- `owner` : `root`, `group` : `otelcol-contrib` et `mode` : `"0640"` : le service tourne sous l'utilisateur `otelcol-contrib`, qui doit pouvoir lire le fichier, et personne d'autre ne doit pouvoir l'écrire ;
- `validate` : `/usr/bin/otelcol-contrib validate --config=%s` : Ansible écrit d'abord le résultat dans un fichier temporaire, lance cette commande dessus (`%s` est remplacé par le chemin du fichier temporaire) et ne remplace le fichier réel que si elle réussit ;
- `notify` : le nom du handler, pour que le service redémarre uniquement quand le fichier change.

Nommez la tâche `Déployer la configuration`. Elle doit être indentée comme les autres tâches de la liste.

```bash
cat >> playbook.yml <<'EOF'
    - name: Déployer la configuration
      ansible.builtin.template:
        src: config.yaml.j2
        dest: /etc/otelcol-contrib/config.yaml
        owner: root
        group: otelcol-contrib
        mode: "0640"
        validate: /usr/bin/otelcol-contrib validate --config=%s
      notify: Redémarrer otelcol-contrib
EOF
```

Déployez, puis générez cinq traces avec `telemetrygen` (lancé depuis `clt-N`) et envoyez-les au **collector** de `srv-N` :

```bash
ansible-playbook playbook.yml
```

```bash
docker run --rm ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 \
  traces --otlp-endpoint $SRV_HOST:4317 --otlp-insecure --rate 10 --traces 5 --service ansible-demo
```

Dans le résumé du playbook, la tâche `Déployer la configuration` est en `changed` et le handler s'est exécuté :

```text
TASK [Déployer la configuration] ***********************************************
changed: [srv-N.monlab.top]

RUNNING HANDLER [Redémarrer otelcol-contrib] ***********************************
changed: [srv-N.monlab.top]

PLAY RECAP *********************************************************************
srv-N.monlab.top           : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Le fichier déployé porte l'en-tête de gestion Ansible, et Jaeger a reçu les traces :

```bash
ansible otel -a 'head -n 3 /etc/otelcol-contrib/config.yaml'
```

```bash
curl -s 'http://localhost:16686/api/v3/traces?query.service_name=ansible-demo&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z' \
  | jq '[.result.resourceSpans[].scopeSpans[].spans[].traceId] | unique | length'
```

```bash
curl -s 'http://localhost:16686/api/v3/traces?query.service_name=ansible-demo&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z' \
  | jq -r '.result.resourceSpans[].resource.attributes[] | select(.key=="lab.id" or .key=="deployment.environment.name") | "\(.key)=\(.value | (.stringValue // .intValue))"' | sort -u
```

La première commande affiche des lignes de commentaire dont `Ansible managed` :

```text
#
# Ansible managed
#
```

La deuxième affiche le nombre de traces uniques :

```text
5
```

La troisième affiche les attributs ajoutés par la boucle du template :

```text
deployment.environment.name=lab4
lab.id=<votre numéro>
```

La même requête, filtrée sur `host.name`, montre ce qu'aucune variable Ansible n'a fourni : le nom de la machine, détecté automatiquement par le processor `resourcedetection`.

**Ces traces ont été générées par `telemetrygen`** (lancé depuis `clt-N`). Elles ont ensuite transité par le **collector** qui tourne sur `srv-N`. C'est pourquoi l'attribut `host.name` vaut le nom du serveur (`srv-N.monlab.top` ou `srv-N`), et non celui de `clt-N`.

```bash
curl -s 'http://localhost:16686/api/v3/traces?query.service_name=ansible-demo&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z' \
  | jq -r '.result.resourceSpans[].resource.attributes[] | select(.key=="host.name" or .key=="os.type") | "\(.key)=\(.value.stringValue)"' | sort -u
```

```text
host.name=srv-N.monlab.top
os.type=linux
```

Selon la configuration de la machine, `host.name` peut n'afficher que `srv-N` : dans les deux cas, c'est le nom du serveur qui fait tourner le **collector**, pas celui de `clt-N`, et aucune variable ne l'a fourni.

> [!NOTE]
>
> Si le comptage vaut 0, attendez quelques secondes et relancez la requête. Le premier export après un redémarrage du service peut prendre quelques instants (la connexion vers Jaeger doit s'établir, et le processor `batch` attend son timeout de 2 s avant d'envoyer).

Ouvrez l'interface de Jaeger (`http://$CLT_HOST:16686`) et sélectionnez le service `ansible-demo` : les cinq traces sont visibles.

![Traces du service ansible-demo dans Jaeger, avec les attributs déployés par Ansible](img/lab04-jaeger-traces.png)

## 4. Déploiements successifs

> [!TIP]
>
> Si vous démarrez directement à cette partie (ou si vous souhaitez remettre votre environnement dans l'état exact de fin de partie 3 : backends démarrés, inventaire, playbook, template et premier déploiement du **collector**), exécutez le script de rattrapage fourni depuis `clt-N` :

```bash
bash ~/opentelemetry-labs/config/lab04/fast-forward-part4.sh
```

```bash
cd ~/lab04
```

Un parc ne se déploie pas une seule fois : il change. Cette partie enchaîne cinq déploiements sur le même serveur, du premier ajout au retour en arrière, en passant par une dérive corrigée et un changement refusé. À chaque fois la mécanique est la même : une variable ou un template, un rendu, le contrôle `validate`, puis un redémarrage si le fichier change.

```mermaid
---
title: Cycle de mise a jour securisee avec Ansible
---
flowchart LR
  HV["host_vars/$SRV_HOST.yml<br/>(surcharge de variables)"]
  CHK["--check --diff<br/>(apercu sans modification)"]
  TPL["template + validate<br/>(controle sur fichier temporaire)"]
  OK["Remplacement config.yaml<br/>+ handler restart"]
  KO["Echec du play<br/>(configuration active preservee)"]

  HV --> CHK --> TPL
  TPL -->|"validate = 0"| OK
  TPL -->|"validate != 0"| KO

  classDef ok fill:#dcfce7,stroke:#15803d,color:#14532d
  classDef ko fill:#fee2e2,stroke:#b91c1c,color:#7f1d1d
  classDef step fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a

  class HV,CHK,TPL step
  class OK ok
  class KO ko
```

### Un ajout

Vous allez activer la collecte des métriques du serveur sans modifier ni le playbook, ni le template : seule une variable change.

Une variable définie pour un hôte précis, dans `host_vars/<nom de l'hôte>.yml`, l'emporte sur celle de `group_vars/all.yml`.

```bash
mkdir -p host_vars
```

```bash
cat > host_vars/$SRV_HOST.yml <<'EOF'
otelcol_hostmetrics_enabled: true
EOF
```

Regardez d'abord ce que ce changement ferait, sans l'appliquer :

```bash
ansible-playbook playbook.yml --check --diff
```

Le diff montre les lignes que le template ajouterait à la configuration du serveur : le receiver `hostmetrics`, l'exporter `otlp_http/prometheus` et le pipeline `metrics` :

```diff
+  hostmetrics:
+    collection_interval: 30s
+    scrapers:
+      cpu: {}
+      load: {}
+      memory: {}
@@ -30,6 +36,8 @@
+  otlp_http/prometheus:
+    metrics_endpoint: http://<CLT_HOST>:9090/api/v1/otlp/v1/metrics
@@ -37,3 +45,7 @@
+    metrics:
+      receivers: [hostmetrics]
+      processors: [memory_limiter, resourcedetection, resource, batch]
+      exporters: [otlp_http/prometheus]
```

Appliquez le changement. Le résumé montre deux tâches modifiées : le fichier déployé, puis le handler qui redémarre le service.

```bash
ansible-playbook playbook.yml | grep -E 'RUNNING HANDLER|changed:' | head -4
```

```text
changed: [srv-N.monlab.top]
RUNNING HANDLER [Redémarrer otelcol-contrib] ***
changed: [srv-N.monlab.top]
```

Contrôlez que l'instance en cours utilise bien cette configuration, puis attendez une minute le temps d'une collecte :

```bash
ansible otel -a 'grep -c hostmetrics /etc/otelcol-contrib/config.yaml'
```

```bash
sleep 60
```

```bash
curl -s http://localhost:9090/api/v1/query --data-urlencode 'query=count({__name__=~"system_cpu.*"})' \
  | jq -r '.data.result[0].value[1]'
```

La première commande affiche `2`, une ligne pour le receiver et une pour le pipeline. La seconde affiche un nombre supérieur à 0 : Prometheus a reçu les métriques de `srv-N`.

```text
12
```

Le nom exact des métriques dépend de la conversion appliquée par Prometheus, d'où l'expression régulière.

![Métriques système de srv-N dans Prometheus, collectées via hostmetrics et OTLP](img/lab04-prometheus-metrics.png)

### Un passage sans changement

Relancez le playbook immédiatement, et lisez le résumé :

```bash
ansible-playbook playbook.yml | grep -A2 'PLAY RECAP'
```

Rien n'a changé (`changed=0`) et le handler n'a pas redémarré le service : un redémarrage inutile aurait interrompu le **collector** sans raison.

```text
PLAY RECAP *********************************************************************
srv-N.monlab.top           : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Un retour en arrière

La collecte des métriques système a été ajoutée, elle peut être retirée de la même façon. Désactivez la variable :

```bash
cat > host_vars/$SRV_HOST.yml <<'EOF'
otelcol_hostmetrics_enabled: false
EOF
```

```bash
ansible-playbook playbook.yml --check --diff
```

Le diff montre cette fois des lignes retirées, les mêmes qu'à l'ajout :

```diff
-  hostmetrics:
-    collection_interval: 30s
-    scrapers:
-      cpu: {}
-      load: {}
-      memory: {}
@@ -36,8 +30,6 @@
-  otlp_http/prometheus:
-    metrics_endpoint: http://<CLT_HOST>:9090/api/v1/otlp/v1/metrics
@@ -45,7 +37,3 @@
-    metrics:
-      receivers: [hostmetrics]
-      processors: [memory_limiter, resourcedetection, resource, batch]
-      exporters: [otlp_http/prometheus]
```

Appliquez, puis vérifiez que la configuration en cours ne contient plus le receiver :

```bash
ansible-playbook playbook.yml | grep -E 'RUNNING HANDLER|changed:' | head -4
```

```bash
ansible otel -m ansible.builtin.shell -a 'grep -c hostmetrics /etc/otelcol-contrib/config.yaml || true'
```

La seconde commande affiche `0`. Dans Prometheus, les séries existantes ne disparaissent pas instantanément : le serveur les marque comme périmées après cinq minutes sans nouvelle valeur, puis les oublie. La partie suivante dure assez longtemps pour le constater à la fin, avec la même requête.

### Une dérive corrigée

Que se passe-t-il si quelqu'un modifie la configuration à la main sur le serveur ? Ajoutez une ligne au fichier déployé, comme le ferait un dépannage pressé :

```bash
ansible otel -b -m ansible.builtin.shell -a 'echo "# ajouté à la main" >> /etc/otelcol-contrib/config.yaml'
```

```bash
ansible otel -a 'tail -1 /etc/otelcol-contrib/config.yaml'
```

Le serveur porte maintenant une configuration que le template ne décrit pas. Demandez à Ansible ce qu'il ferait :

```bash
ansible-playbook playbook.yml --check --diff
```

Le diff contient la ligne à retirer :

```diff
@@ -45,4 +45,3 @@
- # ajouté à la main
```

Appliquez, puis contrôlez la fin du fichier :

```bash
ansible-playbook playbook.yml >/dev/null
```

```bash
ansible otel -a 'tail -1 /etc/otelcol-contrib/config.yaml'
```

La ligne a disparu, et le fichier se termine de nouveau par la déclaration du dernier pipeline du template. Les métriques système étant encore activées à ce stade, c'est le pipeline `metrics` :

```text
      exporters: [otlp_http/prometheus]
```

Ansible est la source de vérité : une modification manuelle est écrasée au passage suivant. C'est ce qui rend un parc prévisible, et c'est aussi pourquoi une urgence se règle en modifiant le template, pas le serveur.

### Un changement refusé

Simulez enfin une erreur de saisie. La valeur de `otelcol_batch_timeout` est invalide (`"deux secondes"` au lieu d’une durée comme `2s`). Le paramètre `validate` du template doit empêcher le déploiement d’une configuration invalide :

```bash
cat > host_vars/$SRV_HOST.yml <<'EOF'
otelcol_hostmetrics_enabled: false
otelcol_batch_timeout: "deux secondes"
EOF
```

```bash
ansible-playbook playbook.yml
```

Le playbook échoue sur la tâche `Déployer la configuration`, avec un message du **collector** qui cite `timeout` et une durée invalide :

```text
fatal: [srv-N.monlab.top]: FAILED! => {"changed": false, ..., "stderr": "Error: ... 'processors' error reading configuration for \"batch\": ... 'timeout' time: invalid duration \"deux ...", "stdout": "", ...}
srv-N.monlab.top           : ok=4    changed=0    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0
```

Le serveur n'a pas été touché : le service tourne toujours avec la dernière configuration valide.

```bash
ansible otel -a 'systemctl is-active otelcol-contrib'
```

```bash
ansible otel -a 'grep -n timeout /etc/otelcol-contrib/config.yaml'
```

Les commandes affichent `active` et une ligne `timeout: 2s`.

Corrigez l'erreur en supprimant la ligne fautive, puis relancez :

```bash
sed -i '/otelcol_batch_timeout/d' host_vars/$SRV_HOST.yml
```

```bash
ansible-playbook playbook.yml | grep -A2 'PLAY RECAP'
```

Le résumé indique `failed=0` et `changed=2`. Le fichier est bien redéployé : la suppression de la ligne fautive retire aussi la valeur `hostmetrics` devenue `false`, donc la configuration générée change par rapport à celle qui tourne, et le service redémarre :

```text
srv-N.monlab.top           : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Pour retrouver un `changed=0`, relancez une seconde fois le playbook : le fichier est alors déjà conforme au template.

> [!NOTE]
>
> Si Ansible affiche `UNREACHABLE`, contrôlez `cat inventory.ini` (le nom du serveur doit apparaître sous `[otel]`) puis testez `ssh $SRV_HOST hostname`. Si une variable booléenne passée avec `-e` semble ignorée, c'est la chaîne `false` qui est évaluée comme vraie par Jinja2 : utilisez la forme JSON, `-e '{"otelcol_hostmetrics_enabled": false}'`.

## 5. Étendre le parc : 4 serveurs, 4 configurations

Votre animateur a provisionné trois serveurs éphémères Debian pour votre groupe, dans le même VPC que `clt-N`. Leurs adresses privées changent d'une session à l'autre, et DigitalOcean ne garantit pas l'ordre dans lequel il les attribue : vous allez donc les découvrir au lieu de les écrire en dur.

Le schéma suivant montre le déploiement simultané d'un seul playbook et d'un seul template vers les quatre serveurs aux profils différenciés :

```mermaid
---
title: Un playbook, un template, quatre configurations dans le VPC
---
flowchart LR
  subgraph CLT["clt-N"]
    direction TB
    ANS["Ansible<br/>1 playbook + 1 template<br/>+ 4 host_vars"]
    PROM[("Prometheus<br/>TCP/9090 (OTLP)")]
  end

  subgraph PARC["4 serveurs cibles dans vpc-N"]
    direction TB
    S0["srv-N (Ubuntu)<br/>env=lab4, batch=2s, hostmetrics=on"]
    S1["srv-frontend (Debian)<br/>env=frontend, batch=1s, hostmetrics=off"]
    S2["srv-backend (Debian)<br/>env=backend, batch=5s, hostmetrics=on"]
    S3["srv-database (Debian)<br/>env=database, batch=10s, hostmetrics=on"]
  end

  ANS -->|SSH| S0
  ANS -->|SSH| S1
  ANS -->|SSH| S2
  ANS -->|SSH| S3
  S0 -->|"OTLP metrics"| PROM
  S2 -->|"OTLP metrics"| PROM
  S3 -->|"OTLP metrics"| PROM

  classDef ctrl fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
  classDef on fill:#fef3c7,stroke:#b45309,color:#78350f
  classDef off fill:#f1f5f9,stroke:#475569,color:#0f172a
  classDef back fill:#ede9fe,stroke:#6d28d9,color:#4c1d95

  class ANS ctrl
  class S0,S2,S3 on
  class S1 off
  class PROM back
```

Le dossier contient `discover-ephemere.sh`, qui balaie le sous-réseau privé de `clt-N` sur le port SSH, interroge les machines qui répondent, et ne garde que celles dont le nom commence par `srv2-`, `srv3-` ou `srv4-`. Lancez-le, puis construisez l'inventaire à partir de son résultat :

```bash
chmod +x discover-ephemere.sh
```

```bash
./discover-ephemere.sh > ephemeres.ini
```

```bash
cat ephemeres.ini
```

```bash
cat > inventory.ini <<EOF
[otel]
$SRV_HOST

$(cat ephemeres.ini)

[collector:children]
otel
ephemere
EOF
```

```bash
cat inventory.ini
```

La découverte prend une dizaine de secondes. Le fichier `ephemeres.ini` contient les trois alias reliés aux adresses trouvées, dans l'ordre croissant des adresses, par exemple :

```text
[ephemere]
srv-frontend ansible_host=10.20.N.7
srv-backend ansible_host=10.20.N.8
srv-database ansible_host=10.20.N.9
```

Les numéros finaux dépendent de la session : c'est justement ce que le script évite de deviner. Vérifiez maintenant que la connexion fonctionne et que le système est bien Debian :

```bash
ansible all -m ansible.builtin.ping -o | head -6
```

```bash
ansible ephemere -m ansible.builtin.setup -a 'filter=ansible_distribution' -o | grep -o 'Debian\|ansible_hostname[^,]*' | head -4
```

La sortie attendue pour le ping est `SUCCESS` sur les quatre machines, et pour `setup`, `ansible_distribution: Debian`.

La structure de l'inventaire est nouvelle :

- `[otel]` contient le serveur principal `srv-N`, déjà déployé ;
- `[ephemere]` contient les trois serveurs Debian, chacun sous un **alias** parlant (`srv-frontend`, `srv-backend`, `srv-database`), avec `ansible_host` qui indique l'adresse IP réelle ;
- `[collector:children]` est un **groupe de groupes** : il regroupe `otel` et `ephemere`, pour que le playbook s'applique à tous.

La partie 4 s'est terminée avec les métriques système désactivées sur le serveur principal. Réactivez-les, puisque cette partie compare des profils de collecte :

```bash
cat > host_vars/$SRV_HOST.yml <<'EOF'
otelcol_hostmetrics_enabled: true
EOF
```

Créez maintenant les variables des trois serveurs éphémères, avec trois profils différents :

```bash
cat > host_vars/srv-frontend.yml <<'EOF'
otelcol_hostmetrics_enabled: false
otelcol_batch_timeout: 1s
otelcol_environment: frontend
EOF
```

```bash
cat > host_vars/srv-backend.yml <<'EOF'
otelcol_hostmetrics_enabled: true
otelcol_batch_timeout: 5s
otelcol_environment: backend
EOF
```

```bash
cat > host_vars/srv-database.yml <<'EOF'
otelcol_hostmetrics_enabled: true
otelcol_batch_timeout: 10s
otelcol_environment: database
EOF
```

Chaque serveur éphémère reçoit :

- un `batch` différent : 1 seconde pour le frontend, 5 pour le backend, 10 pour la database ;
- les métriques système activées ou non : le frontend est un serveur d'application, les deux autres sont des serveurs d'infrastructure dont on veut suivre la charge ;
- un `deployment.environment.name` différent, qui deviendra un label dans Prometheus.

Le playbook doit maintenant s'exécuter sur le groupe `collector` (les quatre serveurs) au lieu de `otel`. Modifiez la ligne `hosts:` :

```bash
sed -i 's/^  hosts: otel/  hosts: collector/' playbook.yml
```

```bash
grep 'hosts:' playbook.yml
```

Lancez le playbook :

```bash
ansible-playbook playbook.yml
```

Le résumé montre quatre serveurs traités en même temps. `srv-0.monlab.top` passe à `changed=2`, parce que vous venez de réactiver ses métriques : sa configuration change et son service redémarre. Les trois serveurs Debian passent de `absent` à installé, configuré et démarré (`changed=4` chacun) :

```text
PLAY RECAP *********************************************************************
srv-0.monlab.top           : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
srv-backend                : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
srv-database               : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
srv-frontend               : ok=6    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Un seul playbook, quatre configurations différentes. Comparez-les :

```bash
ansible collector -b -m ansible.builtin.shell \
  -a "grep -A1 'batch:' /etc/otelcol-contrib/config.yaml | tail -1; grep 'hostmetrics:' /etc/otelcol-contrib/config.yaml | head -1; grep 'value:' /etc/otelcol-contrib/config.yaml | head -1" \
  -o
```

La sortie montre que chaque serveur a bien sa configuration. Les retours à la ligne internes sont remplacés par `\n`, effet de l'option `-o` qui tient chaque hôte sur une seule ligne :

```text
srv-frontend |    timeout: 1s\n        value: "frontend"
srv-backend |     timeout: 5s\n  hostmetrics:\n        value: "backend"
srv-database |    timeout: 10s\n  hostmetrics:\n        value: "database"
srv-0.monlab.top | timeout: 2s\n  hostmetrics:\n        value: "lab4"
```

Le frontend n'affiche pas `hostmetrics`, puisque ses métriques système sont désactivées.

Le **collector** ne fait pas scraper Prometheus : il lui pousse les métriques en OTLP. Dans ce mode, Prometheus ignore par défaut les attributs de ressource, et les collectors des quatre serveurs produiraient la même série `system_cpu_load_average_1m`, sans label, indiscernables. Le fichier `prometheus/prometheus.yml` fourni contient pour cela un bloc `otlp` qui promeut quatre attributs en labels : `service.name`, `service.instance.id`, `deployment.environment.name` et `host.name`.

Attendez une minute, puis interrogez Prometheus pour voir les métriques des serveurs d'infrastructure :

```bash
sleep 60
```

```bash
curl -s -G "http://localhost:9090/api/v1/query" \
  --data-urlencode "query=system_cpu_load_average_1m" \
  | jq -r '.data.result[] | "\(.metric.host_name) [\(.metric.deployment_environment_name)] : \(.value[1])"'
```

La sortie affiche une série par serveur qui envoie des métriques système, avec le rôle entre crochets. Le frontend n'y figure pas, puisque ses métriques système sont désactivées :

```text
srv-0 [lab4] : 0.19
srv4-0 [backend] : 0.05
srv3-0 [database] : 0.13
```

`srv-frontend` n'apparaît pas : la variable `otelcol_hostmetrics_enabled: false` a supprimé le receiver `hostmetrics` et le pipeline `metrics` de sa configuration.

![Métriques système des serveurs dans Prometheus, différenciées par instance et par job](img/lab04-prometheus-multi.png)

> [!NOTE]
>
> Les labels `instance` et `job` de Prometheus viennent des attributs de ressource `service.instance.id` et `service.name`. Ces deux attributs sont désormais ajoutés automatiquement dans le template (via `otelcol_environment` et le fact Ansible `ansible_hostname`).

> [!NOTE]
>
> Les machines éphémères sont détruites par l'animateur à la fin du lab : la configuration qu'elles portent est entièrement reproductible par le playbook, c'est le sens de l'infrastructure-as-code.

## Cleanup

Arrêtez les backends du poste de contrôle, puis désinstallez le **collector** du serveur et effacez le paquet téléchargé :

```bash
cd ~/lab04
```

```bash
docker compose down
```

```bash
ansible otel -b -m ansible.builtin.apt -a "name=otelcol-contrib state=absent purge=true"
```

```bash
ansible otel -b -m ansible.builtin.file -a "path=/tmp/otelcol-contrib_0.165.0.deb state=absent"
```

```bash
ansible otel -m ansible.builtin.shell -a 'command -v otelcol-contrib || echo absent'
```

La dernière commande affiche `absent` : le binaire, la configuration `/etc/otelcol-contrib` et le paquet dans `/tmp` ont disparu du serveur.

Si vous avez réalisé [l'extra 5](#5-installer-node_exporter-sur-un-serveur-et-le-scraper-via-le-collector), désinstallez également `prometheus-node-exporter` sur `srv-N` :

```bash
ansible otel -b -m ansible.builtin.apt -a "name=prometheus-node-exporter state=absent purge=true"
```

Si des serveurs éphémères ont été déployés [à la partie 5](#5-étendre-le-parc--4-serveurs-4-configurations), ils ne se nettoient pas depuis le terminal : votre animateur les détruit en fin de séance avec `animateur/scripts/lab04-vms-destroy.sh`. Aucun playbook n'est nécessaire pour cela, et les machines disparaissent avec leurs paquets et leurs configurations.

Le dossier `~/lab04` peut être conservé si vous voulez rejouer le lab. Les autres labs ne le réutilisent pas : chacun fournit ses propres fichiers.

## Extra

À vous de jouer, si le temps le permet. Chaque exercice est guidé pas à pas.

### 1. Un **collector** pour la préproduction et la production

Le cas d'usage est celui d'une équipe qui exploite deux environnements, `preprod` et `prod`, avec un seul **collector** plutôt que deux machines à maintenir. Les contraintes ne sont pas les mêmes :

- la production doit être vue vite : lots courts (1 seconde) et métriques système collectées, parce que la capacité de ces serveurs compte ;
- la préproduction peut attendre : lots longs (10 secondes), pas de métriques système, pour ne pas payer le coût d'une collecte dont personne ne se sert ;
- les deux flux (streams) doivent rester **séparés et identifiables** : ports différents, donc règles de pare-feu différentes, et un attribut `tenant` qui permet de retrouver l'origine de chaque donnée dans le backend.

C'est exactement ce qu'un template Jinja2 rend confortable : on décrit les deux environnements une fois, et le reste est généré. Sans boucle, il faudrait recopier six blocs de configuration à la main, avec le risque d'en oublier un.

Ajoutez la description des deux locataires à la fin de `host_vars/$SRV_HOST.yml` :

```bash
cd ~/lab04
```

```bash
cat >> host_vars/$SRV_HOST.yml <<'EOF'
otelcol_tenants:
  - name: prod
    environment: production
    port_grpc: 4317
    port_http: 4318
    batch_timeout: 1s
    hostmetrics: true
  - name: preprod
    environment: preproduction
    port_grpc: 5317
    port_http: 5318
    batch_timeout: 10s
    hostmetrics: false
EOF
```

Écrivez un second template, à côté du premier :

```bash
cat > templates/config-tenants.yaml.j2 <<'EOF'
{{ ansible_managed | comment }}
receivers:
{% for t in otelcol_tenants %}
  otlp/{{ t.name }}:
    protocols:
      grpc:
        endpoint: 0.0.0.0:{{ t.port_grpc }}
      http:
        endpoint: 0.0.0.0:{{ t.port_http }}
{% if t.hostmetrics %}
  hostmetrics/{{ t.name }}:
    collection_interval: 30s
    scrapers:
      cpu: {}
      load: {}
      memory: {}
{% endif %}
{% endfor %}

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: 256
    spike_limit_mib: 64
{% for t in otelcol_tenants %}
  resource/{{ t.name }}:
    attributes:
      - key: tenant
        value: {{ t.name | to_json }}
        action: upsert
      - key: deployment.environment.name
        value: {{ t.environment | to_json }}
        action: upsert
      - key: service.instance.id
        value: "otelcol-{{ t.name }}"
        action: upsert
  batch/{{ t.name }}:
    timeout: {{ t.batch_timeout }}
{% endfor %}

exporters:
  otlp_grpc/jaeger:
    endpoint: {{ otelcol_backend_host }}:4317
    tls:
      insecure: true
  otlp_http/prometheus:
    metrics_endpoint: http://{{ otelcol_backend_host }}:9090/api/v1/otlp/v1/metrics

service:
  pipelines:
{% for t in otelcol_tenants %}
    traces/{{ t.name }}:
      receivers: [otlp/{{ t.name }}]
      processors: [memory_limiter, resource/{{ t.name }}, batch/{{ t.name }}]
      exporters: [otlp_grpc/jaeger]
{% if t.hostmetrics %}
    metrics/{{ t.name }}:
      receivers: [hostmetrics/{{ t.name }}]
      processors: [memory_limiter, resource/{{ t.name }}, batch/{{ t.name }}]
      exporters: [otlp_http/prometheus]
{% endif %}
{% endfor %}
EOF
```

Quatre constructions se combinent ici :

- la boucle `{% for t in otelcol_tenants %}` produit un bloc par environnement ;
- la condition `{% if t.hostmetrics %}` n'ajoute le receiver et le pipeline `metrics` que pour ceux qui en veulent ;
- l'accès `{{ t.port_grpc }}` et `{{ t.batch_timeout }}` lit les champs de l'élément en cours d'itération ;
- le suffixe `{{ t.name }}` garantit l'unicité des noms de composants, exigée par le **collector**.

L'attribut `service.instance.id` mérite une explication : c'est lui qui devient le label `instance` dans Prometheus. Sans lui, les séries de métriques arrivent sans label et deviennent impossibles à attribuer à un environnement.

Rendez le template sur `clt-N` et validez-le avant de déployer :

```bash
ansible localhost -m ansible.builtin.template \
  -a "src=templates/config-tenants.yaml.j2 dest=/tmp/config-tenants.yaml" -e @group_vars/all.yml
```

```bash
docker run --rm -v /tmp/config-tenants.yaml:/config.yaml:ro \
  ghcr.io/open-telemetry/opentelemetry-collector-releases/opentelemetry-collector-contrib:0.165.0 \
  validate --config=/config.yaml
```

```bash
echo "code retour : $?"
```

Le rendu montre les pipelines de chaque environnement, et la différence entre les deux :

```yaml
service:
  pipelines:
    traces/prod:
      receivers: [otlp/prod]
      processors: [memory_limiter, resource/prod, batch/prod]
      exporters: [otlp_grpc/jaeger]
    metrics/prod:
      receivers: [hostmetrics/prod]
      processors: [memory_limiter, resource/prod, batch/prod]
      exporters: [otlp_http/prometheus]
    traces/preprod:
      receivers: [otlp/preprod]
      processors: [memory_limiter, resource/preprod, batch/preprod]
      exporters: [otlp_grpc/jaeger]
```

`prod` a deux pipelines, `preprod` un seul : la condition a suffi à produire cette différence.

Déployez cette configuration en pointant la tâche sur le nouveau template :

```bash
sed -i 's|src: config.yaml.j2|src: config-tenants.yaml.j2|' playbook.yml
```

```bash
ansible-playbook playbook.yml | grep -A3 'PLAY RECAP'
```

```text
srv-N.monlab.top           : ok=6    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Les quatre ports OTLP sont en écoute, deux par environnement :

```bash
ansible otel -m ansible.builtin.shell -a "ss -ltn | grep -E ':(4317|4318|5317|5318) '"
```

```text
LISTEN 0      4096               *:5318            *:*
LISTEN 0      4096               *:5317            *:*
LISTEN 0      4096               *:4318            *:*
LISTEN 0      4096               *:4317            *:*
```

Envoyez maintenant trois traces sur chaque endpoint, sous le même nom de service : c'est la situation réelle d'une application déployée dans les deux environnements.

```bash
docker run --rm ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 \
  traces --otlp-endpoint $SRV_HOST:4317 --otlp-insecure --rate 10 --traces 3 --service checkout-web
```

```bash
docker run --rm ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 \
  traces --otlp-endpoint $SRV_HOST:5317 --otlp-insecure --rate 10 --traces 3 --service checkout-web
```

```bash
sleep 5
```

Dans Jaeger, le même service apparaît deux fois, distingué par les attributs que le template a posés :

```bash
curl -s 'http://localhost:16686/api/v3/traces?query.service_name=checkout-web&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z' \
  | jq -r '[.result.resourceSpans[].resource.attributes[] | select(.key=="tenant" or .key=="deployment.environment.name") | "\(.key)=\(.value.stringValue)"] | unique | .[]'
```

```text
deployment.environment.name=preproduction
deployment.environment.name=production
tenant=preprod
tenant=prod
```

C'est la valeur du modèle : un seul pipeline de collecte, et des données attribuables à leur environnement sans ambiguïté, ce qui permet de répondre à « quelle est la latence en production ? » sans mélanger la préproduction.

Vérifiez enfin la différence de traitement sur les métriques. Après une trentaine de secondes, seul `prod` envoie des séries système :

```bash
sleep 35
```

```bash
curl -s -G http://localhost:9090/api/v1/query \
  --data-urlencode 'query=count by (instance) ({__name__=~"system_cpu.*"})' \
  | jq -r '.data.result[] | "instance=\(.metric.instance) : \(.value[1]) series"'
```

```text
instance=otelcol-prod : 12 series
```

`preprod` n'apparaît pas : sa variable `hostmetrics: false` a supprimé le receiver et le pipeline `metrics` de sa configuration. Une seule variable change, et le template produit deux comportements.

> [!NOTE]
>
> Ce modèle a une limite bien réelle, à connaître avant de le déployer en production. Les deux environnements partagent le même processus et donc le même `memory_limiter` : si la préproduction sature son endpoint, le limiteur peut rejeter aussi les données de production. C'est le problème du voisin bruyant, et c'est pourquoi certains parcs isolent la production sur un **collector** distinct. [Le lab 9](Lab_09_Gateway_Production.md) traite ces questions de **gateway** de production.

Revenez à la configuration du lab avant de continuer :

```bash
sed -i 's|src: config-tenants.yaml.j2|src: config.yaml.j2|' playbook.yml
```

```bash
ansible-playbook playbook.yml | grep -A3 'PLAY RECAP'
```

### 2. Activer le scraper network du receiver hostmetrics (extra)

Le receiver `hostmetrics` active par défaut seulement `cpu`, `load` et `memory`. Pour collecter également les métriques réseau (`network` : paquets, octets, erreurs, etc.), décommentez la ligne suivante dans le template :

```yaml
      network: {}
```

Redéployez ensuite le **collector** avec le playbook. Vous verrez alors de nouvelles métriques telles que `system_network_packets` ou `system_network_io` dans Prometheus.

### 3. Conserver les versions précédentes de la configuration

Ajoutez le paramètre `backup: true` à la tâche de configuration et observez les copies conservées sur le serveur à chaque modification.

### 4. Revenir à une version antérieure du binaire

Pour l'exercice, imaginez qu'une régression de la version 0.165.0 vous oblige à revenir à 0.164.0 le temps d'un diagnostic. Le playbook rend l'opération simple, à deux conditions : changer les sommes de contrôle avec la version, et prévenir APT qu'il s'agit d'une descente de version.

Commencez par la version et les sommes. Celles de la 0.164.0 sont publiées avec la version :

```bash
sed -i 's/otelcol_version: "0.165.0"/otelcol_version: "0.164.0"/' group_vars/all.yml
```

```bash
sed -i 's|amd64: "sha256:dafb5174344dd15f339fd8208783b17122fb4cd37fa7e5461fb09d99df212b4b"|amd64: "sha256:1995260c54cf5d74964a85e5e7d27834bb9a252c87a2582a4fb6a6c34565a90d"|' group_vars/all.yml
```

```bash
sed -i 's|arm64: "sha256:4dcfb6b69dfa10132c593ed5782823eec79dc408a0d68291e1c4adc5879d0948"|arm64: "sha256:34dca7290ff50d8be123c587dff51d93711a59e2cff41895e8801b145749dd0e"|' group_vars/all.yml
```

```bash
grep -A3 'otelcol_checksums' group_vars/all.yml
```

Autorisez ensuite la descente de version dans la tâche d'installation :

```bash
sed -i 's|        deb: "/tmp/otelcol-contrib_{{ otelcol_version }}.deb"|        deb: "/tmp/otelcol-contrib_{{ otelcol_version }}.deb"\n        allow_downgrade: true|' playbook.yml
```

```bash
grep -A3 'deb:' playbook.yml | head -4
```

```text
        deb: "/tmp/otelcol-contrib_{{ otelcol_version }}.deb"
        allow_downgrade: true
        state: present
```

Déployez, puis contrôlez la version installée et l'état du service :

```bash
ansible-playbook playbook.yml
```

```bash
ansible otel -a '/usr/bin/otelcol-contrib --version'
```

```bash
ansible otel -a 'systemctl is-active otelcol-contrib'
```

```bash
ansible otel -a 'dpkg-query -W otelcol-contrib'
```

On obtient la version antérieure, un service actif et un paquet marqué `0.164.0` :

```text
otelcol-contrib version 0.164.0
active
otelcol-contrib	0.164.0
```

Envoyez cinq traces pour vérifier que le **collector** déployé fonctionne toujours :

```bash
docker run --rm ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.165.0 \
  traces --otlp-endpoint $SRV_HOST:4317 --otlp-insecure --rate 10 --traces 5 --service ansible-demo
```

```bash
sleep 3
```

```bash
curl -s 'http://localhost:16686/api/v3/traces?query.service_name=ansible-demo&query.startTimeMin=2020-01-01T00:00:00Z&query.startTimeMax=2030-01-01T00:00:00Z' \
  | jq '[.result.resourceSpans[].scopeSpans[].spans[].traceId] | unique | length'
```

> [!NOTE]
>
> Trois choses à retenir de cet exercice. Sans `allow_downgrade`, APT refuse l'opération avec `Packages were downgraded and -y was used without --allow-downgrades`, et le paquet reste en 0.165.0. Une somme de contrôle oubliée fait échouer le téléchargement avant même l'installation. Et la remontée de version est le cas normal : sans `allow_downgrade`, APT installe la version supérieure sans broncher.

### 5. Installer node_exporter sur un serveur et le scraper via le **collector**

Dans ce lab, les métriques système ont été collectées avec le receiver `hostmetrics`. Une autre approche très fréquente en production consiste à installer `node_exporter` (l'exporter Prometheus officiel pour Linux) sur la machine cible, puis à le faire scraper localement par le **collector** OpenTelemetry avec le receiver `prometheus`.

Le schéma suivant zoome sur ce flux entre `srv-N` et le Prometheus central sur `clt-N` :

```mermaid
---
title: Scrape local de node_exporter par le collector et export OTLP vers Prometheus
---
flowchart LR
  subgraph SRV["Machine serveur srv-N"]
    direction LR
    NE["node_exporter<br/>127.0.0.1:9100/metrics"]
    COL["collector (otelcol-contrib)<br/>receiver prometheus -> processors -> exporter otlp_http"]
    COL -->|"scrape HTTP local<br/>(pull, toutes les 15 s)"| NE
  end

  subgraph CLT["Serveur central clt-N"]
    PROM[("Prometheus<br/>TCP/9090<br/>/api/v1/otlp/v1/metrics")]
  end

  COL -->|"export OTLP/HTTP sortant<br/>(push)"| PROM

  classDef exporter fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a
  classDef collector fill:#fef3c7,stroke:#b45309,color:#78350f
  classDef backend fill:#ede9fe,stroke:#6d28d9,color:#4c1d95

  class NE exporter
  class COL collector
  class PROM backend
```

Ce montage présente trois intérêts concrets :

- **Conserver les tableaux de bord et alertes existants.** Le receiver `hostmetrics` produit des métriques aux conventions sémantiques OpenTelemetry (`system_cpu_*`, `system_memory_*`), alors que les tableaux de bord Grafana historiques et de nombreuses règles d'alerte PromQL reposent sur les noms de `node_exporter` (`node_cpu_seconds_total`, `node_memory_MemAvailable_bytes`, `node_load1`). Scraper `node_exporter` via le **collector** permet de basculer le transport vers OpenTelemetry sans réécrire immédiatement les requêtes existantes.
- **Remplacer le pull entrant par un export OTLP sortant.** Avec un scrape Prometheus classique, le serveur Prometheus central doit ouvrir une connexion entrante vers le port `9100` de chaque machine du parc, ce qui complique les règles de pare-feu. Ici, `node_exporter` est interrogé en local sur `127.0.0.1:9100` par le **collector**, qui pousse ensuite les métriques en OTLP sortant en leur appliquant le même pipeline que les autres signaux (`resourcedetection`, `resource`, `batch`, chiffrement, filtrage).
- **Appliquer un modèle unique à tout l'écosystème Prometheus.** La même configuration de receiver `prometheus` sert à collecter n'importe quel exporter existant (`postgres_exporter`, `nginx_exporter`, ou un endpoint `/metrics` applicatif) sans déployer d'agent Prometheus dédié.

En contrepartie, faire tourner simultanément `hostmetrics` et `node_exporter` duplique les métriques système et augmente la cardinalité stockée dans Prometheus (plus de 1 700 séries `node_*` par serveur). En production, on ne conserve généralement que l'un des deux receivers.

**Consigne** : déployez `prometheus-node-exporter` sur un unique serveur (`srv-N`, groupe `otel`), ajoutez une variable booléenne `otelcol_node_exporter_enabled` (désactivée par défaut dans `group_vars/all.yml`, activée uniquement dans `host_vars/$SRV_HOST.yml`) pour activer un receiver `prometheus/node_exporter` dans `templates/config.yaml.j2` qui scrape `127.0.0.1:9100`, redéployez sur `srv-N`, puis vérifiez dans Prometheus sur `clt-N` que la métrique `node_load1` apparaît avec les attributs de ressource (`host_name`, `deployment_environment_name`, `instance`, `job`).

La solution technique détaillée est disponible dans [solutions/sol-4-5.md](solutions/sol-4-5.md).
