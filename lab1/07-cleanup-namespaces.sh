#!/bin/bash

###############################################################################
# Script: cleanup-namespaces.sh
# Description: Suppression complète et sécurisée de l'infrastructure Random
# Usage: ./cleanup-namespaces.sh [--force] [--namespace <n>]
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
FORCE=false
TARGET_NAMESPACE=""
DRY_RUN=false
LOG_FILE="${SCRIPT_DIR}/cleanup-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="${SCRIPT_DIR}/backups/backup-$(date +%Y%m%d-%H%M%S)"

# Liste des namespaces Random
RANDOM_NAMESPACES=("random-backend" "random-jobs" "random-db" "random-frontend" "random-scheduler")

# Fonction d'affichage
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}[INFO]${NC} $1"
}

log_success() {
    log "${GREEN}[✓]${NC} $1"
}

log_warning() {
    log "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    log "${RED}[✗]${NC} $1"
}

log_critical() {
    log "${RED}${MAGENTA}[!!!]${NC} $1"
}

# Fonction d'aide
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Supprime l'infrastructure complète des namespaces Random.

⚠️  ATTENTION: Cette opération est DESTRUCTIVE et IRRÉVERSIBLE!

OPTIONS:
    -f, --force            Suppression sans confirmation (dangereux!)
    -n, --namespace NAME   Supprime uniquement le namespace spécifié
    -d, --dry-run         Simule la suppression sans l'exécuter
    -b, --backup          Crée une backup avant suppression
    -h, --help            Affiche cette aide

EXEMPLES:
    $0                              # Suppression interactive (avec confirmation)
    $0 --dry-run                    # Simulation de suppression
    $0 --namespace random-backend   # Supprime uniquement le backend
    $0 --backup                     # Backup avant suppression
    $0 --force                      # Suppression forcée (DANGEREUX!)

NAMESPACES AFFECTÉS:
    - random-backend
    - random-jobs
    - random-db (⚠️  CONTIENT LA BASE DE DONNÉES)
    - random-frontend
    - random-scheduler

RESSOURCES SUPPRIMÉES:
    ✗ Namespaces et tous leurs contenus
    ✗ Pods et containers
    ✗ Services et endpoints
    ✗ Deployments, StatefulSets, DaemonSets
    ✗ ConfigMaps et Secrets
    ✗ PersistentVolumeClaims (⚠️  DONNÉES PERDUES)
    ✗ NetworkPolicies
    ✗ ResourceQuotas et LimitRanges
    ✗ ServiceAccounts, Roles, RoleBindings

EOF
}

# Parse des arguments
BACKUP=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -n|--namespace)
            TARGET_NAMESPACE="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -b|--backup)
            BACKUP=true
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

# Afficher un avertissement critique
show_critical_warning() {
    log ""
    log_critical "╔════════════════════════════════════════════════════════════════╗"
    log_critical "║                    ⚠️  AVERTISSEMENT CRITIQUE  ⚠️               ║"
    log_critical "╚════════════════════════════════════════════════════════════════╝"
    log ""
    log_warning "Cette opération va SUPPRIMER DÉFINITIVEMENT:"
    log ""
    
    if [ -n "$TARGET_NAMESPACE" ]; then
        log_warning "  • Le namespace: $TARGET_NAMESPACE"
    else
        log_warning "  • Tous les namespaces Random (5 namespaces)"
    fi
    
    log_warning "  • Tous les pods et containers"
    log_warning "  • Tous les services et configurations"
    log_warning "  • Toutes les NetworkPolicies et RBAC"
    log ""
    log_critical "  ⚠️  LES DONNÉES DE LA BASE DE DONNÉES SERONT PERDUES! ⚠️"
    log ""
    log_warning "Cette action est IRRÉVERSIBLE!"
    log ""
}

# Demander confirmation
ask_confirmation() {
    if [ "$FORCE" = true ]; then
        log_warning "Mode --force activé: Suppression sans confirmation"
        return 0
    fi
    
    if [ "$DRY_RUN" = true ]; then
        log_info "Mode --dry-run: Aucune suppression ne sera effectuée"
        return 0
    fi
    
    show_critical_warning
    
    log_warning "Êtes-vous ABSOLUMENT SÛR de vouloir continuer?"
    log_info "Cluster: $(kubectl config current-context)"
    log ""
    
    # Première confirmation
    read -p "Tapez 'yes' pour confirmer: " -r
    echo ""
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log_info "Opération annulée par l'utilisateur"
        exit 0
    fi
    
    # Seconde confirmation pour la database
    if [ -z "$TARGET_NAMESPACE" ] || [ "$TARGET_NAMESPACE" == "random-db" ]; then
        log_critical "DERNIÈRE CONFIRMATION: Les données de la base de données seront PERDUES!"
        read -p "Tapez 'DELETE DATABASE' pour confirmer la suppression: " -r
        echo ""
        if [[ ! $REPLY == "DELETE DATABASE" ]]; then
            log_info "Opération annulée par l'utilisateur"
            exit 0
        fi
    fi
    
    log_warning "Début de la suppression dans 5 secondes..."
    log_warning "Appuyez sur Ctrl+C pour annuler"
    sleep 5
}

# Créer une backup avant suppression
create_backup() {
    if [ "$BACKUP" = false ]; then
        return 0
    fi
    
    log_info "Création d'une backup dans: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    local namespaces_to_backup=()
    if [ -n "$TARGET_NAMESPACE" ]; then
        namespaces_to_backup=("$TARGET_NAMESPACE")
    else
        namespaces_to_backup=("${RANDOM_NAMESPACES[@]}")
    fi
    
    for ns in "${namespaces_to_backup[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_info "Backup du namespace: $ns"
            
            # Backup namespace
            kubectl get namespace "$ns" -o yaml > "$BACKUP_DIR/${ns}-namespace.yaml" 2>/dev/null || true
            
            # Backup resources
            kubectl get all -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-all.yaml" 2>/dev/null || true
            kubectl get configmap -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-configmaps.yaml" 2>/dev/null || true
            kubectl get secret -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-secrets.yaml" 2>/dev/null || true
            kubectl get networkpolicy -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-networkpolicies.yaml" 2>/dev/null || true
            kubectl get resourcequota -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-resourcequotas.yaml" 2>/dev/null || true
            kubectl get limitrange -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-limitranges.yaml" 2>/dev/null || true
            kubectl get serviceaccount -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-serviceaccounts.yaml" 2>/dev/null || true
            kubectl get role -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-roles.yaml" 2>/dev/null || true
            kubectl get rolebinding -n "$ns" -o yaml > "$BACKUP_DIR/${ns}-rolebindings.yaml" 2>/dev/null || true
            
            log_success "Backup de $ns terminé"
        fi
    done
    
    log_success "Backup complète sauvegardée dans: $BACKUP_DIR"
}

# Afficher l'inventaire avant suppression
show_inventory() {
    log_info "Inventaire des ressources à supprimer:"
    log ""
    
    local namespaces_to_check=()
    if [ -n "$TARGET_NAMESPACE" ]; then
        namespaces_to_check=("$TARGET_NAMESPACE")
    else
        namespaces_to_check=("${RANDOM_NAMESPACES[@]}")
    fi
    
    for ns in "${namespaces_to_check[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_info "Namespace: $ns"
            
            local pod_count=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l)
            local svc_count=$(kubectl get svc -n "$ns" --no-headers 2>/dev/null | wc -l)
            local pvc_count=$(kubectl get pvc -n "$ns" --no-headers 2>/dev/null | wc -l)
            local secret_count=$(kubectl get secret -n "$ns" --no-headers 2>/dev/null | wc -l)
            local cm_count=$(kubectl get configmap -n "$ns" --no-headers 2>/dev/null | wc -l)
            
            log "  • Pods: $pod_count"
            log "  • Services: $svc_count"
            log "  • PVCs: $pvc_count"
            log "  • Secrets: $secret_count"
            log "  • ConfigMaps: $cm_count"
            log ""
        fi
    done
}

# Supprimer les finalizers (si nécessaire)
remove_finalizers() {
    local namespace=$1
    
    log_info "Vérification des finalizers pour $namespace..."
    
    # Supprimer les finalizers des PVCs
    local pvcs=$(kubectl get pvc -n "$namespace" -o name 2>/dev/null || echo "")
    if [ -n "$pvcs" ]; then
        for pvc in $pvcs; do
            kubectl patch "$pvc" -n "$namespace" -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        done
    fi
}

# Supprimer un namespace
delete_namespace() {
    local namespace=$1
    
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_warning "Namespace $namespace n'existe pas, skip"
        return 0
    fi
    
    log_info "Suppression du namespace: $namespace"
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "[DRY-RUN] kubectl delete namespace $namespace"
        return 0
    fi
    
    # Supprimer les finalizers si nécessaire
    remove_finalizers "$namespace"
    
    # Supprimer le namespace
    if kubectl delete namespace "$namespace" --timeout=120s 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Namespace $namespace supprimé"
        return 0
    else
        log_error "Échec de la suppression de $namespace"
        
        # Tentative de force delete
        log_warning "Tentative de suppression forcée..."
        kubectl delete namespace "$namespace" --grace-period=0 --force 2>&1 | tee -a "$LOG_FILE" || true
        
        return 1
    fi
}

# Vérifier la suppression
verify_deletion() {
    log_info "Vérification de la suppression..."
    
    local namespaces_to_check=()
    if [ -n "$TARGET_NAMESPACE" ]; then
        namespaces_to_check=("$TARGET_NAMESPACE")
    else
        namespaces_to_check=("${RANDOM_NAMESPACES[@]}")
    fi
    
    local remaining=0
    for ns in "${namespaces_to_check[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_error "Namespace $ns existe toujours"
            ((remaining++))
        else
            log_success "Namespace $ns supprimé avec succès"
        fi
    done
    
    if [ $remaining -eq 0 ]; then
        log_success "Tous les namespaces ont été supprimés"
        return 0
    else
        log_error "$remaining namespace(s) n'ont pas été supprimés complètement"
        return 1
    fi
}

# Nettoyer les ClusterRoles et ClusterRoleBindings (si applicable)
cleanup_cluster_resources() {
    log_info "Nettoyage des ressources cluster-wide..."
    
    # Supprimer les ClusterRoleBindings liés aux ServiceAccounts Random
    local crbs=$(kubectl get clusterrolebinding -o json 2>/dev/null | \
        grep -o '"name":"[^"]*random[^"]*"' | cut -d'"' -f4 || echo "")
    
    if [ -n "$crbs" ]; then
        log_info "ClusterRoleBindings trouvés liés à Random:"
        for crb in $crbs; do
            log_warning "  - $crb"
            if [ "$DRY_RUN" = false ]; then
                kubectl delete clusterrolebinding "$crb" 2>&1 | tee -a "$LOG_FILE" || true
            fi
        done
    else
        log_info "Aucun ClusterRoleBinding lié à Random trouvé"
    fi
}

# Afficher le résumé
show_summary() {
    log ""
    log "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
    log "${MAGENTA}║                  RÉSUMÉ DE LA SUPPRESSION                      ║${NC}"
    log "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    if [ "$DRY_RUN" = true ]; then
        log_warning "Mode DRY-RUN: Aucune suppression réelle effectuée"
    else
        log_success "Suppression terminée"
        
        if [ "$BACKUP" = true ]; then
            log_info "Backup sauvegardée dans: $BACKUP_DIR"
        fi
    fi
    
    log ""
    log_info "Log complet: $LOG_FILE"
    log ""
    
    if [ "$DRY_RUN" = false ]; then
        log_info "Pour recréer l'infrastructure, exécutez:"
        log "  ./setup-namespaces.sh"
    fi
}

# Fonction principale
main() {
    log ""
    log "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    log "${RED}║       CLEANUP NAMESPACES RANDOM - Suppression totale           ║${NC}"
    log "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    log ""
    
    check_prerequisites
    
    log_info "Cluster: $(kubectl config current-context)"
    log_info "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    log ""
    
    # Afficher l'inventaire
    show_inventory
    
    # Demander confirmation
    ask_confirmation
    
    # Créer une backup si demandé
    if [ "$BACKUP" = true ]; then
        create_backup
    fi
    
    log ""
    log "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log "${RED}  DÉBUT DE LA SUPPRESSION${NC}"
    log "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    log ""
    
    # Supprimer les namespaces
    if [ -n "$TARGET_NAMESPACE" ]; then
        delete_namespace "$TARGET_NAMESPACE"
    else
        for ns in "${RANDOM_NAMESPACES[@]}"; do
            delete_namespace "$ns"
        done
    fi
    
    # Nettoyer les ressources cluster-wide
    if [ -z "$TARGET_NAMESPACE" ]; then
        cleanup_cluster_resources
    fi
    
    # Vérifier la suppression
    if [ "$DRY_RUN" = false ]; then
        sleep 3
        verify_deletion
    fi
    
    # Afficher le résumé
    show_summary
    
    log ""
    log "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    log "${GREEN}║                  CLEANUP TERMINÉ                               ║${NC}"
    log "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    log ""
}

# Gestion des erreurs
trap 'log_error "Script interrompu"; exit 1' INT TERM

# Exécution
main