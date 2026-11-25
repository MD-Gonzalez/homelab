#!/bin/sh
#
# wg-failover.sh — keep the router's tunnel to the AWS WireGuard relay alive.
# Runs every minute from root's crontab.
#
# AWS is the only endpoint (the Vultr standby was retired). The script:
#   1. re-applies /etc/wireguard/wg0.conf if wg0 came up with no peers
#      (boot-time setconf failed),
#   2. makes sure the AWS peer owns the client + LAN routes,
#   3. if AWS doesn't answer, re-resolves vpn.sigilos.st so a changed EC2
#      IP is picked up within a minute (wg only resolves hostnames once).

WG=/usr/local/bin/wg
IF=wg0
CONF=/etc/wireguard/wg0.conf

AWS_PEER_IP="10.10.0.6"
AWS_PUBKEY="7gEkjxLsR8mI0M9zo5GJX/tkQb1WQrsOK/0XVPBJDg4="
AWS_ENDPOINT="vpn.sigilos.st:51820"
AWS_ALLOWED="10.10.0.0/24"

log() { logger -t wg-failover "$*"; }

aws_endpoint() {
    $WG show $IF endpoints | awk -v k="$AWS_PUBKEY" '$1 == k { print $2 }'
}

# 1. Interface has no peers/endpoints: apply the config again.
if ! $WG show $IF endpoints | grep -q ':'; then
    if $WG setconf $IF $CONF; then
        log "wg0 had no peers, re-applied $CONF"
    else
        log "wg0 has no peers and setconf failed (DNS not up yet?)"
    fi
    exit 0
fi

# 2. AWS must hold the client and LAN routes (undoes any leftover failover).
if ! $WG show $IF allowed-ips | grep "^$AWS_PUBKEY" | grep -q '10\.10\.0\.0/24'; then
    $WG set $IF peer "$AWS_PUBKEY" allowed-ips "$AWS_ALLOWED"
    log "restored AWS allowed-ips ($AWS_ALLOWED)"
fi

# 3. AWS answering: nothing to do.
ping -c 2 -w 2 "$AWS_PEER_IP" > /dev/null 2>&1 && exit 0

# AWS unreachable: look the hostname up again in case the IP changed.
OLD=$(aws_endpoint)
if $WG set $IF peer "$AWS_PUBKEY" endpoint "$AWS_ENDPOINT"; then
    NEW=$(aws_endpoint)
    if [ "$OLD" != "$NEW" ]; then
        log "AWS endpoint changed: $OLD -> $NEW"
    fi
else
    log "AWS unreachable and $AWS_ENDPOINT did not resolve; keeping $OLD"
fi
