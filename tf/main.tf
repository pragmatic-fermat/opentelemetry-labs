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

resource "digitalocean_tag" "tag" {
  name = var.tag_name
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
  monitoring = true
  ssh_keys   = var.ssh_keys
  user_data = templatefile("${path.module}/cloud-init-clt.yaml", {
    root_password = var.root_password
    lab_id        = count.index
    lab_domain    = var.domain_name
    machine       = "${var.prefix}clt-${count.index}"
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
  monitoring = true
  ssh_keys   = var.ssh_keys
  user_data = templatefile("${path.module}/cloud-init-srv.yaml", {
    root_password = var.root_password
    lab_id        = count.index
    lab_domain    = var.domain_name
    machine       = "${var.prefix}srv-${count.index}"
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
