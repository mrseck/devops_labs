#!/bin/bash
# Script de déploiement kube-prometheus-stack avec Helm
set -e

NAMESPACE="monitoring"
CHART_VERSION="55.0.0"

echo "🚀 Déploiement de kube-prometheus-stack..."

# Ajouter le repo Helm Prometheus Community
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Créer le namespace si nécessaire
kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Déployer kube-prometheus-stack
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace ${NAMESPACE} \
  --version ${CHART_VERSION} \
  --values 11-kube-prometheus-stack-values.yaml \
  --wait --timeout=15m

echo "✅ kube-prometheus-stack déployé!"
echo ""
echo "📊 Vérification des composants:"
kubectl get pods -n ${NAMESPACE}
echo ""
echo "🧪 Test d'une alerte:"
echo "  # Créer un pod qui crashloop pour déclencher une alerte"

