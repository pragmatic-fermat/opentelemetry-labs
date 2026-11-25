#!/usr/bin/env bash
# Script de rattrapage (fast-forward) pour le lab 4 :
# met en place automatiquement l'etat de fin de partie 3 sur clt-N et srv-N
# (backends Docker, inventaire, playbook d'installation, template Jinja2 et
# premier deploiement du collector), afin de demarrer directement a la partie 4.
#
# Usage (depuis clt-N) :
#   bash ~/opentelemetry-labs/config/lab04/fast-forward-part4.sh
set -euo pipefail

[ -f /etc/profile.d/lab-env.sh ] && . /etc/profile.d/lab-env.sh

: "${CLT_HOST:?CLT_HOST non defini : ouvrez un nouveau terminal web}"
: "${SRV_HOST:?SRV_HOST non defini : ouvrez un nouveau terminal web}"
: "${LAB_ID:?LAB_ID non defini : ouvrez un nouveau terminal web}"

SRC_DIR="${HOME}/opentelemetry-labs/config/lab04"
WORK_DIR="${HOME}/lab04"

echo "=== 1. Preparation de ${WORK_DIR} et demarrage des backends sur clt-${LAB_ID} ==="
mkdir -p "${WORK_DIR}/templates" "${WORK_DIR}/host_vars"
cp -r "${SRC_DIR}/." "${WORK_DIR}/"
cd "${WORK_DIR}"
docker compose up -d

echo "=== 2. Creation de inventory.ini ==="
cat > "${WORK_DIR}/inventory.ini" <<EOF
[otel]
${SRV_HOST}
EOF

echo "=== 3. Creation de templates/config.yaml.j2 ==="
cat > "${WORK_DIR}/templates/config.yaml.j2" <<'EOF'
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

echo "=== 4. Creation de playbook.yml ==="
cat > "${WORK_DIR}/playbook.yml" <<'EOF'
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

# Etat propre de fin de partie 3 : pas de surcharge host_vars.
rm -f "${WORK_DIR}/host_vars/${SRV_HOST}.yml"

echo "=== 5. Deploiement sur ${SRV_HOST} ==="
ansible-playbook "${WORK_DIR}/playbook.yml"

echo "=== 6. Verification ==="
ansible otel -a 'systemctl is-active otelcol-contrib'
curl -s http://localhost:9090/-/ready
echo ""
echo "Environnement pret dans ${WORK_DIR} pour demarrer la partie 4."
