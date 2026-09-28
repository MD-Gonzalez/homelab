#!/bin/sh

AWS_PEER="10.10.0.6"
VULTR_PEER="10.10.0.1"
AWS_PUBKEY="7gEkjxLsR8mI0M9zo5GJX/tkQb1WQrsOK/0XVPBJDg4="
VULTR_PUBKEY="faXOJ2U5Un1t/Qpx2E7NDeIQWMTKNZyYXn1g1q0kfXI="

# Do nothing if the interface has no peers/endpoints (wg setconf never ran after boot).
/usr/local/bin/wg show wg0 endpoints | grep -q ':' || { logger -t wg-failover "wg0 has no endpoints, skipping"; exit 0; }
FAIL_FILE="/tmp/wg_fail_count"
ACTIVE_FILE="/tmp/wg_active"

[ -f "$FAIL_FILE" ] || echo 0 > "$FAIL_FILE"
[ -f "$ACTIVE_FILE" ] || echo "aws" > "$ACTIVE_FILE"

ACTIVE=$(cat "$ACTIVE_FILE")
FAILS=$(cat "$FAIL_FILE")

if [ "$ACTIVE" = "aws" ]; then
    if ping -c 2 -w 2 "$AWS_PEER" > /dev/null 2>&1; then
        echo 0 > "$FAIL_FILE"
    else
        FAILS=$((FAILS + 1))
        echo "$FAILS" > "$FAIL_FILE"
        if [ "$FAILS" -ge 3 ]; then
            doas wg set wg0 peer "$AWS_PUBKEY" allowed-ips 10.10.0.6/32
            doas wg set wg0 peer "$VULTR_PUBKEY" allowed-ips 10.10.0.0/24,10.0.0.0/24
            echo "vultr" > "$ACTIVE_FILE"
            echo 0 > "$FAIL_FILE"
            logger "WireGuard: failed over to Vultr"
        fi
    fi
else
    if ping -c 2 -w 2 "$AWS_PEER" > /dev/null 2>&1; then
        doas wg set wg0 peer "$VULTR_PUBKEY" allowed-ips 10.10.0.1/32
        doas wg set wg0 peer "$AWS_PUBKEY" allowed-ips 10.10.0.0/24,10.0.0.0/24
        echo "aws" > "$ACTIVE_FILE"
        echo 0 > "$FAIL_FILE"
        logger "WireGuard: failed back to AWS"
    fi
fi
