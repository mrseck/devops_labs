#!/bin/bash

###############################################################################
# Script: verify-prerequisites.sh
# Description: Vérification automatique de tous les prérequis pour les Labs
# Usage: ./verify-prerequisites.sh
###############################################################################

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNING=0

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║     Vérification des Prérequis - Labs DevOps                  ║
║     Lab 1, Lab 2, Lab 3                                       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
echo ""

# Fonction de vérification
check_command() {
    local command=$1
    local description=$2
    local required=${3:-true}
    
    echo -n "Vérification: ${description}... "
    
    if command -v "$command" &> /dev/null; then
        local version=$($command --version 2>/dev/null | head -n1 || echo "installé")
        echo -e "${GREEN}✅ OK${NC} (${version})"
        ((PASSED++))
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}❌ ÉCHEC${NC} (requis)"
            ((FAILED++))
            return 1
        else
            echo -e "${YELLOW}⚠️  MANQUANT${NC} (optionnel)"
            ((WARNING++))
            return 0
        fi
    fi
}

# Fonction de vérification de version
check_version() {
    local command=$1
    local min_version=$2
    local description=$3
    
    echo -n "Vérification: ${description} (version >= ${min_version})... "
    
    if command -v "$command" &> /dev/null; then
        local version=$($command --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "0.0.0")
        if [ "$(printf '%s\n' "$min_version" "$version" | sort -V | head -n1)" = "$min_version" ]; then
            echo -e "${GREEN}✅ OK${NC} (${version})"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}❌ ÉCHEC${NC} (version ${version} < ${min_version})"
            ((FAILED++))
            return 1
        fi
    else
        echo -e "${RED}❌ ÉCHEC${NC} (non installé)"
        ((FAILED++))
        return 1
    fi
}

echo -e "${BLUE}=== Outils de base ===${NC}"
echo ""

# Vérifications des outils de base
check_command "kubectl" "kubectl" true
check_command "helm" "Helm" true
check_command "minikube" "Minikube" true
check_command "jq" "jq" true
check_command "curl" "curl" true
check_command "wget" "wget" false
check_command "git" "git" false
check_command "mc" "MinIO Client (mc)" false
check_command "base64" "base64" true

echo ""
echo -e "${BLUE}=== Versions spécifiques ===${NC}"
echo ""

# Vérifications de versions
if command -v kubectl &> /dev/null; then
    echo -n "Vérification: Version kubectl (>= 1.20)... "
    KUBECTL_VERSION=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 | cut -d'v' -f2 || echo "0.0.0")
    if [ "$(printf '%s\n' "1.20.0" "$KUBECTL_VERSION" | sort -V | head -n1)" = "1.20.0" ]; then
        echo -e "${GREEN}✅ OK${NC} (${KUBECTL_VERSION})"
        ((PASSED++))
    else
        echo -e "${RED}❌ ÉCHEC${NC} (version ${KUBECTL_VERSION} < 1.20.0)"
        ((FAILED++))
    fi
fi

if command -v helm &> /dev/null; then
    echo -n "Vérification: Version Helm (>= 3.0)... "
    HELM_VERSION=$(helm version --short 2>/dev/null | cut -d'v' -f2 | cut -d'+' -f1 || echo "0.0.0")
    if [ "$(printf '%s\n' "3.0.0" "$HELM_VERSION" | sort -V | head -n1)" = "3.0.0" ]; then
        echo -e "${GREEN}✅ OK${NC} (${HELM_VERSION})"
        ((PASSED++))
    else
        echo -e "${RED}❌ ÉCHEC${NC} (version ${HELM_VERSION} < 3.0.0)"
        ((FAILED++))
    fi
fi

echo ""
echo -e "${BLUE}=== Cluster Kubernetes ===${NC}"
echo ""

# Vérification du cluster
if command -v kubectl &> /dev/null; then
    echo -n "Vérification: Connexion au cluster... "
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        ((PASSED++))
        
        # Vérifier les nodes
        echo -n "Vérification: Nodes disponibles... "
        NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        if [ "$NODES" -gt 0 ]; then
            READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
            echo -e "${GREEN}✅ OK${NC} (${READY_NODES}/${NODES} prêts)"
            ((PASSED++))
        else
            echo -e "${RED}❌ ÉCHEC${NC} (aucun node)"
            ((FAILED++))
        fi
        
        # Vérifier les permissions
        echo -n "Vérification: Permissions (create namespaces)... "
        if kubectl auth can-i create namespaces &> /dev/null; then
            if kubectl auth can-i create namespaces 2>/dev/null | grep -q "yes"; then
                echo -e "${GREEN}✅ OK${NC}"
                ((PASSED++))
            else
                echo -e "${RED}❌ ÉCHEC${NC} (permissions insuffisantes)"
                ((FAILED++))
            fi
        else
            echo -e "${YELLOW}⚠️  INCONNU${NC} (impossible de vérifier)"
            ((WARNING++))
        fi
        
        # Vérifier les StorageClasses
        echo -n "Vérification: StorageClasses disponibles... "
        SC_COUNT=$(kubectl get storageclass --no-headers 2>/dev/null | wc -l)
        if [ "$SC_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✅ OK${NC} (${SC_COUNT} StorageClass(es))"
            ((PASSED++))
        else
            echo -e "${YELLOW}⚠️  ATTENTION${NC} (aucune StorageClass)"
            ((WARNING++))
        fi
        
        # Vérifier les composants système
        echo -n "Vérification: Composants système... "
        SYSTEM_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | wc -l)
        if [ "$SYSTEM_PODS" -gt 0 ]; then
            RUNNING_PODS=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -c " Running " || echo "0")
            echo -e "${GREEN}✅ OK${NC} (${RUNNING_PODS}/${SYSTEM_PODS} pods en cours)"
            ((PASSED++))
        else
            echo -e "${YELLOW}⚠️  ATTENTION${NC} (aucun pod système)"
            ((WARNING++))
        fi
    else
        echo -e "${RED}❌ ÉCHEC${NC} (cluster non accessible)"
        ((FAILED++))
    fi
else
    echo -e "${RED}❌ ÉCHEC${NC} (kubectl non installé)"
    ((FAILED++))
fi

echo ""
echo -e "${BLUE}=== Configuration Minikube ===${NC}"
echo ""

# Vérification Minikube
if command -v minikube &> /dev/null; then
    echo -n "Vérification: Statut Minikube... "
    if minikube status &> /dev/null; then
        MINIKUBE_STATUS=$(minikube status --format='{{.Host}}' 2>/dev/null || echo "Stopped")
        if [ "$MINIKUBE_STATUS" = "Running" ]; then
            echo -e "${GREEN}✅ OK${NC} (Running)"
            ((PASSED++))
        else
            echo -e "${YELLOW}⚠️  ATTENTION${NC} (${MINIKUBE_STATUS})"
            ((WARNING++))
        fi
    else
        echo -e "${YELLOW}⚠️  ATTENTION${NC} (impossible de vérifier)"
        ((WARNING++))
    fi
fi

echo ""
echo -e "${BLUE}=== Configuration Helm ===${NC}"
echo ""

# Vérification Helm
if command -v helm &> /dev/null; then
    echo -n "Vérification: Repositories Helm... "
    REPO_COUNT=$(helm repo list --no-headers 2>/dev/null | wc -l)
    if [ "$REPO_COUNT" -gt 0 ]; then
        echo -e "${GREEN}✅ OK${NC} (${REPO_COUNT} repository(ies))"
        ((PASSED++))
        
        # Vérifier les repositories spécifiques
        if helm repo list 2>/dev/null | grep -q "grafana"; then
            echo -e "  ${GREEN}✓${NC} Repository Grafana configuré"
        else
            echo -e "  ${YELLOW}⚠${NC}  Repository Grafana non configuré (requis pour Lab 3)"
            ((WARNING++))
        fi
        
        if helm repo list 2>/dev/null | grep -q "prometheus-community"; then
            echo -e "  ${GREEN}✓${NC} Repository Prometheus Community configuré"
        else
            echo -e "  ${YELLOW}⚠${NC}  Repository Prometheus Community non configuré (requis pour Lab 3)"
            ((WARNING++))
        fi
    else
        echo -e "${YELLOW}⚠️  ATTENTION${NC} (aucun repository configuré)"
        ((WARNING++))
    fi
fi

echo ""
echo -e "${BLUE}=== Vérification des Labs ===${NC}"
echo ""

# Vérification Lab 1
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    echo -n "Vérification: Lab 1 (namespaces random)... "
    RANDOM_NS=$(kubectl get namespaces -l app=random --no-headers 2>/dev/null | wc -l)
    if [ "$RANDOM_NS" -gt 0 ]; then
        echo -e "${GREEN}✅ OK${NC} (${RANDOM_NS} namespace(s))"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠️  NON DÉPLOYÉ${NC} (Lab 1 non installé)"
        ((WARNING++))
    fi
    
    # Vérification Lab 2
    echo -n "Vérification: Lab 2 (StorageClass fast-ssd-expandable)... "
    if kubectl get storageclass fast-ssd-expandable &> /dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠️  NON DÉPLOYÉ${NC} (Lab 2 non installé)"
        ((WARNING++))
    fi
    
    # Vérification Lab 3
    echo -n "Vérification: Lab 3 (MinIO)... "
    MINIO_PODS=$(kubectl get pods -n minio -l app=minio --no-headers 2>/dev/null | wc -l)
    if [ "$MINIO_PODS" -gt 0 ]; then
        RUNNING_MINIO=$(kubectl get pods -n minio -l app=minio --no-headers 2>/dev/null | grep -c " Running " || echo "0")
        echo -e "${GREEN}✅ OK${NC} (${RUNNING_MINIO}/${MINIO_PODS} pods)"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠️  NON DÉPLOYÉ${NC} (Lab 3 non installé)"
        ((WARNING++))
    fi
fi

echo ""
echo -e "${BLUE}=== Ressources système ===${NC}"
echo ""

# Vérification des ressources
if command -v kubectl &> /dev/null && kubectl cluster-info &> /dev/null; then
    if kubectl top nodes &> /dev/null; then
        echo "Ressources des nodes:"
        kubectl top nodes 2>/dev/null | head -n 5
        echo ""
    else
        echo -e "${YELLOW}⚠️  ATTENTION${NC} (metrics-server non disponible)"
        ((WARNING++))
    fi
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  RÉSUMÉ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "Vérifications réussies: ${GREEN}${PASSED}${NC}"
echo -e "Vérifications échouées: ${RED}${FAILED}${NC}"
echo -e "Avertissements: ${YELLOW}${WARNING}${NC}"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✅ Tous les prérequis essentiels sont installés !${NC}"
    echo ""
    echo "Vous pouvez maintenant procéder à l'installation des Labs."
    echo "Consultez DOCUMENTATION-COMPLETE.md pour les instructions détaillées."
    exit 0
else
    echo -e "${RED}❌ Certains prérequis essentiels manquent.${NC}"
    echo ""
    echo "Consultez DOCUMENTATION-COMPLETE.md pour les instructions d'installation."
    exit 1
fi

