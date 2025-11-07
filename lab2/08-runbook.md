# Runbook - Gestion de Crise : Saturation du PVC PostgreSQL

## Vue d'ensemble

Ce runbook décrit les procédures à suivre en cas de saturation du PVC PostgreSQL dans le namespace `random-db`. Il répond à l'alerte critique du document de passation concernant le risque d'interruption des services.

---

## 1. Détection du Problème

### Alertes Prometheus

Les alertes suivantes peuvent se déclencher :

- **PVCUsageWarning** (70%) : Sévérité `warning`, durée 5 minutes
- **PVCUsageCritical** (85%) : Sévérité `critical`, durée 2 minutes
- **PVCUsageEmergency** (95%) : Sévérité `emergency`, durée 1 minute
- **PVCGrowthRate** : Projection de saturation dans moins de 7 jours

### Symptômes Observables

- Alertes Prometheus/Alertmanager
- Erreurs dans les logs PostgreSQL : "No space left on device"
- Échec des opérations d'écriture dans la base de données
- Pod PostgreSQL en état `CrashLoopBackOff` ou `Error`

### Vérification Rapide

```bash
# Vérifier l'utilisation du PVC
kubectl get pvc -n random-db postgres-data

# Vérifier l'espace dans le pod
kubectl exec -n random-db postgres-0 -c postgres -- df -h /var/lib/postgresql/data

# Vérifier les métriques Prometheus
# Dans Grafana ou Prometheus UI, consulter: pvc_usage_percent
```

---

## 2. Diagnostic Rapide

### Commandes de Vérification

```bash
# 1. État du PVC
kubectl describe pvc -n random-db postgres-data

# 2. État du pod PostgreSQL
kubectl get pod -n random-db -l app=postgresql
kubectl describe pod -n random-db postgres-0
kubectl logs -n random-db postgres-0 -c postgres --tail=50

# 3. Utilisation réelle du filesystem
kubectl exec -n random-db postgres-0 -c postgres -- df -h /var/lib/postgresql/data
kubectl exec -n random-db postgres-0 -c postgres -- du -sh /var/lib/postgresql/data/*

# 4. Taille des plus grandes tables
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;
"

# 5. Espace utilisé par les WAL (Write-Ahead Logs)
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "
SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS wal_size;
"
```

---

## 3. Actions d'Urgence

### 3.1 Libération d'Espace Immédiate

**⚠️ ATTENTION : Ces actions peuvent impacter les performances ou la disponibilité**

#### A. Nettoyage des WAL (Write-Ahead Logs)

```bash
# Vérifier les WAL
kubectl exec -n random-db postgres-0 -c postgres -- ls -lh /var/lib/postgresql/data/pgdata/pg_wal/

# Forcer un checkpoint pour archiver les WAL
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "CHECKPOINT;"

# Si pg_archive est configuré, archiver les WAL anciens
# Sinon, vérifier max_wal_size dans la configuration
```

#### B. VACUUM et VACUUM FULL

```bash
# VACUUM standard (non bloquant)
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "VACUUM ANALYZE;"

# VACUUM FULL (bloquant, nécessite un lock exclusif)
# ⚠️ À utiliser uniquement si absolument nécessaire
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "VACUUM FULL;"
```

#### C. Suppression des Logs Anciens

```bash
# Supprimer les logs PostgreSQL de plus de 7 jours
kubectl exec -n random-db postgres-0 -c postgres -- find /var/lib/postgresql/data -name "*.log" -mtime +7 -delete
```

#### D. Script d'Urgence Automatisé

Utiliser le script `emergency-cleanup.sh` :

```bash
./emergency-cleanup.sh random-db postgres-0
```

---

## 4. Extension du PVC

### Procédure Détaillée

#### Étape 1 : Vérifier le Support d'Expansion

```bash
STORAGE_CLASS=$(kubectl get pvc -n random-db postgres-data -o jsonpath='{.spec.storageClassName}')
kubectl get storageclass $STORAGE_CLASS -o jsonpath='{.allowVolumeExpansion}'
# Doit retourner "true"
```

#### Étape 2 : Étendre le PVC

```bash
# Méthode 1 : Utiliser le script automatisé
./06-extend-pvc.sh random-db postgres-data 60Gi

# Méthode 2 : Commande manuelle
kubectl patch pvc -n random-db postgres-data -p '{"spec":{"resources":{"requests":{"storage":"60Gi"}}}}'
```

#### Étape 3 : Vérifier l'Extension

```bash
# Vérifier côté Kubernetes
kubectl get pvc -n random-db postgres-data

# Vérifier dans le pod (peut nécessiter un redémarrage)
kubectl exec -n random-db postgres-0 -c postgres -- df -h /var/lib/postgresql/data
```

#### Étape 4 : Redémarrage si Nécessaire

Si le filesystem n'a pas été étendu automatiquement :

```bash
# Redémarrer le pod (StatefulSet le recréera automatiquement)
kubectl delete pod -n random-db postgres-0

# Attendre que le pod soit prêt
kubectl wait --for=condition=ready pod -n random-db postgres-0 --timeout=300s
```

---

## 5. Nettoyage PostgreSQL

### Commandes de Maintenance

```bash
# 1. Analyser les statistiques
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "ANALYZE;"

# 2. VACUUM sur toutes les bases
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "VACUUM VERBOSE;"

# 3. Identifier les tables les plus volumineuses
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;
"

# 4. Nettoyer les anciennes réplications slots (si applicable)
kubectl exec -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb -c "
SELECT pg_drop_replication_slot(slot_name) 
FROM pg_replication_slots 
WHERE active = false;
"
```

---

## 6. Post-Mortem

### Analyse des Causes

1. **Croissance des données** : Analyser les métriques de croissance
2. **WAL non archivés** : Vérifier la configuration de `max_wal_size` et `wal_keep_size`
3. **Tables non nettoyées** : Vérifier la fréquence des VACUUM
4. **Backups non nettoyés** : Vérifier la rotation des backups
5. **Logs volumineux** : Vérifier la configuration de logging

### Questions à Poser

- Quand la croissance a-t-elle commencé ?
- Y a-t-il eu un changement récent (migration, import massif) ?
- Les alertes ont-elles fonctionné correctement ?
- Le temps de réaction était-il approprié ?

### Documentation

Documenter :
- Heure de détection
- Actions prises
- Temps de résolution
- Impact sur les services
- Recommandations pour éviter la récurrence

---

## 7. Prévention

### Ajustements de Configuration

#### PostgreSQL

```yaml
# Dans le ConfigMap postgres-config
max_wal_size: "4GB"  # Augmenter si nécessaire
min_wal_size: "1GB"
wal_keep_size: "1GB"  # Si réplication
```

#### Monitoring

- Vérifier que les alertes sont bien configurées
- Tester régulièrement les alertes
- Configurer des notifications (email, Slack, PagerDuty)

#### Maintenance Automatique

- Configurer un CronJob pour VACUUM automatique
- Configurer la rotation des logs
- Vérifier régulièrement la taille des backups

#### Planification

- Planifier l'extension préventive du PVC
- Réviser la stratégie de rétention des données
- Considérer l'archivage des données anciennes

---

## Checklist d'Urgence

Imprimer cette checklist pour une intervention rapide :

```
[ ] 1. Vérifier l'alerte dans Prometheus/Alertmanager
[ ] 2. Confirmer l'utilisation du PVC (kubectl get pvc)
[ ] 3. Vérifier l'espace dans le pod (df -h)
[ ] 4. Consulter les logs PostgreSQL
[ ] 5. Exécuter VACUUM si possible
[ ] 6. Si > 85% : Préparer l'extension du PVC
[ ] 7. Si > 95% : Extension immédiate + cleanup d'urgence
[ ] 8. Vérifier la restauration du service
[ ] 9. Documenter l'incident
[ ] 10. Planifier le post-mortem
```

---

## Contacts

- **Équipe DevOps** : devops@example.com
- **On-Call** : +33 X XX XX XX XX
- **Wiki** : https://wiki.example.com/postgresql-pvc
- **Documentation** : https://docs.example.com/k8s/postgresql

---

**Dernière mise à jour** : 2024-01-15  
**Version** : 1.0

