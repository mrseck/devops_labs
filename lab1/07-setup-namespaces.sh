#!/bin/bash

###############################################################################
# Script: setup-namespaces.sh
# Description: Configuration complète des namespaces Random avec toutes les 
#              politiques de sécurité et ressources
# Usage: ./07-setup-namespaces.sh [--skip-verification] [--dry-run]
###############################################################################

set -euo pipefail

# Couleurs pour l'output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
SKIP_VERIFICATION=false
LOG_FILE="${SCRIPT_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"

# Fichiers de configuration
NAMESPACES_FILE="${SCRIPT_DIR}/01-namespaces.yml"
QUOTAS_FILE="${SCRIPT_DIR}/02-quotas.yml"
LIMITS_FILE="${SCRIPT_DIR}/03-limits.yml"
NETWORK_POLICIES_FILE="${SCRIPT_DIR}/04-network-policies.yml"
RBAC_FILE="${SCRIPT_DIR}/05-rbac.yml"

# Fonction d'affichage et logging
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[✓ SUCCESS]${NC} $1"
}

log_warning() {
    log "${YELLOW}[⚠ WARNING]${NC} $1"
}

log_error() {
    log "${RED}[✗ ERROR]${NC} $1"
}

log_step() {
    log "\n${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${MAGENTA}➤ $1${NC}"
    log "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Configure l'infrastructure complète des namespaces Random avec :
  - Namespaces avec labels et annotations
  - ResourceQuotas
  - LimitRanges
  - NetworkPolicies
  - RBAC (ServiceAccounts, Roles, RoleBindings)

OPTIONS:
    -d, --dry-run              Affiche les commandes sans les exécuter
    -s, --skip-verification    Skip la vérification finale
    -h, --help                 Affiche cette aide

EXEMPLES:
    $0                         # Installation complète
    $0 --dry-run              # Mode simulation
    $0 --skip-verification    # Installation sans vérification

FICHIERS REQUIS:
    01-namespaces.yml          # Définitions des namespaces
    02-quotas.yml              # ResourceQuotas
    03-limits.yml              # LimitRanges
    04-network-policies.yml    # NetworkPolicies
    05-rbac.yml                # RBAC configuration

LOG:
    Les logs sont sauvegardés dans: $LOG_FILE

EOF
}

# Parse des arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-verification)
            SKIP_VERIFICATION=true
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

# Fonction pour exécuter une commande
execute_cmd() {
    local cmd=$1
    local description=$2
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY-RUN] $cmd"
        return 0
    else
        log_info "$description"
        if eval "$cmd" >> "$LOG_FILE" 2>&1; then
            log_success "$description - OK"
            return 0
        else
            log_error "$description - FAILED"
            return 1
        fi
    fi
}

# Vérification des prérequis
check_prerequisites() {
    log_step "ÉTAPE 1/7: Vérification des prérequis"
    
    # Vérifier kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl n'est pas installé"
        exit 1
    fi
    log_success "kubectl est installé"
    
    # Vérifier la connexion au cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Impossible de se connecter au cluster Kubernetes"
        exit 1
    fi
    log_success "Connexion au cluster OK"
    
    # Vérifier les fichiers de configuration
    local missing_files=()
    for file in "$NAMESPACES_FILE" "$QUOTAS_FILE" "$LIMITS_FILE" "$NETWORK_POLICIES_FILE" "$RBAC_FILE"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Fichiers de configuration manquants:"
        for file in "${missing_files[@]}"; do
            log_error "  - $file"
        done
        exit 1
    fi
    log_success "Tous les fichiers de configuration sont présents"
    
    # Afficher les informations du cluster
    log_info "Cluster: $(kubectl config current-context)"
    log_info "Version: $(kubectl version --short 2>/dev/null | grep Server || echo 'N/A')"
}

# Créer les namespaces
create_namespaces() {
    log_step "ÉTAPE 2/7: Création des namespaces"
    
    execute_cmd \
        "kubectl apply -f '$NAMESPACES_FILE'" \
        "Création des namespaces avec labels et annotations"
    
    # Attendre que les namespaces soient prêts
    if [ "$DRY_RUN" = false ]; then
        sleep 2
        local namespaces=("random-backend" "random-jobs" "random-db" "random-frontend" "random-scheduler")
        for ns in "${namespaces[@]}"; do
            if kubectl get namespace "$ns" &> /dev/null; then
                log_success "Namespace $ns créé"
            else
                log_error "Namespace $ns non trouvé"
            fi
        done
    fi
}

# Appliquer les ResourceQuotas
apply_quotas() {
    log_step "ÉTAPE 3/7: Application des ResourceQuotas"
    
    execute_cmd \
        "kubectl apply -f '$QUOTAS_FILE'" \
        "Application des ResourceQuotas"
    
    if [ "$DRY_RUN" = false ]; then
        sleep 1
        log_info "ResourceQuotas appliqués:"
        kubectl get resourcequota --all-namespaces -l app=random 2>/dev/null | tee -a "$LOG_FILE" || true
    fi
}

# Appliquer les LimitRanges
apply_limits() {
    log_step "ÉTAPE 4/7: Application des LimitRanges"
    
    execute_cmd \
        "kubectl apply -f '$LIMITS_FILE'" \
        "Application des LimitRanges"
    
    if [ "$DRY_RUN" = false ]; then
        sleep 1
        log_info "LimitRanges appliqués:"
        kubectl get limitrange --all-namespaces 2>/dev/null | grep random | tee -a "$LOG_FILE" || true
    fi
}

# Appliquer les NetworkPolicies
apply_network_policies() {
    log_step "ÉTAPE 5/7: Application des NetworkPolicies"
    
    execute_cmd \
        "kubectl apply -f '$NETWORK_POLICIES_FILE'" \
        "Application des NetworkPolicies"
    
    if [ "$DRY_RUN" = false ]; then
        sleep 1
        log_info "NetworkPolicies appliquées:"
        kubectl get networkpolicy --all-namespaces 2>/dev/null | grep random | tee -a "$LOG_FILE" || true
    fi
}

# Configurer RBAC
configure_rbac() {
    log_step "ÉTAPE 6/7: Configuration RBAC"
    
    execute_cmd \
        "kubectl apply -f '$RBAC_FILE'" \
        "Configuration RBAC (ServiceAccounts, Roles, RoleBindings)"
    
    if [ "$DRY_RUN" = false ]; then
        sleep 1
        log_info "ServiceAccounts créés:"
        kubectl get serviceaccounts --all-namespaces 2>/dev/null | grep random | tee -a "$LOG_FILE" || true
    fi
}

# Vérification finale
verify_deployment() {
    if [ "$SKIP_VERIFICATION" = true ]; then
        log_warning "Vérification skippée (--skip-verification)"
        return 0
    fi
    
    log_step "ÉTAPE 7/7: Vérification du déploiement"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "Vérification skippée en mode dry-run"
        return 0
    fi
    
    local errors=0
    
    # Vérifier les namespaces
    log_info "Vérification des namespaces..."
    local namespaces=("random-backend" "random-jobs" "random-db" "random-frontend" "random-scheduler")
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_success "✓ Namespace $ns existe"
        else
            log_error "✗ Namespace $ns manquant"
            ((errors++))
        fi
    done
    
    # Vérifier les ResourceQuotas
    log_info "Vérification des ResourceQuotas..."
    for ns in "${namespaces[@]}"; do
        local quota_count=$(kubectl get resourcequota -n "$ns" --no-headers 2>/dev/null | wc -l)
        if [ "$quota_count" -gt 0 ]; then
            log_success "✓ ResourceQuota présent dans $ns"
        else
            log_error "✗ ResourceQuota manquant dans $ns"
            ((errors++))
        fi
    done
    
    # Vérifier les LimitRanges
    log_info "Vérification des LimitRanges..."
    for ns in "${namespaces[@]}"; do
        local limit_count=$(kubectl get limitrange -n "$ns" --no-headers 2>/dev/null | wc -l)
        if [ "$limit_count" -gt 0 ]; then
            log_success "✓ LimitRange présent dans $ns"
        else
            log_error "✗ LimitRange manquant dans $ns"
            ((errors++))
        fi
    done
    
    # Vérifier les NetworkPolicies
    log_info "Vérification des NetworkPolicies..."
    for ns in "${namespaces[@]}"; do
        local np_count=$(kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null | wc -l)
        if [ "$np_count" -gt 0 ]; then
            log_success "✓ NetworkPolicies présentes dans $ns ($np_count)"
        else
            log_error "✗ NetworkPolicies manquantes dans $ns"
            ((errors++))
        fi
    done
    
    # Vérifier les ServiceAccounts
    log_info "Vérification des ServiceAccounts..."
    for ns in "${namespaces[@]}"; do
        local sa_count=$(kubectl get sa -n "$ns" --no-headers 2>/dev/null | grep -v default | wc -l)
        if [ "$sa_count" -gt 0 ]; then
            log_success "✓ ServiceAccount présent dans $ns"
        else
            log_warning "⚠ Aucun ServiceAccount custom dans $ns"
        fi
    done
    
    # Résumé de la vérification
    echo ""
    if [ $errors -eq 0 ]; then
        log_success "═══════════════════════════════════════════════════════"
        log_success "  DÉPLOIEMENT RÉUSSI - Aucune erreur détectée"
        log_success "═══════════════════════════════════════════════════════"
    else
        log_error "═══════════════════════════════════════════════════════"
        log_error "  DÉPLOIEMENT INCOMPLET - $errors erreur(s) détectée(s)"
        log_error "═══════════════════════════════════════════════════════"
        return 1
    fi
}

# Afficher les alertes critiques
show_critical_alerts() {
    log_step "⚠️  ALERTES CRITIQUES"
    
    log_warning "╔════════════════════════════════════════════════════════════════╗"
    log_warning "║  ALERTE CRITIQUE - Base de données PostgreSQL (random-db)     ║"
    log_warning "╚════════════════════════════════════════════════════════════════╝"
    log_warning ""
    log_warning "Il est CRUCIAL de surveiller la saturation du PVC de la base de"
    log_warning "données PostgreSQL pour éviter une interruption de service."
    log_warning ""
    log_warning "Actions recommandées:"
    log_warning "  1. Configurer un StorageClass avec expansion automatique"
    log_warning "  2. Mettre en place des alertes de monitoring (seuil: 80%)"
    log_warning "  3. Implémenter une stratégie de backup régulière"
    log_warning ""
    log_warning "Pour plus de détails, consultez le document de passation."
    log_warning "═══════════════════════════════════════════════════════════════"
}

# Afficher le résumé final
show_summary() {
    log_step "📊 RÉSUMÉ DU DÉPLOIEMENT"
    
    if [ "$DRY_RUN" = false ]; then
        echo ""
        log_info "Namespaces configurés:"
        kubectl get namespaces -l app=random --show-labels 2>/dev/null | tee -a "$LOG_FILE"
        
        echo ""
        log_info "Pour vérifier la configuration complète, exécutez:"
        echo "  ./verify-namespaces.sh"
        
        echo ""
        log_info "Pour tester les permissions RBAC, exécutez:"
        echo "  ./rbac_test.sh"
        
        echo ""
        log_info "Logs sauvegardés dans: $LOG_FILE"
    else
        log_warning "Mode dry-run - Aucune modification effectuée"
    fi
}

# Fonction principale
main() {
    echo ""
    log_success "╔════════════════════════════════════════════════════════════════╗"
    log_success "║      SETUP NAMESPACES RANDOM - Infrastructure K8s              ║"
    log_success "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "═══ MODE DRY-RUN ACTIVÉ - Aucune modification ne sera effectuée ═══"
    fi
    
    # Exécution des étapes
    check_prerequisites
    create_namespaces
    apply_quotas
    apply_limits
    apply_network_policies
    configure_rbac
    verify_deployment
    
    # Affichage des alertes et résumé
    show_critical_alerts
    show_summary
    
    echo ""
    log_success "╔════════════════════════════════════════════════════════════════╗"
    log_success "║                  SETUP TERMINÉ AVEC SUCCÈS                     ║"
    log_success "╚════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Gestion des erreurs
trap 'log_error "Script interrompu"; exit 1' INT TERM

# Exécution
main