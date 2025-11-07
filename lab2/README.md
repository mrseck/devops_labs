# Lab 2 - Gestion du Stockage et Surveillance PVC PostgreSQL

Ce lab met en place une infrastructure de stockage robuste pour PostgreSQL avec surveillance proactive de la saturation du PVC, en réponse à l'alerte critique du document de passation.

## 📋 Objectif

Créer une infrastructure qui prévient automatiquement les problèmes de saturation du stockage pour la base de données PostgreSQL de Random.

## 🏗️ Architecture

```
PostgreSQL Pod
    ↓
PersistentVolumeClaim (PVC) - 50Gi (extensible à 200Gi)
    ↓
StorageClass: fast-ssd-expandable
    ↓
Surveillance & Alertes (Prometheus + Grafana)
```

## 📁 Structure des Fichiers

### Exercice 1 : StorageClass
- `01-storageclass.yaml` - StorageClass avec expansion activée
-  01-storageclass_capture.png

### Exercice 2 : Déploiement PostgreSQL
- `02-postgres-configmap.yaml` - Configuration PostgreSQL
- `02-postgres-secret.yaml` - Secrets (utilisateur/mot de passe)
- `02-postgres-statefulset.yaml` - StatefulSet avec PVC et sidecar de monitoring
- `02-postgres-service-metrics.yaml` - Service pour exposer les métriques

### Exercice 3 : Surveillance Prometheus
- `03-servicemonitor.yaml` - ServiceMonitor pour Prometheus (avec label `team: monitoring`)
- `03-prometheus-instance.yaml` - Instance Prometheus 

### Exercice 4 : Alertes et Alertmanager
- `04-prometheusrule.yaml` - Règles d'alerte (70%, 85%, 95%, croissance) utilisant les métriques `pvc_*`
- `04-alertmanager-config.yaml` - Configuration Alertmanager avec routing par sévérité
- `04-webhook-receiver.yaml` - Webhook receiver pour recevoir et afficher les alertes
- `04-test-pvc-saturation.sh` - Script de test pour simuler la saturation du PVC

### Exercice 5 : Dashboard Grafana
- `05-grafana-dashboard.json` - Dashboard Grafana (JSON)
- `05-grafana-dashboard-configmap.yaml` - ConfigMap pour provisionner le dashboard

### Exercice 6 : Extension du PVC
- `06-extend-pvc.sh` - Script automatisé pour étendre le PVC

### Exercice 7 : Stratégie de Backup
- `07-backup-snapshotclass.yaml` - VolumeSnapshotClass
- `07-backup-volumesnapshot.yaml` - Exemple de VolumeSnapshot
- `07-backup-cronjob.yaml` - CronJob pour pg_dump quotidien
- `07-restore-backup.sh` - Script de restauration

### Exercice 8 : Runbook
- `08-runbook.md` - Runbook complet de gestion de crise
- `08-emergency-cleanup.sh` - Script de nettoyage d'urgence

## 🚀 Déploiement

### Prérequis

- Cluster Kubernetes fonctionnel
- Namespace `random-db` créé (Lab 1)
- `kubectl` et `helm` installés
- Prometheus Operator installé
- Accès à un système de stockage (local-path, NFS, ou cloud provider)

### Étapes de Déploiement

1. **Créer le StorageClass**
```bash
kubectl apply -f 01-storageclass.yaml
kubectl get storageclass
```

2. **Déployer PostgreSQL**
```bash
kubectl apply -f 02-postgres-configmap.yaml
kubectl apply -f 02-postgres-secret.yaml
kubectl apply -f 02-postgres-statefulset.yaml
kubectl apply -f 02-postgres-service-metrics.yaml

# Vérifier le déploiement
kubectl get pods -n random-db
kubectl get pvc -n random-db
```

3. **Configurer la Surveillance Prometheus**
```bash
# Créer l'instance Prometheus
kubectl apply -f 03-prometheus-instance.yaml

# Configurer le ServiceMonitor (avec label team: monitoring requis)
kubectl apply -f 03-servicemonitor.yaml

# Vérifier que Prometheus scrap les métriques
kubectl port-forward -n default prometheus-prometheus-0 9090:9090

# Dans un navigateur: http://localhost:9090
# Rechercher: pvc_usage_percent, pvc_capacity_bytes, pvc_used_bytes
```

4. **Configurer les Alertes**
```bash
# Déployer les règles d'alerte Prometheus
kubectl apply -f 04-prometheusrule.yaml

# Configurer Alertmanager (optionnel, si Alertmanager est déployé)
kubectl apply -f 04-alertmanager-config.yaml

# Vérifier les alertes dans Prometheus
# http://localhost:9090/alerts
```

5. **Configurer Grafana**
```bash
kubectl apply -f 05-grafana-dashboard-configmap.yaml

# Vérifier que Grafana démarrN
kubectl port-forward -n random-db svc/grafana 3000:3000
```

6. **Tester la Connexion PostgreSQL**
```bash
kubectl exec -it -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb
```

## 🔧 Utilisation

### Extension du PVC

```bash
chmod +x 06-extend-pvc.sh
./06-extend-pvc.sh random-db postgres-data 60Gi
```

### Nettoyage d'Urgence

```bash
chmod +x 08-emergency-cleanup.sh
./08-emergency-cleanup.sh random-db postgres-0
```

### Backup et Restauration

**Créer un snapshot :**
```bash
kubectl apply -f 07-backup-volumesnapshot.yaml
```

**Créer un backup pg_dump :**
```bash
kubectl apply -f 07-backup-cronjob.yaml
```

**Restaurer un backup :**
```bash
chmod +x 07-restore-backup.sh
./07-restore-backup.sh /backups/20240115/postgres_backup.dump.gz random-db postgres-0
```

## 📊 Monitoring

### Métriques Exposées

Le sidecar `pvc-monitor` dans le pod PostgreSQL expose les métriques suivantes (avec label `namespace="random-db"`) :

- `pvc_capacity_bytes{namespace="random-db"}` - Capacité totale du PVC en bytes
- `pvc_used_bytes{namespace="random-db"}` - Espace utilisé en bytes
- `pvc_available_bytes{namespace="random-db"}` - Espace disponible en bytes
- `pvc_usage_percent{namespace="random-db"}` - Pourcentage d'utilisation (0-100)

**Accès aux métriques :**
```bash
# Port-forward vers le pod PostgreSQL
kubectl port-forward -n random-db postgres-0 9091:9090

# Accéder aux métriques
curl http://localhost:9091/metrics
```

### Alertes Configurées

Les alertes utilisent les métriques `pvc_*` exposées par le sidecar :

1. **PVCUsageWarning** 
   - Seuil : 70% d'utilisation
   - Sévérité : `warning`
   - Durée : 5 minutes
   - Expression : `pvc_usage_percent{namespace="random-db"} > 70`

2. **PVCUsageCritical**
   - Seuil : 85% d'utilisation
   - Sévérité : `critical`
   - Durée : 2 minutes
   - Expression : `pvc_usage_percent{namespace="random-db"} > 85`

3. **PVCUsageEmergency**
   - Seuil : 95% d'utilisation
   - Sévérité : `emergency`
   - Durée : 1 minute
   - Expression : `pvc_usage_percent{namespace="random-db"} > 95`

4. **PVCGrowthRate**
   - Détection : Projection de saturation dans moins de 7 jours
   - Sévérité : `warning`
   - Durée : 1 heure
   - Condition : Utilisation actuelle > 50% ET projection de saturation < 7 jours
   - Expression : `predict_linear(pvc_used_bytes{namespace="random-db"}[7d], 7*24*3600) > pvc_capacity_bytes{namespace="random-db"} AND pvc_usage_percent{namespace="random-db"} > 50`

### Configuration Alertmanager

L'Alertmanager route les alertes selon leur sévérité :
- **Emergency** → `emergency-team` (répétition toutes les 5 minutes)
- **Critical** → `oncall-team` (répétition toutes les 30 minutes)
- **Warning** → `monitoring-team` (répétition toutes les 4 heures)
- **Default** → Webhook receiver (pour les tests)

### Accès aux Dashboards

**Prometheus :**
```bash
# Port-forward vers Prometheus
kubectl port-forward -n default svc/prometheus-web 9090:9090
# Ou via NodePort (port 30090)
```
- Interface web : `http://localhost:9090`
- Alertes : `http://localhost:9090/alerts`
- Graph : `http://localhost:9090/graph`
- Targets : `http://localhost:9090/targets`

**Webhook Receiver (pour les tests) :**
```bash
# Voir les logs du webhook receiver
kubectl logs -n random-db -l app=webhook-receiver -f
```

**Grafana :**
- Interface : `http://grafana.example.com` (dashboard: "PostgreSQL PVC Monitoring")

## 🧪 Tests

### Test de Charge

Simuler une montée en charge du stockage :

```bash
# Créer une table de test et insérer des données
kubectl exec -it -n random-db postgres-0 -c postgres -- psql -U postgres -d randomdb <<EOF
CREATE TABLE test_data AS 
SELECT generate_series(1, 1000000) AS id, 
       md5(random()::text) AS data;
EOF

# Vérifier l'utilisation
kubectl exec -n random-db postgres-0 -c postgres -- df -h /var/lib/postgresql/data
```

### Test de Saturation du PVC

**Simuler la saturation du PVC :**
```bash
# Utiliser le script de test fourni
chmod +x 04-test-pvc-saturation.sh
./04-test-pvc-saturation.sh

# Ou manuellement
kubectl exec -n random-db postgres-0 -- bash -c '
  for i in {1..100}; do
    dd if=/dev/zero of=/var/lib/postgresql/data/testfile_$i.dat bs=1M count=100 2>/dev/null
    echo "Fichier $i créé ($(df -h /var/lib/postgresql/data | tail -1 | awk "{print \$5}"))"
    sleep 2
  done
'
```

**Vérifier le déclenchement des alertes :**
```bash
# 1. Vérifier les métriques dans Prometheus
# http://localhost:9090/graph?g0.expr=pvc_usage_percent{namespace="random-db"}

# 2. Vérifier les alertes
# http://localhost:9090/alerts

# 3. Surveiller les logs du webhook receiver
kubectl logs -n random-db -l app=webhook-receiver -f

# 4. Vérifier l'utilisation du PVC
kubectl exec -n random-db postgres-0 -c postgres -- df -h /var/lib/postgresql/data
```

**Tests à effectuer :**
1. Remplir progressivement le PVC jusqu'à 70% (alerte Warning)
2. Continuer jusqu'à 85% (alerte Critical)
3. Poursuivre jusqu'à 95% (alerte Emergency)
4. Vérifier le déclenchement des alertes aux bons seuils
5. Tester la procédure d'extension sous charge
6. Valider la restauration depuis un backup

## 📚 Documentation

- **Runbook** : Voir `08-runbook.md` pour les procédures de gestion de crise
- **QCM** : Réponses dans le PDF du Lab 2

## ⚠️ Notes Importantes

1. **Adapter le StorageClass** : Modifier le `provisioner` dans `01-storageclass.yaml` selon votre environnement (local-path pour k3s, ebs.csi.aws.com pour AWS, etc.)

2. **Sécurité** : Changer le mot de passe PostgreSQL dans `02-postgres-secret.yaml` en production !

3. **Monitoring** : 
   - Le sidecar de monitoring utilise Python pour exposer les métriques Prometheus
   - Les métriques incluent le label `namespace` pour faciliter le filtrage
   - Le ServiceMonitor doit avoir le label `team: monitoring` pour être sélectionné par Prometheus
   - La PrometheusRule doit avoir le label `prometheus: default` correspondant à l'instance Prometheus
   - Pour un environnement de production, considérer l'utilisation d'un exporter Prometheus dédié (node-exporter, etc.)

4. **Configuration Prometheus** :
   - L'instance Prometheus dans `04-prometheus-instance.yaml` utilise le sélecteur `team: monitoring` pour les ServiceMonitors
   - Le `ruleSelector: {}` permet de charger toutes les PrometheusRules (peut être restreint si nécessaire)
   - Le ServiceMonitor dans `03-servicemonitor.yaml` doit avoir le label `team: monitoring`

5. **Backups** : Les backups sont configurés pour s'exécuter quotidiennement à 2h du matin. Ajuster selon vos besoins.

6. **Tests d'alertes** : 
   - Le script `04-test-pvc-saturation.sh` génère environ 10GB de données de test
   - Pour un PVC de 50Gi, cela représente environ 20% d'utilisation
   - Pour tester les alertes, vous devrez peut-être ajuster le script ou créer plus de données
   - N'oubliez pas de nettoyer les fichiers de test après les tests : `kubectl exec -n random-db postgres-0 -- rm -f /var/lib/postgresql/data/testfile_*.dat`

## 🔍 Validation

Checklist de validation :

**Exercice 1-2 : Infrastructure de base**
- [ ] StorageClass configuré avec expansion activée
- [ ] PostgreSQL déployé avec StatefulSet et PVC
- [ ] Sidecar de monitoring opérationnel et exposant les métriques

**Exercice 3 : Surveillance**
- [ ] ServiceMonitor créé avec le label `team: monitoring`
- [ ] Instance Prometheus déployée
- [ ] Métriques `pvc_*` visibles dans Prometheus (avec label `namespace`)
- [ ] ServiceMonitor détecté par Prometheus (vérifier dans `/targets`)

**Exercice 4 : Alertes**
- [ ] PrometheusRule déployée avec le label `prometheus: default`
- [ ] Règles d'alerte chargées dans Prometheus (vérifier dans `/rules`)
- [ ] Alertes visibles dans l'interface Prometheus (`/alerts`)
- [ ] Webhook receiver déployé et fonctionnel
- [ ] Configuration Alertmanager appliquée (si Alertmanager est déployé)
- [ ] Test de saturation effectué et alertes déclenchées aux bons seuils

**Exercice 5-8 : Dashboard et procédures**
- [ ] Dashboard Grafana fonctionnel
- [ ] Procédure d'extension documentée et testée
- [ ] Stratégie de backup opérationnelle
- [ ] Runbook complet et accessible

## 📞 Support

Pour toute question ou problème, consulter :
- Le runbook (`08-runbook.md`)
- La documentation Kubernetes
- L'équipe DevOps

---

## 🔧 Dépannage

### Les métriques ne sont pas scrapées par Prometheus

1. Vérifier que le ServiceMonitor a le label `team: monitoring` :
```bash
kubectl get servicemonitor -n random-db postgres-pvc-monitor -o yaml | grep -A 5 labels
```

2. Vérifier que Prometheus détecte le ServiceMonitor :
```bash
# Port-forward vers Prometheus
kubectl port-forward -n default svc/prometheus-web 9090:9090
# Aller sur http://localhost:9090/targets
```

3. Vérifier que le service de métriques existe et pointe vers les pods :
```bash
kubectl get svc -n random-db postgres-metrics
kubectl get endpoints -n random-db postgres-metrics
```

### Les alertes ne se déclenchent pas

1. Vérifier que les métriques sont disponibles :
```bash
# Dans Prometheus, exécuter la requête :
pvc_usage_percent{namespace="random-db"}
```

2. Vérifier que la PrometheusRule est chargée :
```bash
kubectl get prometheusrule -n random-db postgres-pvc-alerts
# Dans Prometheus : http://localhost:9090/rules
```

3. Vérifier que le label `prometheus: default` correspond à l'instance Prometheus :
```bash
kubectl get prometheus -n default prometheus -o yaml | grep -A 2 labels
kubectl get prometheusrule -n random-db postgres-pvc-alerts -o yaml | grep prometheus
```

4. Tester manuellement une règle d'alerte :
```bash
# Dans Prometheus, exécuter :
pvc_usage_percent{namespace="random-db"} > 70
```

### Les métriques n'ont pas de label namespace

1. Redémarrer le pod PostgreSQL pour recharger le sidecar avec la nouvelle configuration :
```bash
kubectl rollout restart statefulset/postgres -n random-db
```

2. Vérifier que la variable d'environnement NAMESPACE est définie :
```bash
kubectl exec -n random-db postgres-0 -c pvc-monitor -- env | grep NAMESPACE
```

---

**Dernière mise à jour** : 2024-11-07

