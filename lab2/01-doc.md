🔍 Justification des choix techniques
1. Provisioner : rancher.io/local-path
Choix : Utilisation du provisioner local-path natif de k3s
Justifications :

✅ Adapté à l'environnement local : k3s inclut ce provisioner par défaut
✅ Performance optimale : Accès direct au système de fichiers sans couche réseau
✅ Simplicité : Aucune configuration infrastructure externe requise
✅ Idéal pour les labs : Facilite les démonstrations et tests rapides

Alternative en production :

Cloud AWS : ebs.csi.aws.com avec type gp3
Cloud GCP : pd.csi.storage.gke.io avec type pd-ssd
Cloud Azure : disk.csi.azure.com avec type managed-premium

2. VolumeBindingMode : WaitForFirstConsumer
Choix : Liaison différée du volume jusqu'au scheduling du pod
Justifications :

✅ Optimisation des ressources : Le PV n'est créé que lorsqu'un pod l'utilise réellement
✅ Topology-aware : Garantit que le volume est créé sur le même nœud que le pod
✅ Évite les deadlocks : Empêche les situations où un pod ne peut pas démarrer car son volume est sur un mauvais nœud
✅ Best practice Kubernetes : Recommandé par la documentation officielle pour les provisioners dynamiques

Comparaison avec Immediate :
----------------------------------------------------------------------------------
Critère                |       WaitForFirstConsumer        |     Immediate
----------------------------------------------------------------------------------
Création du volume     | À la création du pod              | À la création du PVC 
Affinité de nœud       | ✅ Respectée                      | ❌ Peut poser problème 
Utilisation ressources | ✅ Optimale                       | ⚠️ Peut gaspiller

3. ReclaimPolicy : Retain
Choix : Conservation des données après suppression du PVC
Justifications :

✅ Protection des données : Évite la perte accidentelle de données PostgreSQL critiques
✅ Conformité : Respecte les exigences de rétention des données en production
✅ Récupération possible : Permet de réattacher le volume manuellement si nécessaire
✅ Audit trail : Facilite les investigations post-incident

Comportement :
Suppression PVC → PV passe en "Released" → Données conservées sur disque
Alternative Delete :

⚠️ Utilisée uniquement pour les environnements de développement éphémères
❌ Risque de perte de données définitive

4. AllowVolumeExpansion : true
Choix : Activation de l'expansion dynamique des volumes
Justifications :

✅ Évolutivité : Permet d'augmenter la taille du volume sans downtime (selon le provisioner)
✅ Gestion de la croissance : Anticipe l'augmentation des données PostgreSQL
✅ Opérations simplifiées : Pas besoin de recréer le PVC/PV
✅ Production-ready : Feature essentielle pour les bases de données

Exemple d'utilisation :
bash# Augmenter la taille du PVC de 10Gi à 20Gi
kubectl edit pvc postgres-data
# Modifier spec.resources.requests.storage: 20Gi
Limitations :

⚠️ Le local-path provisioner ne supporte pas l'expansion en ligne (nécessite un redémarrage du pod)
✅ En production cloud (EBS, GCE PD), l'expansion est souvent possible sans downtime

🏷️ Labels et métadonnées
labels:
  app: postgresql
  component: storage
  lab: lab2
  
Justifications :

✅ Organisation : Facilite le filtrage avec kubectl get sc -l app=postgresql
✅ Documentation : Labels descriptifs conformes aux conventions Kubernetes
✅ Traçabilité : Identification claire du contexte (lab2)