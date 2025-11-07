# QCM - Réponses Lab 2

## Réponses

1. **A** - Pour avoir un nom de pod stable et prévisible
2. **B** - Il est possible d'étendre manuellement le PVC sans recréer le pod
3. **B** - Retain - pour conserver les données même après suppression du PVC
4. **A** - Pour créer le volume dans la même zone de disponibilité que le pod
5. **B** - `kubectl patch pvc -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'`
6. **C** - `predict_linear()`
7. **B** - Pour avoir des métriques spécifiques au pod sans modifier l'image PostgreSQL
8. **A** - VolumeSnapshot est un snapshot du volume entier, pg_dump un export logique SQL
9. **C** - La saturation du PVC de la base de données
10. **B** - `scrapeInterval`
11. **B** - Pour avoir des niveaux d'urgence progressifs et le temps de réagir
12. **B** - `df -h` (dans le pod)
13. **A** - `0 2 * * *`
14. **B** - Pour avoir un DNS stable pour chaque pod du StatefulSet
15. **B** - Une erreur est retournée et le PVC reste inchangé

## Explications Détaillées

### Question 1 : StatefulSet vs Deployment

Les StatefulSets sont utilisés pour les applications qui nécessitent :
- Des identités réseau stables et uniques
- Un stockage persistant stable
- Un ordre de déploiement et de mise à l'échelle ordonné et gracieux
- Un ordre de suppression et de mise à l'échelle ordonné et gracieux

Pour PostgreSQL, le nom de pod stable est crucial pour la configuration et la réplication.

### Question 2 : allowVolumeExpansion

`allowVolumeExpansion: true` permet d'étendre un PVC existant sans avoir à recréer le pod. Cependant, cela ne se fait pas automatiquement - il faut modifier manuellement la taille du PVC.

### Question 3 : reclaimPolicy

- **Delete** : Le PV est supprimé automatiquement quand le PVC est supprimé (risque de perte de données)
- **Retain** : Le PV est conservé même après suppression du PVC (sécurisé pour les données critiques)
- **Recycle** : Obsolète, remplacé par Delete

### Question 4 : WaitForFirstConsumer

Ce mode garantit que le volume est créé dans la même zone de disponibilité que le pod qui l'utilise, optimisant ainsi les performances et la disponibilité.

### Question 5 : Extension du PVC

La commande `kubectl patch` permet de modifier la spécification du PVC pour augmenter sa taille. Le StorageClass doit avoir `allowVolumeExpansion: true`.

### Question 6 : Taux de Croissance

`predict_linear()` est une fonction Prometheus qui prédit la valeur future d'une métrique basée sur une régression linéaire sur une fenêtre de temps donnée.

### Question 7 : Sidecar Container

Un sidecar permet d'ajouter des fonctionnalités (comme l'exposition de métriques) sans modifier l'image principale de l'application.

### Question 8 : VolumeSnapshot vs pg_dump

- **VolumeSnapshot** : Snapshot au niveau du volume de stockage (copie complète du volume)
- **pg_dump** : Export logique au format SQL (plus portable, mais plus lent)

### Question 9 : Risque Principal

Selon le document de passation, l'alerte critique concerne spécifiquement la saturation du PVC PostgreSQL.

### Question 10 : ScrapeInterval

Dans un ServiceMonitor, `scrapeInterval` définit la fréquence à laquelle Prometheus collecte les métriques depuis le service.

### Question 11 : Seuils Multiples

Des seuils progressifs (70%, 85%, 95%) permettent une escalade graduelle de l'urgence, donnant le temps de réagir avant qu'il ne soit trop tard.

### Question 12 : Vérification de l'Utilisation

`df -h` dans le pod montre l'utilisation réelle du filesystem monté, ce qui est plus précis que les métriques Kubernetes qui peuvent avoir un délai.

### Question 13 : Expression Cron

Format cron : `minute heure jour mois jour-semaine`
- `0 2 * * *` = Tous les jours à 2h00 du matin

### Question 14 : Service Headless

Un service Headless (`clusterIP: None`) crée des enregistrements DNS pour chaque pod du StatefulSet, permettant un accès direct et stable aux pods.

### Question 15 : Extension Sans Support

Si le StorageClass ne supporte pas l'expansion (`allowVolumeExpansion: false`), Kubernetes retournera une erreur et le PVC restera inchangé.

