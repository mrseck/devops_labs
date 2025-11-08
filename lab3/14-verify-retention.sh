#!/bin/bash
# Script de vérification de l'espace libéré après rétention
set -e

echo "🔍 Vérification de l'espace de stockage..."

# Vérifier l'espace utilisé dans MinIO
echo "📊 Espace utilisé par bucket MinIO:"
kubectl exec -n minio deployment/minio -- mc du /data

echo ""
echo "📦 Buckets et leurs tailles:"
for bucket in loki-data mimir-blocks mimir-ruler mimir-alertmanager tempo-data; do
    echo "  - ${bucket}:"
    kubectl exec -n minio deployment/minio -- mc du /data/${bucket} 2>/dev/null || echo "    Bucket non trouvé"
done

echo ""
echo "🧹 Vérification des données expirées:"
echo "  Loki: Vérifier les logs > 90 jours"
echo "  Mimir: Vérifier les blocks > 365 jours"
echo "  Tempo: Vérifier les traces > 30 jours"

echo ""
echo "📈 Espace libéré estimé:"
echo "  Utiliser les métriques Prometheus pour calculer l'espace libéré"
echo "  Query: minio_disk_usage_bytes - minio_disk_usage_bytes[7d]"

