#!/bin/bash

###############################################################################
# Script: apply-labels-annotations.sh
# Description: Applique les labels et annotations standardisés aux namespaces
# Usage: ./apply-labels-annotations.sh [--dry-run] [--namespace <name>]
###############################################################################

set -euo pipefail

# Couleurs pour l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
TARGET_NAMESPACE=""

# Fonction d'affichage
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Applique les labels et annotations standardisés aux namespaces Random.

OPTIONS:
    -d, --dry-run           Affiche les commandes sans les exécuter
    -n, --namespace NAME    Applique uniquement au namespace spécifié
    -h, --help             Affiche cette aide
    -v, --verify           Vérifie les labels/annotations après application

EXEMPLES:
    $0                              # Applique à tous les namespaces
    $0 --dry-run                    # Mode simulation
    $0 --namespace random-backend   # Applique uniquement au backend
    $0 --verify                     # Applique et vérifie

EOF
}

# Parse des arguments
VERIFY=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -n|--namespace)
            TARGET_NAMESPACE="$2"
            shift 2
            ;;
        -v|--verify)
            VERIFY=true
            shift
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

# Vérification de kubectl
if ! command -v kubectl &> /dev/null; then
    log_error "kubectl n'est pas installé ou n'est pas dans le PATH"
    exit 1
fi

# Vérification de la connexion au cluster
if ! kubectl cluster-info &> /dev/null; then
    log_error "Impossible de se connecter au cluster Kubernetes"
    exit 1
fi

# Fonction pour vérifier si les labels sont déjà présents
check_labels() {
    local namespace=$1
    local component=$2
    
    local current_env=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.env}' 2>/dev/null)
    local current_app=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.app}' 2>/dev/null)
    local current_component=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels.component}' 2>/dev/null)
    
    if [[ "$current_env" == "production" && "$current_app" == "random" && "$current_component" == "$component" ]]; then
        return 0  # Labels déjà présents et corrects
    else
        return 1  # Labels manquants ou incorrects
    fi
}

# Fonction pour appliquer les labels
apply_labels() {
    local namespace=$1
    local component=$2
    
    # Vérifier si les labels sont déjà présents
    if check_labels "$namespace" "$component"; then
        log_success "Labels déjà présents et corrects sur $namespace"
        return 0
    fi
    
    log_info "Application des labels sur le namespace: $namespace"
    
    local cmd="kubectl label namespace $namespace \
        env=production \
        app=random \
        component=$component \
        --overwrite"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY-RUN] $cmd"
    else
        local output
        if output=$(eval "$cmd" 2>&1); then
            if [[ "$output" == *"not labeled"* ]]; then
                log_success "Labels déjà présents et corrects sur $namespace"
            else
                log_success "Labels appliqués sur $namespace"
            fi
        else
            log_error "Échec de l'application des labels sur $namespace"
            log_error "Détails: $output"
            return 1
        fi
    fi
}

# Fonction pour vérifier si les annotations sont déjà présentes
check_annotations() {
    local namespace=$1
    local description=$2
    local contact=$3
    local alert=${4:-""}
    
    local current_desc=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.annotations.description}' 2>/dev/null)
    local current_contact=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.annotations.contact}' 2>/dev/null)
    local current_alert=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.annotations.alert}' 2>/dev/null)
    
    if [[ "$current_desc" == "$description" && "$current_contact" == "$contact" ]]; then
        if [[ -z "$alert" && -z "$current_alert" ]] || [[ "$current_alert" == "$alert" ]]; then
            return 0  # Annotations déjà présentes et correctes
        fi
    fi
    return 1  # Annotations manquantes ou incorrectes
}

# Fonction pour appliquer les annotations
apply_annotations() {
    local namespace=$1
    local description=$2
    local contact=$3
    local alert=${4:-""}
    
    # Vérifier si les annotations sont déjà présentes
    if check_annotations "$namespace" "$description" "$contact" "$alert"; then
        log_success "Annotations déjà présentes et correctes sur $namespace"
        return 0
    fi
    
    log_info "Application des annotations sur le namespace: $namespace"
    
    local base_cmd="kubectl annotate namespace $namespace \
        description='$description' \
        contact='$contact' \
        --overwrite"
    
    if [ -n "$alert" ]; then
        base_cmd="$base_cmd alert='$alert'"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY-RUN] $base_cmd"
    else
        local output
        if output=$(eval "$base_cmd" 2>&1); then
            if [[ "$output" == *"not annotated"* ]]; then
                log_success "Annotations déjà présentes et correctes sur $namespace"
            else
                log_success "Annotations appliquées sur $namespace"
            fi
        else
            log_error "Échec de l'application des annotations sur $namespace"
            log_error "Détails: $output"
            return 1
        fi
    fi
}

# Fonction de vérification
verify_namespace() {
    local namespace=$1
    
    log_info "Vérification du namespace: $namespace"
    
    echo "=== Labels ==="
    kubectl get namespace "$namespace" --show-labels
    
    echo ""
    echo "=== Annotations ==="
    kubectl get namespace "$namespace" -o jsonpath='{.metadata.annotations}' | jq '.'
    
    echo ""
}

# Configuration des namespaces avec leurs métadonnées
declare -A NAMESPACES_CONFIG=(
    ["random-backend"]="backend|Backend API services for Random application|backend-team@random.com|"
    ["random-jobs"]="jobs|Spark jobs and batch processing for Random application|data-team@random.com|"
    ["random-db"]="database|PostgreSQL database for Random application|database-team@random.com|CRITICAL - Monitor PVC saturation to prevent service interruption"
    ["random-frontend"]="frontend|Frontend web application for Random|frontend-team@random.com|"
    ["random-scheduler"]="scheduler|Job scheduler and orchestrator for Random application|platform-team@random.com|"
)

# Fonction pour traiter un namespace
process_namespace() {
    local namespace=$1
    
    if [[ ! -v NAMESPACES_CONFIG[$namespace] ]]; then
        log_error "Configuration non trouvée pour le namespace: $namespace"
        return 1
    fi
    
    # Parse de la configuration
    IFS='|' read -r component description contact alert <<< "${NAMESPACES_CONFIG[$namespace]}"
    
    # Vérification de l'existence du namespace
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_warning "Le namespace $namespace n'existe pas. Création..."
        if [ "$DRY_RUN" = false ]; then
            kubectl create namespace "$namespace"
        fi
    fi
    
    echo ""
    echo "======================================"
    echo "Traitement: $namespace"
    echo "======================================"
    
    # Application des labels
    apply_labels "$namespace" "$component"
    
    # Application des annotations
    apply_annotations "$namespace" "$description" "$contact" "$alert"
    
    # Vérification si demandée
    if [ "$VERIFY" = true ] && [ "$DRY_RUN" = false ]; then
        echo ""
        verify_namespace "$namespace"
    fi
    
    echo ""
}

# Main
main() {
    log_info "Démarrage de l'application des labels et annotations"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "=== MODE DRY-RUN ACTIVÉ ==="
    fi
    
    echo ""
    
    if [ -n "$TARGET_NAMESPACE" ]; then
        # Traitement d'un seul namespace
        process_namespace "$TARGET_NAMESPACE"
    else
        # Traitement de tous les namespaces
        for namespace in "${!NAMESPACES_CONFIG[@]}"; do
            process_namespace "$namespace"
        done
    fi
    
    echo ""
    log_success "Traitement terminé!"
    
    if [ "$DRY_RUN" = false ]; then
        echo ""
        log_info "Pour vérifier les labels de tous les namespaces:"
        echo "  kubectl get namespaces -l app=random --show-labels"
        echo ""
        log_info "Pour vérifier les annotations d'un namespace:"
        echo "  kubectl get namespace <name> -o yaml"
    fi
}

# Exécution
main