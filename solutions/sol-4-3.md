# Solution Lab 4 – Extra 4 : Conserver les versions précédentes de la configuration

## Objectif

Ajouter le paramètre `backup: true` à la tâche `ansible.builtin.template` afin qu’Ansible conserve automatiquement une copie horodatée de l’ancienne configuration à chaque déploiement.

## Solution

### 1. Modifier le playbook

Dans `playbook.yml`, ajoutez `backup: true` dans la tâche qui déploie le template :

```yaml
      ansible.builtin.template:
        src: config.yaml.j2
        dest: /etc/otelcol-contrib/config.yaml
        owner: root
        group: otelcol-contrib
        mode: "0640"
        validate: /usr/bin/otelcol-contrib validate --config=%s
        backup: true               # ← ajouté
      notify: Redémarrer otelcol-contrib
```

### 2. Redéployer pour tester

```bash
ansible-playbook playbook.yml
```

### 3. Vérifier les sauvegardes

```bash
ls -l /etc/otelcol-contrib/config.yaml*
```

Vous verrez des fichiers du type :

```text
config.yaml
config.yaml.2026-11-24@10:15:22~
config.yaml.2026-11-24@10:17:45~
```

Chaque déploiement crée une nouvelle sauvegarde horodatée.

---

**Liens de navigation**

- [Retour au lab 4](../Lab_04_Ansible_Jinja2.md#3-conserver-les-versions-précédentes-de-la-configuration)
- [Solution précédente (Extra 2)](sol-4-2.md)
- [Solution suivante (Extra 4)](sol-4-4.md)
- [Retour au répertoire solutions](../solutions/)
```

---

### Création du répertoire de navigation

Je vais aussi créer un fichier d’index pour faciliter la navigation :

```bash
cat > solutions/README.md <<'EOF'
# Solutions Lab 4

## Extras

- [Extra 3 – Activer le scraper network](sol-4-3.md)
- [Extra 4 – Conserver les versions précédentes](sol-4-4.md)

## Navigation

- [Retour au lab 4](../Lab_04_Ansible_Jinja2.md)
- [Retour à la racine](../)
EOF
```

Voulez-vous que je crée tout de suite ces fichiers (sol-4-4.md + README.md dans solutions/) ?