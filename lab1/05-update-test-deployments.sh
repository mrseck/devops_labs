#!/bin/bash

# Script pour associer les ServiceAccounts aux déploiements existants

echo "======================================"
echo "Association des ServiceAccounts"
echo "======================================"
echo ""

# RANDOM-BACKEND
echo "1. Mise à jour de random-backend..."
kubectl patch deployment test-backend -n random-backend -p '{"spec":{"template":{"spec":{"serviceAccountName":"random-backend-sa"}}}}'

# RANDOM-JOBS (si vous avez des déploiements)
# kubectl patch deployment <nom-deployment> -n random-jobs -p '{"spec":{"template":{"spec":{"serviceAccountName":"random-jobs-sa"}}}}'

# RANDOM-SCHEDULER
echo "2. Mise à jour de random-scheduler..."
kubectl patch deployment test-scheduler -n random-scheduler -p '{"spec":{"template":{"spec":{"serviceAccountName":"random-scheduler-sa"}}}}'

# RANDOM-FRONTEND
echo "3. Mise à jour de random-frontend..."
kubectl patch deployment test-frontend -n random-frontend -p '{"spec":{"template":{"spec":{"serviceAccountName":"random-frontend-sa"}}}}'

# RANDOM-DB
echo "4. Mise à jour de random-db..."
kubectl patch deployment test-db -n random-db -p '{"spec":{"template":{"spec":{"serviceAccountName":"random-db-sa"}}}}'

echo ""
echo "======================================"
echo "Vérification des ServiceAccounts"
echo "======================================"
kubectl get pods -n random-backend -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.serviceAccountName}{"\n"}{end}'
kubectl get pods -n random-scheduler -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.serviceAccountName}{"\n"}{end}'
kubectl get pods -n random-frontend -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.serviceAccountName}{"\n"}{end}'
kubectl get pods -n random-db -o=jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.serviceAccountName}{"\n"}{end}'

echo ""
echo "Terminé !"