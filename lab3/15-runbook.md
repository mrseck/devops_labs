# Runbook - Troubleshooting Stack Monitoring

## Table des matières
1. [Vérification de l'état des composants](#vérification-de-létat-des-composants)
2. [Problèmes d'ingestion](#problèmes-dingestion)
3. [Problèmes de performance](#problèmes-de-performance)
4. [Problèmes de stockage](#problèmes-de-stockage)
5. [Problèmes réseau](#problèmes-réseau)
6. [Scripts de diagnostic](#scripts-de-diagnostic)

---

## Vérification de l'état des composants

### Commandes kubectl pour chaque namespace

```bash
# MinIO
kubectl get pods -n minio
kubectl logs -n minio deployment/minio
kubectl describe pod -n minio -l app=minio

# Loki
kubectl get pods -n loki
kubectl logs -n loki -l app=loki,component=distributor
kubectl logs -n loki -l app=loki,component=ingester
kubectl logs -n loki -l app=loki,component=querier

# Mimir
kubectl get pods -n mimir
kubectl logs -n mimir -l app=mimir,component=distributor
kubectl logs -n mimir -l app=mimir,component=ingester

# Tempo
kubectl get pods -n tempo
kubectl logs -n tempo -l app=tempo,component=distributor

# Alloy
kubectl get pods -n alloy-logs
kubectl get pods -n alloy-metrics
kubectl get pods -n alloy-traces

# Grafana
kubectl get pods -n grafana
kubectl logs -n grafana deployment/grafana
```

### Healthchecks

```bash
# MinIO
kubectl exec -n minio deployment/minio -- curl http://localhost:9000/minio/health/live

# Loki
kubectl exec -n loki deployment/loki-gateway -- curl http://localhost:80/ready

# Mimir
kubectl exec -n mimir deployment/mimir-gateway -- curl http://localhost:80/ready

# Tempo
kubectl exec -n tempo deployment/tempo-query-frontend -- curl http://localhost:3200/ready
```

---

## Problèmes d'ingestion

### Logs non visibles dans Loki

**Symptômes:**
- Les logs n'apparaissent pas dans Grafana
- Alloy Logs collecte mais n'envoie pas

**Diagnostics:**
```bash
# Vérifier Alloy Logs
kubectl logs -n alloy-logs -l app=alloy-logs --tail=100

# Vérifier Loki Distributor
kubectl logs -n loki -l app=loki,component=distributor --tail=100

# Vérifier la connectivité
kubectl exec -n alloy-logs -l app=alloy-logs -- wget -O- http://loki-gateway.loki.svc.cluster.local:80/ready

# Vérifier les métriques d'ingestion
# Dans Grafana: rate(loki_distributor_lines_received_total[5m])
```

**Solutions:**
1. Vérifier la configuration Alloy (ConfigMap)
2. Vérifier les labels et filtres
3. Vérifier la connectivité réseau vers Loki
4. Vérifier les quotas de ressources

### Métriques manquantes dans Mimir

**Symptômes:**
- Métriques non disponibles dans Grafana
- Alloy Metrics ne scrape pas

**Diagnostics:**
```bash
# Vérifier Alloy Metrics
kubectl logs -n alloy-metrics -l app=alloy-metrics --tail=100

# Vérifier les ServiceMonitors
kubectl get servicemonitors -A

# Vérifier la connectivité vers Mimir
kubectl exec -n alloy-metrics -l app=alloy-metrics -- wget -O- http://mimir-gateway.mimir.svc.cluster.local:80/ready

# Vérifier les métriques d'ingestion
# Dans Grafana: rate(mimir_distributor_samples_received_total[5m])
```

**Solutions:**
1. Vérifier les ServiceMonitors et PodMonitors
2. Vérifier les OrgID (pods vs nodes)
3. Vérifier la configuration remote_write
4. Vérifier les limites de rate limiting

### Traces perdues dans Tempo

**Symptômes:**
- Traces non visibles dans Grafana
- Alloy Traces ne reçoit pas

**Diagnostics:**
```bash
# Vérifier Alloy Traces
kubectl logs -n alloy-traces -l app=alloy-traces --tail=100

# Vérifier Tempo Distributor
kubectl logs -n tempo -l app=tempo,component=distributor --tail=100

# Vérifier la connectivité
kubectl exec -n alloy-traces -l app=alloy-traces -- nc -zv tempo-distributor.tempo.svc.cluster.local 4317

# Vérifier les métriques d'ingestion
# Dans Grafana: rate(tempo_distributor_spans_received_total[5m])
```

**Solutions:**
1. Vérifier la configuration OTLP
2. Vérifier les processors (k8sattributes, batch)
3. Vérifier la connectivité réseau
4. Vérifier l'échantillonnage

---

## Problèmes de performance

### Requêtes lentes dans Grafana

**Symptômes:**
- Timeout des requêtes
- Grafana non responsive

**Diagnostics:**
```bash
# Vérifier les ressources
kubectl top pods -n loki
kubectl top pods -n mimir
kubectl top pods -n tempo

# Vérifier les métriques de performance
# Loki: loki_query_frontend_query_latency_seconds
# Mimir: mimir_query_frontend_query_latency_seconds
```

**Solutions:**
1. Augmenter les replicas des queriers
2. Activer le cache dans query-frontend
3. Optimiser les requêtes (limiter la plage temporelle)
4. Vérifier les HPA

### Queriers surchargés

**Symptômes:**
- CPU > 80% sur les queriers
- Requêtes en timeout

**Solutions:**
```bash
# Vérifier les HPA
kubectl get hpa -n loki
kubectl get hpa -n mimir
kubectl get hpa -n tempo

# Scale manuel si nécessaire
kubectl scale deployment loki-querier -n loki --replicas=5
```

### Ingesters à saturation

**Symptômes:**
- Ingesters en erreur
- Données non persistées

**Solutions:**
1. Augmenter les ressources (CPU/RAM)
2. Augmenter le nombre de replicas
3. Vérifier les limites d'ingestion
4. Vérifier le stockage (PVC)

---

## Problèmes de stockage

### MinIO indisponible

**Symptômes:**
- Erreurs de connexion S3
- Données non accessibles

**Diagnostics:**
```bash
# Vérifier l'état du pod
kubectl get pods -n minio
kubectl describe pod -n minio -l app=minio

# Vérifier le PVC
kubectl get pvc -n minio
kubectl describe pvc -n minio minio-storage

# Vérifier les logs
kubectl logs -n minio deployment/minio
```

**Solutions:**
1. Redémarrer le pod MinIO
2. Vérifier le PVC et le StorageClass
3. Vérifier l'espace disque disponible
4. Restaurer depuis backup si nécessaire

### Buckets pleins

**Symptômes:**
- Erreurs d'écriture
- Stockage > 95%

**Solutions:**
```bash
# Vérifier l'espace utilisé
kubectl exec -n minio deployment/minio -- mc du /data

# Nettoyer les données expirées
# Vérifier les rétentions configurées
# Forcer la compaction
```

### Compaction échouée

**Symptômes:**
- Compactor en erreur
- Données non compactées

**Diagnostics:**
```bash
# Loki Compactor
kubectl logs -n loki -l app=loki,component=compactor

# Mimir Compactor
kubectl logs -n mimir -l app=mimir,component=compactor

# Tempo Compactor
kubectl logs -n tempo -l app=tempo,component=compactor
```

**Solutions:**
1. Vérifier les permissions S3
2. Vérifier l'espace disponible
3. Redémarrer le compactor
4. Vérifier la configuration de compaction

---

## Problèmes réseau

### Communication inter-composants

**Symptômes:**
- Timeout de connexion
- Services non accessibles

**Diagnostics:**
```bash
# Vérifier les Services
kubectl get svc -n loki
kubectl get svc -n mimir
kubectl get svc -n tempo

# Tester la connectivité DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup loki-gateway.loki.svc.cluster.local

# Tester la connectivité réseau
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://loki-gateway.loki.svc.cluster.local:80/ready
```

**Solutions:**
1. Vérifier les Services et Endpoints
2. Vérifier les NetworkPolicies
3. Vérifier la résolution DNS
4. Vérifier les firewall rules

### NetworkPolicies bloquantes

**Symptômes:**
- Communication bloquée entre namespaces

**Solutions:**
```bash
# Lister les NetworkPolicies
kubectl get networkpolicies -A

# Vérifier les règles
kubectl describe networkpolicy -n loki

# Désactiver temporairement pour test
kubectl delete networkpolicy -n loki --all
```

---

## Scripts de diagnostic

### Checklist de vérification rapide

```bash
#!/bin/bash
# 15-check-health.sh

echo "🔍 Vérification de la santé de la stack..."

# MinIO
echo "MinIO:"
kubectl get pods -n minio | grep -v Running && echo "  ⚠️  Problème détecté" || echo "  ✅ OK"

# Loki
echo "Loki:"
kubectl get pods -n loki | grep -v Running && echo "  ⚠️  Problème détecté" || echo "  ✅ OK"

# Mimir
echo "Mimir:"
kubectl get pods -n mimir | grep -v Running && echo "  ⚠️  Problème détecté" || echo "  ✅ OK"

# Tempo
echo "Tempo:"
kubectl get pods -n tempo | grep -v Running && echo "  ⚠️  Problème détecté" || echo "  ✅ OK"

# Alloy
echo "Alloy:"
kubectl get pods -n alloy-logs | grep -v Running && echo "  ⚠️  Problème détecté" || echo "  ✅ OK"
kubectl get pods -n alloy-metrics | grep -v Running && echo "  ⚠️  Problème détecté" || echo "  ✅ OK"
kubectl get pods -n alloy-traces | grep -v Running && echo "  ⚠️  Problème détecté" || echo "  ✅ OK"

# Grafana
echo "Grafana:"
kubectl get pods -n grafana | grep -v Running && echo "  ⚠️  Problème détecté" || echo "  ✅ OK"
```

### Procédures de rollback

```bash
# Rollback Loki
helm rollback loki -n loki

# Rollback Mimir
helm rollback mimir -n mimir

# Rollback Tempo
helm rollback tempo -n tempo

# Rollback Grafana
helm rollback grafana -n grafana
```

---

**Dernière mise à jour:** 2024-01-15

