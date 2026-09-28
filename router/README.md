# Router (OpenBSD, 10.0.0.1)

Snapshot of the router's configuration, kept here so it can be diffed and
reviewed. It is *not* applied automatically — copy files back by hand.

| file            | lives at                          | reload with                                  |
|-----------------|-----------------------------------|----------------------------------------------|
| pf.conf         | /etc/pf.conf                      | `doas pfctl -f /etc/pf.conf`                 |
| unbound.conf    | /var/unbound/etc/unbound.conf     | `doas unbound-checkconf && doas unbound-control reload` |
| dhcpd.conf      | /etc/dhcpd.conf                   | `doas rcctl restart dhcpd`                   |
| rc.conf.local   | /etc/rc.conf.local                | (boot-time; `rcctl` for individual services) |
| rc.local        | /etc/rc.local                     | boot-time; applies wg0 peers via `wg setconf` with a retry once DNS is up |
| hostname.wg0    | /etc/hostname.wg0                 | address + up only; peers live in /etc/wireguard/wg0.conf (not in repo)   |
| wg-failover.sh  | /usr/local/bin/wg-failover.sh     | run every minute from root's crontab         |
| crontab.root    | `doas crontab -l`                 | `doas crontab -e`                            |

Not included on purpose: `/etc/wireguard/wg0.conf` (WireGuard private key) and
`/etc/hostname.re*`.

Refresh the snapshot: on the router, copy the files to `~/export` with doas,
then `scp` them into this directory from the homelab box.
