# VPN endpoint - AWS EC2 primary
resource "cloudflare_record" "vpn" {
  zone_id = var.zone_id
  name    = "vpn"
  content = "52.15.238.228"
  type    = "A"
  ttl     = 60
  proxied = false
}

# Sigilos site - CloudFront
resource "cloudflare_record" "root" {
  zone_id = var.zone_id
  name    = "sigilos.st"
  content = "dacqr1a8yoqay.cloudfront.net"
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "www" {
  zone_id = var.zone_id
  name    = "www"
  content = "dacqr1a8yoqay.cloudfront.net"
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

# ACM certificate validation records
resource "cloudflare_record" "acm_validation_www" {
  zone_id = var.zone_id
  name    = "_ad33aa87996bf31623cdc6c1a71ac642.www"
  content = "_97dc1da149385d5b9db22cd4c7402733.jkddzztszm.acm-validations.aws"
  type    = "CNAME"
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "acm_validation_root" {
  zone_id = var.zone_id
  name    = "_c1193d2489d93ec9b6ef6556accf5ee0"
  content = "_1223e75aa6cc462f384fabba53614b24.jkddzztszm.acm-validations.aws"
  type    = "CNAME"
  ttl     = 1
  proxied = false
}
