# Labs DevOps - Infrastructure Kubernetes et Monitoring

## 📋 Vue d'ensemble

Ce projet contient trois labs complets pour apprendre et pratiquer DevOps avec Kubernetes :

- **Lab 1** : Infrastructure Kubernetes pour l'Application Random
- **Lab 2** : Gestion du Stockage et Surveillance PVC PostgreSQL
- **Lab 3** : Déploiement Stack Monitoring Grafana (Loki, Mimir, Tempo)

## 🚀 Démarrage rapide

### 1. Installation des prérequis

Consultez la **[Documentation Complète des Prérequis](DOCUMENTATION-COMPLETE.md)** pour installer tous les outils nécessaires :

- Minikube (cluster Kubernetes local)
- kubectl (client Kubernetes)
- Helm 3 (gestionnaire de paquets)
- Outils complémentaires (jq, curl, mc, etc.)

### 2. Vérification des prérequis

Exécutez le script de vérification automatique :

```bash
./verify-prerequisites.sh
```

### 3. Installation des Labs

#### Lab 1 : Infrastructure Kubernetes

```bash
cd lab1
chmod +x *.sh
./07-setup-namespaces.sh
./06-apply-labels-annotations.sh
./07-setup-simple-storage.sh
kubectl apply -f 07-postgres-pvc.yml
```

Consultez le [README du Lab 1](lab1/README.md) pour plus de détails.

#### Lab 2 : Gestion du Stockage

```bash
cd lab2
kubectl apply -f 01-storageclass.yaml
# Suivre les instructions du README.md
```

Consultez le [README du Lab 2](lab2/README.md) pour plus de détails.

#### Lab 3 : Stack Monitoring

```bash
cd lab3
# Configurer les repositories Helm
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Suivre les instructions du DEPLOIEMENT-RAPIDE.md
```

Consultez le [README du Lab 3](lab3/README.md) pour plus de détails.

## 📚 Documentation

### Documentation principale

- **[Documentation Complète des Prérequis](DOCUMENTATION-COMPLETE.md)** - Guide d'installation de tous les outils nécessaires
- **[Script de Vérification](verify-prerequisites.sh)** - Vérification automatique des prérequis

### Documentation par Lab

- **[Lab 1 - README](lab1/README.md)** - Infrastructure Kubernetes
- **[Lab 1 - Guide Rapide](lab1/GUIDE-RAPIDE.md)** - Installation rapide
- **[Lab 2 - README](lab2/README.md)** - Gestion du Stockage
- **[Lab 3 - README](lab3/README.md)** - Stack Monitoring
- **[Lab 3 - Déploiement Rapide](lab3/DEPLOIEMENT-RAPIDE.md)** - Installation rapide

## 🔧 Prérequis minimaux

### Système

- **CPU** : 4 cœurs minimum (8 recommandés)
- **RAM** : 16 Gi minimum (32 Gi recommandés pour Lab 3)
- **Stockage** : 50 Gi minimum (100 Gi recommandés)
- **OS** : Linux, macOS, ou Windows avec WSL2

### Outils

- **kubectl** : Version 1.20+
- **Minikube** : Dernière version
- **Helm** : Version 3.0+
- **jq** : Pour le traitement JSON
- **curl** : Pour télécharger les outils
- **MinIO Client (mc)** : Pour le Lab 3 (optionnel)

Consultez la [Documentation Complète](DOCUMENTATION-COMPLETE.md) pour les instructions d'installation détaillées.

## 📖 Structure du projet

```
devops_labs/
├── DOCUMENTATION-COMPLETE.md      # Documentation complète des prérequis
├── verify-prerequisites.sh        # Script de vérification des prérequis
├── README.md                      # Ce fichier
│
├── lab1/                          # Lab 1 : Infrastructure Kubernetes
│   ├── README.md
│   ├── GUIDE-RAPIDE.md
│   ├── 01-namespaces.yml
│   ├── 02-quotas.yml
│   ├── 03-limits.yml
│   ├── 04-network-policies.yml
│   ├── 05-rbac.yml
│   └── ...
│
├── lab2/                          # Lab 2 : Gestion du Stockage
│   ├── README.md
│   ├── 01-storageclass.yaml
│   ├── 02-postgres-statefulset.yaml
│   ├── 03-prometheus-instance.yaml
│   ├── 04-prometheusrule.yaml
│   ├── 05-grafana-deployment.yaml
│   └── ...
│
└── lab3/                          # Lab 3 : Stack Monitoring
    ├── README.md
    ├── DEPLOIEMENT-RAPIDE.md
    ├── 01-minio-deployment.yaml
    ├── 02-loki-deploy.sh
    ├── 03-mimir-deploy.sh
    ├── 04-tempo-deploy.sh
    └── ...
```

## ✅ Checklist d'installation

### Phase 1 : Prérequis

- [ ] kubectl installé et configuré
- [ ] Minikube installé et démarré
- [ ] Helm 3 installé
- [ ] jq installé
- [ ] curl et wget installés
- [ ] MinIO Client installé (pour Lab 3)

### Phase 2 : Cluster

- [ ] Minikube démarré avec suffisamment de ressources
- [ ] Cluster Kubernetes accessible
- [ ] StorageClasses configurées
- [ ] Addons Minikube activés

### Phase 3 : Labs

- [ ] Lab 1 déployé et vérifié
- [ ] Lab 2 déployé et vérifié
- [ ] Lab 3 déployé et vérifié

## 🆘 Dépannage

### Problèmes courants

1. **Minikube ne démarre pas**
   - Vérifier les logs : `minikube logs`
   - Vérifier le driver : `minikube config view`
   - Réinitialiser : `minikube delete && minikube start`

2. **kubectl ne peut pas se connecter**
   - Vérifier que Minikube est démarré : `minikube status`
   - Redémarrer Minikube : `minikube stop && minikube start`

3. **PVC reste en "Pending"**
   - Vérifier les StorageClasses : `kubectl get storageclass`
   - Activer le provisioner : `minikube addons enable default-storageclass`

4. **Ressources insuffisantes**
   - Augmenter les ressources : `minikube start --memory=16384 --cpus=6`

Consultez la section [Dépannage](DOCUMENTATION-COMPLETE.md#dépannage) de la documentation complète pour plus de détails.

## 📞 Support

Pour toute question ou problème :

1. Consultez la [Documentation Complète](DOCUMENTATION-COMPLETE.md)
2. Vérifiez les READMEs de chaque Lab
3. Exécutez le script de vérification : `./verify-prerequisites.sh`
4. Consultez les logs : `minikube logs`, `kubectl logs`

## 📝 Licence

Ce projet est fourni à des fins éducatives.

## 🔗 Ressources

- [Documentation Kubernetes](https://kubernetes.io/docs/)
- [Documentation Minikube](https://minikube.sigs.k8s.io/docs/)
- [Documentation Helm](https://helm.sh/docs/)
- [Documentation Grafana](https://grafana.com/docs/)

---

**Version :** 1.0  
**Dernière mise à jour :** 2024-01-15

