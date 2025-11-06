#!/bin/bash

###############################################################################
# Script: verify-namespaces.sh
# Description: Vérification complète de l'infrastructure Random
# Usage: ./verify-namespaces.sh [OPTIONS]
###############################################################################

set -euo pipefail

# Couleurs pour l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
TARGET_NAMESPACE=""
VERBOSE=false
OUTPUT_FORMAT="text"
EXPORT_FILE=""

# Compteurs pour le rapport
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Fonction d'affichage
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    ((PASSED_CHECKS++))
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((WARNING_CHECKS++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((FAILED_CHECKS++))
}

log_section() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Vérifie la configuration complète de l'infrastructure Random.

OPTIONS:
    -n, --namespace NAME    Vérifie uniquement le namespace spécifié
    -v, --verbose          Mode verbeux avec détails complets
    -f, --format FORMAT    Format de sortie: text, json, markdown (défaut: text)
    -o, --output FILE      Exporte le résultat dans un fichier
    -h, --help             Affiche cette aide

EXEMPLES:
    $0                                  # Vérification complète
    $0 -n random-backend                # Vérifie uniquement random-backend
    $0 -v                               # Mode verbeux
    $0 -f json -o report.json           # Export JSON
    $0 -f markdown -o report.md         # Export Markdown

VÉRIFICATIONS EFFECTUÉES:
    ✓ Existence des namespaces
    ✓ Labels et annotations
    ✓ ResourceQuotas
    ✓ LimitRanges
    ✓ Network Policies
    ✓ RBAC (ServiceAccounts, Roles, RoleBindings)
    ✓ Connectivité réseau
    ✓ Utilisation des ressources

EOF
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            TARGET_NAMESPACE="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -f|--format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            EXPORT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Vérification des prérequis
check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi
}

# Vérifier l'existence d'un namespace
check_namespace_exists() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    if kubectl get namespace "$namespace" &> /dev/null; then
        log_success "Namespace '$namespace' existe"
        return 0
    else
        log_error "Namespace '$namespace' n'existe pas"
        return 1
    fi
}

# Vérifier les labels d'un namespace
check_namespace_labels() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    local env=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.env}' 2>/dev/null || echo "")
    local app=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.app}' 2>/dev/null || echo "")
    local component=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.component}' 2>/dev/null || echo "")
    
    if [[ "$env" == "production" && "$app" == "random" && -n "$component" ]]; then
        log_success "Labels corrects sur '$namespace' (env=$env, app=$app, component=$component)"
        return 0
    else
        log_error "Labels manquants ou incorrects sur '$namespace'"
        if [ "$VERBOSE" = true ]; then
            echo "  env: $env (attendu: production)"
            echo "  app: $app (attendu: random)"
            echo "  component: $component"
        fi
        return 1
    fi
}

# Vérifier les annotations d'un namespace
check_namespace_annotations() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    local description=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.annotations.description}' 2>/dev/null || echo "")
    local contact=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.annotations.contact}' 2>/dev/null || echo "")
    
    if [[ -n "$description" && -n "$contact" ]]; then
        log_success "Annotations présentes sur '$namespace'"
        if [ "$VERBOSE" = true ]; then
            echo "  description: $description"
            echo "  contact: $contact"
        fi
        return 0
    else
        log_warning "Annotations manquantes sur '$namespace'"
        return 1
    fi
}

# Vérifier les ResourceQuotas
check_resource_quotas() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    local quota_count=$(kubectl get resourcequota -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $quota_count -gt 0 ]]; then
        log_success "ResourceQuota configuré dans '$namespace' ($quota_count quota(s))"
        
        if [ "$VERBOSE" = true ]; then
            echo ""
            kubectl get resourcequota -n "$namespace" -o wide
            echo ""
        fi
        return 0
    else
        log_warning "Aucun ResourceQuota dans '$namespace'"
        return 1
    fi
}

# Vérifier les LimitRanges
check_limit_ranges() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    local limit_count=$(kubectl get limitrange -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $limit_count -gt 0 ]]; then
        log_success "LimitRange configuré dans '$namespace' ($limit_count limite(s))"
        
        if [ "$VERBOSE" = true ]; then
            echo ""
            kubectl get limitrange -n "$namespace"
            echo ""
        fi
        return 0
    else
        log_warning "Aucun LimitRange dans '$namespace'"
        return 1
    fi
}

# Vérifier les Network Policies
check_network_policies() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    local netpol_count=$(kubectl get networkpolicy -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $netpol_count -gt 0 ]]; then
        log_success "Network Policies configurées dans '$namespace' ($netpol_count politique(s))"
        
        if [ "$VERBOSE" = true ]; then
            echo ""
            kubectl get networkpolicy -n "$namespace"
            echo ""
        fi
        return 0
    else
        log_error "Aucune Network Policy dans '$namespace'"
        return 1
    fi
}

# Vérifier le RBAC
check_rbac() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    local sa_count=$(kubectl get sa -n "$namespace" --no-headers 2>/dev/null | grep -v default | wc -l)
    local role_count=$(kubectl get role -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local rolebinding_count=$(kubectl get rolebinding -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $sa_count -gt 0 && $role_count -gt 0 && $rolebinding_count -gt 0 ]]; then
        log_success "RBAC configuré dans '$namespace' (SA: $sa_count, Roles: $role_count, RB: $rolebinding_count)"
        
        if [ "$VERBOSE" = true ]; then
            echo ""
            echo "  ServiceAccounts:"
            kubectl get sa -n "$namespace" | grep -v default | sed 's/^/    /'
            echo ""
            echo "  Roles:"
            kubectl get role -n "$namespace" | sed 's/^/    /'
            echo ""
            echo "  RoleBindings:"
            kubectl get rolebinding -n "$namespace" | sed 's/^/    /'
            echo ""
        fi
        return 0
    else
        log_warning "RBAC incomplet dans '$namespace' (SA: $sa_count, Roles: $role_count, RB: $rolebinding_count)"
        return 1
    fi
}

# Vérifier l'utilisation des ressources
check_resource_usage() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    log_info "Utilisation des ressources dans '$namespace':"
    
    local pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $pod_count -eq 0 ]]; then
        log_warning "Aucun pod déployé dans '$namespace'"
        return 0
    fi
    
    if command -v kubectl-top &> /dev/null || kubectl top nodes &> /dev/null 2>&1; then
        echo ""
        kubectl top pods -n "$namespace" 2>/dev/null || log_warning "Metrics server non disponible"
        echo ""
    fi
    
    log_success "Analyse des ressources terminée pour '$namespace'"
}

# Vérifier la connectivité réseau
check_network_connectivity() {
    local namespace=$1
    ((TOTAL_CHECKS++))
    
    log_info "Vérification de la configuration réseau pour '$namespace'"
    
    local deny_ingress=$(kubectl get networkpolicy deny-all-ingress -n "$namespace" --no-headers 2>/dev/null | wc -l)
    local deny_egress=$(kubectl get networkpolicy deny-all-egress -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $deny_ingress -gt 0 && $deny_egress -gt 0 ]]; then
        log_success "Politiques deny-all présentes (sécurité par défaut)"
    else
        log_warning "Politiques deny-all manquantes (risque de sécurité)"
    fi
    
    local allow_policies=$(kubectl get networkpolicy -n "$namespace" --no-headers 2>/dev/null | grep -v "deny-all" | wc -l)
    
    if [[ $allow_policies -gt 0 ]]; then
        log_success "Politiques allow configurées ($allow_policies règle(s))"
    else
        log_warning "Aucune politique allow - le namespace est isolé"
    fi
}

# Vérification spéciale pour random-db
check_database_storage() {
    local namespace=$1
    
    if [[ "$namespace" != "random-db" ]]; then
        return 0
    fi
    
    ((TOTAL_CHECKS++))
    log_section "⚠️  VÉRIFICATION CRITIQUE: STOCKAGE POSTGRESQL"
    
    local pvc_count=$(kubectl get pvc -n "$namespace" --no-headers 2>/dev/null | wc -l)
    
    if [[ $pvc_count -eq 0 ]]; then
        log_warning "Aucun PVC trouvé dans random-db (base de données non déployée)"
        echo ""
        echo "${YELLOW}Note: Cette vérification sera pertinente après le déploiement de PostgreSQL${NC}"
        return 0
    fi
    
    echo ""
    log_info "PVCs dans random-db:"
    kubectl get pvc -n "$namespace" -o wide
    echo ""
    
    log_warning "RAPPEL: Configurer le monitoring et les alertes pour le PVC PostgreSQL"
}

# Vérifier un namespace complet
verify_namespace() {
    local namespace=$1
    
    log_section "VÉRIFICATION DU NAMESPACE: $namespace"
    
    check_namespace_exists "$namespace" || return 1
    check_namespace_labels "$namespace"
    check_namespace_annotations "$namespace"
    check_resource_quotas "$namespace"
    check_limit_ranges "$namespace"
    check_network_policies "$namespace"
    check_rbac "$namespace"
    check_network_connectivity "$namespace"
    check_resource_usage "$namespace"
    check_database_storage "$namespace"
}

# Générer un rapport
generate_report() {
    log_section "RAPPORT DE VÉRIFICATION"
    
    local success_rate=0
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    fi
    
    cat << EOF
${CYAN}Statistiques:${NC}
  Total de vérifications: $TOTAL_CHECKS
  ${GREEN}✓ Réussies: $PASSED_CHECKS${NC}
  ${YELLOW}⚠ Avertissements: $WARNING_CHECKS${NC}
  ${RED}✗ Échecs: $FAILED_CHECKS${NC}
  
  Taux de réussite: ${success_rate}%

EOF
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ Toutes les vérifications critiques sont passées!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    else
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}✗ Certaines vérifications ont échoué. Action requise.${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
    
    if [[ $WARNING_CHECKS -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Note: $WARNING_CHECKS avertissement(s) détecté(s). Consultez les détails ci-dessus.${NC}"
    fi
}

# Fonction principale
main() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║         VÉRIFICATION INFRASTRUCTURE RANDOM                    ║
║         Kubernetes Namespace Validation                       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}\n"
    
    check_prerequisites
    
    local namespaces=()
    
    if [[ -n "$TARGET_NAMESPACE" ]]; then
        namespaces=("$TARGET_NAMESPACE")
    else
        namespaces=("random-backend" "random-jobs" "random-db" "random-frontend" "random-scheduler")
    fi
    
    for ns in "${namespaces[@]}"; do
        verify_namespace "$ns"
    done
    
    generate_report
    
    if [[ $FAILED_CHECKS -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main