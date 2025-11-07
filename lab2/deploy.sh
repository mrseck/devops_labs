#!/bin/bash
# Script de déploiement complet pour le Lab 2
# Usage: ./deploy.sh [namespace]

set -e

NAMESPACE=${1:-random-db}

echo "=========================================="
echo "Déploiement Lab 2 - PostgreSQL PVC"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo ""

# Vérifier que le namespace existe
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    echo "❌ Erreur: Le namespace $NAMESPACE n'existe pas"
    echo "   Créez-le d'abord avec: kubectl create namespace $NAMESPACE"
    exit 1
fi

# Étape 1: StorageClass
echo "[1/8] Création du StorageClass..."
kubectl apply -f 01-storageclass.yaml
echo "✅ StorageClass créé"
kubectl get storageclass fast-ssd-expandable
echo ""

# Étape 2: ConfigMap et Secret
echo "[2/8] Création du ConfigMap et Secret..."
kubectl apply -f 02-postgres-configmap.yaml
kubectl apply -f 02-postgres-secret.yaml
echo "✅ ConfigMap et Secret créés"
echo ""

# Étape 3: StatefulSet et Services
echo "[3/8] Déploiement du StatefulSet PostgreSQL..."
kubectl apply -f 02-postgres-statefulset.yaml
kubectl apply -f 02-postgres-service-metrics.yaml
echo "✅ StatefulSet et Services créés"
echo ""

# Attendre que le pod soit prêt
echo "[4/8] Attente du démarrage du pod PostgreSQL..."
kubectl wait --for=condition=ready pod -n "$NAMESPACE" -l app=postgresql --timeout=300s || {
    echo "⚠️  Le pod n'est pas prêt après 5 minutes. Vérifiez les logs:"
    echo "   kubectl logs -n $NAMESPACE -l app=postgresql"
}
echo ""

# Vérifier le PVC
echo "[5/8] Vérification du PVC..."
kubectl get pvc -n "$NAMESPACE"
PVC_STATUS=$(kubectl get pvc -n "$NAMESPACE" postgres-data -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
if [ "$PVC_STATUS" != "Bound" ]; then
    echo "⚠️  Le PVC n'est pas encore lié. Vérifiez:"
    echo "   kubectl describe pvc -n $NAMESPACE postgres-data"
else
    echo "✅ PVC lié avec succès"
fi
echo ""

# Étape 6: ServiceMonitor
echo "[6/8] Configuration du ServiceMonitor..."
kubectl apply -f 03-servicemonitor.yaml
echo "✅ ServiceMonitor créé"
echo ""

# Étape 7: PrometheusRules
echo "[7/8] Configuration des PrometheusRules..."
kubectl apply -f 04-prometheusrule.yaml
echo "✅ PrometheusRules créées"
echo ""

# Étape 8: Dashboard Grafana
echo "[8/8] Configuration du dashboard Grafana..."
kubectl apply -f 05-grafana-dashboard-configmap.yaml
echo "✅ ConfigMap du dashboard créé"
echo "   Note: Importez le dashboard depuis Grafana UI ou utilisez l'API"
echo ""

# Résumé
echo "=========================================="
echo "✅ Déploiement terminé!"
echo "=========================================="
echo ""
echo "Vérifications:"
echo "  - Pods:        kubectl get pods -n $NAMESPACE"
echo "  - PVC:         kubectl get pvc -n $NAMESPACE"
echo "  - Services:    kubectl get svc -n $NAMESPACE"
echo "  - Métriques:   kubectl port-forward -n $NAMESPACE svc/postgres-metrics 9090:9090"
echo ""
echo "Test de connexion:"
echo "  kubectl exec -it -n $NAMESPACE postgres-0 -c postgres -- psql -U postgres -d randomdb"
echo ""
echo "Monitoring:"
echo "  - Vérifier les métriques dans Prometheus"
echo "  - Importer le dashboard Grafana depuis 05-grafana-dashboard.json"
echo ""

