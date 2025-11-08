#!/bin/bash
# Script de vérification rapide de la santé de la stack
set -e

echo "🔍 Vérification de la santé de la stack de monitoring..."
echo ""

check_namespace() {
    local ns=$1
    local name=$2
    
    if kubectl get namespace ${ns} &>/dev/null; then
        local not_running=$(kubectl get pods -n ${ns} --no-headers 2>/dev/null | grep -v Running | wc -l)
        if [ "${not_running}" -eq 0 ]; then
            echo "  ✅ ${name}: OK"
        else
            echo "  ⚠️  ${name}: ${not_running} pod(s) non Running"
            kubectl get pods -n ${ns} | grep -v Running
        fi
    else
        echo "  ❌ ${name}: Namespace non trouvé"
    fi
}

echo "📦 Namespaces et Pods:"
check_namespace "minio" "MinIO"
check_namespace "loki" "Loki"
check_namespace "mimir" "Mimir"
check_namespace "tempo" "Tempo"
check_namespace "alloy-logs" "Alloy Logs"
check_namespace "alloy-metrics" "Alloy Metrics"
check_namespace "alloy-traces" "Alloy Traces"
check_namespace "grafana" "Grafana"
check_namespace "monitoring" "Monitoring"

echo ""
echo "🔌 Services:"
for ns in minio loki mimir tempo alloy-logs alloy-metrics alloy-traces grafana; do
    if kubectl get namespace ${ns} &>/dev/null; then
        svc_count=$(kubectl get svc -n ${ns} --no-headers 2>/dev/null | wc -l)
        echo "  ${ns}: ${svc_count} service(s)"
    fi
done

echo ""
echo "💾 Stockage:"
kubectl get pvc -A | grep -E "(minio|loki|mimir|tempo|grafana)" || echo "  Aucun PVC trouvé"

echo ""
echo "📊 HPA:"
kubectl get hpa -A | grep -E "(loki|mimir|tempo|alloy)" || echo "  Aucun HPA trouvé"

echo ""
echo "✅ Vérification terminée"

