# Solution Lab 4 - Extra 3 : Conserver les versions precedentes de la configuration

## Objectif

<sub>1</sub> Ajouter le parametre `backup: true` a la tache `ansible.builtin.template` afin qu'Ansible conserve automatiquement une copie horodatee de l'ancienne configuration a chaque deploiement.

## Solution

### 1. Modifier le playbook

Dans `playbook.yml`, ajoutez `backup: true` dans la tache qui deploie le template :

```yaml
      ansible.builtin.template:
        src: config.yaml.j2
        dest: /etc/otelcol-contrib/config.yaml
        owner: root
        group: otelcol-contrib
        mode: "0640"
        validate: /usr/bin/otelcol-contrib validate --config=%s
        backup: true
      notify: Redemarrer otelcol-contrib
```

### 2. Redeployer pour tester

```bash
ansible-playbook playbook.yml
```

### 3. Verifier les sauvegardes

```bash
ls -l /etc/otelcol-contrib/config.yaml*
```

<sub>2</sub> Vous verrez des fichiers du type :

```text
config.yaml
config.yaml.2026-11-24@10:15:22~
config.yaml.2026-11-24@10:17:45~
```

Chaque deploiement cree une nouvelle sauvegarde horodatee.

---

<sub>3</sub> **Liens de navigation**

- [Retour au lab 4](../Lab_04_Ansible_Jinja2.md#3-conserver-les-versions-précédentes-de-la-configuration)
- [Solution precedente (Extra 2)](sol-4-2.md)
- [Solution suivante (Extra 4)](sol-4-4.md)
- [Retour au repertoire solutions](../solutions/)
