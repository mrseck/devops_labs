#!/bin/bash

# Script de test des permissions RBAC
# Usage: ./rbac_test.sh

echo "======================================"
echo "Tests des permissions RBAC"
echo "======================================"
echo ""

# Couleurs pour l'affichage
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour tester une permission
test_permission() {
    local sa=$1
    local sa_namespace=$2
    local target_namespace=$3
    local verb=$4
    local resource=$5
    local expected=$6
    
    result=$(kubectl auth can-i $verb $resource --as=system:serviceaccount:$sa_namespace:$sa -n $target_namespace 2>&1)
    
    if [[ "$result" == "yes" && "$expected" == "yes" ]]; then
        echo -e "${GREEN}✓${NC} $sa peut '$verb' sur '$resource' dans $target_namespace"
    elif [[ "$result" == "no" && "$expected" == "no" ]]; then
        echo -e "${GREEN}✓${NC} $sa ne peut PAS '$verb' sur '$resource' dans $target_namespace (attendu)"
    else
        echo -e "${RED}✗${NC} $sa: résultat inattendu pour '$verb' sur '$resource' (obtenu: $result, attendu: $expected)"
    fi
}

echo "======================================"
echo "1. Tests RANDOM-BACKEND-SA"
echo "======================================"
# Permissions autorisées
test_permission "random-backend-sa" "random-backend" "random-backend" "get" "pods" "yes"
test_permission "random-backend-sa" "random-backend" "random-backend" "list" "services" "yes"
test_permission "random-backend-sa" "random-backend" "random-backend" "watch" "configmaps" "yes"
test_permission "random-backend-sa" "random-backend" "random-backend" "get" "secrets" "yes"

# Permissions refusées
test_permission "random-backend-sa" "random-backend" "random-backend" "create" "pods" "no"
test_permission "random-backend-sa" "random-backend" "random-backend" "delete" "services" "no"
test_permission "random-backend-sa" "random-backend" "random-backend" "update" "configmaps" "no"

echo ""
echo "======================================"
echo "2. Tests RANDOM-JOBS-SA"
echo "======================================"
# Permissions autorisées
test_permission "random-jobs-sa" "random-jobs" "random-jobs" "create" "jobs" "yes"
test_permission "random-jobs-sa" "random-jobs" "random-jobs" "delete" "jobs" "yes"
test_permission "random-jobs-sa" "random-jobs" "random-jobs" "get" "jobs" "yes"
test_permission "random-jobs-sa" "random-jobs" "random-jobs" "list" "pods" "yes"
test_permission "random-jobs-sa" "random-jobs" "random-jobs" "get" "configmaps" "yes"
test_permission "random-jobs-sa" "random-jobs" "random-jobs" "get" "secrets" "yes"

# Permissions refusées
test_permission "random-jobs-sa" "random-jobs" "random-jobs" "delete" "pods" "no"
test_permission "random-jobs-sa" "random-jobs" "random-jobs" "create" "services" "no"

echo ""
echo "======================================"
echo "3. Tests RANDOM-SCHEDULER-SA"
echo "======================================"
# Permissions dans random-scheduler
test_permission "random-scheduler-sa" "random-scheduler" "random-scheduler" "get" "pods" "yes"
test_permission "random-scheduler-sa" "random-scheduler" "random-scheduler" "create" "pods" "yes"
test_permission "random-scheduler-sa" "random-scheduler" "random-scheduler" "delete" "pods" "yes"
test_permission "random-scheduler-sa" "random-scheduler" "random-scheduler" "get" "secrets" "yes"

# Permissions dans random-jobs (cross-namespace)
test_permission "random-scheduler-sa" "random-scheduler" "random-jobs" "create" "jobs" "yes"
test_permission "random-scheduler-sa" "random-scheduler" "random-jobs" "delete" "jobs" "yes"
test_permission "random-scheduler-sa" "random-scheduler" "random-jobs" "list" "pods" "yes"

# Permissions refusées
test_permission "random-scheduler-sa" "random-scheduler" "random-backend" "get" "pods" "no"

echo ""
echo "======================================"
echo "4. Tests RANDOM-FRONTEND-SA"
echo "======================================"
# Permissions autorisées (minimales)
test_permission "random-frontend-sa" "random-frontend" "random-frontend" "get" "services" "yes"
test_permission "random-frontend-sa" "random-frontend" "random-frontend" "list" "configmaps" "yes"

# Permissions refusées
test_permission "random-frontend-sa" "random-frontend" "random-frontend" "get" "pods" "no"
test_permission "random-frontend-sa" "random-frontend" "random-frontend" "get" "secrets" "no"
test_permission "random-frontend-sa" "random-frontend" "random-frontend" "create" "services" "no"
test_permission "random-frontend-sa" "random-frontend" "random-frontend" "delete" "configmaps" "no"

echo ""
echo "======================================"
echo "5. Tests RANDOM-DB-SA"
echo "======================================"
# Permissions autorisées (secrets uniquement)
test_permission "random-db-sa" "random-db" "random-db" "get" "secrets" "yes"
test_permission "random-db-sa" "random-db" "random-db" "list" "secrets" "yes"
test_permission "random-db-sa" "random-db" "random-db" "watch" "secrets" "yes"

# Permissions refusées
test_permission "random-db-sa" "random-db" "random-db" "get" "pods" "no"
test_permission "random-db-sa" "random-db" "random-db" "get" "services" "no"
test_permission "random-db-sa" "random-db" "random-db" "get" "configmaps" "no"
test_permission "random-db-sa" "random-db" "random-db" "delete" "secrets" "no"

echo ""
echo "======================================"
echo "Tests terminés !"
echo "======================================"