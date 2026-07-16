locals {
  # NOTE: Prometheus relabel replacements use $1/$2 for regex capture groups.
  # Terraform only treats ${...} as interpolation, so bare $1/$2 pass through
  # unchanged. Do NOT write $$1/$$2 (Terraform leaves $$ as-is, then Prometheus
  # collapses $$ to a literal $ and the address rewrite breaks), nor ${1}/${2}
  # (Terraform would evaluate that as interpolation).
  prometheus_yaml = <<-EOT
apiVersion: v1
kind: Namespace
metadata:
  name: ${var.monitoring_namespace}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: ${var.monitoring_namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus-live-status
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints", "nodes", "namespaces"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus-live-status
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus-live-status
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: ${var.monitoring_namespace}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: ${var.monitoring_namespace}
data:
  prometheus.yml: |
    global:
      scrape_interval: 5s
      evaluation_interval: 5s
    scrape_configs:
      - job_name: synthetic-service
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          # keep only pods annotated prometheus.io/scrape: "true"
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: "true"
          # honour prometheus.io/path
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          # rewrite address to pod-ip:prometheus.io/port
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: $1:$2
            target_label: __address__
          # surface pod labels + namespace/pod for context
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            action: replace
            target_label: kubernetes_namespace
          - source_labels: [__meta_kubernetes_pod_name]
            action: replace
            target_label: kubernetes_pod_name
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: ${var.monitoring_namespace}
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
        - name: prometheus
          image: prom/prometheus:v3.13.1
          args:
            - --config.file=/etc/prometheus/prometheus.yml
          ports:
            - containerPort: 9090
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
      volumes:
        - name: config
          configMap:
            name: prometheus-config
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: ${var.monitoring_namespace}
spec:
  selector:
    app: prometheus
  ports:
    - port: 9090
      targetPort: 9090
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus
  namespace: ${var.monitoring_namespace}
spec:
  ingressClassName: traefik
  rules:
  # Reachable at http://prometheus.localhost. Browsers route *.localhost to
  # loopback; for curl add an /etc/hosts entry.
  - host: prometheus.localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus
            port:
              number: 9090
EOT

  # Printed on the deployment summary (runs on the Octopus Server).
  access_info_script = <<-EOT
NS="${var.monitoring_namespace}"
HOST="prometheus.localhost"

if command -v write_highlight >/dev/null 2>&1; then
  write_highlight "Prometheus UI: http://$${HOST} (Ingress), or \`kubectl -n $${NS} port-forward svc/prometheus 9090:9090\`"
fi

echo "==================================================================="
echo " Accessing Prometheus   (namespace: $${NS})"
echo "==================================================================="
echo ""
echo "DEV cluster (Colima / Docker Desktop / k3d):"
echo "  Ingress (Traefik):  http://$${HOST}"
echo "    - browsers resolve *.localhost to loopback automatically"
echo "    - curl: add '127.0.0.1 $${HOST}' to /etc/hosts"
echo "    - Colima: LoadBalancer ports auto-forward; otherwise run:"
echo "        kubectl -n kube-system port-forward svc/traefik 80:80"
echo "    - Docker Desktop built-in k8s has NO ingress controller:"
echo "        use k3d (--port '80:80@loadbalancer') or install one"
echo "  Always-works fallback (no ingress needed):"
echo "        kubectl -n $${NS} port-forward svc/prometheus 9090:9090"
echo "        then open http://localhost:9090"
echo ""
echo "REAL / shared cluster:"
echo "  - '$${HOST}' is a dev-only hostname. Point a real Ingress host or a"
echo "    LoadBalancer at svc/prometheus (port 9090), or for ad-hoc access:"
echo "        kubectl -n $${NS} port-forward svc/prometheus 9090:9090"
echo "        then open http://localhost:9090"
echo "==================================================================="
EOT
}
