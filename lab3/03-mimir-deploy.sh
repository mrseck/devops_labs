#!/bin/bash
# Script de déploiement Mimir avec Helm
set -e

NAMESPACE="mimir"
CHART_VERSION="6.0.3"

echo "🚀 Déploiement de Mimir..."

# Ajouter le repo Helm Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Créer le namespace si nécessaire
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Appliquer le secret S3
kubectl apply -f 03-mimir-secret.yaml

# Déployer Mimir
helm upgrade --install mimir grafana/mimir-distributed \
  --namespace ${NAMESPACE} \
  --version ${CHART_VERSION} \
  --values 03-mimir-values.yaml \
  --wait --timeout=15m

echo "✅ Mimir déployé!"
echo ""
echo "📊 Vérification des composants:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "🧪 Test d'ingestion de métriques:"
echo "  # Utiliser un exporter Prometheus ou Alloy Metrics"
echo "  # Vérifier dans Mimir via Grafana avec OrgID: pods ou nodes"

