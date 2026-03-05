# nixos.kr infra

Infrastructure for [nixos.kr](https://nixos.kr) — the Korean NixOS community knowledge base.

## Prerequisites

```bash
cd nixos.kr   # direnv loads the devShell
```

## Deploy site

Pushes to `master` trigger deployment automatically. To deploy manually:

```bash
gh workflow run "Deploy to GitHub Pages" --repo nixos-kr/infra --ref master
```

## DNS management

DNS records are managed declaratively via OpenTofu + Cloudflare.

```bash
cd nixos.kr/dns
cp terraform.tfvars.example terraform.tfvars
# fill in cloudflare_api_token and zone_id
tofu init
tofu plan
tofu apply
```

To import an existing record:

```bash
# find the record ID
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/ZONE_ID/dns_records?name=RECORD_NAME" \
  | jq '.result[0].id'

# import into state
tofu import 'cloudflare_record.RESOURCE_NAME' ZONE_ID/RECORD_ID
```

## Local development

```bash
cd nixos.kr
nix run          # live preview server
nix build        # build static site to ./result
```

## Content

Content lives in `nixos.kr/ko/` as Markdown files with `[[wiki-links]]`. See [Emanote docs](https://emanote.srid.ca) for syntax.
