terraform {
  required_version = ">= 1.5.0"
}

variable "release" {
  type    = string
  default = "v2.0.0" # ZMIANA — wpływa na #12 i na output
}

variable "api_token" {
  type      = string
  sensitive = true
  default   = "tok-bbbb2222" # ZMIANA — diff zredagowany jako (sensitive value)
}

locals {
  common_labels = {
    owner = "platform"
    env   = "staging"
    tier  = "edge" # ZMIANA — nowy klucz w mapie, wpływa na #03
  }
}

# 01 — no-op: nic nie tykamy
resource "terraform_data" "noop" {
  input = "constant"
}

# 02 — update in-place: ~ input
resource "terraform_data" "update_scalar" {
  input = "replicas=5" # ZMIANA (było replicas=2)
}

# 03 — update in-place, zagnieżdżony:
#      bump wersji obrazu, nowy element listy, nowy klucz w mapie
resource "terraform_data" "update_nested" {
  input = {
    image  = "app:1.5.2"          # ZMIANA
    ports  = [8080, 9090, 9091]   # ZMIANA — dopisany element
    labels = local.common_labels  # ZMIANA — przez locals
  }
}

# 04 — replace destroy → create: zmiana triggers_replace
resource "terraform_data" "replace_destroy_first" {
  input = "cache-node"

  triggers_replace = {
    volume = "vol-b" # ZMIANA (było vol-a)
  }
}

# 05 — replace create → destroy: zmiana triggers_replace + create_before_destroy
resource "terraform_data" "replace_create_first" {
  input = "edge-proxy"

  triggers_replace = {
    cert = "cert-2026-08" # ZMIANA (było cert-2026-01)
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 06 — replace przez zależność: config nietknięty, replace bo #04 idzie do replace
resource "terraform_data" "replace_by_dependency" {
  input = terraform_data.replace_destroy_first.output

  lifecycle {
    replace_triggered_by = [terraform_data.replace_destroy_first]
  }
}

# 07 — create: nowy blok, którego w v1 nie było
resource "terraform_data" "created" {
  input = "metrics-shipper"
}

# 08 — move: `renamed_before` → `renamed_after`, config bez zmian.
#      Bez bloku `moved` byłoby to destroy + create.
resource "terraform_data" "renamed_after" {
  input = "queue-consumer"
}

moved {
  from = terraform_data.renamed_before
  to   = terraform_data.renamed_after
}

# 09 — count 3 → 2: destroy instancji [2], pozostałe bez zmian
resource "terraform_data" "counted" {
  count = 2 # ZMIANA (było 3)

  input = "shard-${count.index}"
}

# 10 — for_each: "cron" usunięty (destroy), "scheduler" dodany (create),
#      "api" z nowym obrazem (update), "worker" bez zmian (no-op)
resource "terraform_data" "for_each_svc" {
  for_each = {
    api       = "api:1.3.0"       # ZMIANA
    worker    = "worker:1.2.0"    # bez zmian
    scheduler = "scheduler:0.1.0" # NOWY klucz
    # cron — USUNIĘTY klucz
  }

  input = {
    service = each.key
    image   = each.value
  }
}

# 11 — no-op mimo zmiany w configu: ignore_changes zjada diff
resource "terraform_data" "ignored" {
  input = "value-changed-in-config" # ZMIANA, ale ignorowana
}

# 12 — update in-place z wartością sensitive:
#      release widoczny w diffie, token zredagowany
resource "terraform_data" "sensitive_holder" {
  input = {
    token   = var.api_token
    release = var.release
  }
}

# --- outputs: jeden zmieniony, jeden nowy, jeden usunięty ---

output "release" {
  value = var.release # ZMIANA wartości
}

output "shard_count" {
  value = length(terraform_data.counted) # ZMIANA (3 → 2)
}

output "service_names" {
  value = keys(terraform_data.for_each_svc) # NOWY output
}

# output "dropped_output" — USUNIĘTY
