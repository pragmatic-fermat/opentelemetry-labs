# Solutions Lab 4 – Extras 3 et 4

## Extra 3 : Activer le scraper `network` du receiver `hostmetrics`

### Solution

1. **Modifier le template** (`templates/config.yaml.j2`)

Dans la section `hostmetrics`, décommentez et activez le scraper `network` :

```yaml
  hostmetrics:
    collection_interval: 30s
    scrapers:
      cpu: {}
      load: {}
      memory: {}
      network: {}          # ← activé
```

2. **Redéployer**

```bash
ansible-playbook playbook.yml
```

3. **Vérifier**

```bash
# Nombre de métriques réseau collectées
ansible otel -a 'grep -c network /etc/otelcol-contrib/config.yaml'

# Exemple de métriques visibles dans Prometheus
curl -s -G "http://localhost:9090/api/v1/query" \
  --data-urlencode "query=system_network_packets" \
  | jq -r '.data.result[0] | "\(.metric.instance) : \(.value[1])"'
```

Vous verrez alors des métriques telles que :
- `system_network_packets`
- `system_network_io`
- `system_network_errors`

---

**Liens de navigation**

- [Retour au lab 4](../Lab_04_Ansible_Jinja2.md#2-activer-le-scraper-network-du-receiver-hostmetrics-extra)
- [Solution suivante (Extra 3)](sol-4-3.md)
- [Retour au répertoire solutions](../solutions/)

---

## Extra 4 : Conserver les versions précédentes de la configuration

### Solution

1. **Ajouter le paramètre `backup` dans la tâche de template**

Modifiez la tâche `Déployer la configuration` dans `playbook.yml` :

```yaml
      ansible.builtin.template:
        src: config.yaml.j2
        dest: /etc/otelcol-contrib/config.yaml
        owner: root
        group: otelcol-contrib
        mode: "0640"
        validate: /usr/bin/otelcol-contrib validate --config=%s
        backup: true          # ← ajouté
      notify: Redémarrer otelcol-contrib
```

2. **Vérifier les sauvegardes après plusieurs déploiements**

```bash
ls -l /etc/otelcol-contrib/config.yaml*
```

Ansible crée automatiquement des fichiers de la forme :
- `config.yaml.2026-11-24@09:45:12~`
- `config.yaml.2026-11-24@09:47:33~`

Chaque déploiement conserve une copie horodatée de l’ancienne version.

---

Ces deux extras sont maintenant documentés de manière autonome dans `solutions/sol-4-3.md`.  
Vous pouvez les copier-coller ou les adapter selon vos besoins.