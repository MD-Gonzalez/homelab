# Homelab Infrastructure

A production-style self-hosted infrastructure platform built on Kubernetes, NixOS, OpenBSD, and Proxmox. All services are self-hosted, all configuration is declarative and version-controlled, and nothing is exposed to the internet except a WireGuard VPN endpoint.

## Architecture Overview

```
Internet
    │
    ▼
[AWS EC2 - Debian]  ← Primary WireGuard endpoint (port 51820)
    │ WireGuard tunnel
    │
[Vultr VPS - OpenBSD]  ← Standby WireGuard endpoint (auto-failover)
    │ WireGuard tunnel
    ▼
[OpenBSD Router - pf firewall]  10.0.0.1
    │ LAN 10.0.0.0/24
    ├──► [Homelab - NixOS + k3s]  10.0.0.50  ← 50+ Kubernetes services
    ├──► [Nix Desktop]  10.0.0.102
    ├──► [LL-Nix - NixOS Laptop]  10.0.0.162
    └──► [Proxmox Server]  10.0.0.60  ← VMs (NixOS HTB, Windows)
```

**Security model:** Nothing is exposed to the internet except WireGuard port 51820 on the VPS endpoints. All services are accessed via WireGuard VPN or LAN only. Automatic failover between AWS EC2 (primary) and Vultr VPS (standby) via a router-side cron script.

## Infrastructure Stack

| Layer | Technology |
|-------|-----------|
| OS | NixOS (declarative, flake-based) |
| Container Orchestration | k3s Kubernetes |
| GitOps / CD | ArgoCD (manual sync, drift detection) |
| Infrastructure as Code | Terraform (AWS + Cloudflare DNS) |
| Load Balancer | MetalLB |
| Ingress | nginx ingress controller |
| TLS | cert-manager + Let's Encrypt (Cloudflare DNS-01) |
| Secret Management | Sealed Secrets |
| Network | OpenBSD pf firewall + WireGuard VPN |
| Virtualization | Proxmox VE (GPU passthrough/VFIO) |
| Monitoring | Prometheus + Grafana |
| Backups | Velero (k8s, local + S3 offsite) + Kopia (file-level) |
| Notifications | Diun + ntfy |

## Services (50+ pods)

### Media
| Service | Description |
|---------|-------------|
| Jellyfin | Media server |
| Radarr | Movie management |
| Sonarr | TV/Anime management |
| Lidarr | Music management (Deemix integration) |
| Prowlarr | Indexer management |
| Bazarr | Subtitle management |
| Jellyseerr | Media requests |
| MusicSeerr | Music requests |
| qBittorrent | Torrent client |
| Navidrome | Music streaming |
| slskd | Soulseek client |
| Soularr | Soulseek automation |

### Productivity
| Service | Description |
|---------|-------------|
| Nextcloud | File sync, notes, tasks, bookmarks, calendar, contacts |
| OnlyOffice | Document editing (integrated with Nextcloud) |
| Immich | Photo backup + ML (facial recognition, smart search) |
| Syncthing | File synchronization across all devices |

### Infrastructure
| Service | Description |
|---------|-------------|
| ArgoCD | GitOps continuous deployment |
| Kopia | Backup server |
| MinIO | S3-compatible storage (Velero local backend) |
| Velero | Kubernetes state backup (local + AWS S3 offsite) |
| Prometheus | Metrics collection |
| Grafana | Dashboards + alerting |
| ntfy | Push notifications to Android |
| Diun | Container update monitoring |
| Sealed Secrets | Secret management |
| cert-manager | TLS certificate automation |
| MetalLB | Load balancer |
| nginx ingress | Reverse proxy / TLS termination |

## NixOS Configuration

All machines are managed declaratively via NixOS flakes. The configuration is fully reproducible — any machine can be rebuilt from scratch using only the flake.

```
nixos/
├── flake.nix              # Flake inputs and host definitions
├── hardware-configuration.nix
└── modules/               # Shared modules
    ├── ssh.nix            # SSH configuration
    ├── syncthing.nix      # Syncthing setup
    ├── kopia.nix          # Backup client (systemd timer)
    ├── sudo.nix           # Sudo rules
    └── ...
```

## Kubernetes Manifests & GitOps

All services are defined as Kubernetes manifests organized by service and managed via ArgoCD. Each service directory typically contains:

```
kubernetes/
└── service-name/
    ├── deployment.yaml      # Pod spec and container config
    ├── service.yaml         # Internal cluster networking
    ├── ingress.yaml         # External access via nginx
    ├── certificate.yaml     # TLS cert via cert-manager
    └── *-sealed.yaml        # Encrypted secrets (Sealed Secrets)
```

ArgoCD monitors this repository and detects any drift between the git state and the live cluster. All syncs are manually approved — nothing is applied automatically without review.

## Secret Management

All secrets are managed via [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets). Rather than storing plaintext credentials in the repository, secrets are encrypted using the cluster's public key before being committed. The encrypted values are completely safe to store in a public repository — they can only be decrypted by the Sealed Secrets controller running inside the specific cluster that generated the key pair. This allows the entire infrastructure to be version-controlled and publicly shared without exposing any sensitive data.

## Network Architecture

- **AWS EC2 (primary)**: Debian VPS running WireGuard, primary endpoint for all VPN clients
- **Vultr VPS (standby)**: OpenBSD VPS running WireGuard, automatic failover target if AWS goes down
- **Failover**: Router-side cron script pings the AWS WireGuard IP every minute — switches routing to Vultr after 3 consecutive failures, fails back when AWS recovers
- **Router (OpenBSD + pf)**: Firewall, NAT, WireGuard client, Unbound DNS resolver
- **Internal DNS**: All `*.sigilos.st` subdomains resolve to the nginx ingress IP (10.0.0.210) via Unbound on the router
- **TLS**: cert-manager automatically issues and renews Let's Encrypt certificates via Cloudflare DNS-01 challenge — no ports need to be open for certificate issuance

## Backup Strategy

- **Kubernetes state (local)**: Velero daily snapshots → MinIO (local S3-compatible storage), 30-day retention
- **Kubernetes state (offsite)**: Velero daily snapshots → AWS S3 bucket, 30-day retention, dedicated least-privilege IAM credentials
- **File-level**: Kopia daily snapshots to the Kopia server running on the homelab
- **Clients**: PC and laptop back up `/home` daily at 2am via systemd timer with `Persistent=true` (runs on boot if the scheduled time was missed)

## Monitoring

Prometheus + Grafana with a custom home dashboard tracking:
- CPU, RAM, and disk usage (with alerting thresholds)
- Pod restart counts per service
- Non-running deployments
- Network traffic (inbound/outbound)
- CPU temperature
- System uptime

Alerts fire to ntfy (self-hosted push notification server) which delivers notifications to Android phones when disk usage exceeds 85%, pods fail, CPU temperature spikes, or RAM usage is high.

## Machines

| Host | OS | Role |
|------|----|------|
| Homelab | NixOS | k3s single-node cluster |
| Nix Desktop | NixOS | Desktop workstation |
| LL-Nix | NixOS | Laptop (AMD+NVIDIA Prime offload) |
| Proxmox | Proxmox VE | Virtualization server |
| nixos-htb | NixOS (VM) | Cybersecurity / HTB labs (NVIDIA GPU passthrough) |

## Prerequisites

To deploy this infrastructure you will need:

- A server or PC running NixOS (this setup uses a single-node k3s cluster)
- Two VPS instances for redundant WireGuard endpoints (AWS EC2 + any OpenBSD VPS)
- A domain name with Cloudflare DNS (required for cert-manager DNS-01 challenge)
- A Cloudflare API token with DNS edit permissions
- A Sealed Secrets controller deployed in your cluster (required to decrypt the sealed secrets in this repo — note: the sealed secrets here are encrypted for this specific cluster and cannot be decrypted elsewhere; you will need to re-seal your own secrets)
- MetalLB configured with an IP range on your LAN
- Basic familiarity with Kubernetes, NixOS, and networking

## Deployment

> **Note:** The Sealed Secrets in this repository are encrypted for this specific cluster's key pair. If you are deploying on a new cluster you will need to generate your own secrets and seal them with your cluster's public key.

### 1. Bootstrap the cluster

```bash
# Install k3s on NixOS
services.k3s.enable = true;

# Apply core infrastructure (order matters)
kubectl apply -f kubernetes/namespaces/
kubectl apply -f kubernetes/metallb/
kubectl apply -f kubernetes/ingress-nginx/
kubectl apply -f kubernetes/cert-manager/
kubectl apply -f kubernetes/storage/
```

### 2. Deploy Sealed Secrets controller

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/latest/download/controller.yaml
```

### 3. Create your own sealed secrets

Each service that requires secrets has a `*-sealed.yaml` file. You will need to recreate these with your own credentials using your cluster's public key:

```bash
# Fetch your cluster's public key
kubeseal --fetch-cert --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system > pub.pem

# Seal a new secret
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --dry-run=client -o yaml | \
  kubeseal --cert pub.pem --format yaml > my-secret-sealed.yaml
```

### 4. Deploy ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 5. Deploy services via ArgoCD

```bash
argocd app create homelab \
  --repo https://github.com/YOUR_USERNAME/homelab.git \
  --path kubernetes \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace homelab \
  --sync-policy none \
  --directory-recurse
```

## Known Issues & Limitations

- **Single node**: The k3s cluster runs on a single node — there is no high availability. If the homelab goes down, all services go down.
- **CGNAT**: The homelab ISP uses CGNAT so the homelab has no public IP. All external access is routed through the VPS via WireGuard.
- **OnlyOffice version pinning**: OnlyOffice is pinned to version 8.2 due to a compatibility issue with the Nextcloud ONLYOFFICE app and newer OnlyOffice versions.
- **Sealed Secrets are cluster-specific**: The encrypted secrets in this repo cannot be decrypted outside of the original cluster. Anyone deploying this will need to generate and seal their own secrets.
- **GPU passthrough**: The NVIDIA GTX 1070 is passed through to either the Windows VM or the NixOS HTB VM — not both simultaneously. Switching requires stopping one VM before starting the other.
- **Music stack**: Some albums are not available on Soulseek or Deezer and require manual sourcing.
- **WireGuard failover**: Automatic failover between AWS and Vultr is handled at the router level only. Mobile clients require manual endpoint switching.

## Infrastructure as Code (Terraform)

All cloud infrastructure and DNS is managed declaratively using Terraform, organized under `terraform/`:

```
terraform/
├── cloudflare/    # Cloudflare DNS records for sigilos.st
└── aws/           # AWS infrastructure (S3, IAM, EC2 role)
```

**Cloudflare DNS** — all public DNS records for `sigilos.st` declared as code including the VPN endpoint, CloudFront distribution, and ACM certificate validation records.

**AWS** — all AWS resources declared and version-controlled:
- S3 buckets (site hosting + Velero offsite backups)
- IAM users with scoped least-privilege policies (CI/CD, backup)
- IAM group with AdministratorAccess
- EC2 instance role for the Debian VPN server
- All IAM policies as JSON

Any change to cloud infrastructure goes through a `terraform plan` review before `terraform apply` — the same GitOps discipline applied to Kubernetes manifests.
