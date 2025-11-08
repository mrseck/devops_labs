#!/bin/bash
# Script de déploiement Grafana avec Helm
set -e

NAMESPACE="grafana"
CHART_VERSION="6.57.0"

echo "🚀 Déploiement de Grafana..."

# Ajouter le repo Helm Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Créer le namespace si nécessaire
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Appliquer les datasources
kubectl apply -f 08-grafana-datasources.yaml

# Déployer Grafana
helm upgrade --install grafana grafana/grafana \
  --namespace ${NAMESPACE} \
  --version ${CHART_VERSION} \
  --values 08-grafana-values.yaml \
  --wait --timeout=10m

echo "✅ Grafana déployé!"
echo ""
echo "📊 Accès à Grafana:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/grafana 3000:80"
echo "  Puis ouvrir: http://localhost:3000"
echo "  User: admin"
echo "  Password: admin123!"

