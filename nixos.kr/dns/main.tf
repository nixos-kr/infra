terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}

variable "zone_id" {
  type        = string
  description = "Cloudflare zone ID for nixos.kr"
}


# GitHub Pages A records
resource "cloudflare_record" "pages_a" {
  for_each = toset([
    "185.199.108.153",
    "185.199.109.153",
    "185.199.110.153",
    "185.199.111.153",
  ])

  zone_id = var.zone_id
  name    = "nixos.kr"
  type    = "A"
  content = each.value
  proxied = false
}

# GitHub Pages verification (www redirect)
resource "cloudflare_record" "pages_www" {
  zone_id = var.zone_id
  name    = "www"
  type    = "CNAME"
  content = "nixos-kr.github.io"
  proxied = false
}

# Discord invite redirect (discord.nixos.kr → Discord server)
resource "cloudflare_record" "discord" {
  zone_id = var.zone_id
  name    = "discord"
  type    = "A"
  content = "192.0.2.1"
  proxied = true
}

resource "cloudflare_ruleset" "discord_redirect" {
  zone_id = var.zone_id
  name    = "Discord redirect"
  kind    = "zone"
  phase   = "http_request_dynamic_redirect"

  rules {
    action = "redirect"
    action_parameters {
      from_value {
        target_url {
          value = "https://discord.gg/6fybcHTnup"
        }
        status_code          = 302
        preserve_query_string = false
      }
    }
    expression  = "(http.host eq \"discord.nixos.kr\")"
    description = "Redirect discord.nixos.kr to Discord invite"
    enabled     = true
  }
}
