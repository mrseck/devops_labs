# Guide de Déploiement Rapide - Lab 3

## 🚀 Déploiement en une commande (séquentiel)

```bash
# 1. MinIO
kubectl apply -f 01-minio-namespace.yaml,01-minio-secret.yaml,01-minio-pvc.yaml,01-minio-deployment.yaml
kubectl wait --for=condition=ready pod -l app=minio -n minio --timeout=300s
./01-minio-create-buckets.sh

# 2. Loki
kubectl apply -f 02-loki-namespace.yaml,02-loki-secret.yaml
./02-loki-deploy.sh

# 3. Mimir
kubectl apply -f 03-mimir-namespace.yaml,03-mimir-secret.yaml
./03-mimir-deploy.sh

# 4. Tempo
kubectl apply -f 04-tempo-namespace.yaml,04-tempo-secret.yaml
./04-tempo-deploy.sh

# 5. Alloy Logs
kubectl apply -f 05-alloy-logs-namespace.yaml,05-alloy-logs-daemonset.yaml

# 6. Alloy Metrics
kubectl apply -f 06-alloy-metrics-namespace.yaml,06-kube-state-metrics.yaml,06-node-exporter.yaml,06-alloy-metrics-deployment.yaml

# 7. Alloy Traces
kubectl apply -f 07-alloy-traces-namespace.yaml,07-alloy-traces-deployment.yaml
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml
kubectl apply -f 07-opentelemetry-instrumentation.yaml

# 8. Grafana
kubectl apply -f 08-grafana-namespace.yaml,08-grafana-datasources.yaml
./08-grafana-deploy.sh

# 9. cAdvisor
kubectl apply -f 10-cadvisor-namespace.yaml,10-cadvisor-daemonset.yaml

# 10. Kube-Prometheus-Stack
./11-kube-prometheus-stack-deploy.sh

# 11. Surveillance
kubectl apply -f 12-stack-monitoring-servicemonitors.yaml,12-stack-monitoring-alerts.yaml

# 12. Scaling
kubectl apply -f 13-hpa-scaling.yaml,13-pdb-high-availability.yaml
```

## ✅ Vérification

```bash
# Vérification rapide
./15-check-health.sh

# Vérifier tous les pods
kubectl get pods -A | grep -E "(minio|loki|mimir|tempo|alloy|grafana)"

# Vérifier les services
kubectl get svc -A | grep -E "(minio|loki|mimir|tempo|alloy|grafana)"
```

## 🔗 Accès aux Services

```bash
# Grafana
kubectl port-forward -n grafana svc/grafana 3000:80
# http://localhost:3000 (admin/admin123!)

# MinIO Console
kubectl port-forward -n minio svc/minio 9001:9001
# http://localhost:9001 (minioadmin/minioadmin123!)

# Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090
```

## 📊 Tests Rapides

```bash
# 1. Générer un log
kubectl run test-logger --image=busybox --rm -it --restart=Never -- sh -c 'echo "Test log $(date)"'

# 2. Vérifier dans Loki (via Grafana)
# Explorer → Loki → Requête: {pod_name="test-logger"}

# 3. Vérifier les métriques (via Grafana)
# Explorer → Mimir → Requête: rate(container_cpu_usage_seconds_total[5m])

# 4. Vérifier les traces (nécessite une app instrumentée)
# Explorer → Tempo → Rechercher par service
```

## 🆘 En cas de problème

```bash
# Vérifier la santé
./15-check-health.sh

# Consulter le runbook
cat 15-runbook.md

# Vérifier les logs
kubectl logs -n <namespace> <pod-name>
```

