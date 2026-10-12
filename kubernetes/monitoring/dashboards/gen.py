#!/usr/bin/env python3
"""Grafana dashboards for the Switch kiosk, as code.

Three dashboards, one per sway workspace on the console, each built to fit a
1280x720 panel in kiosk mode without scrolling: 18 grid rows at 30 px plus the
8 px gutters is ~680 px. Run this and commit the ConfigMaps it writes next to
it; ArgoCD applies them and Grafana's sidecar (label grafana_dashboard=1) loads
them within seconds. Kiosk URL: /d/<uid>/?kiosk&refresh=10s
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
DS = {"type": "prometheus", "uid": "prometheus"}
WAN = "enp0s31f6"
PCT = {"mode": "absolute", "steps": [{"color": "green", "value": None}, {"color": "orange", "value": 70}, {"color": "red", "value": 90}]}
OK0 = {"mode": "absolute", "steps": [{"color": "green", "value": None}, {"color": "red", "value": 1}]}

def thr(*steps):
    return {"mode": "absolute", "steps": [{"color": "green", "value": None}] + [{"color": c, "value": v} for c, v in steps]}

def targets(*qs, instant=False, table=False):
    out = []
    for i, q in enumerate(qs):
        expr, legend = (q if isinstance(q, tuple) else (q, ""))
        t = {"datasource": DS, "expr": expr, "legendFormat": legend, "refId": chr(65 + i)}
        if instant: t.update(instant=True, range=False)
        if table: t["format"] = "table"
        out.append(t)
    return out

def panel(kind, title, x, y, w, h, tg, unit="none", thresholds=None, decimals=None, lo=None, hi=None, **extra):
    defaults = {"unit": unit, "thresholds": thresholds or PCT, "color": {"mode": "thresholds"}}
    if decimals is not None: defaults["decimals"] = decimals
    if lo is not None: defaults["min"] = lo
    if hi is not None: defaults["max"] = hi
    p = {"type": kind, "title": title, "datasource": DS, "gridPos": {"x": x, "y": y, "w": w, "h": h},
         "targets": tg, "fieldConfig": {"defaults": defaults, "overrides": []}}
    reduce = {"calcs": ["lastNotNull"], "fields": "", "values": False}
    if kind == "stat":
        p["options"] = {"reduceOptions": reduce, "colorMode": "value", "graphMode": "none", "textMode": "value", "justifyMode": "center", "wideLayout": True}
    elif kind == "gauge":
        p["options"] = {"reduceOptions": reduce, "showThresholdLabels": False, "showThresholdMarkers": True}
    elif kind == "bargauge":
        p["options"] = {"reduceOptions": reduce, "orientation": "horizontal", "displayMode": "gradient", "showUnfilled": True,
                        "valueMode": "color", "namePlacement": "left", "sizing": "auto", "minVizHeight": 14, "maxVizHeight": 28}
        defaults["color"] = {"mode": "continuous-GrYlRd"}
    elif kind == "timeseries":
        p["options"] = {"legend": {"displayMode": "list", "placement": "bottom", "showLegend": True}, "tooltip": {"mode": "multi", "sort": "desc"}}
        defaults["custom"] = {"lineWidth": 2, "fillOpacity": 12, "showPoints": "never", "spanNulls": True}
        defaults["color"] = {"mode": "palette-classic"}
    elif kind == "table":
        p["options"] = {"showHeader": True, "cellHeight": "sm", "footer": {"show": False}}
    p.update(extra)
    return p

def keep(*names):
    """table transformation: only these columns, in this order"""
    return [{"id": "organize", "options": {"includeByName": {n: True for n in names}, "indexByName": {n: i for i, n in enumerate(names)}}}]

def dashboard(uid, title, panels):
    return {"uid": uid, "title": title, "tags": ["switch"], "timezone": "browser", "editable": True, "graphTooltip": 1,
            "refresh": "10s", "time": {"from": "now-1h", "to": "now"}, "schemaVersion": 39, "version": 1, "panels": panels}

# ---------------------------------------------------------------- 1 · Machine
machine = dashboard("switch-machine", "Switch · Machine", [
    panel("stat", "Uptime", 0, 0, 4, 6, targets("max(time() - node_boot_time_seconds)"), unit="dtdurations", thresholds=thr()),
    panel("gauge", "CPU", 4, 0, 4, 6, targets('100 - avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100'), unit="percent", decimals=0, lo=0, hi=100),
    panel("gauge", "RAM", 8, 0, 4, 6, targets("100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)"), unit="percent", decimals=0, lo=0, hi=100),
    panel("stat", "CPU temp", 12, 0, 4, 6, targets('max(node_hwmon_temp_celsius{chip="platform_coretemp_0"})'), unit="celsius", decimals=0, thresholds=thr(("orange", 75), ("red", 90))),
    panel("stat", "Load / core", 16, 0, 4, 6, targets('node_load1 / count(node_cpu_seconds_total{mode="idle"})'), decimals=2, thresholds=thr(("orange", 0.7), ("red", 1))),
    panel("stat", "Alerts firing", 20, 0, 4, 6, targets('count(ALERTS{alertstate="firing", alertname!="Watchdog"}) or vector(0)'), decimals=0, thresholds=OK0,
          options={"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False}, "colorMode": "background", "graphMode": "none", "textMode": "value", "justifyMode": "center"}),
    panel("bargauge", "Disks", 0, 6, 8, 6, targets(*[(f'100 * (1 - node_filesystem_avail_bytes{{mountpoint="{m}"}} / node_filesystem_size_bytes{{mountpoint="{m}"}})', n)
                                                     for m, n in (("/", "/"), ("/data", "/data"), ("/media", "/media"), ("/var/lib/k8s", "k8s"))]),
          unit="percent", decimals=0, lo=0, hi=100, thresholds=thr(("orange", 80), ("red", 90))),
    panel("timeseries", "Network · " + WAN, 8, 6, 16, 12, targets((f'rate(node_network_receive_bytes_total{{device="{WAN}"}}[2m]) * 8', "in"),
                                                                   (f'- rate(node_network_transmit_bytes_total{{device="{WAN}"}}[2m]) * 8', "out")), unit="bps"),
    panel("timeseries", "CPU and RAM", 0, 12, 8, 6, targets(('100 - avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100', "cpu"),
                                                          ("100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)", "ram")), unit="percent", lo=0, hi=100),
])

# ---------------------------------------------------------------- 2 · Cluster
cluster = dashboard("switch-cluster", "Switch · Cluster", [
    panel("stat", "Running", 0, 0, 4, 5, targets('sum(kube_pod_status_phase{phase="Running"})'), decimals=0, thresholds=thr()),
    panel("stat", "Pending", 4, 0, 4, 5, targets('sum(kube_pod_status_phase{phase="Pending"}) or vector(0)'), decimals=0, thresholds=thr(("orange", 1))),
    panel("stat", "Failed", 8, 0, 4, 5, targets('sum(kube_pod_status_phase{phase=~"Failed|Unknown"}) or vector(0)'), decimals=0, thresholds=OK0),
    panel("stat", "Restarts · 1h", 12, 0, 4, 5, targets("sum(increase(kube_pod_container_status_restarts_total[1h]))"), decimals=0, thresholds=thr(("orange", 1), ("red", 5))),
    panel("stat", "Deployments short", 16, 0, 4, 5, targets("count(kube_deployment_status_replicas_unavailable > 0) or vector(0)"), decimals=0, thresholds=OK0),
    panel("stat", "Nodes ready", 20, 0, 4, 5, targets('sum(kube_node_status_condition{condition="Ready", status="true"})'), decimals=0,
          thresholds={"mode": "absolute", "steps": [{"color": "red", "value": None}, {"color": "green", "value": 1}]}),
    panel("table", "Not running", 0, 5, 8, 6, targets('kube_pod_status_phase{phase!~"Running|Succeeded"} == 1', instant=True, table=True), transformations=keep("namespace", "pod", "phase")),
    panel("table", "Restarted · 1h", 0, 11, 8, 7, targets("sum(increase(kube_pod_container_status_restarts_total[1h])) by (namespace, pod) > 0.5", instant=True, table=True),
          decimals=0, transformations=keep("namespace", "pod", "Value") + [{"id": "sortBy", "options": {"sort": [{"field": "Value", "desc": True}]}}]),
    panel("bargauge", "Top CPU · cores", 8, 5, 8, 6, targets(('topk(6, sum(rate(container_cpu_usage_seconds_total{container!="", container!="POD"}[2m])) by (pod))', "{{pod}}"), instant=True),
          decimals=2, lo=0, thresholds=thr()),
    panel("bargauge", "Top memory", 8, 11, 8, 7, targets(('topk(7, sum(container_memory_working_set_bytes{container!="", container!="POD"}) by (pod))', "{{pod}}"), instant=True),
          unit="bytes", lo=0, thresholds=thr()),
    panel("bargauge", "Volumes", 16, 5, 8, 13, targets(("sort_desc(100 * kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes)", "{{persistentvolumeclaim}}"), instant=True),
          unit="percent", decimals=0, lo=0, hi=100, thresholds=thr(("orange", 80), ("red", 90))),
])

# ---------------------------------------------------------------- 3 · Network
network = dashboard("switch-network", "Switch · Network", [
    panel("stat", "WAN in", 0, 0, 4, 5, targets(f'rate(node_network_receive_bytes_total{{device="{WAN}"}}[2m]) * 8'), unit="bps", decimals=1, thresholds=thr()),
    panel("stat", "WAN out", 4, 0, 4, 5, targets(f'rate(node_network_transmit_bytes_total{{device="{WAN}"}}[2m]) * 8'), unit="bps", decimals=1, thresholds=thr()),
    panel("stat", "TCP established", 8, 0, 4, 5, targets("node_netstat_Tcp_CurrEstab"), decimals=0, thresholds=thr()),
    panel("stat", "DNS queries", 12, 0, 4, 5, targets("sum(rate(coredns_dns_requests_total[2m]))"), unit="reqps", decimals=1, thresholds=thr()),
    panel("stat", "DNS errors", 16, 0, 4, 5, targets('100 * (sum(rate(coredns_dns_responses_total{rcode="SERVFAIL"}[2m])) or vector(0)) / sum(rate(coredns_dns_responses_total[2m]))'),
          unit="percent", decimals=1, thresholds=thr(("orange", 1), ("red", 5))),
    panel("stat", "API p99", 20, 0, 4, 5, targets('histogram_quantile(0.99, sum(rate(apiserver_request_duration_seconds_bucket{verb=~"GET|LIST"}[5m])) by (le))'),
          unit="s", decimals=2, thresholds=thr(("orange", 0.5), ("red", 1))),
    panel("table", "Firing alerts", 0, 5, 8, 13, targets('ALERTS{alertstate="firing", alertname!="Watchdog"}', instant=True, table=True), transformations=keep("alertname", "severity", "namespace")),
    panel("timeseries", "WAN throughput", 8, 5, 8, 7, targets((f'rate(node_network_receive_bytes_total{{device="{WAN}"}}[2m]) * 8', "in"),
                                                              (f'- rate(node_network_transmit_bytes_total{{device="{WAN}"}}[2m]) * 8', "out")), unit="bps"),
    panel("timeseries", "DNS by type", 8, 12, 8, 6, targets(("sum(rate(coredns_dns_requests_total[2m])) by (type)", "{{type}}")), unit="reqps"),
    panel("timeseries", "API requests by code", 16, 5, 8, 7, targets(("sum(rate(apiserver_request_total[2m])) by (code)", "{{code}}")), unit="reqps"),
    panel("timeseries", "Connections", 16, 12, 8, 6, targets(("node_netstat_Tcp_CurrEstab", "tcp established"), ("node_nf_conntrack_entries", "conntrack"))),
])

for d in (machine, cluster, network):
    name = d["uid"]
    body = json.dumps(d, indent=2)
    with open(os.path.join(HERE, f"{name}.yaml"), "w") as f:
        f.write("# generated by gen.py - edit the generator, not this file\n")
        f.write(f"apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: {name}\n  namespace: monitoring\n  labels:\n    grafana_dashboard: \"1\"\n")
        f.write(f"data:\n  {name}.json: |\n")
        f.write("".join("    " + line + "\n" for line in body.splitlines()))
    print(f"{name}.yaml: {len(d['panels'])} panels, {max(p['gridPos']['y'] + p['gridPos']['h'] for p in d['panels'])} rows")
