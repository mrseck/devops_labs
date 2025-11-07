#!/bin/bash
# Script pour étendre un PVC PostgreSQL
# Usage: ./06-extend-pvc.sh <namespace> <pvc-name> <new-size>
# Exemple: ./06-extend-pvc.sh random-db postgres-data 60Gi

set -e

NAMESPACE=${1:-random-db}
PVC_NAME=${2:-postgres-data}
NEW_SIZE=${3:-60Gi}

echo "=========================================="
echo "Extension du PVC PostgreSQL"
echo "=========================================="
echo "Namespace: $NAMESPACE"
echo "PVC: $PVC_NAME"
echo "Nouvelle taille: $NEW_SIZE"
echo ""

# Étape 1: Vérifier que le StorageClass supporte l'expansion
echo "[1/5] Vérification du StorageClass..."
PVC_STORAGE_CLASS=$(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.spec.storageClassName}')
if [ -z "$PVC_STORAGE_CLASS" ]; then
    echo "❌ Erreur: StorageClass non trouvé pour le PVC $PVC_NAME"
    exit 1
fi

ALLOW_EXPANSION=$(kubectl get storageclass "$PVC_STORAGE_CLASS" -o jsonpath='{.allowVolumeExpansion}')
if [ "$ALLOW_EXPANSION" != "true" ]; then
    echo "❌ Erreur: Le StorageClass $PVC_STORAGE_CLASS ne supporte pas l'expansion (allowVolumeExpansion != true)"
    exit 1
fi
echo "✅ StorageClass $PVC_STORAGE_CLASS supporte l'expansion"

# Étape 2: Vérifier la taille actuelle
CURRENT_SIZE=$(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.spec.resources.requests.storage}')
echo "[2/5] Taille actuelle: $CURRENT_SIZE"
echo "      Nouvelle taille: $NEW_SIZE"

# Étape 3: Étendre le PVC
echo "[3/5] Extension du PVC..."
kubectl patch pvc -n "$NAMESPACE" "$PVC_NAME" -p "{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"$NEW_SIZE\"}}}}"
echo "✅ PVC mis à jour"

# Étape 4: Vérifier l'extension côté Kubernetes
echo "[4/5] Vérification de l'extension côté Kubernetes..."
TIMEOUT=300  # 5 minutes
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    PVC_STATUS=$(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.status.conditions[?(@.type=="Resizing")].status}')
    if [ "$PVC_STATUS" != "True" ]; then
        PVC_CAPACITY=$(kubectl get pvc -n "$NAMESPACE" "$PVC_NAME" -o jsonpath='{.status.capacity.storage}')
        if [ "$PVC_CAPACITY" == "$NEW_SIZE" ]; then
            echo "✅ PVC étendu avec succès à $PVC_CAPACITY"
            break
        fi
    fi
    echo "   En attente... ($ELAPSED/$TIMEOUT secondes)"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Timeout: L'extension du PVC a pris plus de $TIMEOUT secondes"
    exit 1
fi

# Étape 5: Vérifier l'extension dans le pod PostgreSQL
echo "[5/5] Vérification de l'extension dans le pod..."
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=postgresql -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    echo "⚠️  Aucun pod PostgreSQL trouvé, impossible de vérifier l'extension dans le pod"
    exit 0
fi

echo "   Pod: $POD_NAME"
echo "   Vérification de l'espace disponible dans le pod..."
kubectl exec -n "$NAMESPACE" "$POD_NAME" -c postgres -- df -h /var/lib/postgresql/data

echo ""
echo "=========================================="
echo "✅ Extension terminée avec succès!"
echo "=========================================="
echo ""
echo "Note: Si le filesystem n'a pas été étendu automatiquement,"
echo "vous devrez peut-être redémarrer le pod ou exécuter:"
echo "  kubectl exec -n $NAMESPACE $POD_NAME -c postgres -- resize2fs /dev/..."
echo ""

