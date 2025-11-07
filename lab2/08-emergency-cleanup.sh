#!/bin/bash
# Script de nettoyage d'urgence pour libérer de l'espace sur le PVC PostgreSQL
# Usage: ./08-emergency-cleanup.sh <namespace> <pod-name>
# Exemple: ./08-emergency-cleanup.sh random-db postgres-0

set -e

NAMESPACE=${1:-random-db}
POD_NAME=${2:-postgres-0}

echo "=========================================="
echo "Nettoyage d'Urgence - PVC PostgreSQL"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "Pod: $POD_NAME"
echo ""

# Vérifier que le pod existe
if ! kubectl get pod -n "$NAMESPACE" "$POD_NAME" &>/dev/null; then
    echo "❌ Erreur: Pod $POD_NAME non trouvé dans le namespace $NAMESPACE"
    exit 1
fi

# Fonction pour afficher l'espace disponible
show_space() {
    echo "Espace actuel:"
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- df -h /var/lib/postgresql/data | tail -1
    echo ""
}

# Afficher l'espace initial
echo "[État Initial]"
show_space

# 1. Forcer un checkpoint pour archiver les WAL
echo "[1/6] Forçage d'un checkpoint pour archiver les WAL..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- psql -U postgres -d randomdb -c "CHECKPOINT;" || true
echo "✅ Checkpoint effectué"
echo ""

# 2. VACUUM standard (non bloquant)
echo "[2/6] Exécution de VACUUM ANALYZE..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- psql -U postgres -d randomdb -c "VACUUM ANALYZE;" || true
echo "✅ VACUUM ANALYZE terminé"
show_space

# 3. Nettoyer les logs PostgreSQL anciens
echo "[3/6] Suppression des logs PostgreSQL de plus de 7 jours..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- find /var/lib/postgresql/data -name "*.log" -mtime +7 -delete 2>/dev/null || true
echo "✅ Logs anciens supprimés"
show_space

# 4. Nettoyer les fichiers temporaires
echo "[4/6] Suppression des fichiers temporaires..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- find /var/lib/postgresql/data -name "*.tmp" -delete 2>/dev/null || true
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- find /tmp -type f -mtime +1 -delete 2>/dev/null || true
echo "✅ Fichiers temporaires supprimés"
show_space

# 5. Analyser les WAL et suggérer des actions
echo "[5/6] Analyse des WAL..."
WAL_SIZE=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- du -sh /var/lib/postgresql/data/pgdata/pg_wal/ 2>/dev/null | awk '{print $1}' || echo "N/A")
echo "   Taille des WAL: $WAL_SIZE"
if [ "$WAL_SIZE" != "N/A" ]; then
    echo "   ⚠️  Si les WAL sont volumineux, vérifier la configuration de max_wal_size"
fi
echo ""

# 6. Afficher les plus grandes tables
echo "[6/6] Identification des plus grandes tables..."
echo "   Top 10 des tables les plus volumineuses:"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- psql -U postgres -d randomdb -t -c "
SELECT 
    schemaname || '.' || tablename || ' : ' || 
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
" 2>/dev/null || echo "   Impossible de récupérer les informations"
echo ""

# Afficher l'espace final
echo "[État Final]"
show_space

echo "=========================================="
echo "✅ Nettoyage d'urgence terminé"
echo "=========================================="
echo ""
echo "⚠️  Si l'espace est toujours insuffisant, considérer:"
echo "   1. Extension du PVC (voir 06-extend-pvc.sh)"
echo "   2. VACUUM FULL sur les tables les plus volumineuses (bloquant)"
echo "   3. Archivage ou suppression de données anciennes"
echo ""

