#!/bin/bash
# Script pour restaurer un backup PostgreSQL
# Usage: ./07-restore-backup.sh <backup-file> [namespace] [pod-name]
# Exemple: ./07-restore-backup.sh /backups/20240115/postgres_backup.dump.gz random-db postgres-0

set -e

BACKUP_FILE=${1}
NAMESPACE=${2:-random-db}
POD_NAME=${3:-postgres-0}

if [ -z "$BACKUP_FILE" ]; then
    echo "❌ Erreur: Fichier de backup non spécifié"
    echo "Usage: $0 <backup-file> [namespace] [pod-name]"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Erreur: Fichier de backup non trouvé: $BACKUP_FILE"
    exit 1
fi

echo "=========================================="
echo "Restauration du backup PostgreSQL"
echo "=========================================="
echo "Fichier: $BACKUP_FILE"
echo "Namespace: $NAMESPACE"
echo "Pod: $POD_NAME"
echo ""

# Vérifier que le pod existe
if ! kubectl get pod -n "$NAMESPACE" "$POD_NAME" &>/dev/null; then
    echo "❌ Erreur: Pod $POD_NAME non trouvé dans le namespace $NAMESPACE"
    exit 1
fi

# Décompresser si nécessaire
TEMP_FILE="/tmp/restore_$(basename $BACKUP_FILE)"
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo "[1/4] Décompression du backup..."
    gunzip -c "$BACKUP_FILE" > "$TEMP_FILE"
else
    cp "$BACKUP_FILE" "$TEMP_FILE"
fi

# Copier le fichier dans le pod
echo "[2/4] Copie du backup dans le pod..."
kubectl cp "$TEMP_FILE" "$NAMESPACE/$POD_NAME:/tmp/restore.dump" -c postgres

# Restaurer le backup
echo "[3/4] Restauration du backup..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- bash -c "
    export PGPASSWORD=\$POSTGRES_PASSWORD
    pg_restore \
      -h localhost \
      -U \$POSTGRES_USER \
      -d \$POSTGRES_DB \
      --clean \
      --if-exists \
      /tmp/restore.dump
"

# Nettoyer
echo "[4/4] Nettoyage..."
rm -f "$TEMP_FILE"
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- rm -f /tmp/restore.dump

echo ""
echo "=========================================="
echo "✅ Restauration terminée avec succès!"
echo "=========================================="

