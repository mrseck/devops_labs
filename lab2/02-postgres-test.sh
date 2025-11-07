#!/bin/bash

# Script de test de connexion à PostgreSQL
# Lab2 - Test de connexion à la base de données

set -e

NAMESPACE="random-db"
POD_NAME="postgres-0"
CONTAINER_NAME="postgres"

echo "=========================================="
echo "  Test de connexion PostgreSQL - Lab2"
echo "=========================================="
echo ""

# Couleurs pour l'affichage
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher les résultats
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
        exit 1
    fi
}

# 1. Vérifier que le pod existe et est prêt
echo "1. Vérification du pod PostgreSQL..."
kubectl get pod $POD_NAME -n $NAMESPACE &> /dev/null
print_result $? "Pod $POD_NAME existe"

POD_STATUS=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.phase}')
if [ "$POD_STATUS" == "Running" ]; then
    print_result 0 "Pod est en état Running"
else
    print_result 1 "Pod n'est pas en état Running (état actuel: $POD_STATUS)"
fi

# 2. Vérifier que les conteneurs sont prêts
echo ""
echo "2. Vérification des conteneurs..."
READY=$(kubectl get pod $POD_NAME -n $NAMESPACE -o jsonpath='{.status.containerStatuses[?(@.name=="postgres")].ready}')
if [ "$READY" == "true" ]; then
    print_result 0 "Conteneur PostgreSQL est prêt"
else
    print_result 1 "Conteneur PostgreSQL n'est pas prêt"
fi

# 3. Test de connexion basique
echo ""
echo "3. Test de connexion à PostgreSQL..."
kubectl exec $POD_NAME -n $NAMESPACE -c $CONTAINER_NAME -- psql -U postgres -d randomdb -c "SELECT 1;" &> /dev/null
print_result $? "Connexion à la base 'randomdb' réussie"

# 4. Vérifier la version de PostgreSQL
echo ""
echo "4. Récupération des informations PostgreSQL..."
PG_VERSION=$(kubectl exec $POD_NAME -n $NAMESPACE -c $CONTAINER_NAME -- psql -U postgres -d randomdb -t -c "SELECT version();" | head -n 1)
echo -e "${YELLOW}   Version PostgreSQL:${NC} $PG_VERSION"

# 5. Vérifier les bases de données existantes
echo ""
echo "5. Liste des bases de données..."
kubectl exec $POD_NAME -n $NAMESPACE -c $CONTAINER_NAME -- psql -U postgres -c "\l" | grep -E "Name|randomdb|postgres|template"

# 6. Vérifier les tables dans randomdb
echo ""
echo "6. Vérification des tables dans 'randomdb'..."
TABLES=$(kubectl exec $POD_NAME -n $NAMESPACE -c $CONTAINER_NAME -- psql -U postgres -d randomdb -t -c "\dt" 2>&1)
if echo "$TABLES" | grep -q "Did not find any relations"; then
    echo -e "${YELLOW}   Aucune table trouvée (base vide - c'est normal)${NC}"
else
    echo "$TABLES"
fi

# 7. Test d'insertion et de lecture
echo ""
echo "7. Test d'écriture/lecture..."
kubectl exec $POD_NAME -n $NAMESPACE -c $CONTAINER_NAME -- psql -U postgres -d randomdb -c "CREATE TABLE IF NOT EXISTS test_connection (id SERIAL PRIMARY KEY, message TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP);" &> /dev/null
kubectl exec $POD_NAME -n $NAMESPACE -c $CONTAINER_NAME -- psql -U postgres -d randomdb -c "INSERT INTO test_connection (message) VALUES ('Test de connexion réussi - Lab2');" &> /dev/null
print_result $? "Création de table et insertion de données"

RESULT=$(kubectl exec $POD_NAME -n $NAMESPACE -c $CONTAINER_NAME -- psql -U postgres -d randomdb -t -c "SELECT message FROM test_connection ORDER BY id DESC LIMIT 1;" 2>/dev/null | xargs)
if [ -n "$RESULT" ]; then
    echo -e "${YELLOW}   Message récupéré:${NC} $RESULT"
    print_result 0 "Lecture des données réussie"
else
    print_result 1 "Échec de lecture des données"
fi

# Nettoyage des données de test
echo ""
echo "8. Nettoyage des données de test..."
kubectl exec $POD_NAME -n $NAMESPACE -c $CONTAINER_NAME -- psql -U postgres -d randomdb -c "DROP TABLE IF EXISTS test_connection;" &> /dev/null
print_result $? "Table de test supprimée"

# 9. Vérifier le service PostgreSQL
echo ""
echo "9. Vérification des services..."
kubectl get svc -n $NAMESPACE | grep postgres

# 10. Vérifier les métriques (si l'exporter est configuré)
echo ""
echo "10. Test de l'exporter de métriques..."
kubectl exec $POD_NAME -n $NAMESPACE -c postgres-exporter -- wget -q -O- http://localhost:9187/metrics | head -n 5 &> /dev/null
if [ $? -eq 0 ]; then
    print_result 0 "Exporter de métriques fonctionne"
    echo -e "${YELLOW}   Endpoint métriques:${NC} http://localhost:9187/metrics"
else
    echo -e "${YELLOW}   ⚠ Exporter de métriques non disponible ou non configuré${NC}"
fi

# 10. Vérifier le PVC
echo ""
echo "10. Vérification du stockage persistant..."
PVC_STATUS=$(kubectl get pvc postgres-data -n $NAMESPACE -o jsonpath='{.status.phase}')
PVC_CAPACITY=$(kubectl get pvc postgres-data -n $NAMESPACE -o jsonpath='{.status.capacity.storage}')
if [ "$PVC_STATUS" == "Bound" ]; then
    print_result 0 "PVC est lié (Bound) - Capacité: $PVC_CAPACITY"
else
    print_result 1 "PVC n'est pas lié (état: $PVC_STATUS)"
fi

# Résumé final
echo ""
echo "=========================================="
echo -e "${GREEN}  ✓ Tous les tests sont passés !${NC}"
echo "=========================================="
echo ""
echo "Informations de connexion:"
echo "  • Namespace: $NAMESPACE"
echo "  • Pod: $POD_NAME"
echo "  • Base de données: randomdb"
echo "  • Port PostgreSQL: 5432"
echo "  • Port Métriques: 9187"
echo ""
echo "Notes:"
echo "  • Les données de test ont été nettoyées"
echo "  • La base 'randomdb' est prête à l'emploi"
echo ""
echo "Commandes utiles:"
echo "  • Se connecter: kubectl exec -it $POD_NAME -n $NAMESPACE -c postgres -- psql -U postgres -d randomdb"
echo "  • Voir les logs: kubectl logs $POD_NAME -n $NAMESPACE -c postgres"
echo "  • Voir les métriques: kubectl port-forward -n $NAMESPACE $POD_NAME 9187:9187"
echo ""