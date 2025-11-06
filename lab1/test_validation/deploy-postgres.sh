#!/bin/bash

###############################################################################
# Script: deploy-postgres.sh
# Description: Déploiement de PostgreSQL avec PVC
# Usage: ./deploy-postgres.sh
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║           Déploiement PostgreSQL pour Random App             ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# 1. Vérifier que le namespace existe
echo ""
echo "🔍 Vérification du namespace random-db..."
if ! kubectl get namespace random-db &>/dev/null; then
    echo -e "${RED}[✗]${NC} Le namespace random-db n'existe pas!"
    echo "Exécutez d'abord: kubectl create namespace random-db"
    exit 1
fi
echo -e "${GREEN}[✓]${NC} Namespace random-db existe"

# 2. Vérifier que le PVC existe
echo ""
echo "🔍 Vérification du PVC postgres-data-pvc..."
if ! kubectl get pvc postgres-data-pvc -n random-db &>/dev/null; then
    echo -e "${RED}[✗]${NC} Le PVC postgres-data-pvc n'existe pas!"
    echo "Exécutez d'abord: ./07-setup-simple-storage.sh"
    exit 1
fi

PVC_STATUS=$(kubectl get pvc postgres-data-pvc -n random-db -o jsonpath='{.status.phase}')
echo -e "${YELLOW}[i]${NC} Status actuel du PVC: $PVC_STATUS"

if [ "$PVC_STATUS" = "Bound" ]; then
    echo -e "${YELLOW}[⚠]${NC} Le PVC est déjà Bound. Un pod l'utilise probablement."
    read -p "Continuer quand même? (yes/no): " continue_anyway
    if [ "$continue_anyway" != "yes" ]; then
        exit 0
    fi
fi

# 3. Vérifier le ResourceQuota
echo ""
echo "📊 Vérification des quotas..."
kubectl get resourcequota random-db-quota -n random-db

# 4. Vérifier si PostgreSQL existe déjà
echo ""
if kubectl get deployment postgres -n random-db &>/dev/null; then
    echo -e "${YELLOW}[⚠]${NC} Un déploiement 'postgres' existe déjà!"
    read -p "Voulez-vous le supprimer et le recréer? (yes/no): " recreate
    if [ "$recreate" = "yes" ]; then
        echo "Suppression de l'ancien déploiement..."
        kubectl delete deployment postgres -n random-db --ignore-not-found=true
        kubectl delete service postgres -n random-db --ignore-not-found=true
        sleep 5
    else
        echo "Annulation du déploiement"
        exit 0
    fi
fi

# 5. Déployer PostgreSQL
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  DÉPLOIEMENT POSTGRESQL"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "📦 Application du manifeste PostgreSQL..."
kubectl apply -f deployment-pgsql.yml

echo ""
echo "⏳ Attente du démarrage de PostgreSQL..."
echo "   (Cela peut prendre 30-60 secondes pour l'initialisation)"

# Attendre que le pod soit créé
sleep 5

# Attendre que le deployment soit prêt (timeout 2 minutes)
if kubectl wait --for=condition=available --timeout=120s deployment/postgres -n random-db; then
    echo -e "${GREEN}[✓]${NC} PostgreSQL est prêt!"
else
    echo -e "${RED}[✗]${NC} Timeout - PostgreSQL n'est pas prêt"
    echo ""
    echo "Vérification des pods:"
    kubectl get pods -n random-db -l component=database
    echo ""
    echo "Logs du pod:"
    kubectl logs -n random-db -l component=database --tail=30
    exit 1
fi

# 6. Vérifications
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  VÉRIFICATIONS"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "📊 Status du PVC (devrait être Bound maintenant):"
kubectl get pvc postgres-data-pvc -n random-db

echo ""
echo "🐘 Status du déploiement PostgreSQL:"
kubectl get deployment postgres -n random-db

echo ""
echo "🔌 Status du service PostgreSQL:"
kubectl get service postgres -n random-db

echo ""
echo "📦 Pods PostgreSQL:"
kubectl get pods -n random-db -l component=database

echo ""
echo "💾 PersistentVolume créé:"
PV_NAME=$(kubectl get pvc postgres-data-pvc -n random-db -o jsonpath='{.spec.volumeName}')
if [ -n "$PV_NAME" ]; then
    kubectl get pv "$PV_NAME"
else
    echo -e "${YELLOW}[⚠]${NC} Aucun PV trouvé (le PVC est peut-être encore Pending)"
fi

# 7. Test de connectivité
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  TEST DE CONNECTIVITÉ"
echo "════════════════════════════════════════════════════════════════"

echo ""
echo "🧪 Test de connexion à PostgreSQL..."
sleep 5

POD_NAME=$(kubectl get pod -n random-db -l component=database -o jsonpath='{.items[0].metadata.name}')

if [ -n "$POD_NAME" ]; then
    echo "Pod trouvé: $POD_NAME"
    echo ""
    
    # Test de connexion
    if kubectl exec -n random-db "$POD_NAME" -- psql -U randomuser -d randomdb -c "SELECT version();" > /dev/null 2>&1; then
        echo -e "${GREEN}[✓]${NC} Connexion PostgreSQL réussie!"
        
        echo ""
        echo "Version de PostgreSQL:"
        kubectl exec -n random-db "$POD_NAME" -- psql -U randomuser -d randomdb -c "SELECT version();"
        
        echo ""
        echo "Bases de données disponibles:"
        kubectl exec -n random-db "$POD_NAME" -- psql -U randomuser -d randomdb -c "\l"
    else
        echo -e "${YELLOW}[⚠]${NC} Impossible de se connecter (PostgreSQL démarre peut-être encore)"
        echo ""
        echo "Logs récents:"
        kubectl logs -n random-db "$POD_NAME" --tail=20
    fi
else
    echo -e "${RED}[✗]${NC} Aucun pod PostgreSQL trouvé"
fi

# 8. Afficher les quotas utilisés
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  UTILISATION DES QUOTAS"
echo "════════════════════════════════════════════════════════════════"
kubectl get resourcequota random-db-quota -n random-db

# 9. Instructions finales
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           DÉPLOIEMENT POSTGRESQL TERMINÉ                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

cat << 'EOF'
✅ COMPOSANTS DÉPLOYÉS:
   • Deployment: postgres (namespace: random-db)
   • Service: postgres (ClusterIP sur port 5432)
   • Secret: postgres-secret (credentials DB)
   • PVC: postgres-data-pvc (devrait être Bound maintenant)

🔌 CONNEXION À POSTGRESQL:

   Depuis un pod dans le cluster:
   
   Host: postgres.random-db.svc.cluster.local
   Port: 5432
   Database: randomdb
   User: randomuser
   Password: RandomPass2024!

   Connection String:
   postgresql://randomuser:RandomPass2024!@postgres.random-db.svc.cluster.local:5432/randomdb

📝 COMMANDES UTILES:

   # Se connecter en interactif
   kubectl exec -it -n random-db deployment/postgres -- \
     psql -U randomuser -d randomdb

   # Exécuter une requête
   kubectl exec -n random-db deployment/postgres -- \
     psql -U randomuser -d randomdb -c "SELECT 1;"

   # Voir les logs
   kubectl logs -n random-db -l component=database -f

   # Redémarrer PostgreSQL
   kubectl rollout restart deployment/postgres -n random-db

   # Vérifier la santé
   kubectl exec -n random-db deployment/postgres -- \
     pg_isready -U randomuser -d randomdb

🔍 VÉRIFICATIONS:

   # Status du PVC
   kubectl get pvc -n random-db

   # Status des pods
   kubectl get pods -n random-db

   # Décrire le PV
   kubectl get pv

   # Voir l'utilisation des ressources
   kubectl top pods -n random-db

💡 TROUBLESHOOTING:

   Si le pod ne démarre pas:
   1. Vérifier les logs: kubectl logs -n random-db -l component=database
   2. Vérifier les events: kubectl get events -n random-db --sort-by='.lastTimestamp'
   3. Vérifier les quotas: kubectl describe resourcequota -n random-db
   4. Vérifier le PVC: kubectl describe pvc postgres-data-pvc -n random-db

   Si le PVC reste Pending:
   - C'est normal avec WaitForFirstConsumer, il sera Bound quand le pod démarre
   - Vérifier le provisioner: kubectl get pods -n local-path-storage

📊 MONITORING:

   # CPU/Memory en temps réel
   watch kubectl top pods -n random-db

   # Events en temps réel
   kubectl get events -n random-db --watch

EOF

echo ""
echo -e "${GREEN}[✓]${NC} PostgreSQL est prêt à l'emploi! 🎉"
echo ""
echo "Prochaines étapes:"
echo "  1. Configurer votre backend pour se connecter à PostgreSQL"
echo "  2. Créer les tables de votre application"
echo "  3. Tester la persistance des données"
echo ""