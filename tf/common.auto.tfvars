# Valeurs par défaut communes aux groupes. Les secrets (do_token,
# root_password) et les variables par groupe (domain_name, tag_name,
# group_count) se saisissent dans le workspace Terraform Cloud, jamais ici.
#
# Image Ubuntu 24.04 LTS (gabarit vérifié le 2026-11-19).
droplet_image = "ubuntu-24-04-x64"

# Poste de travail : 8 Go de RAM (Docker + cluster KinD à venir).
clt_size = "s-4vcpu-8gb-intel"
# Machine serveur : le TP1 y déploie la stack Docker (Jaeger, Prometheus,
# Grafana, Collector), 4 Go de RAM.
srv_size = "s-2vcpu-4gb"

# Région où les resources sont créées.
region_name = "ams3"

# Clé SSH (ID DigitalOcean) autorisée en plus sur chaque droplet.
ssh_keys = ["24566267"]

# Plage dont chaque groupe tire son /24 de VPC (groupe N : 10.20.N.0/24).
vpc_base_range = "10.20.0.0/16"
