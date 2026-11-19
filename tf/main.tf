variable "region_name" {
  type = string
}
variable "domain_name" {
  type = string
}
variable "clt_size" {
  type = string
}
variable "srv_size" {
  type = string
}
variable "droplet_image" {
  type = string
}
variable "prefix" {
  type = string
}

variable "tag_name" {
  type = string
}

variable "ssh_keys" {
  default = []
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "group_count" {
  type = number
}

# Plage IP dont chaque groupe tire son /24 (10.x.N.0/24 pour le groupe N).
variable "vpc_base_range" {
  type = string
}

resource "digitalocean_tag" "tag" {
  name = var.tag_name
}

# Un VPC par groupe : clt-N et srv-N d'un même groupe se voient sur le réseau
# privé, les groupes restent cloisonnés entre eux. Chaque groupe reçoit un
# /24 découpé depuis vpc_base_range (256 groupes au maximum).
resource "digitalocean_vpc" "group" {
  count    = var.group_count
  name     = "${var.prefix}vpc-${count.index}"
  region   = var.region_name
  ip_range = cidrsubnet(var.vpc_base_range, 8, count.index)
}

# Machine clt-N : poste de travail des labs. Le cluster Kubernetes des TP
# suivants sera un cluster KinD sur cette machine, d'où 8 Go de RAM et un swap.
resource "digitalocean_droplet" "clt" {
  count      = var.group_count
  image      = var.droplet_image
  name       = "${var.prefix}clt-${count.index}"
  region     = var.region_name
  size       = var.clt_size
  tags       = [digitalocean_tag.tag.id]
  vpc_uuid   = digitalocean_vpc.group[count.index].id
  monitoring = true
  ssh_keys   = var.ssh_keys
  user_data = templatefile("${path.module}/cloud-init-clt.yaml", {
    root_password = var.root_password
    lab_id        = count.index
    lab_domain    = var.domain_name
    clt_machine   = "${var.prefix}clt-${count.index}"
    srv_machine   = "${var.prefix}srv-${count.index}"
  })
}

# Machine srv-N : serveur cible des labs (minimal, sans Docker).
resource "digitalocean_droplet" "srv" {
  count      = var.group_count
  image      = var.droplet_image
  name       = "${var.prefix}srv-${count.index}"
  region     = var.region_name
  size       = var.srv_size
  tags       = [digitalocean_tag.tag.id]
  vpc_uuid   = digitalocean_vpc.group[count.index].id
  monitoring = true
  ssh_keys   = var.ssh_keys
  user_data = templatefile("${path.module}/cloud-init-srv.yaml", {
    root_password = var.root_password
    lab_id        = count.index
    lab_domain    = var.domain_name
    clt_machine   = "${var.prefix}clt-${count.index}"
    srv_machine   = "${var.prefix}srv-${count.index}"
  })
}

resource "digitalocean_record" "clt_dns" {
  count  = var.group_count
  domain = var.domain_name
  type   = "A"
  name   = "${var.prefix}clt-${count.index}"
  value  = digitalocean_droplet.clt[count.index].ipv4_address
  ttl    = 60
}

resource "digitalocean_record" "srv_dns" {
  count  = var.group_count
  domain = var.domain_name
  type   = "A"
  name   = "${var.prefix}srv-${count.index}"
  value  = digitalocean_droplet.srv[count.index].ipv4_address
  ttl    = 60
}

resource "digitalocean_project" "training" {
  name        = "training"
  description = "Labs OpenTelemetry"
  environment = "Development"
  # Les VPC ne sont pas assignables à un projet (type de ressource non
  # accepté par l'API) ; seuls les droplets sont regroupés ici.
  resources = flatten([
    [for droplet in digitalocean_droplet.clt : droplet.urn],
    [for droplet in digitalocean_droplet.srv : droplet.urn],
  ])
}

output "clt_hosts" {
  value = [for i in range(var.group_count) : "${var.prefix}clt-${i}.${var.domain_name}"]
}

output "srv_hosts" {
  value = [for i in range(var.group_count) : "${var.prefix}srv-${i}.${var.domain_name}"]
}
