#!/bin/bash
# Script de déploiement Tempo avec Helm
set -e

NAMESPACE="tempo"
CHART_VERSION="1.3.0"

echo "🚀 Déploiement de Tempo..."

# Ajouter le repo Helm Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Créer le namespace si nécessaire
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Appliquer le secret S3
kubectl apply -f 04-tempo-secret.yaml

# Déployer Tempo
helm upgrade --install tempo grafana/tempo-distributed \
  --namespace ${NAMESPACE} \
  --version ${CHART_VERSION} \
  --values 04-tempo-values.yaml \
  --wait --timeout=15m

echo "✅ Tempo déployé!"
echo ""
echo "📊 Vérification des composants:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "🧪 Test d'envoi d'une trace OTLP:"
echo "  # Utiliser un client OTLP ou Alloy Traces"
echo "  # Endpoint: tempo-distributor.tempo.svc.cluster.local:4317 (gRPC)"

