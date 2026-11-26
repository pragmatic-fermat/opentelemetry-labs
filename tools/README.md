# Outils du dépôt

## `number-paragraphs.py`

Numérote les paragraphes de corps d'un fichier Markdown avec un exposant discret
(`<sup>N</sup>`), pour permettre de se repérer dans un texte long et de renvoyer
à un paragraphe précis.

```bash
# Renuméroter un ou plusieurs fichiers sur place
./tools/number-paragraphs.py Lab_04_Ansible_Jinja2.md

# Vérifier, sans écrire : utile en intégration continue (code retour 1 si à jour non)
./tools/number-paragraphs.py --check Lab_04_Ansible_Jinja2.md

# Ajouter en plus une ancre stable avant chaque numéro
./tools/number-paragraphs.py --anchors Lab_04_Ansible_Jinja2.md
```

Le script est idempotent : il retire les numéros existants avant de renuméroter,
donc il peut être relancé après chaque ajout ou retrait de paragraphe.

Sont exclus de la numérotation : les titres, les listes (puces et items
numérotés), les tableaux, les citations et encarts d'alerte (`>`), les blocs de
code clôturés, le code indenté, les lignes HTML et les images.
