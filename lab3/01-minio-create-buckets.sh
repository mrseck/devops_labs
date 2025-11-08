#!/bin/bash
# Script de création automatique des buckets MinIO
# Usage: ./01-minio-create-buckets.sh [namespace] [minio-service]

NAMESPACE=${1:-minio}
MINIO_SERVICE=${2:-minio}
MINIO_PORT=9000

echo "🔧 Configuration des buckets MinIO..."

# Attendre que MinIO soit prêt
echo "⏳ Attente de MinIO..."
kubectl wait --for=condition=ready pod -l app=minio -n ${NAMESPACE} --timeout=300s

# Récupérer les credentials depuis le secret
ROOT_USER=$(kubectl get secret minio-credentials -n ${NAMESPACE} -o jsonpath='{.data.root-user}' | base64 -d)
ROOT_PASSWORD=$(kubectl get secret minio-credentials -n ${NAMESPACE} -o jsonpath='{.data.root-password}' | base64 -d)

# Installer mc (MinIO Client) si nécessaire
if ! command -v mc &> /dev/null; then
    echo "📦 Installation de MinIO Client..."
    curl https://dl.min.io/client/mc/release/linux-amd64/mc -o /tmp/mc
    chmod +x /tmp/mc
    MC=/tmp/mc
else
    MC=mc
fi

# Configurer l'alias MinIO
ALIAS="minio-local"
${MC} alias set ${ALIAS} http://localhost:${MINIO_PORT} ${ROOT_USER} ${ROOT_PASSWORD} 2>/dev/null || true

# Port-forward en arrière-plan
echo "🔌 Établissement du port-forward..."
kubectl port-forward -n ${NAMESPACE} svc/${MINIO_SERVICE} ${MINIO_PORT}:${MINIO_PORT} &
PF_PID=$!
sleep 5

# Fonction de nettoyage
cleanup() {
    kill $PF_PID 2>/dev/null || true
}
trap cleanup EXIT

# Configurer l'alias avec le port-forward
${MC} alias set ${ALIAS} http://localhost:${MINIO_PORT} ${ROOT_USER} ${ROOT_PASSWORD}

# Créer les buckets
BUCKETS=("loki-data" "mimir-blocks" "mimir-ruler" "mimir-alertmanager" "tempo-data")

for bucket in "${BUCKETS[@]}"; do
    echo "📦 Création du bucket: ${bucket}"
    ${MC} mb ${ALIAS}/${bucket} 2>/dev/null || echo "  ⚠️  Bucket ${bucket} existe déjà ou erreur"
    
    # Configurer les policies IAM par bucket
    echo "  🔒 Configuration des policies pour ${bucket}..."
    ${MC} anonymous set download ${ALIAS}/${bucket} 2>/dev/null || true
done

# Lister les buckets créés
echo ""
echo "✅ Buckets créés:"
${MC} ls ${ALIAS}

# Afficher les informations de connexion
echo ""
echo "📋 Informations de connexion:"
echo "  Endpoint API: http://${MINIO_SERVICE}.${NAMESPACE}.svc.cluster.local:9000"
echo "  Console: http://${MINIO_SERVICE}.${NAMESPACE}.svc.cluster.local:9001"
echo "  User: ${ROOT_USER}"
echo "  Password: ${ROOT_PASSWORD}"
echo ""
echo "🔐 Pour accéder à la console depuis votre machine:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/${MINIO_SERVICE} 9001:9001"
echo "  Puis ouvrir: http://localhost:9001"

