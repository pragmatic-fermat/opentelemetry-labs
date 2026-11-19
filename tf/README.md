# Infrastructure des labs (Terraform)

Ce dossier décrit les machines des labs sur DigitalOcean. Il est prévu pour être exécuté par Terraform Cloud (TFC).

## Ressources créées

Pour chaque numéro N de 0 à `group_count - 1` (le numéro 0 est celui du formateur) :

- un droplet `clt-N` et un droplet `srv-N`, initialisés par les fichiers `cloud-init-clt.yaml` et `cloud-init-srv.yaml` ;
- deux enregistrements DNS `clt-N` et `srv-N` dans la zone `domain_name` ;
- un tag commun (`tag_name`) et un projet DigitalOcean `training` qui regroupe les droplets.

## Utilisation avec TFC

Créez un workspace relié à ce dépôt (workflow par gestion de versions) et indiquez `tf` comme répertoire de travail Terraform (Terraform Working Directory). Définissez ensuite les variables dans le workspace :

| Variable | Type | Rôle |
|---|---|---|
| `do_token` | Terraform, sensible | Jeton d'API DigitalOcean |
| `root_password` | Terraform, sensible | Mot de passe du compte root, injecté dans les fichiers cloud-init |
| `domain_name` | Terraform | Zone DNS DigitalOcean qui reçoit les enregistrements |
| `prefix` | Terraform | Préfixe de nommage (déclaré, à renseigner) |
| `tag_name` | Terraform | Nom du tag appliqué aux droplets |
| `group_count` | Terraform | Nombre d'environnements, formateur compris |

Les autres variables (`region_name`, `droplet_size`, `droplet_image`, `ssh_keys`) ont leur valeur dans `common.auto.tfvars`, que TFC charge automatiquement. Aucun secret ne doit être écrit dans ce dossier : le jeton et le mot de passe se saisissent uniquement dans les variables du workspace.

## Contrôle en local

```bash
cd tf
terraform init -backend=false
terraform validate
```
