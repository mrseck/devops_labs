# Guide d'Adaptation du StorageClass

Le StorageClass fourni dans `01-storageclass.yaml` utilise `local-path` par défaut, ce qui convient pour les environnements locaux (k3s, minikube). Pour les environnements cloud, vous devez adapter la configuration.

## Environnements Locaux

### k3s / Rancher

```yaml
provisioner: local-path
parameters: {}
```

### minikube

```yaml
provisioner: k8s.io/minikube-hostpath
parameters: {}
```

## AWS (EKS)

### EBS gp3 (recommandé)

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd-expandable
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
```

### EBS gp2 (alternative)

```yaml
provisioner: ebs.csi.aws.com
parameters:
  type: gp2
  fsType: ext4
```

## Google Cloud Platform (GKE)

### Persistent Disk SSD

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd-expandable
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-ssd
  replication-type: regional-pd
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
```

### Persistent Disk Standard (moins cher)

```yaml
provisioner: pd.csi.storage.gke.io
parameters:
  type: pd-standard
```

## Azure (AKS)

### Managed Premium Disk

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd-expandable
provisioner: disk.csi.azure.com
parameters:
  skuName: Premium_LRS
  cachingMode: ReadOnly
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain
```

### Managed Standard SSD

```yaml
provisioner: disk.csi.azure.com
parameters:
  skuName: StandardSSD_LRS
```

## Vérification

Après avoir créé le StorageClass, vérifiez qu'il est bien configuré :

```bash
kubectl get storageclass fast-ssd-expandable -o yaml
```

Vérifiez notamment :
- `allowVolumeExpansion: true`
- `volumeBindingMode: WaitForFirstConsumer`
- `reclaimPolicy: Retain`

## Test

Pour tester le StorageClass, créez un PVC de test :

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: random-db
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: fast-ssd-expandable
  resources:
    requests:
      storage: 1Gi
EOF

# Vérifier
kubectl get pvc -n random-db test-pvc

# Nettoyer
kubectl delete pvc -n random-db test-pvc
```

## Notes Importantes

1. **CSI Drivers** : Assurez-vous que le CSI driver approprié est installé dans votre cluster
2. **Permissions** : Certains provisioners nécessitent des permissions IAM spécifiques
3. **Coûts** : Les disques SSD sont plus chers que les disques standard
4. **Zones** : `WaitForFirstConsumer` garantit que le volume est créé dans la même zone que le pod

## Ressources

- [Kubernetes Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [GCP PD CSI Driver](https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver)
- [Azure Disk CSI Driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver)

