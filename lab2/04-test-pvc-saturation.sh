#!/bin/bash
# test-pvc-saturation.sh

POD_NAME=$(kubectl get pod -n random-db -l app=postgresql -o jsonpath='{.items[0].metadata.name}')

echo "🧪 Simulation de saturation du PVC..."
kubectl exec -n random-db $POD_NAME -- bash -c '
  for i in {1..100}; do
    dd if=/dev/zero of=/var/lib/postgresql/data/testfile_$i.dat bs=1M count=100 2>/dev/null
    echo "Fichier $i créé"
    sleep 2
  done
'       