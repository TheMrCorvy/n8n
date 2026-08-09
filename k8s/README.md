# n8n – Kubernetes Manifests
#
# This directory is a STARTING POINT for running n8n on Kubernetes.
# It mirrors the Docker Compose configuration as closely as possible.
#
# Assumptions
# -----------
# * kubectl is configured and pointing at the target cluster.
# * A StorageClass that supports ReadWriteOnce PVCs is available
#   (most cloud providers and k3s/kind ship one by default).
# * You have already created the "n8n" namespace:
#     kubectl create namespace n8n
# * You have created the Secret (see Secret section below).
#
# Apply everything with:
#   kubectl apply -k k8s/
# or individually:
#   kubectl apply -f k8s/namespace.yaml
#   kubectl apply -f k8s/secret.yaml        ← fill in values first!
#   kubectl apply -f k8s/pvc.yaml
#   kubectl apply -f k8s/deployment.yaml
#   kubectl apply -f k8s/service.yaml
#
# ─────────────────────────────────────────────────────────────────────────
# NOTE: This is intentionally minimal. Production clusters should also
# add:  Ingress, TLS (cert-manager), HorizontalPodAutoscaler, NetworkPolicy,
#        and resource quotas.
# ─────────────────────────────────────────────────────────────────────────
