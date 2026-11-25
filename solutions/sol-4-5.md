# Solution Lab 4 - Extra 5 : Installer node_exporter sur un serveur et le scraper via le collector

## Objectif

Installer `prometheus-node-exporter` sur un unique serveur (`srv-N`, groupe `otel`), configurer le **collector** OpenTelemetry pour le scraper localement sur `127.0.0.1:9100` via le receiver `prometheus`, et vérifier la réception des métriques `node_*` en OTLP dans Prometheus sur `clt-N`.

Toutes les commandes ci-dessous s'exécutent depuis `clt-N`, dans `~/lab04`.

## Solution

### 1. Installer `prometheus-node-exporter` sur `srv-N`

```bash
ansible otel -b -m ansible.builtin.apt -a "name=prometheus-node-exporter state=present update_cache=true"
ansible otel -m ansible.builtin.shell -a "curl -s http://127.0.0.1:9100/metrics | grep -E '^node_load1 '"
```

On obtient une ligne de métrique au format Prometheus :

```text
node_load1 0.12
```

### 2. Activer la variable uniquement pour `srv-N`

Déclarez `otelcol_node_exporter_enabled` à `false` par défaut dans `group_vars/all.yml`, puis activez-la dans `host_vars/$SRV_HOST.yml` :

```bash
echo 'otelcol_node_exporter_enabled: false' >> group_vars/all.yml
cat > host_vars/$SRV_HOST.yml <<'EOF'
otelcol_hostmetrics_enabled: true
otelcol_node_exporter_enabled: true
EOF
```

### 3. Ajouter le receiver `prometheus/node_exporter` dans `templates/config.yaml.j2`

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
{% endif %}
{% if otelcol_node_exporter_enabled %}
  prometheus/node_exporter:
    config:
      scrape_configs:
        - job_name: node_exporter
          scrape_interval: 15s
          static_configs:
            - targets: ["127.0.0.1:9100"]
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
        action: upsert
      - key: service.instance.id
        value: {{ ansible_hostname | to_json }}
        action: upsert
  batch:
    timeout: {{ otelcol_batch_timeout }}

exporters:
  otlp_grpc/jaeger:
    endpoint: {{ otelcol_backend_host }}:4317
    tls:
      insecure: true
{% if otelcol_hostmetrics_enabled or otelcol_node_exporter_enabled %}
  otlp_http/prometheus:
    metrics_endpoint: http://{{ otelcol_backend_host }}:9090/api/v1/otlp/v1/metrics
{% endif %}

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resourcedetection, resource, batch]
      exporters: [otlp_grpc/jaeger]
{% if otelcol_hostmetrics_enabled or otelcol_node_exporter_enabled %}
    metrics:
      receivers:
{% if otelcol_hostmetrics_enabled %}
        - hostmetrics
{% endif %}
{% if otelcol_node_exporter_enabled %}
        - prometheus/node_exporter
{% endif %}
      processors: [memory_limiter, resourcedetection, resource, batch]
      exporters: [otlp_http/prometheus]
{% endif %}
EOF
```

### 4. Déployer sur `srv-N` et vérifier dans Prometheus

```bash
ansible-playbook playbook.yml --limit otel
sleep 30
curl -s -G "http://localhost:9090/api/v1/query" \
  --data-urlencode "query=node_load1" \
  | jq -r '.data.result[] | "\(.metric.host_name) [\(.metric.deployment_environment_name)] instance=\(.metric.instance) job=\(.metric.job) : \(.value[1])"'
```

Résultat attendu :

```text
srv-N [lab4] instance=srv-N job=lab4 : 0.44
```

Pour compter l'ensemble des séries `node_*` remontées en OTLP :

```bash
curl -s -G "http://localhost:9090/api/v1/query" \
  --data-urlencode 'query=count({__name__=~"node_.*"})' \
  | jq -r '.data.result[0].value[1]'
```

### 5. Nettoyer

```bash
ansible otel -b -m ansible.builtin.apt -a "name=prometheus-node-exporter state=absent purge=true"
```

---

**Liens de navigation**

- [Retour au lab 4](../Lab_04_Ansible_Jinja2.md#5-installer-node_exporter-sur-un-serveur-et-le-scraper-via-le-collector)
- [Solution précédente (Extra 4)](sol-4-4.md)
- [Retour au répertoire solutions](../solutions/)
