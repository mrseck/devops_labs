# Lab 1 - Infrastructure Kubernetes pour l'Application Random

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis](#prérequis)
3. [Architecture](#architecture)
4. [Installation étape par étape](#installation-étape-par-étape)
5. [Vérification](#vérification)
6. [Dépannage](#dépannage)
7. [Documentation détaillée](#documentation-détaillée)

---

## Vue d'ensemble

Ce lab permet de mettre en place une infrastructure Kubernetes complète pour l'application **Random** avec :

- **5 namespaces** organisés par composant (backend, frontend, database, jobs, scheduler)
- **Quotas et limites de ressources** pour chaque namespace
- **Network Policies** pour sécuriser les communications entre composants
- **RBAC** (Role-Based Access Control) pour gérer les permissions
- **Stockage persistant** pour la base de données PostgreSQL
- **Labels et annotations** standardisés pour la traçabilité

### Composants de l'application Random

| Namespace | Composant | Description |
|-----------|-----------|-------------|
| `random-backend` | Backend | APIs REST et services métier |
| `random-frontend` | Frontend | Interface utilisateur web |
| `random-db` | Database | Base de données PostgreSQL |
| `random-jobs` | Jobs | Traitements batch et Spark jobs |
| `random-scheduler` | Scheduler | Orchestrateur de jobs |

---

## Prérequis

### Système requis

- **Cluster Kubernetes** fonctionnel (version 1.20+)
- **kubectl** configuré et connecté au cluster
- **Accès administrateur** au cluster (pour créer namespaces, RBAC, etc.)
- **Bash** (pour exécuter les scripts)

### Vérification des prérequis

```bash
# Vérifier la connexion au cluster
kubectl cluster-info

# Vérifier la version de Kubernetes
kubectl version

# Vérifier les permissions
kubectl auth can-i create namespaces
kubectl auth can-i create resourcequotas
kubectl auth can-i create networkpolicies
```

### Préparation de l'environnement

```bash
# Se placer dans le répertoire du lab
cd /home/sismael/Documents/exercices/lab1

# Rendre les scripts exécutables
chmod +x *.sh
chmod +x test_validation/*.sh
```

---

## Architecture

### Schéma des communications

```
┌─────────────────┐
│  random-frontend│
│   (Port 80/443) │
└────────┬────────┘
         │ HTTP 8080
         ▼
┌─────────────────┐
│ random-backend  │
│   (Port 8080)   │
└────────┬────────┘
         │ PostgreSQL 5432
         ▼
┌─────────────────┐
│   random-db     │
│  (PostgreSQL)   │
└─────────────────┘
         ▲
         │ PostgreSQL 5432
┌────────┴────────┐
│  random-jobs    │
│  (Spark/Batch)  │
└────────┬────────┘
         │ HTTP 8080
         ▲
┌────────┴────────┐
│ random-scheduler│
│  (Orchestrator) │
└─────────────────┘
```

### Flux de données

1. **Frontend → Backend** : Requêtes HTTP sur le port 8080
2. **Backend → Database** : Connexions PostgreSQL sur le port 5432
3. **Jobs → Database** : Accès en lecture/écriture pour les traitements batch
4. **Scheduler → Jobs** : Orchestration et déclenchement des jobs

---

## Installation étape par étape

### Étape 1 : Création des namespaces

Les namespaces sont la base de l'organisation. Ils incluent les labels et annotations standardisés.

```bash
# Appliquer les définitions de namespaces
kubectl apply -f 01-namespaces.yml

# Vérifier la création
kubectl get namespaces -l app=random
```

**Résultat attendu :**
```
NAME                STATUS   AGE
random-backend      Active   5s
random-db           Active   5s
random-frontend     Active   5s
random-jobs         Active   5s
random-scheduler    Active   5s
```

**Alternative avec script :**
```bash
# Le script setup-namespaces.sh inclut cette étape
./07-setup-namespaces.sh
```

### Étape 2 : Application des labels et annotations

Les labels permettent l'organisation et la sélection, les annotations fournissent la documentation.

```bash
# Appliquer les labels et annotations standardisés
./06-apply-labels-annotations.sh

# Vérifier les labels
kubectl get namespaces -l app=random --show-labels

# Vérifier les annotations
kubectl get namespace random-db -o jsonpath='{.metadata.annotations}' | jq '.'
```

**Labels attendus pour chaque namespace :**
- `env: production`
- `app: random`
- `component: backend|database|frontend|jobs|scheduler`

**Annotations attendues :**
- `description`: Description du namespace
- `contact`: Email de l'équipe responsable
- `alert`: (optionnel) Alertes critiques

### Étape 3 : Configuration des quotas de ressources

Les ResourceQuotas limitent l'utilisation globale des ressources par namespace.

```bash
# Appliquer les quotas
kubectl apply -f 02-quotas.yml

# Vérifier les quotas
kubectl get resourcequota --all-namespaces
```

**Quotas configurés :**

| Namespace | CPU Request | Memory Request | CPU Limit | Memory Limit | Pods | Services | PVCs |
|-----------|-------------|---------------|-----------|--------------|------|----------|------|
| random-backend | 4 | 8Gi | 8 | 16Gi | 10 | 5 | 5 |
| random-jobs | 8 | 16Gi | 16 | 32Gi | 20 | 5 | 3 |
| random-db | 2 | 4Gi | 4 | 8Gi | 5 | 2 | 2 |
| random-frontend | 1 | 2Gi | 2 | 4Gi | 8 | 1 | 1 |
| random-scheduler | 1 | 2Gi | 2 | 4Gi | 3 | 2 | 1 |

### Étape 4 : Configuration des limites de ressources

Les LimitRanges définissent les limites par pod et par conteneur.

```bash
# Appliquer les limites
kubectl apply -f 03-limits.yml

# Vérifier les limites
kubectl get limitrange --all-namespaces
```

**Exemple pour random-db :**
- **Pod max** : 800m CPU, 1600Mi mémoire
- **Pod min** : 400m CPU, 800Mi mémoire
- **Container default** : 500m CPU, 1Gi mémoire
- **PVC max** : 10Gi
- **PVC min** : 2Gi

### Étape 5 : Configuration des Network Policies

Les Network Policies sécurisent les communications entre les composants selon le principe Zero Trust.

```bash
# Appliquer les Network Policies
kubectl apply -f 04-network-policies.yml

# Vérifier les policies
kubectl get networkpolicies --all-namespaces
```

**Politiques appliquées :**

1. **Par défaut** : Blocage de tout le trafic (deny-all)
2. **Autorisations explicites** :
   - Frontend → Backend (port 8080)
   - Backend → Database (port 5432)
   - Jobs → Database (port 5432)
   - Scheduler → Jobs (port 8080)
   - Externe → Frontend (ports 80, 443)
3. **DNS** : Autorisation des requêtes DNS pour tous les namespaces

**Documentation détaillée :** Voir `04-network-policies_doc.md`

### Étape 6 : Configuration RBAC

Le RBAC définit les permissions pour chaque composant via ServiceAccounts, Roles et RoleBindings.

```bash
# Appliquer la configuration RBAC
kubectl apply -f 05-rbac.yml

# Vérifier les ServiceAccounts
kubectl get serviceaccounts --all-namespaces -l app=random

# Vérifier les Roles
kubectl get roles --all-namespaces -l app=random

# Vérifier les RoleBindings
kubectl get rolebindings --all-namespaces -l app=random
```

**Permissions configurées :**

| Namespace | ServiceAccount | Permissions |
|-----------|----------------|-------------|
| random-backend | random-backend-sa | Lecture seule (pods, services, configmaps, secrets) |
| random-jobs | random-jobs-sa | Gestion des Jobs (create, delete, update) |
| random-scheduler | random-scheduler-sa | Gestion complète dans scheduler + orchestration des jobs |
| random-frontend | random-frontend-sa | Lecture minimale (services, configmaps) |
| random-db | random-db-sa | Lecture des secrets uniquement |

**Test RBAC :**
```bash
# Tester les permissions (script fourni)
./05-rbac_test.sh
```

### Étape 7 : Configuration du stockage

Configuration d'un StorageClass pour le stockage persistant de PostgreSQL.

```bash
# Installer le provisioner de stockage et créer le StorageClass
./07-setup-simple-storage.sh
```

**Ce script :**
1. Installe Local Path Provisioner (solution simple et fiable)
2. Crée le StorageClass `random-db-expandable`
3. Configure les paramètres de stockage

**Vérification :**
```bash
# Vérifier le StorageClass
kubectl get storageclass random-db-expandable

# Vérifier le provisioner
kubectl get pods -n local-path-storage
```

### Étape 8 : Création du PVC pour PostgreSQL

Création du PersistentVolumeClaim pour la base de données.

```bash
# Appliquer le PVC
kubectl apply -f 07-postgres-pvc.yml

# Vérifier le PVC
kubectl get pvc -n random-db

# Attendre que le PVC soit Bound
kubectl wait --for=condition=Bound pvc/postgres-data-pvc -n random-db --timeout=60s
```

**PVC configuré :**
- **Nom** : `postgres-data-pvc`
- **Namespace** : `random-db`
- **Taille** : 10Gi
- **StorageClass** : `random-db-expandable`
- **Access Mode** : ReadWriteOnce

---

## Installation automatisée

Pour installer tous les composants en une seule commande :

```bash
# Option 1 : Script complet (recommandé)
./07-setup-namespaces.sh

# Option 2 : Installation manuelle étape par étape
kubectl apply -f 01-namespaces.yml
./06-apply-labels-annotations.sh
kubectl apply -f 02-quotas.yml
kubectl apply -f 03-limits.yml
kubectl apply -f 04-network-policies.yml
kubectl apply -f 05-rbac.yml
./07-setup-simple-storage.sh
kubectl apply -f 07-postgres-pvc.yml
```

---

## Vérification

### Vérification complète

```bash
# Script de vérification automatique
./07-verify-namespaces.sh
```

### Vérifications manuelles

#### 1. Namespaces

```bash
# Lister tous les namespaces Random
kubectl get namespaces -l app=random

# Vérifier les labels
kubectl get namespaces -l app=random --show-labels

# Vérifier les annotations
for ns in random-backend random-db random-frontend random-jobs random-scheduler; do
  echo "=== $ns ==="
  kubectl get namespace $ns -o jsonpath='{.metadata.annotations}' | jq '.'
done
```

#### 2. Quotas et limites

```bash
# Vérifier les quotas
kubectl get resourcequota --all-namespaces

# Vérifier les limites
kubectl get limitrange --all-namespaces

# Détails d'un quota
kubectl describe resourcequota random-db-quota -n random-db
```

#### 3. Network Policies

```bash
# Lister toutes les Network Policies
kubectl get networkpolicies --all-namespaces

# Détails d'une policy
kubectl describe networkpolicy allow-db-from-backend-and-jobs -n random-db
```

#### 4. RBAC

```bash
# Vérifier les ServiceAccounts
kubectl get serviceaccounts --all-namespaces -l app=random

# Vérifier les Roles
kubectl get roles --all-namespaces

# Vérifier les RoleBindings
kubectl get rolebindings --all-namespaces

# Tester les permissions
./05-rbac_test.sh
```

#### 5. Stockage

```bash
# Vérifier le StorageClass
kubectl get storageclass random-db-expandable

# Vérifier le PVC
kubectl get pvc -n random-db

# Vérifier le PV créé
kubectl get pv

# Détails du PVC
kubectl describe pvc postgres-data-pvc -n random-db
```

### Tests de connectivité

Des déploiements de test sont disponibles pour valider les Network Policies :

```bash
# Appliquer les déploiements de test
kubectl apply -f 04-test-deployments.yaml

# Tester la connectivité (voir 04-network-policies_test.md)
# Exemples de tests :
kubectl exec -it -n random-frontend deployment/test-frontend -- \
  curl http://test-backend.random-backend.svc.cluster.local:8080

kubectl exec -it -n random-backend deployment/test-backend -- \
  nc -zv postgres.random-db.svc.cluster.local 5432
```

---

## Déploiement de PostgreSQL (optionnel)

Un script de déploiement PostgreSQL est disponible dans `test_validation/` :

```bash
cd test_validation
./deploy-postgres.sh
```

Ce script :
- Vérifie le namespace et le PVC
- Déploie PostgreSQL avec les bonnes configurations
- Teste la connectivité
- Affiche les informations de connexion

---

## Dépannage

### Problèmes courants

#### 1. PVC reste en état "Pending"

**Symptôme :**
```bash
kubectl get pvc -n random-db
# NAME                STATUS    VOLUME   CAPACITY   ACCESS MODES
# postgres-data-pvc   Pending                                     10Gi
```

**Solutions :**
```bash
# Vérifier le StorageClass
kubectl get storageclass random-db-expandable

# Vérifier le provisioner
kubectl get pods -n local-path-storage

# Vérifier les événements
kubectl get events -n random-db --sort-by='.lastTimestamp'

# Si le StorageClass utilise WaitForFirstConsumer, créer un pod qui utilise le PVC
```

#### 1.1. Suppression de PVC bloquée

**Symptôme :** Le script `07-setup-simple-storage.sh` reste bloqué lors de la suppression d'un PVC existant.

**Cause :** Le PVC est utilisé par un pod (ex: PostgreSQL) et ne peut pas être supprimé tant que le pod l'utilise.

**Solutions :**
```bash
# Option 1 : Utiliser le script qui gère automatiquement ce cas
# Le script détecte si PostgreSQL utilise le PVC et propose de le supprimer d'abord
./07-setup-simple-storage.sh

# Option 2 : Suppression manuelle
# 1. Supprimer le déploiement PostgreSQL d'abord
kubectl delete deployment postgres -n random-db
kubectl delete service postgres -n random-db

# 2. Attendre que les pods soient terminés
kubectl wait --for=delete pod -l component=database -n random-db --timeout=60s

# 3. Supprimer le PVC
kubectl delete pvc postgres-data-pvc -n random-db

# 4. Vérifier la suppression complète
kubectl get pvc postgres-data-pvc -n random-db  # Devrait retourner "NotFound"

# 5. Recréer le PVC
kubectl apply -f 07-postgres-pvc.yml

# 6. Redéployer PostgreSQL
cd test_validation && ./deploy-postgres.sh
```

#### 2. Network Policies bloquent les communications

**Symptôme :** Les pods ne peuvent pas communiquer entre eux.

**Solutions :**
```bash
# Vérifier les Network Policies
kubectl get networkpolicies --all-namespaces

# Vérifier les labels des namespaces (importants pour les sélecteurs)
kubectl get namespaces --show-labels

# Tester la connectivité
kubectl run test-pod --image=busybox -n random-backend --rm -it -- sh
# Dans le pod : wget -O- http://test-backend.random-backend.svc.cluster.local:8080
```

#### 3. Quotas dépassés

**Symptôme :**
```
Error creating: pods "my-pod" is forbidden: exceeded quota: random-backend-quota
```

**Solutions :**
```bash
# Vérifier l'utilisation des quotas
kubectl describe resourcequota random-backend-quota -n random-backend

# Vérifier les ressources utilisées
kubectl top pods -n random-backend

# Ajuster les quotas si nécessaire (modifier 02-quotas.yml)
```

#### 4. Permissions RBAC insuffisantes

**Symptôme :**
```
Error from server (Forbidden): pods "my-pod" is forbidden: User "system:serviceaccount:random-backend:random-backend-sa" cannot get resource "pods"
```

**Solutions :**
```bash
# Vérifier les permissions du ServiceAccount
kubectl describe role random-backend-role -n random-backend

# Vérifier le RoleBinding
kubectl describe rolebinding random-backend-rolebinding -n random-backend

# Tester les permissions
./05-rbac_test.sh
```

#### 5. StorageClass non trouvé

**Symptôme :**
```
StorageClass "random-db-expandable" not found
```

**Solutions :**
```bash
# Réinstaller le stockage
./07-setup-simple-storage.sh

# Vérifier le StorageClass
kubectl get storageclass random-db-expandable

# Si nécessaire, modifier le PVC pour utiliser un StorageClass existant
kubectl get storageclass  # Lister les StorageClasses disponibles
```

### Commandes de diagnostic

```bash
# État général du cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Événements récents
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -20

# Logs du provisioner de stockage
kubectl logs -n local-path-storage -l app=local-path-provisioner

# Vérifier les ressources par namespace
for ns in random-backend random-db random-frontend random-jobs random-scheduler; do
  echo "=== $ns ==="
  kubectl get all -n $ns
  kubectl get pvc -n $ns
done
```

---

## Nettoyage

### Suppression complète

```bash
# Script de nettoyage
./07-cleanup-namespaces.sh
```

### Suppression manuelle

```bash
# Supprimer les ressources dans l'ordre inverse
kubectl delete -f 07-postgres-pvc.yml
kubectl delete -f 05-rbac.yml
kubectl delete -f 04-network-policies.yml
kubectl delete -f 03-limits.yml
kubectl delete -f 02-quotas.yml
kubectl delete -f 01-namespaces.yml

# Supprimer le StorageClass et le provisioner
kubectl delete storageclass random-db-expandable
kubectl delete -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.24/deploy/local-path-storage.yaml
```

**⚠️ Attention :** La suppression des namespaces supprime toutes les ressources qu'ils contiennent (pods, services, PVCs, etc.).

---

## Documentation détaillée

### Fichiers de documentation

- **`06-labels-conventions.md`** : Conventions de labels et annotations
- **`04-network-policies_doc.md`** : Documentation des Network Policies
- **`04-network-policies_test.md`** : Guide de test des Network Policies
- **`actions-documentées.md`** : Alertes critiques et bonnes pratiques

### Structure des fichiers

```
lab1/
├── 01-namespaces.yml              # Définitions des namespaces
├── 02-quotas.yml                  # ResourceQuotas
├── 03-limits.yml                  # LimitRanges
├── 04-network-policies.yml        # Network Policies
├── 04-network-policies_doc.md     # Documentation Network Policies
├── 04-network-policies_test.md    # Tests Network Policies
├── 04-test-deployments.yaml       # Déploiements de test
├── 05-rbac.yml                    # Configuration RBAC
├── 05-rbac_test.sh                # Script de test RBAC
├── 06-apply-labels-annotations.sh # Script d'application labels/annotations
├── 06-labels-conventions.md       # Documentation labels/annotations
├── 07-setup-namespaces.sh         # Script d'installation complète
├── 07-setup-simple-storage.sh     # Script d'installation stockage
├── 07-postgres-pvc.yml            # PVC pour PostgreSQL
├── 07-verify-namespaces.sh        # Script de vérification
├── 07-cleanup-namespaces.sh       # Script de nettoyage
|__ GUIDE-RAPIDE.md                # Guide rapide
|__ Lab1.pdf                       # Le lab à mettre en place
|__ QCM.md                         # Les reponses aux questions du Quiz
└── README.md                      # Cette documentation
```

---

## Bonnes pratiques

### 1. Configuration d'un StorageClass avec expansion automatique

Le StorageClass actuel `random-db-expandable` utilise Local Path Provisioner qui ne supporte pas l'expansion automatique. Pour activer l'expansion automatique, plusieurs options sont disponibles selon l'environnement :

#### Option A : StorageClass avec expansion pour AWS EBS

Pour un cluster Kubernetes sur AWS, utilisez le provisioner EBS avec expansion automatique :

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: random-db-expandable-aws
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  encrypted: "true"
  allowAutoIOPSPerGBIncrease: "true"
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true  # ⭐ Clé pour l'expansion automatique
```

#### Option B : StorageClass avec expansion pour GCP Persistent Disk

Pour un cluster Kubernetes sur GCP :

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: random-db-expandable-gcp
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: none
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
allowVolumeExpansion: true  # ⭐ Activation de l'expansion
```

#### Option C : StorageClass avec expansion pour Ceph/Rook

Pour un cluster on-premise avec Ceph/Rook :

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: random-db-expandable-rook
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
  clusterID: rook-ceph
  pool: replicapool
  imageFormat: "2"
  imageFeatures: layering
volumeBindingMode: Immediate
reclaimPolicy: Retain
allowVolumeExpansion: true  # ⭐ Activation de l'expansion
```

#### Utilisation de l'expansion automatique

Une fois le StorageClass configuré avec `allowVolumeExpansion: true`, l'expansion se fait en deux étapes :

**1. Modification du PVC pour demander plus d'espace :**

```bash
# Éditer le PVC pour augmenter la taille
kubectl patch pvc postgres-data-pvc -n random-db -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'

# Ou éditer directement le fichier
kubectl edit pvc postgres-data-pvc -n random-db
# Modifier la ligne : storage: 10Gi → storage: 20Gi
```

**2. Expansion automatique du volume sous-jacent :**

Le CSI driver détecte automatiquement la demande d'expansion et agrandit le volume. Vérification :

```bash
# Vérifier le statut du PVC
kubectl get pvc postgres-data-pvc -n random-db

# Vérifier les événements
kubectl describe pvc postgres-data-pvc -n random-db | grep -A 10 Events

# Vérifier la capacité réelle du volume
kubectl get pv $(kubectl get pvc postgres-data-pvc -n random-db -o jsonpath='{.spec.volumeName}') -o jsonpath='{.spec.capacity.storage}'
```

**3. Expansion du système de fichiers (si nécessaire) :**

Pour les volumes qui nécessitent une expansion du filesystem (ext4, xfs), ajouter un initContainer ou utiliser un sidecar :

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: random-db
spec:
  template:
    spec:
      initContainers:
      - name: volume-expand
        image: busybox
        command: ['sh', '-c']
        args:
          - |
            if [ -d /var/lib/postgresql/data ]; then
              resize2fs /dev/$(df /var/lib/postgresql/data | tail -1 | awk '{print $1}' | sed 's|/dev/||')
            fi
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
      containers:
      # ... reste de la configuration
```

#### Limitation actuelle avec Local Path Provisioner

Le provisioner Local Path utilisé dans ce lab **ne supporte pas** `allowVolumeExpansion: true`. Pour activer l'expansion automatique, il faudrait migrer vers un provisioner qui le supporte (EBS, GCP PD, Ceph/Rook, Longhorn, etc.).

### 2. Alertes de monitoring sur l'utilisation du PVC

Le namespace `random-db` inclut une annotation critique pour la surveillance du PVC :

```yaml
annotations:
  alert: "CRITICAL - Monitor PVC saturation to prevent service interruption"
```

#### Configuration des alertes Prometheus

Pour surveiller l'utilisation du PVC en temps réel, configurez Prometheus avec les alertes suivantes :

**Fichier : `prometheus-alerts-pvc.yml`**

```yaml
groups:
- name: pvc_usage_alerts
  interval: 30s
  rules:
  # Alerte WARNING à 80% d'utilisation
  - alert: PVCUsageHigh
    expr: (kubelet_volume_stats_used_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"} / kubelet_volume_stats_capacity_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"}) * 100 > 80
    for: 5m
    labels:
      severity: warning
      component: database
      namespace: random-db
    annotations:
      summary: "PVC usage is high ({{ $value | humanizePercentage }})"
      description: "PVC postgres-data-pvc in namespace random-db is {{ $value | humanizePercentage }} full. Consider expanding the volume."
      runbook_url: "https://wiki.random.com/runbooks/pvc-expansion"

  # Alerte CRITICAL à 90% d'utilisation
  - alert: PVCUsageCritical
    expr: (kubelet_volume_stats_used_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"} / kubelet_volume_stats_capacity_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"}) * 100 > 90
    for: 2m
    labels:
      severity: critical
      component: database
      namespace: random-db
    annotations:
      summary: "PVC usage is CRITICAL ({{ $value | humanizePercentage }})"
      description: "PVC postgres-data-pvc in namespace random-db is {{ $value | humanizePercentage }} full. IMMEDIATE action required to prevent service interruption."
      runbook_url: "https://wiki.random.com/runbooks/pvc-expansion-urgent"

  # Alerte CRITICAL à 95% d'utilisation (risque d'arrêt imminent)
  - alert: PVCUsageImminentFailure
    expr: (kubelet_volume_stats_used_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"} / kubelet_volume_stats_capacity_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"}) * 100 > 95
    for: 1m
    labels:
      severity: critical
      component: database
      namespace: random-db
    annotations:
      summary: "PVC usage is at CRITICAL level ({{ $value | humanizePercentage }}) - Service interruption imminent"
      description: "PVC postgres-data-pvc in namespace random-db is {{ $value | humanizePercentage }} full. Service may stop working. EXPAND VOLUME IMMEDIATELY."
      runbook_url: "https://wiki.random.com/runbooks/pvc-expansion-emergency"
```

#### Configuration dans Prometheus

**1. Appliquer les règles d'alerte :**

```bash
# Créer un ConfigMap avec les règles
kubectl create configmap prometheus-pvc-alerts \
  --from-file=pvc-alerts.yml=prometheus-alerts-pvc.yml \
  -n monitoring

# Configurer Prometheus pour charger ces règles
# (ajouter dans la configuration Prometheus)
# rule_files:
#   - /etc/prometheus/rules/*.yml
```

**2. Configurer Alertmanager pour notifier :**

```yaml
# alertmanager-config.yml
route:
  group_by: ['alertname', 'namespace', 'component']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  routes:
  - match:
      severity: critical
      component: database
    receiver: 'database-critical'
    continue: true

receivers:
- name: 'default'
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    channel: '#kubernetes-alerts'
    title: 'Kubernetes Alert'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

- name: 'database-critical'
  slack_configs:
  - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
    channel: '#database-critical'
    title: '🚨 CRITICAL: Database PVC Alert'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
  email_configs:
  - to: 'dba-team@random.com'
    from: 'alertmanager@random.com'
    headers:
      Subject: 'CRITICAL: Database PVC Alert'
```

#### Dashboard Grafana pour le monitoring

Créer un dashboard Grafana pour visualiser l'utilisation du PVC :

**Requête PromQL pour le graphique :**

```promql
# Utilisation actuelle en pourcentage
(kubelet_volume_stats_used_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"} / kubelet_volume_stats_capacity_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"}) * 100

# Espace utilisé en Go
kubelet_volume_stats_used_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"} / 1024 / 1024 / 1024

# Espace disponible en Go
(kubelet_volume_stats_capacity_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"} - kubelet_volume_stats_used_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"}) / 1024 / 1024 / 1024

# Taux de croissance (sur 24h)
rate(kubelet_volume_stats_used_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"}[24h])
```

#### Vérification manuelle des métriques

```bash
# Vérifier l'utilisation du PVC
kubectl get pvc -n random-db

# Détails du PVC avec métriques (si kubelet expose les métriques)
kubectl describe pvc postgres-data-pvc -n random-db

# Interroger les métriques Prometheus directement (si accessible)
curl -G 'http://prometheus:9090/api/v1/query' \
  --data-urlencode 'query=kubelet_volume_stats_used_bytes{namespace="random-db", persistentvolumeclaim="postgres-data-pvc"}'

# Utiliser kubelet metrics pour obtenir l'utilisation (sur chaque node)
# Nécessite l'accès aux métriques kubelet (port 10250)
```

#### Surveillance avec des outils externes

**Avec kubectl et scripts de surveillance :**

```bash
#!/bin/bash
# scripts/monitor-pvc.sh

PVC_NAMESPACE="random-db"
PVC_NAME="postgres-data-pvc"
WARNING_THRESHOLD=80
CRITICAL_THRESHOLD=90

# Obtenir la capacité et l'utilisation (nécessite kubelet metrics ou autre source)
# Exemple avec kubectl describe (parse la sortie)
PVC_INFO=$(kubectl describe pvc $PVC_NAME -n $PVC_NAMESPACE)

# Pour une solution complète, utiliser un exporter de métriques PVC
# comme prometheus-pvc-exporter ou consulter directement kubelet metrics
```

### 3. Stratégie de backup pour PostgreSQL

Une stratégie de backup robuste est essentielle pour protéger les données de la base PostgreSQL.

#### Architecture de backup recommandée

```
┌─────────────────┐
│  PostgreSQL Pod │
│  (random-db)    │
└────────┬────────┘
         │
         ├──► Backup local (initContainer)
         │
         ├──► Backup vers S3/Object Storage
         │
         └──► Backup vers NFS/PersistentVolume
```

#### Stratégie de backup multi-niveaux

**1. Backup complet quotidien (Full Backup)**

- **Fréquence** : Tous les jours à 02:00 UTC
- **Rétention** : 30 jours
- **Destination** : Object Storage (S3, MinIO, etc.)
- **Format** : Dump PostgreSQL (`pg_dump`)

**2. Backup incrémental horaire (WAL Archiving)**

- **Fréquence** : Toutes les heures
- **Rétention** : 7 jours
- **Destination** : Object Storage
- **Format** : Write-Ahead Logs (WAL)

**3. Backup avant migration/mise à jour (Snapshot)**

- **Fréquence** : Avant chaque changement majeur
- **Rétention** : 90 jours
- **Destination** : Volume Snapshot + Object Storage
- **Format** : Snapshot du PVC + dump SQL

#### Implémentation avec CronJob Kubernetes

**Fichier : `postgres-backup-cronjob.yml`**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
  namespace: random-db
  labels:
    app: random
    component: database
    backup: enabled
spec:
  # Exécution quotidienne à 02:00 UTC
  schedule: "0 2 * * *"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: random
            component: database-backup
        spec:
          serviceAccountName: postgres-backup-sa
          containers:
          - name: postgres-backup
            image: postgres:15-alpine
            env:
            - name: PGHOST
              value: postgres.random-db.svc.cluster.local
            - name: PGPORT
              value: "5432"
            - name: PGUSER
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: username
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-credentials
                  key: password
            - name: PGDATABASE
              value: "random_db"
            - name: BACKUP_S3_BUCKET
              value: "s3://random-postgres-backups"
            - name: BACKUP_S3_ENDPOINT
              value: "https://s3.example.com"
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: s3-backup-credentials
                  key: access-key-id
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: s3-backup-credentials
                  key: secret-access-key
            command:
            - /bin/bash
            - -c
            - |
              set -euo pipefail
              
              # Créer le répertoire de backup
              BACKUP_DIR="/backups"
              mkdir -p $BACKUP_DIR
              
              # Nom du fichier de backup avec timestamp
              BACKUP_FILE="$BACKUP_DIR/postgres-backup-$(date +%Y%m%d-%H%M%S).sql.gz"
              
              echo "=== Démarrage du backup PostgreSQL ==="
              echo "Date: $(date)"
              echo "Base de données: $PGDATABASE"
              
              # Effectuer le dump
              echo "Création du dump..."
              pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE \
                --format=custom \
                --compress=9 \
                --file=$BACKUP_FILE
              
              # Vérifier la taille du backup
              BACKUP_SIZE=$(du -h $BACKUP_FILE | cut -f1)
              echo "Taille du backup: $BACKUP_SIZE"
              
              # Upload vers S3
              echo "Upload vers S3..."
              aws s3 cp $BACKUP_FILE $BACKUP_S3_BUCKET/daily/ \
                --endpoint-url=$BACKUP_S3_ENDPOINT
              
              # Nettoyer les anciens backups locaux (garder les 3 derniers)
              echo "Nettoyage des anciens backups..."
              ls -t $BACKUP_DIR/*.sql.gz | tail -n +4 | xargs -r rm
              
              # Nettoyer les backups S3 de plus de 30 jours
              echo "Nettoyage des backups S3 de plus de 30 jours..."
              aws s3 ls $BACKUP_S3_BUCKET/daily/ --endpoint-url=$BACKUP_S3_ENDPOINT | \
                awk '$1 < "'$(date -d '30 days ago' +%Y-%m-%d)'" {print $4}' | \
                xargs -I {} aws s3 rm $BACKUP_S3_BUCKET/daily/{} --endpoint-url=$BACKUP_S3_ENDPOINT
              
              echo "=== Backup terminé avec succès ==="
            volumeMounts:
            - name: backup-storage
              mountPath: /backups
          volumes:
          - name: backup-storage
            persistentVolumeClaim:
              claimName: postgres-backup-pvc
          restartPolicy: OnFailure
---
# ServiceAccount pour le backup avec permissions minimales
apiVersion: v1
kind: ServiceAccount
metadata:
  name: postgres-backup-sa
  namespace: random-db
---
# Secret pour les credentials S3
apiVersion: v1
kind: Secret
metadata:
  name: s3-backup-credentials
  namespace: random-db
type: Opaque
stringData:
  access-key-id: "YOUR_ACCESS_KEY"
  secret-access-key: "YOUR_SECRET_KEY"
```

#### Backup avec snapshot de volume (alternative)

Pour une approche plus rapide, utiliser les snapshots de volume Kubernetes :

**Fichier : `postgres-backup-snapshot.yml`**

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgres-snapshot-$(date +%Y%m%d)
  namespace: random-db
  labels:
    app: random
    component: database
    backup-type: snapshot
spec:
  source:
    persistentVolumeClaimName: postgres-data-pvc
  volumeSnapshotClassName: csi-snapshotter  # Adapter selon votre CSI driver
```

**CronJob pour créer des snapshots automatiques :**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-snapshot
  namespace: random-db
spec:
  schedule: "0 2 * * *"  # Quotidien à 02:00
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: postgres-snapshot-sa
          containers:
          - name: snapshot-creator
            image: bitnami/kubectl:latest
            command:
            - /bin/bash
            - -c
            - |
              SNAPSHOT_NAME="postgres-snapshot-$(date +%Y%m%d-%H%M%S)"
              cat <<EOF | kubectl apply -f -
              apiVersion: snapshot.storage.k8s.io/v1
              kind: VolumeSnapshot
              metadata:
                name: ${SNAPSHOT_NAME}
                namespace: random-db
              spec:
                source:
                  persistentVolumeClaimName: postgres-data-pvc
                volumeSnapshotClassName: csi-snapshotter
              EOF
              echo "Snapshot créé: ${SNAPSHOT_NAME}"
          restartPolicy: OnFailure
```

#### Procédure de restauration

**1. Restauration depuis un dump SQL :**

```bash
#!/bin/bash
# scripts/restore-postgres.sh

BACKUP_FILE=$1
PGHOST=postgres.random-db.svc.cluster.local
PGPORT=5432
PGUSER=postgres
PGDATABASE=random_db

# Scale down PostgreSQL
kubectl scale deployment postgres -n random-db --replicas=0

# Attendre l'arrêt complet
kubectl wait --for=delete pod -l app=postgres -n random-db --timeout=60s

# Créer un pod temporaire pour la restauration
kubectl run postgres-restore \
  --image=postgres:15-alpine \
  --rm -it \
  --restart=Never \
  -n random-db \
  --env="PGHOST=$PGHOST" \
  --env="PGPORT=$PGPORT" \
  --env="PGUSER=$PGUSER" \
  --env="PGDATABASE=$PGDATABASE" \
  -- sh -c "
    # Télécharger le backup depuis S3
    aws s3 cp s3://random-postgres-backups/daily/$BACKUP_FILE /tmp/backup.sql.gz
    
    # Restaurer
    gunzip -c /tmp/backup.sql.gz | psql -h \$PGHOST -p \$PGPORT -U \$PGUSER -d \$PGDATABASE
  "

# Scale up PostgreSQL
kubectl scale deployment postgres -n random-db --replicas=1
```

**2. Restauration depuis un snapshot de volume :**

```bash
# Créer un PVC depuis le snapshot
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data-pvc-restored
  namespace: random-db
spec:
  dataSource:
    name: postgres-snapshot-20250101-020000
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  storageClassName: random-db-expandable
  resources:
    requests:
      storage: 10Gi
EOF

# Modifier le déploiement PostgreSQL pour utiliser le nouveau PVC
kubectl set volume deployment/postgres -n random-db \
  --name=postgres-storage \
  --claim-name=postgres-data-pvc-restored
```

#### Tests de restauration

**Plan de test mensuel :**

```bash
#!/bin/bash
# scripts/test-backup-restore.sh

# 1. Créer une base de test
kubectl exec -it deployment/postgres -n random-db -- \
  psql -U postgres -c "CREATE DATABASE test_restore;"

# 2. Créer des données de test
kubectl exec -it deployment/postgres -n random-db -- \
  psql -U postgres -d test_restore -c "CREATE TABLE test_table (id INT, data TEXT); INSERT INTO test_table VALUES (1, 'test');"

# 3. Effectuer un backup
./scripts/backup-postgres.sh

# 4. Supprimer les données
kubectl exec -it deployment/postgres -n random-db -- \
  psql -U postgres -c "DROP DATABASE test_restore;"

# 5. Restaurer
./scripts/restore-postgres.sh latest-backup.sql.gz

# 6. Vérifier la restauration
kubectl exec -it deployment/postgres -n random-db -- \
  psql -U postgres -d test_restore -c "SELECT * FROM test_table;"
```

#### Documentation de la stratégie de backup

**Checklist de backup :**

- [ ] Backup quotidien configuré et testé
- [ ] Backup incrémental (WAL) configuré
- [ ] Backup avant chaque migration documenté
- [ ] Procédure de restauration testée et documentée
- [ ] Tests de restauration mensuels planifiés
- [ ] Monitoring des backups (succès/échec) configuré
- [ ] Alertes en cas d'échec de backup configurées
- [ ] Documentation de la procédure de disaster recovery
- [ ] Rotation des backups configurée (30 jours)
- [ ] Backup stocké dans un datacenter différent (geo-redundancy)

**Commandes de surveillance des backups :**

```bash
# Vérifier les CronJobs de backup
kubectl get cronjobs -n random-db

# Vérifier l'historique des jobs de backup
kubectl get jobs -n random-db -l component=database-backup

# Vérifier les logs du dernier backup
kubectl logs -n random-db \
  $(kubectl get pods -n random-db -l component=database-backup --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')

# Lister les snapshots disponibles
kubectl get volumesnapshots -n random-db

# Vérifier les backups dans S3
aws s3 ls s3://random-postgres-backups/daily/ --endpoint-url=https://s3.example.com
```

### 4. Gestion des quotas

- Surveiller régulièrement l'utilisation des quotas
- Ajuster les quotas selon les besoins réels
- Documenter les changements de quotas

### 5. Sécurité

- Ne jamais désactiver les Network Policies en production
- Vérifier régulièrement les permissions RBAC
- Utiliser les ServiceAccounts pour tous les pods
- Ne pas utiliser le ServiceAccount `default`

### 6. Maintenance

- Exécuter régulièrement les scripts de vérification
- Documenter les changements dans les manifests
- Utiliser Git pour versionner les configurations
- Tester les changements dans un environnement de développement

---

## Support et contribution

### En cas de problème

1. Consulter la section [Dépannage](#dépannage)
2. Vérifier les logs et événements Kubernetes
3. Consulter la documentation détaillée des composants
4. Contacter l'équipe platform : `platform-team@random.com`

### Amélioration de la documentation

Les contributions sont les bienvenues ! Pour améliorer cette documentation :

1. Identifier les sections à améliorer
2. Proposer des modifications claires
3. Tester les changements
4. Documenter les nouveaux cas d'usage

---

## Checklist de déploiement

Avant de considérer l'installation comme complète, vérifier :

- [ ] Tous les namespaces sont créés et actifs
- [ ] Les labels et annotations sont correctement appliqués
- [ ] Les ResourceQuotas sont configurés et respectés
- [ ] Les LimitRanges sont configurés
- [ ] Les Network Policies sont actives et fonctionnelles
- [ ] Les ServiceAccounts, Roles et RoleBindings sont créés
- [ ] Le StorageClass est créé et fonctionnel
- [ ] Le PVC PostgreSQL est en état "Bound"
- [ ] Les tests de connectivité passent
- [ ] Les tests RBAC passent
- [ ] La documentation est à jour

---

## Résumé des commandes essentielles

```bash
# Installation complète
./07-setup-namespaces.sh

# Vérification
./07-verify-namespaces.sh

# Application labels/annotations
./06-apply-labels-annotations.sh

# Configuration stockage
./07-setup-simple-storage.sh

# Tests RBAC
./05-rbac_test.sh

# Nettoyage
./07-cleanup-namespaces.sh

# Vérification manuelle
kubectl get all --all-namespaces -l app=random
kubectl get networkpolicies --all-namespaces
kubectl get resourcequota --all-namespaces
kubectl get limitrange --all-namespaces
```

---

**Version :** 1.0  
**Dernière mise à jour :** Novembre 2025  
**Auteur :** Platform Team  
**Contact :** platform-team@random.com

