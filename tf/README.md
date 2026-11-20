# Infrastructure des labs (Terraform)

Ce dossier décrit les machines des labs sur DigitalOcean. Il est prévu pour être exécuté par Terraform Cloud (TFC).

## Ressources créées

Pour chaque numéro N de 0 à `group_count - 1` (le numéro 0 est celui du formateur) :

- un droplet `clt-N` (poste de travail, Docker et Compose, Ansible, kubectl, helm, kind) et un droplet `srv-N` (serveur cible minimal, sans Docker), initialisés par les fichiers `cloud-init-clt.yaml` et `cloud-init-srv.yaml` ;
- un VPC `vpc-N` (plage `10.20.N.0/24`, découpée depuis `vpc_base_range`) dans lequel sont placés les deux droplets du groupe : les machines d'un même groupe se voient sur le réseau privé, les groupes restent cloisonnés entre eux ;
- deux enregistrements DNS `clt-N` et `srv-N` dans la zone `domain_name` ;
- un tag commun (`tag_name`) et un projet DigitalOcean `training` qui regroupe les droplets (les VPC ne sont pas assignables à un projet, ils restent en dehors).

Chaque machine expose un terminal web (ttyd derrière Caddy) sur `https://clt-N.<domaine>` et `https://srv-N.<domaine>`, protégé par le mot de passe `webshell_password` (compte `stagiaire` dans la basic auth). Le terminal ouvre des sessions directement en root (machines éphémères), le dépôt des labs est cloné dans `/root/opentelemetry-labs`, en SSH avec la clé de déploiement `github_deploy_key` tant que le dépôt est privé, en HTTPS anonyme ensuite. Le cluster Kubernetes des TP suivants sera un cluster KinD sur `clt-N`, d'où les 8 Go de RAM et le swap de 2 Go.

## Utilisation avec TFC

Créez un workspace relié à ce dépôt (workflow par gestion de versions) et indiquez `tf` comme répertoire de travail Terraform (Terraform Working Directory). Définissez ensuite les variables dans le workspace :

| Variable | Type | Rôle |
|---|---|---|
| `do_token` | Terraform, sensible | Jeton d'API DigitalOcean |
| `root_password` | Terraform, sensible | Mot de passe du compte root, injecté dans les fichiers cloud-init |
| `webshell_password` | Terraform, sensible | Mot de passe du webshell (ttyd), communiqué aux stagiaires |
| `github_deploy_key` | Terraform, sensible | Clé de déploiement GitHub (lecture seule) pour cloner le dépôt tant qu'il est privé ; vide quand le dépôt est public |
| `domain_name` | Terraform | Zone DNS DigitalOcean qui reçoit les enregistrements |
| `tag_name` | Terraform | Nom du tag appliqué aux droplets |
| `group_count` | Terraform | Nombre d'environnements, formateur compris |

Les autres variables (`region_name`, `clt_size`, `srv_size`, `droplet_image`, `ssh_keys`, `vpc_base_range`) ont leur valeur dans `common.auto.tfvars`, que TFC charge automatiquement. Aucun secret ne doit être écrit dans ce dossier : le jeton et le mot de passe se saisissent uniquement dans les variables du workspace.

## Versions (vérifiées le 2026-11-19)

Les paquets apt (Docker, Ansible, Caddy) sont installés sans épinglage de version : la dernière version des dépôts est utilisée à chaque création de machine. Les binaires téléchargés hors apt restent épinglés.

| Composant | Version vérifiée | Source |
|---|---|---|
| Image de droplet | Ubuntu 24.04 LTS (`ubuntu-24-04-x64`) | DigitalOcean |
| Docker Engine | 29.8.1 | dépôt officiel Docker |
| Ansible | core 2.16.3 | dépôt Ubuntu noble |
| ttyd | `1.7.7` | GitHub releases |
| Caddy | 2.11.9 | dépôt officiel Caddy |
| yq | `4.54.3` | GitHub releases |
| kubectl | `1.37.2` | dl.k8s.io |
| helm | `4.3.2` | get.helm.sh |
| kind | `0.33.0` | kind.sigs.k8s.io |

## Contrôle en local

```bash
cd tf
terraform init -backend=false
terraform validate
```
