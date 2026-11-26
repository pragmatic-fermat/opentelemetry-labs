# Solution Lab 4 - Extra 2 : Activer le scraper `network` du receiver `hostmetrics`

## Objectif

<sub>1</sub> Activer le scraper `network` du receiver `hostmetrics`, redéployer le **collector** et vérifier que les métriques réseau arrivent dans Prometheus.

## Solution

### 1. Modifier le template

Dans `templates/config.yaml.j2`, décommentez et activez le scraper `network` dans la section `hostmetrics` :

```yaml
  hostmetrics:
    collection_interval: 30s
    scrapers:
      cpu: {}
      load: {}
      memory: {}
      network: {}          # active
```

### 2. Redéployer

```bash
ansible-playbook playbook.yml
```

### 3. Vérifier

```bash
ansible otel -a 'grep -c network /etc/otelcol-contrib/config.yaml'
```

```bash
curl -s -G "http://localhost:9090/api/v1/query" \
  --data-urlencode "query=system_network_packets" \
  | jq -r '.data.result[0] | "\(.metric.instance) : \(.value[1])"'
```

<sub>2</sub> Vous verrez alors des métriques telles que `system_network_packets`, `system_network_io` et `system_network_errors`.

---

**Liens de navigation**

- [Retour au lab 4](../Lab_04_Ansible_Jinja2.md#2-activer-le-scraper-network-du-receiver-hostmetrics-extra)
- [Solution suivante (Extra 3)](sol-4-3.md)
- [Retour au répertoire solutions](../solutions/)
