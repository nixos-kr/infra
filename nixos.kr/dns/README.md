# DNS management

nixos.kr DNS records managed declaratively via OpenTofu + Cloudflare.

## Setup

1. Get Cloudflare credentials:
   - **Zone ID**: Dashboard → nixos.kr → Overview → right sidebar
   - **API Token**: My Profile → API Tokens → Create Token → "Edit zone DNS"

2. Create secret file:
   ```bash
   cp .env.example .env
   # fill in your Cloudflare API token and zone ID
   ```

   > `.env` contains **secrets** and is gitignored. Never commit it.

## Usage

From the `nixos.kr/` directory:

```bash
nix run .#dns -- plan   # preview changes
nix run .#dns           # apply changes
```

## Adding records

Edit `main.tf` and add a new `cloudflare_record` resource:

```hcl
resource "cloudflare_record" "example" {
  zone_id = var.zone_id
  name    = "sub"
  type    = "CNAME"
  content = "example.com"
  proxied = false
}
```

Then `nix run .#dns -- plan` and `nix run .#dns`.

## Importing existing records

If a record already exists in Cloudflare, import it before applying:

```bash
# find the record ID
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records?name=RECORD_NAME" \
  | jq '.result[0].id'

# import into state
nix run .#dns -- import 'cloudflare_record.RESOURCE_NAME' ZONE_ID/RECORD_ID
```
