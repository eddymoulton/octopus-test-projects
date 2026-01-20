#!/bin/bash

set -e

# Configuration
NEW_PASSWORD="${ARGOCD_PASSWORD:-Password01!}"
USERNAME="gateway"

echo 'Deploying ArgoCD'
# Idempotent namespace creation
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo 'Waiting for ArgoCD server to be ready'
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=180s

# echo 'Enabling load balancer'
# kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

echo 'Enabling port forwarding on :8089'
# Kill any existing port-forward to ensure idempotency
pkill -f "port-forward svc/argocd-server" || true
kubectl port-forward svc/argocd-server -n argocd 8089:443 >/dev/null 2>&1 &
sleep 3

echo 'Logging in as admin'

# Check if initial password secret exists (indicates first run)
if kubectl get secret argocd-initial-admin-secret -n argocd >/dev/null 2>&1; then
  echo 'Initial password exists - this appears to be first run'
  ARGOCD_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d)

  argocd login localhost:8089 \
    --username admin \
    --password "$ARGOCD_PASSWORD" \
    --insecure

  echo 'Updating admin password'
  argocd account update-password \
    --current-password "$ARGOCD_PASSWORD" \
    --new-password "$NEW_PASSWORD"

  # Delete the initial password secret after successful password change
  kubectl delete secret argocd-initial-admin-secret -n argocd
else
  echo 'Initial password secret not found - using configured password'
fi

# Login with the new password
argocd login localhost:8089 \
  --username admin \
  --password "$NEW_PASSWORD" \
  --insecure

# Add user (idempotent - patch will update if exists)
echo "Adding user: $USERNAME"
kubectl patch configmap/argocd-cm \
  -n argocd \
  --type merge \
  -p "{\"data\":{\"accounts.$USERNAME\":\"apiKey, login\"}}"

# Set permissions (idempotent - patch will update if exists)
echo "Setting permissions"
kubectl patch configmap/argocd-rbac-cm \
  -n argocd \
  --type merge \
  -p "{\"data\":{\"policy.csv\":\"g, $USERNAME, role:admin\"}}"

# Restart argocd-server to pick up configmap changes
# echo "Restarting ArgoCD server to apply changes"
# kubectl rollout restart deployment/argocd-server -n argocd
# kubectl rollout status deployment/argocd-server -n argocd --timeout=180s

# Generate or retrieve access token for gateway user
echo "Managing access token for $USERNAME"
TOKEN_SECRET_NAME="argocd-${USERNAME}-token"

if kubectl get secret "$TOKEN_SECRET_NAME" -n argocd >/dev/null 2>&1; then
  echo "Access token already exists - retrieving from secret"
  GATEWAY_TOKEN=$(kubectl get secret "$TOKEN_SECRET_NAME" -n argocd -o jsonpath="{.data.token}" | base64 -d)
else
  echo "Generating new access token for $USERNAME"
  GATEWAY_TOKEN=$(argocd account generate-token --account "$USERNAME")

  # Store token in Kubernetes secret for future retrieval
  kubectl create secret generic "$TOKEN_SECRET_NAME" \
    -n argocd \
    --from-literal=token="$GATEWAY_TOKEN"
fi

echo ""
echo "=========================================="
echo "ArgoCD Access Token for $USERNAME:"
echo "$GATEWAY_TOKEN"
echo "=========================================="
echo ""

echo "ArgoCD installation and configuration complete!"
