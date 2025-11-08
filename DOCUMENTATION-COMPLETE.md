# Documentation Complète - Prérequis et Installation pour les Labs DevOps

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Prérequis système](#prérequis-système)
3. [Installation des outils de base](#installation-des-outils-de-base)
4. [Installation et configuration de Minikube](#installation-et-configuration-de-minikube)
5. [Installation de Helm](#installation-de-helm)
6. [Installation des outils complémentaires](#installation-des-outils-complémentaires)
7. [Configuration du cluster Kubernetes](#configuration-du-cluster-kubernetes)
8. [Prérequis par Lab](#prérequis-par-lab)
9. [Ordre d'installation recommandé](#ordre-dinstallation-recommandé)
10. [Vérifications et tests](#vérifications-et-tests)
11. [Dépannage](#dépannage)

---

## Vue d'ensemble

Cette documentation couvre l'installation complète de tous les outils et prérequis nécessaires pour exécuter les trois labs DevOps :

- **Lab 1** : Infrastructure Kubernetes pour l'Application Random
- **Lab 2** : Gestion du Stockage et Surveillance PVC PostgreSQL
- **Lab 3** : Déploiement Stack Monitoring Grafana (Loki, Mimir, Tempo)

### Architecture globale

```
┌─────────────────────────────────────────────────────┐
│              Environnement Local                     │
│  ┌──────────────┐  ┌──────────────┐                │
│  │   Minikube   │  │     Helm     │                │
│  │   Cluster    │  │   (v3.x)     │                │
│  └──────┬───────┘  └──────┬───────┘                │
│         │                  │                        │
│         └──────────┬───────┘                        │
│                    ▼                                │
│         ┌──────────────────┐                        │
│         │  kubectl Client  │                        │
│         └──────────┬───────┘                        │
│                    │                                │
└────────────────────┼────────────────────────────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │  Kubernetes Cluster   │
         │  (via Minikube)       │
         │                       │
         │  ┌─────────────────┐ │
         │  │   Lab 1         │ │
         │  │  Namespaces     │ │
         │  │  Network Pol.   │ │
         │  │  RBAC           │ │
         │  └─────────────────┘ │
         │                       │
         │  ┌─────────────────┐ │
         │  │   Lab 2         │ │
         │  │  PostgreSQL     │ │
         │  │  Prometheus     │ │
         │  │  Grafana        │ │
         │  └─────────────────┘ │
         │                       │
         │  ┌─────────────────┐ │
         │  │   Lab 3         │ │
         │  │  Loki/Mimir     │ │
         │  │  Tempo          │ │
         │  │  Alloy          │ │
         │  └─────────────────┘ │
         └───────────────────────┘
```

---

## Prérequis système

### Exigences matérielles minimales

- **CPU** : 4 cœurs minimum (8 recommandés)
- **RAM** : 16 Gi minimum (32 Gi recommandés)
  - Minikube : 4 Gi minimum
  - Lab 1 : 2 Gi
  - Lab 2 : 4 Gi
  - Lab 3 : 32 Gi (stack monitoring complète)
- **Stockage** : 50 Gi minimum (100 Gi recommandés)
- **Système d'exploitation** :
  - Linux (Ubuntu 20.04+, Debian 11+, CentOS 8+)
  - macOS 10.15+
  - Windows 10/11 avec WSL2

### Prérequis logiciels

- **Bash** : Version 4.0+ (pour les scripts)
- **curl** : Pour télécharger les outils
- **wget** : Alternative à curl
- **jq** : Pour le traitement JSON
- **base64** : Pour décoder les secrets (généralement inclus)
- **git** : Pour cloner le dépôt (optionnel)

---

## Installation des outils de base

### 1. Installation de kubectl

kubectl est l'outil de ligne de commande pour interagir avec le cluster Kubernetes.

#### Sur Linux

```bash
# Télécharger la dernière version
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Télécharger la somme de contrôle
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

# Vérifier l'intégrité
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Installer
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Vérifier l'installation
kubectl version --client
```

#### Sur macOS

```bash
# Avec Homebrew (recommandé)
brew install kubectl

# Ou télécharger manuellement
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Vérifier
kubectl version --client
```

#### Vérification

```bash
kubectl version --client --output=yaml
```

### 2. Installation de jq

jq est utilisé pour le traitement JSON dans les scripts.

#### Sur Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y jq
```

#### Sur Linux (CentOS/RHEL)

```bash
sudo yum install -y jq
```

#### Sur macOS

```bash
brew install jq
```

#### Vérification

```bash
jq --version
echo '{"test": "value"}' | jq .
```

### 3. Installation de curl et wget

#### Sur Linux (Debian/Ubuntu)

```bash
sudo apt-get update
sudo apt-get install -y curl wget
```

#### Sur Linux (CentOS/RHEL)

```bash
sudo yum install -y curl wget
```

#### Sur macOS

```bash
brew install curl wget
```

---

## Installation et configuration de Minikube

Minikube est l'outil recommandé pour créer un cluster Kubernetes local.

### 1. Installation de Minikube

#### Sur Linux

```bash
# Télécharger le binaire
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Installer
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Vérifier
minikube version
```

#### Sur macOS

```bash
# Avec Homebrew (recommandé)
brew install minikube

# Ou télécharger manuellement
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube
```

#### Vérification

```bash
minikube version
```

### 2. Installation d'un driver hyperviseur

Minikube nécessite un hyperviseur pour créer la VM. Options disponibles :

#### Option A : Docker (recommandé pour Linux)

```bash
# Installer Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER

# Reconnecter ou exécuter
newgrp docker

# Vérifier
docker --version
```

#### Option B : KVM2 (Linux)

```bash
# Installer KVM
sudo apt-get install -y qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils

# Ajouter l'utilisateur au groupe libvirt
sudo usermod -aG libvirt $USER

# Installer le driver minikube pour KVM2
minikube config set driver kvm2
```

#### Option C : VirtualBox (Linux/macOS/Windows)

```bash
# Installer VirtualBox depuis https://www.virtualbox.org/

# Configurer minikube pour utiliser VirtualBox
minikube config set driver virtualbox
```

#### Option D : Hyperkit (macOS)

```bash
# Installer Hyperkit
brew install hyperkit

# Configurer minikube
minikube config set driver hyperkit
```

### 3. Démarrage de Minikube

#### Configuration de base

```bash
# Configuration des ressources (recommandé pour les 3 labs)
minikube config set memory 8192        # 8 Gi de RAM
minikube config set cpus 4             # 4 CPU
minikube config set disk-size 50g      # 50 Gi de disque

# Vérifier la configuration
minikube config view
```

#### Démarrage du cluster

```bash
# Démarrer minikube avec Docker (si disponible)
minikube start --driver=docker

# Ou avec un autre driver
minikube start --driver=kvm2
minikube start --driver=virtualbox
minikube start --driver=hyperkit

# Vérifier le statut
minikube status
```

#### Configuration de kubectl

Minikube configure automatiquement kubectl. Vérifier :

```bash
# Vérifier la connexion
kubectl cluster-info

# Vérifier les nodes
kubectl get nodes

# Vérifier la version de Kubernetes
kubectl version
```

### 4. Activation des addons Minikube

```bash
# Activer le dashboard (optionnel)
minikube addons enable dashboard

# Activer le stockage par défaut (nécessaire pour les PVCs)
minikube addons enable default-storageclass
minikube addons enable storage-provisioner

# Activer les métriques (optionnel, pour kubectl top)
minikube addons enable metrics-server

# Lister les addons
minikube addons list
```

### 5. Vérification du cluster

```bash
# Vérifier les nodes
kubectl get nodes

# Vérifier les composants système
kubectl get pods --all-namespaces

# Vérifier les StorageClasses
kubectl get storageclass

# Tester la création d'un pod
kubectl run test-pod --image=nginx --rm -it --restart=Never -- nginx -v
```

---

## Installation de Helm

Helm est le gestionnaire de paquets pour Kubernetes, nécessaire pour le Lab 3.

### 1. Installation de Helm 3

#### Sur Linux

```bash
# Télécharger Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Ou télécharger manuellement
curl -LO https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz
tar -zxvf helm-v3.12.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm

# Vérifier
helm version
```

#### Sur macOS

```bash
# Avec Homebrew (recommandé)
brew install helm

# Ou télécharger manuellement
curl -LO https://get.helm.sh/helm-v3.12.0-darwin-amd64.tar.gz
tar -zxvf helm-v3.12.0-darwin-amd64.tar.gz
sudo mv darwin-amd64/helm /usr/local/bin/helm
```

#### Vérification

```bash
helm version
```

### 2. Configuration des repositories Helm

Les labs utilisent les repositories suivants :

```bash
# Repository Grafana (pour Loki, Mimir, Tempo, Grafana)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Repository Prometheus Community (pour kube-prometheus-stack)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Vérifier les repositories
helm repo list
```

### 3. Test d'installation

```bash
# Rechercher un chart
helm search repo grafana

# Lister les charts disponibles
helm search repo grafana/loki
helm search repo prometheus-community/kube-prometheus-stack
```

---

## Installation des outils complémentaires

### 1. Installation de MinIO Client (mc)

Le client MinIO est nécessaire pour créer les buckets dans le Lab 3.

#### Sur Linux

```bash
# Télécharger mc
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Vérifier
mc --version
```

#### Sur macOS

```bash
# Avec Homebrew
brew install minio/stable/mc

# Ou télécharger manuellement
wget https://dl.min.io/client/mc/release/darwin-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/
```

#### Vérification

```bash
mc --version
```

### 2. Installation de base64

base64 est généralement inclus dans les systèmes Unix. Vérifier :

```bash
base64 --version
```

Si absent :

```bash
# Sur Linux
sudo apt-get install -y coreutils

# Sur macOS (déjà inclus)
```

### 3. Installation de git (optionnel)

```bash
# Sur Linux (Debian/Ubuntu)
sudo apt-get install -y git

# Sur Linux (CentOS/RHEL)
sudo yum install -y git

# Sur macOS
brew install git

# Vérifier
git --version
```

---

## Configuration du cluster Kubernetes

### 1. Vérification de la configuration kubectl

```bash
# Vérifier le contexte actuel
kubectl config current-context

# Vérifier la configuration
kubectl config view

# Vérifier les permissions
kubectl auth can-i create namespaces
kubectl auth can-i create resourcequotas
kubectl auth can-i create networkpolicies
kubectl auth can-i create persistentvolumeclaims
```

### 2. Configuration des ressources du cluster

Pour le Lab 3, il est recommandé d'augmenter les ressources :

```bash
# Arrêter minikube
minikube stop

# Redémarrer avec plus de ressources
minikube start --memory=16384 --cpus=6 --disk-size=100g

# Ou modifier la configuration
minikube config set memory 16384
minikube config set cpus 6
minikube config set disk-size 100g
minikube start
```

### 3. Vérification des StorageClasses

```bash
# Lister les StorageClasses
kubectl get storageclass

# Vérifier la StorageClass par défaut
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'

# Si aucune StorageClass par défaut, en créer une
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s.io/minikube-hostpath
volumeBindingMode: Immediate
EOF
```

### 4. Activation de métriques-server (optionnel)

Pour utiliser `kubectl top` :

```bash
# Activer l'addon
minikube addons enable metrics-server

# Vérifier
kubectl top nodes
kubectl top pods --all-namespaces
```

---

## Prérequis par Lab

### Lab 1 : Infrastructure Kubernetes

#### Prérequis

- ✅ Cluster Kubernetes fonctionnel (Minikube)
- ✅ kubectl configuré et connecté
- ✅ Accès administrateur au cluster
- ✅ Bash pour exécuter les scripts
- ✅ jq pour le traitement JSON

#### Vérifications

```bash
# Vérifier la connexion
kubectl cluster-info

# Vérifier la version (1.20+)
kubectl version

# Vérifier les permissions
kubectl auth can-i create namespaces
kubectl auth can-i create resourcequotas
kubectl auth can-i create networkpolicies
```

#### Stockage

Le Lab 1 utilise Local Path Provisioner (installé via script). Aucune configuration supplémentaire nécessaire.

### Lab 2 : Gestion du Stockage et Surveillance

#### Prérequis

- ✅ Lab 1 complété (namespace `random-db` créé)
- ✅ Cluster Kubernetes fonctionnel
- ✅ kubectl configuré
- ✅ Helm 3 installé (pour Prometheus Operator, optionnel)
- ✅ StorageClass configuré

#### Vérifications

```bash
# Vérifier que le namespace random-db existe
kubectl get namespace random-db

# Vérifier les StorageClasses
kubectl get storageclass

# Vérifier Helm (si utilisé)
helm version
```

#### Stockage

Le Lab 2 nécessite un StorageClass avec expansion activée. Le script d'installation du Lab 1 crée `random-db-expandable`, mais pour le Lab 2, vous pouvez utiliser :

```bash
# Vérifier le StorageClass du Lab 1
kubectl get storageclass random-db-expandable

# Ou créer le StorageClass du Lab 2
kubectl apply -f lab2/01-storageclass.yaml
```

### Lab 3 : Stack Monitoring Grafana

#### Prérequis

- ✅ Lab 1 complété
- ✅ Lab 2 complété (StorageClass `fast-ssd-expandable`)
- ✅ Cluster Kubernetes fonctionnel
- ✅ Helm 3 installé et configuré
- ✅ kubectl configuré
- ✅ MinIO Client (mc) installé
- ✅ 32 Gi RAM minimum disponible
- ✅ 100 Gi de stockage disponible

#### Vérifications

```bash
# Vérifier Helm
helm version

# Vérifier les repositories Helm
helm repo list | grep -E "(grafana|prometheus)"

# Vérifier MinIO Client
mc --version

# Vérifier les ressources disponibles
kubectl top nodes
kubectl get nodes -o jsonpath='{.items[*].status.capacity.memory}'

# Vérifier le StorageClass
kubectl get storageclass fast-ssd-expandable
```

#### Stockage

Le Lab 3 nécessite :
- StorageClass `fast-ssd-expandable` (du Lab 2)
- MinIO pour le stockage objet (S3-compatible)

---

## Ordre d'installation recommandé

### Phase 1 : Installation des outils de base

```bash
# 1. Installer kubectl
# (voir section Installation des outils de base)

# 2. Installer jq
# (voir section Installation des outils de base)

# 3. Installer curl et wget
# (voir section Installation des outils de base)

# 4. Installer Minikube
# (voir section Installation et configuration de Minikube)

# 5. Installer Helm
# (voir section Installation de Helm)

# 6. Installer MinIO Client (pour Lab 3)
# (voir section Installation des outils complémentaires)
```

### Phase 2 : Configuration du cluster

```bash
# 1. Démarrer Minikube
minikube start --driver=docker --memory=8192 --cpus=4 --disk-size=50g

# 2. Activer les addons nécessaires
minikube addons enable default-storageclass
minikube addons enable storage-provisioner
minikube addons enable metrics-server

# 3. Vérifier le cluster
kubectl get nodes
kubectl get pods --all-namespaces
```

### Phase 3 : Installation des Labs

```bash
# 1. Lab 1 : Infrastructure Kubernetes
cd lab1
chmod +x *.sh
./07-setup-namespaces.sh
./06-apply-labels-annotations.sh
./07-setup-simple-storage.sh
kubectl apply -f 07-postgres-pvc.yml

# 2. Lab 2 : Gestion du Stockage
cd ../lab2
kubectl apply -f 01-storageclass.yaml
# Suivre les instructions du README.md du Lab 2

# 3. Lab 3 : Stack Monitoring
cd ../lab3
# Configurer les repositories Helm
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Suivre les instructions du DEPLOIEMENT-RAPIDE.md du Lab 3
```

---

## Vérifications et tests

### 1. Vérification globale

```bash
# Script de vérification complète
cat << 'EOF' > verify-setup.sh
#!/bin/bash

echo "=== Vérification des outils ==="
echo -n "kubectl: "
kubectl version --client --short 2>/dev/null || echo "❌ Non installé"

echo -n "helm: "
helm version --short 2>/dev/null || echo "❌ Non installé"

echo -n "minikube: "
minikube version --short 2>/dev/null || echo "❌ Non installé"

echo -n "jq: "
jq --version 2>/dev/null || echo "❌ Non installé"

echo -n "mc (MinIO): "
mc --version 2>/dev/null || echo "❌ Non installé"

echo ""
echo "=== Vérification du cluster ==="
echo -n "Cluster: "
kubectl cluster-info 2>/dev/null && echo "✅ Connecté" || echo "❌ Non connecté"

echo -n "Nodes: "
kubectl get nodes 2>/dev/null | grep -q Ready && echo "✅ Prêts" || echo "❌ Non prêts"

echo -n "StorageClasses: "
kubectl get storageclass 2>/dev/null | grep -q . && echo "✅ Configurées" || echo "❌ Non configurées"

echo ""
echo "=== Vérification des Labs ==="
echo -n "Lab 1 (namespaces): "
kubectl get namespaces -l app=random 2>/dev/null | grep -q random && echo "✅ Déployé" || echo "❌ Non déployé"

echo -n "Lab 2 (StorageClass): "
kubectl get storageclass fast-ssd-expandable 2>/dev/null && echo "✅ Déployé" || echo "❌ Non déployé"

echo -n "Lab 3 (MinIO): "
kubectl get pods -n minio -l app=minio 2>/dev/null | grep -q Running && echo "✅ Déployé" || echo "❌ Non déployé"
EOF

chmod +x verify-setup.sh
./verify-setup.sh
```

### 2. Test de création d'un pod

```bash
# Créer un pod de test
kubectl run test-pod --image=nginx --restart=Never

# Vérifier le statut
kubectl get pod test-pod

# Nettoyer
kubectl delete pod test-pod
```

### 3. Test de création d'un PVC

```bash
# Créer un PVC de test
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# Vérifier le statut
kubectl get pvc test-pvc

# Nettoyer
kubectl delete pvc test-pvc
```

### 4. Test de Helm

```bash
# Lister les repositories
helm repo list

# Rechercher un chart
helm search repo grafana/loki

# Tester l'installation (dry-run)
helm install test-loki grafana/loki-distributed --dry-run --debug
```

---

## Dépannage

### Problèmes courants

#### 1. Minikube ne démarre pas

**Symptôme :**
```
Error starting cluster: minikube start
```

**Solutions :**
```bash
# Vérifier les logs
minikube logs

# Réinitialiser minikube
minikube delete
minikube start

# Vérifier le driver
minikube config view
minikube start --driver=docker
```

#### 2. kubectl ne peut pas se connecter

**Symptôme :**
```
The connection to the server was refused
```

**Solutions :**
```bash
# Vérifier que minikube est démarré
minikube status

# Redémarrer minikube
minikube stop
minikube start

# Vérifier la configuration
kubectl config view
kubectl config get-contexts
```

#### 3. PVC reste en "Pending"

**Symptôme :**
```
kubectl get pvc
NAME        STATUS    VOLUME   CAPACITY
test-pvc    Pending
```

**Solutions :**
```bash
# Vérifier les StorageClasses
kubectl get storageclass

# Vérifier les événements
kubectl describe pvc test-pvc

# Activer le provisioner de stockage
minikube addons enable default-storageclass
minikube addons enable storage-provisioner
```

#### 4. Helm ne peut pas installer les charts

**Symptôme :**
```
Error: failed to download "grafana/loki-distributed"
```

**Solutions :**
```bash
# Mettre à jour les repositories
helm repo update

# Vérifier les repositories
helm repo list

# Réajouter le repository
helm repo remove grafana
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

#### 5. Ressources insuffisantes

**Symptôme :**
```
0/1 nodes are available: 1 Insufficient memory
```

**Solutions :**
```bash
# Arrêter minikube
minikube stop

# Redémarrer avec plus de ressources
minikube start --memory=16384 --cpus=6

# Ou modifier la configuration
minikube config set memory 16384
minikube config set cpus 6
minikube start
```

#### 6. MinIO Client (mc) ne fonctionne pas

**Symptôme :**
```
mc: command not found
```

**Solutions :**
```bash
# Installer mc
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
sudo mv mc /usr/local/bin/

# Vérifier
mc --version
```

### Commandes de diagnostic

```bash
# État du cluster
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Ressources
kubectl top nodes
kubectl top pods --all-namespaces

# Stockage
kubectl get storageclass
kubectl get pv
kubectl get pvc --all-namespaces

# Services
kubectl get svc --all-namespaces
kubectl get endpoints --all-namespaces

# Logs Minikube
minikube logs

# État Minikube
minikube status
minikube dashboard --url
```

---

## Ressources supplémentaires

### Documentation officielle

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)

### Documentation des Labs

- [Lab 1 README](lab1/README.md)
- [Lab 2 README](lab2/README.md)
- [Lab 3 README](lab3/README.md)

### Liens utiles

- [Kubernetes Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Minikube Troubleshooting](https://minikube.sigs.k8s.io/docs/handbook/troubleshooting/)

---

## Checklist d'installation complète

### Outils de base
- [ ] kubectl installé et configuré
- [ ] jq installé
- [ ] curl et wget installés
- [ ] git installé (optionnel)

### Minikube
- [ ] Minikube installé
- [ ] Driver hyperviseur installé (Docker/KVM/VirtualBox)
- [ ] Minikube démarré avec suffisamment de ressources
- [ ] Addons nécessaires activés
- [ ] Cluster vérifié et fonctionnel

### Helm
- [ ] Helm 3 installé
- [ ] Repositories Grafana et Prometheus ajoutés
- [ ] Repositories mis à jour

### Outils complémentaires
- [ ] MinIO Client (mc) installé
- [ ] base64 disponible

### Labs
- [ ] Lab 1 déployé et vérifié
- [ ] Lab 2 déployé et vérifié
- [ ] Lab 3 déployé et vérifié

### Vérifications finales
- [ ] Tous les pods sont en état "Running"
- [ ] Tous les PVCs sont en état "Bound"
- [ ] Services accessibles
- [ ] Dashboards Grafana accessibles
- [ ] Métriques Prometheus disponibles

---

**Version :** 1.0  
**Dernière mise à jour :** 2024-01-15  
**Auteur :** Documentation DevOps Labs  
**Contact :** support@devops-labs.com

