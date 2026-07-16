locals {
  # PET-derived identity, resolved by Octopus at deploy time.
  #   service = project name (checkout|payments)
  #   env     = environment name (production|staging)
  #   tenant  = deployment tenant (empty for untenanted checkout)
  app_namespace = "live-status-#{Octopus.Environment.Name | ToLower}"
  app_instance  = "#{Octopus.Project.Name | ToLower}-#{Octopus.Environment.Name | ToLower}#{if Octopus.Deployment.Tenant.Name}-#{Octopus.Deployment.Tenant.Name | ToLower}#{/if}"

  app_yaml = <<-EOT
apiVersion: v1
kind: Namespace
metadata:
  name: "${local.app_namespace}"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: "${local.app_instance}"
  namespace: "${local.app_namespace}"
  labels:
    app: synthetic-service
    service: "#{Octopus.Project.Name | ToLower}"
spec:
  replicas: 1
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      instance: "${local.app_instance}"
  template:
    metadata:
      labels:
        app: synthetic-service
        instance: "${local.app_instance}"
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: synthetic-service
        image: "ghcr.io/#{Octopus.Action.Package[app].PackageId}:#{Octopus.Action.Package[app].PackageVersion}"
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        env:
        - name: APP_PROJECT
          value: "#{Octopus.Project.Name | ToLower}"
        - name: APP_ENVIRONMENT
          value: "#{Octopus.Environment.Name | ToLower}"
        - name: APP_TENANT
          value: "#{if Octopus.Deployment.Tenant.Name}#{Octopus.Deployment.Tenant.Name | ToLower}#{/if}"
        - name: APP_RELEASE
          value: "#{Octopus.Release.Number}"
        - name: APP_ERROR_RATE
          value: "#{App.ErrorRate}"
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: "${local.app_instance}"
  namespace: "${local.app_namespace}"
  labels:
    app: synthetic-service
spec:
  selector:
    instance: "${local.app_instance}"
  ports:
  - name: http
    port: 80
    targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: "${local.app_instance}"
  namespace: "${local.app_namespace}"
spec:
  ingressClassName: traefik
  rules:
  # Reachable at http://<instance>.localhost (e.g. checkout-production.localhost).
  # Browsers route *.localhost to loopback; for curl add an /etc/hosts entry.
  - host: "${local.app_instance}.localhost"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: "${local.app_instance}"
            port:
              number: 80
EOT

  # Printed on the deployment summary (runs on the Octopus Server). Octostache
  # (#{...}) resolves at deploy time; $${..} are bash vars ($$ escapes $ in the
  # Terraform heredoc so it renders as a single $).
  access_info_script = <<-EOT
INSTANCE="#{Octopus.Project.Name | ToLower}-#{Octopus.Environment.Name | ToLower}#{if Octopus.Deployment.Tenant.Name}-#{Octopus.Deployment.Tenant.Name | ToLower}#{/if}"
NS="live-status-#{Octopus.Environment.Name | ToLower}"
HOST="$${INSTANCE}.localhost"

if command -v write_highlight >/dev/null 2>&1; then
  write_highlight "UI for **$${INSTANCE}**: http://$${HOST} (Ingress), or \`kubectl -n $${NS} port-forward deploy/$${INSTANCE} 8080:8080\`"
fi

echo "==================================================================="
echo " Accessing the '$${INSTANCE}' synthetic-service UI   (namespace: $${NS})"
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
echo "        kubectl -n $${NS} port-forward deploy/$${INSTANCE} 8080:8080"
echo "        then open http://localhost:8080"
echo ""
echo "REAL / shared cluster:"
echo "  - '$${HOST}' is a dev-only hostname. Point a real Ingress host or a"
echo "    LoadBalancer at the '$${INSTANCE}' Service (port 80 -> 8080),"
echo "    or for ad-hoc access:"
echo "        kubectl -n $${NS} port-forward svc/$${INSTANCE} 8080:80"
echo "        then open http://localhost:8080"
echo "==================================================================="
EOT
}
