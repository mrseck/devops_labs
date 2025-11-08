   # Lab 3 - Déploiement Stack Monitoring Grafana (Loki, Mimir, Tempo)

## 📋 Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Architecture](#architecture)
3. [Prérequis](#prérequis)
4. [Structure des fichiers](#structure-des-fichiers)
5. [Installation étape par étape](#installation-étape-par-étape)
6. [Validation](#validation)
7. [Documentation détaillée](#documentation-détaillée)

---

## Vue d'ensemble

Ce lab permet de déployer une stack complète d'observabilité basée sur l'écosystème Grafana comprenant :
- **Loki** : Agrégation de logs
- **Mimir** : Métriques TSDB (Time Series Database)
- **Tempo** : Traces distribuées
- **Alloy** : Collecteurs de logs, métriques et traces
- **MinIO** : Stockage objet (compatible S3)
- **Grafana** : Visualisation et dashboards

### Objectif

Mettre en place l'infrastructure de monitoring décrite dans le document "Projet Monitoring des Cluster" pour assurer l'observabilité complète de la plateforme Random.

---

## Architecture

### Architecture des Trois Piliers

```
┌──────────────────────────────────────────────────┐
│            Applications                           │
│  (random-backend, random-jobs, etc.)             │
└────────┬─────────────┬──────────────┬────────────┘
         │             │              │
    Metrics        Traces          Logs
         │             │              │
         ▼             ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│Alloy Metrics│ │Alloy Traces │ │ Alloy Logs  │
└──────┬──────┘ └──────┬──────┘ └──────┬──────┘
       │               │               │
       ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   Mimir    │ │    Tempo    │ │    Loki     │
└──────┬──────┘ └──────┬──────┘ └──────┬──────┘
       │               │               │
       └───────────────┴───────────────┘
                      │
                      ▼
              ┌─────────────────┐
              │      MinIO      │
              │  (S3 Storage)   │
              └─────────────────┘
                      ▲
                      │
              ┌─────────────────┐
              │     Grafana     │
              │ (Visualization) │
              └─────────────────┘
```

---

## Prérequis

- Cluster Kubernetes fonctionnel
- Helm 3 installé
- kubectl configuré
- 32Gi RAM minimum disponible sur le cluster
- 100Gi de stockage disponible
- Namespaces des Labs 1 et 2 déployés
- StorageClass `fast-ssd-expandable` (du Lab 2)

### Vérification des prérequis

```bash
# Vérifier la connexion au cluster
kubectl cluster-info

# Vérifier Helm
helm version

# Vérifier les ressources disponibles
kubectl top nodes

# Vérifier le StorageClass
kubectl get storageclass fast-ssd-expandable
```

---

## Structure des fichiers

### Exercice 1 : Déploiement MinIO
- `01-minio-namespace.yaml` - Namespace MinIO
- `01-minio-secret.yaml` - Credentials MinIO
- `01-minio-pvc.yaml` - PersistentVolumeClaim (50Gi)
- `01-minio-deployment.yaml` - Déploiement MinIO
- `01-minio-create-buckets.sh` - Script de création des buckets

### Exercice 2 : Déploiement Loki
- `02-loki-namespace.yaml` - Namespace Loki
- `02-loki-secret.yaml` - Credentials S3 pour Loki
- `02-loki-values.yaml` - Values Helm pour Loki
- `02-loki-deploy.sh` - Script de déploiement

### Exercice 3 : Déploiement Mimir
- `03-mimir-namespace.yaml` - Namespace Mimir
- `03-mimir-secret.yaml` - Credentials S3 pour Mimir
- `03-mimir-values.yaml` - Values Helm pour Mimir
- `03-mimir-deploy.sh` - Script de déploiement

### Exercice 4 : Déploiement Tempo
- `04-tempo-namespace.yaml` - Namespace Tempo
- `04-tempo-secret.yaml` - Credentials S3 pour Tempo
- `04-tempo-values.yaml` - Values Helm pour Tempo
- `04-tempo-deploy.sh` - Script de déploiement

### Exercice 5 : Déploiement Alloy Logs
- `05-alloy-logs-namespace.yaml` - Namespace Alloy Logs
- `05-alloy-logs-config.yaml` - Configuration Alloy Logs
- `05-alloy-logs-daemonset.yaml` - DaemonSet Alloy Logs

### Exercice 6 : Déploiement Alloy Metrics
- `06-alloy-metrics-namespace.yaml` - Namespace Alloy Metrics
- `06-alloy-metrics-config.yaml` - Configuration Alloy Metrics
- `06-alloy-metrics-deployment.yaml` - Deployment Alloy Metrics
- `06-kube-state-metrics.yaml` - kube-state-metrics
- `06-node-exporter.yaml` - node-exporter

### Exercice 7 : Déploiement Alloy Traces
- `07-alloy-traces-namespace.yaml` - Namespace Alloy Traces
- `07-alloy-traces-config.yaml` - Configuration Alloy Traces
- `07-alloy-traces-deployment.yaml` - Deployment Alloy Traces
- `07-opentelemetry-operator.yaml` - OpenTelemetry Operator
- `07-opentelemetry-instrumentation.yaml` - Instrumentation Python

### Exercice 8 : Déploiement Grafana
- `08-grafana-namespace.yaml` - Namespace Grafana
- `08-grafana-datasources.yaml` - Datasources pré-configurées
- `08-grafana-values.yaml` - Values Helm pour Grafana
- `08-grafana-deploy.sh` - Script de déploiement

### Exercice 9 : Configuration OpenTelemetry
- Voir Exercice 7

### Exercice 10 : cAdvisor
- `10-cadvisor-namespace.yaml` - Namespace monitoring
- `10-cadvisor-daemonset.yaml` - DaemonSet cAdvisor

### Exercice 11 : Kube-Prometheus-Stack
- `11-kube-prometheus-stack-values.yaml` - Values Helm
- `11-kube-prometheus-stack-deploy.sh` - Script de déploiement

### Exercice 12 : Surveillance de la Stack
- `12-stack-monitoring-servicemonitors.yaml` - ServiceMonitors
- `12-stack-monitoring-alerts.yaml` - PrometheusRules

### Exercice 13 : Mise à l'Échelle
- `13-hpa-scaling.yaml` - HorizontalPodAutoscaler
- `13-pdb-high-availability.yaml` - PodDisruptionBudget

### Exercice 14 : Rétentions et Compaction
- `14-retention-config.yaml` - Configuration des rétentions
- `14-verify-retention.sh` - Script de vérification

### Exercice 15 : Troubleshooting
- `15-runbook.md` - Runbook complet
- `15-check-health.sh` - Script de vérification de santé

---

## Installation étape par étape

### 1. Déploiement MinIO

```bash
# Créer le namespace et les secrets
kubectl apply -f 01-minio-namespace.yaml
kubectl apply -f 01-minio-secret.yaml
kubectl apply -f 01-minio-pvc.yaml

# Déployer MinIO
kubectl apply -f 01-minio-deployment.yaml

# Attendre que MinIO soit prêt
kubectl wait --for=condition=ready pod -l app=minio -n minio --timeout=300s

# Créer les buckets
chmod +x 01-minio-create-buckets.sh
./01-minio-create-buckets.sh
```

### 2. Déploiement Loki

```bash
# Créer le namespace et les secrets
kubectl apply -f 02-loki-namespace.yaml
kubectl apply -f 02-loki-secret.yaml

# Déployer Loki avec Helm
chmod +x 02-loki-deploy.sh
./02-loki-deploy.sh
```

### 3. Déploiement Mimir

```bash
# Créer le namespace et les secrets
kubectl apply -f 03-mimir-namespace.yaml
kubectl apply -f 03-mimir-secret.yaml

# Déployer Mimir avec Helm
chmod +x 03-mimir-deploy.sh
./03-mimir-deploy.sh
```

### 4. Déploiement Tempo

```bash
# Créer le namespace et les secrets
kubectl apply -f 04-tempo-namespace.yaml
kubectl apply -f 04-tempo-secret.yaml

# Déployer Tempo avec Helm
chmod +x 04-tempo-deploy.sh
./04-tempo-deploy.sh
```

### 5. Déploiement Alloy Logs

```bash
# Créer le namespace
kubectl apply -f 05-alloy-logs-namespace.yaml

# Déployer Alloy Logs
kubectl apply -f 05-alloy-logs-daemonset.yaml
```

### 6. Déploiement Alloy Metrics

```bash
# Créer le namespace
kubectl apply -f 06-alloy-metrics-namespace.yaml

# Déployer kube-state-metrics et node-exporter
kubectl apply -f 06-kube-state-metrics.yaml
kubectl apply -f 06-node-exporter.yaml

# Déployer Alloy Metrics
kubectl apply -f 06-alloy-metrics-deployment.yaml
```

### 7. Déploiement Alloy Traces

```bash
# Créer le namespace
kubectl apply -f 07-alloy-traces-namespace.yaml

# Installer OpenTelemetry Operator
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Déployer Alloy Traces
kubectl apply -f 07-alloy-traces-deployment.yaml

# Configurer l'instrumentation
kubectl apply -f 07-opentelemetry-instrumentation.yaml
```

### 8. Déploiement Grafana

```bash
# Créer le namespace
kubectl apply -f 08-grafana-namespace.yaml

# Appliquer les datasources
kubectl apply -f 08-grafana-datasources.yaml

# Déployer Grafana avec Helm
chmod +x 08-grafana-deploy.sh
./08-grafana-deploy.sh
```

### 9. Déploiement cAdvisor

```bash
# Créer le namespace
kubectl apply -f 10-cadvisor-namespace.yaml

# Déployer cAdvisor
kubectl apply -f 10-cadvisor-daemonset.yaml
```

### 10. Déploiement Kube-Prometheus-Stack

```bash
# Déployer kube-prometheus-stack
chmod +x 11-kube-prometheus-stack-deploy.sh
./11-kube-prometheus-stack-deploy.sh
```

### 11. Configuration de la Surveillance

```bash
# Appliquer les ServiceMonitors
kubectl apply -f 12-stack-monitoring-servicemonitors.yaml

# Appliquer les alertes
kubectl apply -f 12-stack-monitoring-alerts.yaml
```

### 12. Configuration du Scaling

```bash
# Appliquer les HPA
kubectl apply -f 13-hpa-scaling.yaml

# Appliquer les PDB
kubectl apply -f 13-pdb-high-availability.yaml
```

---

## Validation

### Checklist Infrastructure

- [ ] MinIO déployé et buckets créés
- [ ] Loki opérationnel (tous les composants)
- [ ] Mimir opérationnel (tous les composants)
- [ ] Tempo opérationnel (tous les composants)
- [ ] Alloy Logs collecte les logs K8s
- [ ] Alloy Metrics scrape kube-state-metrics et node-exporter
- [ ] Alloy Traces reçoit les traces OTLP
- [ ] Grafana déployé avec datasources configurées
- [ ] OpenTelemetry Operator installé
- [ ] cAdvisor exposant les métriques
- [ ] Kube-prometheus-stack déployé
- [ ] Auto-surveillance configurée
- [ ] Dashboards provisionnés
- [ ] Alertes configurées

### Tests End-to-End

1. **Déployer une application de test**
```bash
kubectl run test-app --image=nginx -n random-backend
```

2. **Générer des logs, métriques et traces**
```bash
# Logs: générés automatiquement par Alloy Logs
# Métriques: générées automatiquement par Alloy Metrics
# Traces: nécessitent une application instrumentée
```

3. **Rechercher les logs dans Loki via Grafana**
   - Accéder à Grafana: `kubectl port-forward -n grafana svc/grafana 3000:80`
   - Ouvrir http://localhost:3000
   - User: `admin`, Password: `admin123!`
   - Explorer → Loki → Requête: `{namespace="random-backend"}`

4. **Requêter les métriques dans Mimir via Grafana**
   - Explorer → Mimir → Requête PromQL: `rate(container_cpu_usage_seconds_total[5m])`

5. **Visualiser les traces dans Tempo via Grafana**
   - Explorer → Tempo → Rechercher par service

6. **Naviguer d'une trace vers les logs corrélés**
   - Cliquer sur une trace dans Tempo
   - Utiliser le lien "View Logs" pour voir les logs corrélés

7. **Visualiser le service graph**
   - Dashboards → Service Graph

8. **Déclencher une alerte**
```bash
# Créer un pod qui crashloop
kubectl run crashloop --image=busybox --restart=Always -- /bin/false
```

9. **Tester la rétention**
```bash
# Vérifier les données anciennes
chmod +x 14-verify-retention.sh
./14-verify-retention.sh
```

10. **Simuler une panne et vérifier l'auto-healing**
```bash
# Supprimer un pod
kubectl delete pod -n loki -l app=loki,component=querier

# Vérifier la recréation
kubectl get pods -n loki -w
```

### Script de vérification rapide

```bash
chmod +x 15-check-health.sh
./15-check-health.sh
```

---

## Documentation détaillée

### Accès aux Services

#### MinIO Console
```bash
kubectl port-forward -n minio svc/minio 9001:9001
# Ouvrir http://localhost:9001
# User: minioadmin
# Password: minioadmin123!
```

#### Grafana
```bash
kubectl port-forward -n grafana svc/grafana 3000:80
# Ouvrir http://localhost:3000
# User: admin
# Password: admin123!
```

#### Prometheus (kube-prometheus-stack)
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Ouvrir http://localhost:9090
```

### Configuration Multi-Tenancy Mimir

Mimir utilise deux OrgID pour séparer les métriques:
- **OrgID "pods"** : Métriques applicatives (kube-state-metrics, ServiceMonitors, PodMonitors)
- **OrgID "nodes"** : Métriques infrastructure (node-exporter, cAdvisor)

### Rétentions Configurées

- **Loki** : 90 jours (2160h)
- **Mimir** : 365 jours (8760h)
- **Tempo** : 30 jours (720h)

### Endpoints OTLP

- **gRPC** : `alloy-traces.alloy-traces.svc.cluster.local:4317`
- **HTTP** : `alloy-traces.alloy-traces.svc.cluster.local:4318`

### Instrumentation OpenTelemetry

Pour instrumenter automatiquement une application Python FastAPI:

1. Ajouter l'annotation au Deployment:
```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-python: "true"
```

2. L'operator injectera automatiquement les sidecars nécessaires.

### Runbook

Voir `15-runbook.md` pour les procédures de troubleshooting complètes.

---

## ⚠️ Notes Importantes

1. **Credentials** : Changer tous les mots de passe par défaut en production !
2. **Stockage** : Adapter le StorageClass selon votre environnement
3. **Ressources** : Ajuster les ressources selon la taille de votre cluster
4. **Sécurité** : Configurer l'authentification OAuth2/LDAP pour Grafana en production
5. **Réseau** : Vérifier les NetworkPolicies si elles sont activées

---

## 🔍 Dépannage

### Problèmes courants

1. **Pods en CrashLoopBackOff**
   - Vérifier les logs: `kubectl logs -n <namespace> <pod-name>`
   - Vérifier les ressources: `kubectl describe pod -n <namespace> <pod-name>`

2. **Services non accessibles**
   - Vérifier les Services: `kubectl get svc -n <namespace>`
   - Vérifier les Endpoints: `kubectl get endpoints -n <namespace>`

3. **Données non visibles dans Grafana**
   - Vérifier la connectivité entre composants
   - Vérifier les datasources dans Grafana
   - Vérifier les logs des collecteurs (Alloy)

### Scripts de diagnostic

- `15-check-health.sh` : Vérification rapide de la santé
- `15-runbook.md` : Guide complet de troubleshooting

---

## 📚 Ressources

- [Documentation Loki](https://grafana.com/docs/loki/latest/)
- [Documentation Mimir](https://grafana.com/docs/mimir/latest/)
- [Documentation Tempo](https://grafana.com/docs/tempo/latest/)
- [Documentation Alloy](https://grafana.com/docs/alloy/latest/)
- [Documentation Grafana](https://grafana.com/docs/grafana/latest/)
- [Documentation OpenTelemetry](https://opentelemetry.io/docs/)

---

**Dernière mise à jour** : 2024-01-15

