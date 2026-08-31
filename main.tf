terraform {
  required_version = ">= 1.5.0"
}

variable "release" {
  type    = string
  default = "v1.0.0"
}

variable "api_token" {
  type      = string
  sensitive = true
  default   = "tok-aaaa1111"
}

locals {
  common_labels = {
    owner = "platform"
    env   = "staging"
  }
}

# 01 — bez zmian w v2 (no-op)
resource "terraform_data" "noop" {
  input = "constant"
}

# 02 — update in-place, skalar
resource "terraform_data" "update_scalar" {
  input = "replicas=2"
}

# 03 — update in-place, obiekt + lista + mapa (diff zagnieżdżony)
resource "terraform_data" "update_nested" {
  input = {
    image  = "app:1.4.0"
    ports  = [8080, 9090]
    labels = local.common_labels
  }
}

# 04 — replace: destroy → create
resource "terraform_data" "replace_destroy_first" {
  input = "cache-node"

  triggers_replace = {
    volume = "vol-a"
  }
}

# 05 — replace: create → destroy (create_before_destroy)
resource "terraform_data" "replace_create_first" {
  input = "edge-proxy"

  triggers_replace = {
    cert = "cert-2026-01"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 06 — replace wymuszony przez zależność (replace_triggered_by)
#      dodatkowo `input` czytany z atrybutu computed → w planie "(known after apply)"
resource "terraform_data" "replace_by_dependency" {
  input = terraform_data.replace_destroy_first.output

  lifecycle {
    replace_triggered_by = [terraform_data.replace_destroy_first]
  }
}

# 07 — destroy (blok usunięty w v2)
resource "terraform_data" "destroyed" {
  input = "legacy-worker"
}

# 08 — rename adresu (w v2: `renamed_after` + blok `moved`)
resource "terraform_data" "renamed_before" {
  input = "queue-consumer"
}

# 09 — count: 3 instancje, w v2 zjeżdża do 2 (destroy indeksu [2])
resource "terraform_data" "counted" {
  count = 3

  input = "shard-${count.index}"
}

# 10 — for_each: w v2 jeden klucz usunięty, jeden dodany, jeden zmieniony
resource "terraform_data" "for_each_svc" {
  for_each = {
    api    = "api:1.2.0"
    worker = "worker:1.2.0"
    cron   = "cron:1.2.0"
  }

  input = {
    service = each.key
    image   = each.value
  }
}

# 11 — zmiana w configu, ale ignorowana (ignore_changes) → no-op
resource "terraform_data" "ignored" {
  input = "drifts-but-ignored"

  lifecycle {
    ignore_changes = [input]
  }
}

# 12 — wartość sensitive → w planie redakcja "(sensitive value)"
resource "terraform_data" "sensitive_holder" {
  input = {
    token   = var.api_token
    release = var.release
  }
}

output "release" {
  value = var.release
}

output "shard_count" {
  value = length(terraform_data.counted)
}

output "dropped_output" {
  value = terraform_data.destroyed.output
}
