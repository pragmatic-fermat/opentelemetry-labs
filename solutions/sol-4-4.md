# Solution Lab 4 – Extra 4 : Revenir à une version antérieure du binaire

## Objectif

Simuler une régression et revenir de la version 0.165.0 à 0.164.0 du **collector** en utilisant Ansible, tout en gérant les sommes de contrôle et l’option `allow_downgrade`.

## Solution

### 1. Changer la version et les sommes de contrôle

```bash
sed -i 's/otelcol_version: "0.165.0"/otelcol_version: "0.164.0"/' group_vars/all.yml

sed -i 's|amd64: "sha256:dafb5174344dd15f339fd8208783b17122fb4cd37fa7e5461fb09d99df212b4b"|amd64: "sha256:1995260c54cf5d74964a85e5e7d27834bb9a252c87a2582a4fb6a6c34565a90d"|' group_vars/all.yml

sed -i 's|arm64: "sha256:4dcfb6b69dfa10132c593ed5782823eec79dc408a0d68291e1c4adc5879d0948"|arm64: "sha256:34dca7290ff50d8be123c587dff51d93711a59e2cff41895e8801b145749dd0e"|' group_vars/all.yml

grep -A3 'otelcol_checksums' group_vars/all.yml
```

### 2. Autoriser la descente de version dans le playbook

```bash
sed -i 's|        deb: "/tmp/otelcol-contrib_{{ otelcol_version }}.deb"|        deb: "/tmp/otelcol-contrib_{{ otelcol_version }}.deb"\n        allow_downgrade: true|' playbook.yml

grep -A3 'deb:' playbook.yml | head -4
```

### 3. Déployer et vérifier

```bash
ansible-playbook playbook.yml

ansible otel -a '/usr/bin/otelcol-contrib --version'
ansible otel -a 'systemctl is-active otelcol-contrib'
ansible otel -a 'dpkg-query -W otelcol-contrib'
```

**Résultat attendu :**

```text
otelcol-contrib version 0.164.0
active
otelcol-contrib	0.164.0
```

### 4. Remettre en version 0.165.0 (facultatif)

```bash
sed -i 's/otelcol_version: "0.164.0"/otelcol_version: "0.165.0"/' group_vars/all.yml
sed -i '/allow_downgrade: true/d' playbook.yml
ansible-playbook playbook.yml
```

---

**Liens de navigation**

- [Retour au lab 4](../Lab_04_Ansible_Jinja2.md#5-revenir-à-une-version-antérieure-du-binaire)
- [Solution précédente (Extra 3)](sol-4-3.md)
- [Retour au répertoire solutions](../solutions/)
