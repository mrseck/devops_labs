#!/bin/bash
# Script de déploiement Loki avec Helm
set -e

NAMESPACE="loki"
CHART_VERSION="0.69.0"

echo "🚀 Déploiement de Loki..."

# Ajouter le repo Helm Grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Créer le namespace si nécessaire
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Appliquer le secret S3
kubectl apply -f 02-loki-secret.yaml

# Déployer Loki
helm upgrade --install loki grafana/loki-distributed \
  --namespace ${NAMESPACE} \
  --version ${CHART_VERSION} \
  --values 02-loki-values.yaml \
  --wait --timeout=10m

echo "✅ Loki déployé!"
echo ""
echo "📊 Vérification des composants:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "🧪 Test d'ingestion d'un log:"
echo "  kubectl run test-logger --image=busybox --rm -it --restart=Never -- sh -c 'echo \"Test log from pod\"'"
echo "  # Puis vérifier dans Loki via Grafana"

