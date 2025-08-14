# Dynamic DNS using DigitalOcean's DNS Services

[![](https://images.microbadger.com/badges/image/tunix/digitalocean-dyndns.svg)](https://microbadger.com/images/tunix/digitalocean-dyndns "Get your own image badge on microbadger.com")

A script that pushes the public IP address of the running machine to DigitalOcean's DNS API's. It supports updating A records (IPv4), AAAA records (IPv6), or both simultaneously for dual-stack operation. The resulting container image is roughly around 7 MB (thanks to Alpine Linux).

## Setup

Assuming you already have a DigitalOcean account and your domain associated with it. 

For single-stack operation (IPv4 only or IPv6 only): Add either an A record (for IPv4) or AAAA record (for IPv6) with the desired name and IP address.

For dual-stack operation: Add both an A record and AAAA record with the desired name and initial IP addresses. The script will manage both records simultaneously.

## Usage

Pick one of the options below using the following settings:

* **DIGITALOCEAN_TOKEN:** The token you generate in DigitalOcean's API settings.
* **DOMAIN:** The domain your subdomain is registered at. (i.e. `foo.com` for `home.foo.com`)
* **NAME:** Subdomain to use. (name in A record) (i.e. `home` for `home.foo.com`). Multiple subdomains must be separated by semicolons `;`
* **SLEEP_INTERVAL:** Polling time in seconds. (default: 300)
* **REMOVE_DUPLICATES:** If set to `"true"`, removes extra DNS records if more than one A record is found on a subdomain. *Note that if this is not enabled, the script will NOT update subdomains with more than one A record* (default: false)
* **USE_IPV6:** If set to `"true"`, manages AAAA records for IPv6 addresses instead of A records for IPv4 addresses. (default: false)
* **USE_DUAL_STACK:** If set to `"true"`, manages both A records (IPv4) and AAAA records (IPv6) simultaneously. Takes precedence over USE_IPV6 when enabled. (default: false)

### Docker (Recommended)

```
$ docker pull tunix/digitalocean-dyndns
$ docker run -d --name dyndns \
    -e DIGITALOCEAN_TOKEN="your_token_here" \
    -e DOMAIN="yourdomain.com" \
    -e NAME="subdomain" \
    -e SLEEP_INTERVAL=2 \
    -e REMOVE_DUPLICATES="true" \
    compscidr/digitalocean-dyndns
```

For dual-stack IPv4/IPv6 support:
```
$ docker run -d --name dyndns \
    -e DIGITALOCEAN_TOKEN="your_token_here" \
    -e DOMAIN="yourdomain.com" \
    -e NAME="subdomain" \
    -e USE_DUAL_STACK="true" \
    -e SLEEP_INTERVAL=2 \
    -e REMOVE_DUPLICATES="true" \
    compscidr/digitalocean-dyndns
```

### Manual

You can also create a cronjob using below command:

```
$ DIGITALOCEAN_TOKEN="your_token_here" DOMAIN="yourdomain.com" NAME="subdomain" SLEEP_INTERVAL=2 ./dyndns.sh
```

For dual-stack IPv4/IPv6 support:
```
$ DIGITALOCEAN_TOKEN="your_token_here" DOMAIN="yourdomain.com" NAME="subdomain" USE_DUAL_STACK="true" SLEEP_INTERVAL=2 ./dyndns.sh
```
