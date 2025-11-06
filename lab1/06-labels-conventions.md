# Conventions de Labels et Annotations - Application Random

## Table des matières
- [Vue d'ensemble](#vue-densemble)
- [Labels obligatoires](#labels-obligatoires)
- [Annotations obligatoires](#annotations-obligatoires)
- [Configuration par namespace](#configuration-par-namespace)
- [Cas particuliers](#cas-particuliers)
- [Utilisation pratique](#utilisation-pratique)
- [Scripts d'automatisation](#scripts-dautomatisation)
- [Vérification et audit](#vérification-et-audit)

---

## Vue d'ensemble

Cette documentation définit les standards de labellisation et d'annotation pour l'application Random dans Kubernetes. Ces conventions facilitent la gestion, la traçabilité et l'automatisation des opérations.

### Objectifs
- **Traçabilité** : Identifier rapidement l'environnement et le composant
- **Sélection** : Faciliter les requêtes Kubernetes avec des labels
- **Documentation** : Fournir un contexte via les annotations
- **Alerting** : Signaler les points d'attention critiques

---

## Labels obligatoires

Les labels sont des métadonnées clé-valeur attachées aux objets Kubernetes. Ils sont utilisés pour l'organisation et la sélection.

### Standard de l'application Random

| Label | Valeur | Description | Utilisation |
|-------|--------|-------------|-------------|
| `env` | `production` | Environnement d'exécution | Sélection par environnement |
| `app` | `random` | Nom de l'application | Groupement de tous les composants |
| `component` | `backend`, `database`, `frontend`, `jobs`, `scheduler` | Type de composant | Sélection par type de service |

### Règles de nommage des labels

**✅ Bonnes pratiques:**
```yaml
# Labels courts et standardisés
env: production
app: random
component: backend
```

**❌ À éviter:**
```yaml
# Labels trop verbeux ou non standardisés
environment: production-environment
application-name: random-app
component-type: backend-service
```

### Sélection avec labels

```bash
# Tous les namespaces de l'application Random
kubectl get ns -l app=random

# Tous les composants de production
kubectl get ns -l env=production

# Namespace de la base de données uniquement
kubectl get ns -l app=random,component=database

# Tous les services sauf la base de données
kubectl get ns -l 'app=random,component!=database'
```

---

## Annotations obligatoires

Les annotations stockent des métadonnées non identifiantes. Elles ne sont pas utilisées pour la sélection mais pour la documentation et l'information.

### Standard de l'application Random

| Annotation | Type | Obligatoire | Description |
|------------|------|-------------|-------------|
| `description` | String | Oui | Description détaillée du rôle du namespace |
| `contact` | Email | Oui | Email de l'équipe responsable |
| `alert` | String | Conditionnel | Alertes ou avertissements critiques |

### Format des annotations

#### Description
- **Format** : Texte libre, 1-2 phrases
- **Contenu** : Rôle fonctionnel du namespace
- **Langue** : Anglais (standard de l'entreprise)

```yaml
description: "Backend API services for Random application"
```

#### Contact
- **Format** : Adresse email valide
- **Contenu** : Email de l'équipe responsable (pas d'individus)
- **Usage** : Point de contact pour les incidents

```yaml
contact: "backend-team@random.com"
```

#### Alert (Optionnel)
- **Format** : `<NIVEAU> - <MESSAGE>`
- **Niveaux** : `CRITICAL`, `WARNING`, `INFO`
- **Usage** : Signaler les points d'attention importants

```yaml
alert: "CRITICAL - Monitor PVC saturation to prevent service interruption"
```

---

## Configuration par namespace

### random-backend

```yaml
metadata:
  name: random-backend
  labels:
    env: production
    app: random
    component: backend
  annotations:
    description: "Backend API services for Random application"
    contact: "backend-team@random.com"
```

**Responsabilités:**
- APIs REST
- Services métier
- Logique applicative

---

### random-jobs

```yaml
metadata:
  name: random-jobs
  labels:
    env: production
    app: random
    component: jobs
  annotations:
    description: "Spark jobs and batch processing for Random application"
    contact: "data-team@random.com"
```

**Responsabilités:**
- Jobs Spark
- Traitements batch
- ETL et traitement de données

---

### random-db

```yaml
metadata:
  name: random-db
  labels:
    env: production
    app: random
    component: database
  annotations:
    description: "PostgreSQL database for Random application"
    contact: "database-team@random.com"
    alert: "CRITICAL - Monitor PVC saturation to prevent service interruption"
```

**Responsabilités:**
- Base de données PostgreSQL
- Stockage persistant
- **⚠️ Point critique:** Surveillance du PVC obligatoire

**Alertes configurées:**
- Saturation du PVC
- Performance des requêtes
- Connexions actives

---

### random-frontend

```yaml
metadata:
  name: random-frontend
  labels:
    env: production
    app: random
    component: frontend
  annotations:
    description: "Frontend web application for Random"
    contact: "frontend-team@random.com"
```

**Responsabilités:**
- Interface utilisateur web
- Applications client
- Assets statiques

---

### random-scheduler

```yaml
metadata:
  name: random-scheduler
  labels:
    env: production
    app: random
    component: scheduler
  annotations:
    description: "Job scheduler and orchestrator for Random application"
    contact: "platform-team@random.com"
```

**Responsabilités:**
- Orchestration des jobs
- Planification des tâches
- Coordination des workflows

---

## Cas particuliers

### Alerte PVC sur random-db

Le namespace `random-db` inclut une annotation d'alerte critique:

```yaml
alert: "CRITICAL - Monitor PVC saturation to prevent service interruption"
```

**Raison:** La saturation du PVC peut entraîner:
- Perte de données
- Interruption de service
- Impossibilité d'écriture

**Actions requises:**
1. Configurer des alertes Prometheus sur l'utilisation du PVC
2. Seuil d'alerte à 80% d'utilisation
3. Seuil critique à 90% d'utilisation
4. Plan d'extension automatique ou manuel

**Commandes de surveillance:**
```bash
# Vérifier l'utilisation du PVC
kubectl get pvc -n random-db

# Détails d'un PVC spécifique
kubectl describe pvc <pvc-name> -n random-db

# Métriques via kubectl top (si metrics-server installé)
kubectl top pod -n random-db
```

---

## Utilisation pratique

### Commandes utiles

#### Lister tous les namespaces Random
```bash
kubectl get namespaces -l app=random --show-labels
```

#### Voir les annotations d'un namespace
```bash
kubectl get namespace random-db -o yaml | grep -A 10 annotations
```

#### Filtrer par composant
```bash
# Tous les namespaces backend
kubectl get ns -l component=backend

# Tous sauf database
kubectl get ns -l 'component!=database'
```

#### Exporter la configuration
```bash
# Export de tous les namespaces avec labels/annotations
for ns in $(kubectl get ns -l app=random -o name); do
  kubectl get $ns -o yaml > ${ns#*/}.yaml
done
```

### Intégration CI/CD

#### Validation dans les pipelines
```bash
#!/bin/bash
# Vérifier que tous les labels obligatoires sont présents

REQUIRED_LABELS=("env" "app" "component")

for ns in $(kubectl get ns -l app=random -o jsonpath='{.items[*].metadata.name}'); do
  for label in "${REQUIRED_LABELS[@]}"; do
    if ! kubectl get ns "$ns" -o jsonpath="{.metadata.labels.$label}" &>/dev/null; then
      echo "ERROR: Label $label manquant sur $ns"
      exit 1
    fi
  done
done
```

---

## Scripts d'automatisation

### Script principal: apply-labels-annotations.sh

#### Installation
```bash
# Rendre le script exécutable
chmod +x apply-labels-annotations.sh

# Placer dans le PATH (optionnel)
sudo cp apply-labels-annotations.sh /usr/local/bin/
```

#### Utilisation

**Mode normal** (applique les changements):
```bash
./apply-labels-annotations.sh
```

**Mode dry-run** (simulation):
```bash
./apply-labels-annotations.sh --dry-run
```

**Namespace spécifique**:
```bash
./apply-labels-annotations.sh --namespace random-backend
```

**Avec vérification**:
```bash
./apply-labels-annotations.sh --verify
```

#### Exemples de sortie

**Première exécution:**
```
[INFO] Démarrage de l'application des labels et annotations

======================================
Traitement: random-backend
======================================
[INFO] Application des labels sur le namespace: random-backend
[SUCCESS] Labels appliqués sur random-backend
[INFO] Application des annotations sur le namespace: random-backend
[SUCCESS] Annotations appliquées sur random-backend
```

**Exécutions suivantes (idempotent):**
```
======================================
Traitement: random-backend
======================================
[SUCCESS] Labels déjà présents et corrects sur random-backend
[SUCCESS] Annotations déjà présentes et correctes sur random-backend
```

---

## Vérification et audit

### Script de vérification

Créez un fichier `verify-compliance.sh` :

```bash
#!/bin/bash
# verify-compliance.sh
# Vérifie la conformité des labels et annotations

echo "=== Audit des labels et annotations ==="
echo ""

COMPLIANT=true

for ns in $(kubectl get ns -l app=random -o jsonpath='{.items[*].metadata.name}'); do
  echo "Namespace: $ns"
  
  # Vérifier les labels
  env=$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.env}' 2>/dev/null)
  app=$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.app}' 2>/dev/null)
  component=$(kubectl get ns "$ns" -o jsonpath='{.metadata.labels.component}' 2>/dev/null)
  
  # Vérifier les annotations
  desc=$(kubectl get ns "$ns" -o jsonpath='{.metadata.annotations.description}' 2>/dev/null)
  contact=$(kubectl get ns "$ns" -o jsonpath='{.metadata.annotations.contact}' 2>/dev/null)
  
  # Rapport
  echo "  Labels: env=$env, app=$app, component=$component"
  echo "  Annotations: description=$desc, contact=$contact"
  
  # Validation
  if [[ -z "$env" || -z "$app" || -z "$component" ]]; then
    echo "  ❌ LABELS MANQUANTS"
    COMPLIANT=false
  else
    echo "  ✅ Labels OK"
  fi
  
  if [[ -z "$desc" || -z "$contact" ]]; then
    echo "  ❌ ANNOTATIONS MANQUANTES"
    COMPLIANT=false
  else
    echo "  ✅ Annotations OK"
  fi
  
  echo ""
done

if [ "$COMPLIANT" = true ]; then
  echo "✅ Tous les namespaces sont conformes"
  exit 0
else
  echo "❌ Certains namespaces ne sont pas conformes"
  exit 1
fi
```

**Utilisation:**
```bash
chmod +x verify-compliance.sh
./verify-compliance.sh
```

### Vue d'ensemble rapide

```bash
# Afficher tous les namespaces avec leurs labels
kubectl get ns -l app=random --show-labels

# Afficher les annotations de tous les namespaces
kubectl get ns -l app=random -o custom-columns=\
NAME:.metadata.name,\
DESCRIPTION:.metadata.annotations.description,\
CONTACT:.metadata.annotations.contact,\
ALERT:.metadata.annotations.alert
```

### Dashboard Kubernetes

Les labels permettent de créer des vues dans les dashboards:

```yaml
# Exemple de filtre Grafana
{
  "expr": "kube_namespace_labels{app='random', env='production'}"
}
```

### Exportation pour documentation

```bash
# Générer un rapport CSV
echo "Namespace,Component,Contact,Alert" > namespaces-report.csv
kubectl get ns -l app=random -o jsonpath='{range .items[*]}{.metadata.name},{.metadata.labels.component},{.metadata.annotations.contact},{.metadata.annotations.alert}{"\n"}{end}' >> namespaces-report.csv
```

---

## Matrice de responsabilités

| Namespace | Équipe | Contact | Criticité | Alerte PVC |
|-----------|--------|---------|-----------|------------|
| random-backend | Backend Team | backend-team@random.com | Haute | Non |
| random-jobs | Data Team | data-team@random.com | Moyenne | Non |
| random-db | Database Team | database-team@random.com | **Critique** | **Oui** |
| random-frontend | Frontend Team | frontend-team@random.com | Haute | Non |
| random-scheduler | Platform Team | platform-team@random.com | Moyenne | Non |

---

## Maintenance

### Mise à jour des labels
```bash
# Ajouter un nouveau label
kubectl label namespace random-backend version=v2 --overwrite

# Supprimer un label
kubectl label namespace random-backend version-
```

### Mise à jour des annotations
```bash
# Modifier une annotation
kubectl annotate namespace random-backend description="New description" --overwrite

# Supprimer une annotation
kubectl annotate namespace random-backend alert-
```

### Automatisation avec GitOps

Dans un workflow GitOps (ArgoCD, Flux), les labels et annotations sont gérés via les manifests YAML:

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

commonLabels:
  app: random
  env: production

resources:
  - namespaces/
```

---

## Troubleshooting

### Les labels ne s'appliquent pas

**Problème:** Le message "not labeled" apparaît

**Solution:** C'est normal ! Cela signifie que les labels sont déjà présents et identiques. Le script détecte maintenant cette situation.

### Les annotations sont écrasées

**Problème:** Les annotations personnalisées disparaissent

**Solution:** Le flag `--overwrite` écrase les valeurs existantes. Pour ajouter sans écraser, utilisez `kubectl annotate` sans ce flag.

### Vérification manuelle

```bash
# Vérifier un namespace spécifique
kubectl get namespace random-backend -o yaml

# Vérifier uniquement les labels
kubectl get namespace random-backend --show-labels

# Vérifier uniquement les annotations
kubectl get namespace random-backend -o jsonpath='{.metadata.annotations}' | jq '.'
```

---

## Checklist de déploiement

Avant de déployer en production, vérifiez :

- [ ] Tous les namespaces ont les 3 labels obligatoires (env, app, component)
- [ ] Tous les namespaces ont les annotations description et contact
- [ ] Le namespace random-db a l'alerte PVC configurée
- [ ] Les contacts email sont valides et actifs
- [ ] Le script d'application est idempotent (peut être relancé sans erreur)
- [ ] Le script de vérification valide tous les namespaces
- [ ] La documentation est à jour et accessible à toutes les équipes

---

## Références

- [Kubernetes Labels and Selectors](https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/)
- [Kubernetes Annotations](https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/)
- [Best Practices for Kubernetes Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)
- [Kubernetes Recommended Labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/#labels)

---

## Historique des versions

| Version | Date | Auteur | Changements |
|---------|------|--------|-------------|
| 1.0 | Nov 2025 | Platform Team | Version initiale |
| 1.1 | Nov 2025 | Platform Team | Amélioration idempotence du script |

---

**Version:** 1.1  
**Dernière mise à jour:** Novembre 2025  
**Contact:** platform-team@random.com  
**Statut:** ✅ Validé et en production