# Guide de Démarrage Rapide - Lab 1

## 🚀 Installation en 3 étapes

### Étape 1 : Préparation

```bash
cd /home/sismael/Documents/exercices/lab1
chmod +x *.sh
chmod +x test_validation/*.sh
```

### Étape 2 : Installation complète

```bash
./07-setup-namespaces.sh
./06-apply-labels-annotations.sh
```

### Étape 3 : Configuration du stockage

```bash
./07-setup-simple-storage.sh
kubectl apply -f 07-postgres-pvc.yml
```

## ✅ Vérification rapide

```bash
# Vérifier les namespaces
kubectl get namespaces -l app=random

# Vérifier les quotas
kubectl get resourcequota --all-namespaces

# Vérifier les Network Policies
kubectl get networkpolicies --all-namespaces

# Vérifier le PVC
kubectl get pvc -n random-db
```

## 📋 Checklist minimale

- [ ] 5 namespaces créés (random-backend, random-db, random-frontend, random-jobs, random-scheduler)
- [ ] ResourceQuotas appliqués
- [ ] Network Policies actives
- [ ] RBAC configuré
- [ ] StorageClass créé
- [ ] PVC PostgreSQL en état "Bound"

## 🔧 Commandes utiles

```bash
# Voir tous les composants
kubectl get all --all-namespaces -l app=random

# Vérifier les labels
kubectl get namespaces -l app=random --show-labels

# Tester RBAC
./05-rbac_test.sh

# Vérification complète
./07-verify-namespaces.sh
```

## 🆘 Problèmes courants

**PVC en Pending ?**
```bash
kubectl describe pvc postgres-data-pvc -n random-db
kubectl get events -n random-db
```

**Network Policies bloquent ?**
```bash
kubectl get networkpolicies --all-namespaces
kubectl get namespaces --show-labels
```

**Quotas dépassés ?**
```bash
kubectl describe resourcequota -n <namespace>
```

## 📚 Documentation complète

Pour plus de détails, consultez le [README.md](README.md)

## 🧹 Nettoyage

```bash
./07-cleanup-namespaces.sh
```

