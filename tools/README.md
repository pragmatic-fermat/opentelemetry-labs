# Outils du dépôt

## `number-paragraphs.py`

Numérote les paragraphes de corps d'un fichier Markdown avec un numéro discret,
en indice par défaut (`<sub>N</sub>`). Un paragraphe sur deux est numéroté
(`--step 2`, la valeur par défaut), pour alléger la lecture tout en gardant des
points de repère réguliers.

```bash
# Renuméroter un ou plusieurs fichiers sur place
./tools/number-paragraphs.py Lab_04_Ansible_Jinja2.md

# Vérifier, sans écrire : utile en intégration continue
# (code retour 1 si un fichier n'est pas à jour)
./tools/number-paragraphs.py --check Lab_*.md solutions/sol*.md

# Numéroter tous les paragraphes, un par un
./tools/number-paragraphs.py --step 1 Lab_04_Ansible_Jinja2.md

# Passer les numéros en exposant au lieu de l'indice
./tools/number-paragraphs.py --style sup Lab_04_Ansible_Jinja2.md

# Ajouter en plus une ancre stable avant chaque numéro
./tools/number-paragraphs.py --anchors Lab_04_Ansible_Jinja2.md
```

Le script est idempotent : il retire les numéros existants avant de renuméroter,
donc il peut être relancé après chaque ajout ou retrait de paragraphe.

Sont exclus de la numérotation : les titres, les listes (puces et items
numérotés), les tableaux, les citations et encarts d'alerte (`>`), les règles
horizontales (`---`), les blocs de code clôturés, le code indenté, les lignes
HTML et les images.

## Intégration continue

Le workflow `.github/workflows/paragraph-numbers.yml` :

- sur une pull request et sur un push vers `main`, vérifie que `Lab_*.md` et
  `solutions/sol*.md` sont à jour et échoue sinon, avec la commande à lancer ;
- sur déclenchement manuel (`workflow_dispatch`), renumérote les fichiers et
  affiche le diff. Il ne commite que si l'option `commit` est cochée, pour ne
  jamais pousser de commit surprise sur `main`.
