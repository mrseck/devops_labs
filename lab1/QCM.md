# QCM - Évaluation des Connaissances

## Question 1
Pourquoi est-il important de séparer la base de données dans un namespace dédié ?

A) Pour des raisons esthétiques

B) Pour isoler les ressources critiques et appliquer des politiques de sécurité spécifiques ✅

C) Parce que Kubernetes l'exige

D) Pour réduire les coûts

## Question 2
Quelle est la différence principale entre un ResourceQuota et un LimitRange ?

A) Aucune différence, ce sont des synonymes

B) ResourceQuota limite les ressources totales du namespace, LimitRange limite les ressources par pod ✅

C) LimitRange est obsolète, il faut utiliser ResourceQuota

D) ResourceQuota est pour le CPU, LimitRange pour la mémoire

## Question 3
Dans une NetworkPolicy, que signifie une règle sans ingress ni egress définis ?

A) Tout le trafic est autorisé

B) Tout le trafic est bloqué ✅

C) Seul le trafic HTTP est autorisé

D) La policy est invalide

## Question 4
Quel paramètre d'un StorageClass permet l'extension automatique d'un PVC ?

A) autoExpand: true

B) allowVolumeExpansion: true ✅

C) dynamicProvisioning: true

D) expandable: true

## Question 5
Pourquoi utiliser un StatefulSet plutôt qu'un Deployment pour PostgreSQL ?

A) C'est plus moderne

B) Pour garantir une identité stable et un ordre de démarrage prévisible ✅

C) Les Deployments ne supportent pas les volumes

D) C'est obligatoire pour les bases de données

## Question 6
Dans le contexte RBAC, quelle est la portée d'un Role (vs ClusterRole) ?

A) Un Role s'applique à tout le cluster

B) Un Role s'applique uniquement au namespace où il est défini ✅

C) Un Role s'applique uniquement aux ServiceAccounts

D) Aucune différence, les deux sont identiques

## Question 7
Que se passe-t-il si un pod demande plus de ressources que le LimitRange autorise ?

A) Le pod est créé avec les limites du LimitRange

B) Le pod est rejeté et ne démarre pas ✅

C) Un warning est émis mais le pod démarre quand même

D) Le scheduler attend que des ressources se libèrent

## Question 8
Selon le document de passation, quel est le risque critique à surveiller pour random-db ?

A) La saturation CPU

B) La saturation du PVC (stockage) ✅

C) Le nombre de connexions

D) La latence réseau

## Question 9
Quelle commande permet de labelliser un namespace existant ?

A) kubectl label namespace key=value  ✅

B) kubectl set label namespace key=value

C) kubectl annotate namespace key=value

D) kubectl tag namespace key=value

## Question 10
Pourquoi utiliser volumeBindingMode: WaitForFirstConsumer dans un StorageClass ?

A) Pour accélérer le provisioning

B) Pour que le volume soit créé dans la même zone que le pod qui l'utilise ✅

C) Pour économiser des ressources

D) C'est obligatoire pour les PVC