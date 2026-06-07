variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  sensitive   = true
}

variable "zone_id" {
  description = "Cloudflare zone ID for sigilos.st"
}
