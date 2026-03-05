# DNS management

nixos.kr DNS records managed declaratively via OpenTofu + Cloudflare.

## Setup

1. Get Cloudflare credentials:
   - **Zone ID**: Dashboard → nixos.kr → Overview → right sidebar
   - **API Token**: My Profile → API Tokens → Create Token → "Edit zone DNS"

2. Configure:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # fill in cloudflare_api_token and zone_id
   ```

3. Initialize:
   ```bash
   tofu init
   ```

## Usage

```bash
tofu plan    # preview changes
tofu apply   # apply changes
```

## Importing existing records

If a record already exists in Cloudflare, import it before `tofu apply`:

```bash
# find the record ID
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records?name=RECORD_NAME" \
  | jq '.result[0].id'

# import into state
tofu import 'cloudflare_record.RESOURCE_NAME' ZONE_ID/RECORD_ID
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

Then `tofu plan` and `tofu apply`.
