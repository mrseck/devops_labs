# Documentation des NetworkPolicies

Cette documentation décrit les NetworkPolicies appliquées aux différents namespaces de l'application **Random**, leur objectif, et les ports/protocoles autorisés.

---

## 1. Namespace `random-db`

| Nom de la policy | Type | Description | Ports / Protocoles | Sources / Destinations |
|-----------------|------|-------------|------------------|----------------------|
| `deny-all-ingress` | Ingress | Bloque tout le trafic entrant vers les pods `random-db`. | - | - |
| `deny-all-egress` | Egress | Bloque tout le trafic sortant des pods `random-db`. | - | - |
| `allow-db-from-backend-and-jobs` | Ingress | Autorise les pods `random-backend` et `random-jobs` à accéder à la base de données PostgreSQL. | TCP 5432 | Pods des namespaces avec `component: backend` et `component: jobs` |
| `allow-db-egress-responses` | Egress | Autorise les réponses de la base de données vers `random-backend` et `random-jobs`. | Tous ports | Pods des namespaces avec `component: backend` et `component: jobs` |
| `allow-dns-egress` | Egress | Permet les requêtes DNS sortantes. | UDP 53 | Pods du namespace avec `name: kube-system` |

**Remarques :**  
- Seules les sources explicitement autorisées peuvent accéder à la base de données.  
- La base de données peut renvoyer les réponses aux requêtes SQL vers le backend et les jobs.
- Tout autre trafic est bloqué par défaut.

---

## 2. Namespace `random-backend`

| Nom de la policy | Type | Description | Ports / Protocoles | Sources / Destinations |
|-----------------|------|-------------|------------------|----------------------|
| `deny-all-ingress` | Ingress | Bloque tout le trafic entrant vers les pods backend. | - | - |
| `deny-all-egress` | Egress | Bloque tout le trafic sortant des pods backend. | - | - |
| `allow-backend-from-frontend` | Ingress | Autorise le frontend à accéder au backend sur le port HTTP 8080. | TCP 8080 | Pods des namespaces avec `component: frontend` |
| `allow-egress-to-database` | Egress | Autorise le trafic sortant vers la base de données PostgreSQL. | TCP 5432 | Pods des namespaces avec `component: database` |
| `allow-dns-egress` | Egress | Permet les requêtes DNS sortantes. | UDP 53 | Pods du namespace avec `name: kube-system` |

**Remarques :**  
- Le backend ne peut communiquer qu'avec le frontend (ingress) et la base de données (egress).
- Tout autre trafic est bloqué par défaut.

---

## 3. Namespace `random-jobs`

| Nom de la policy | Type | Description | Ports / Protocoles | Sources / Destinations |
|-----------------|------|-------------|------------------|----------------------|
| `deny-all-ingress` | Ingress | Bloque tout le trafic entrant vers les pods jobs. | - | - |
| `deny-all-egress` | Egress | Bloque tout le trafic sortant des pods jobs. | - | - |
| `allow-jobs-from-scheduler` | Ingress | Autorise le scheduler à communiquer avec les jobs. | Tous ports | Pods des namespaces avec `component: scheduler` |
| `allow-jobs-to-database` | Egress | Autorise le trafic sortant vers la base de données PostgreSQL. | TCP 5432 | Pods des namespaces avec `component: database` |
| `allow-dns-egress` | Egress | Permet les requêtes DNS sortantes. | UDP 53 | Pods du namespace avec `name: kube-system` |

**Remarques :**  
- Les jobs peuvent recevoir des déclenchements du scheduler sur tous les ports.
- Les jobs peuvent interroger la base de données.
- Tout autre trafic est bloqué par défaut.

---

## 4. Namespace `random-frontend`

| Nom de la policy | Type | Description | Ports / Protocoles | Sources / Destinations |
|-----------------|------|-------------|------------------|----------------------|
| `deny-all-ingress` | Ingress | Bloque tout le trafic entrant vers le frontend. | - | - |
| `deny-all-egress` | Egress | Bloque tout le trafic sortant des pods frontend. | - | - |
| `allow-external-to-frontend` | Ingress | Autorise le trafic externe HTTP/HTTPS. | TCP 80, TCP 443 | Toutes sources (pas de restriction) |
| `allow-frontend-to-backend` | Egress | Autorise le trafic sortant vers le backend. | TCP 8080 | Pods des namespaces avec `component: backend` |
| `allow-dns-egress` | Egress | Permet les requêtes DNS sortantes. | UDP 53 | Pods du namespace avec `name: kube-system` |

**Remarques :**  
- Le frontend est accessible publiquement via HTTP/HTTPS.
- Le frontend ne peut communiquer qu'avec le backend en sortie.
- Tout autre trafic est bloqué par défaut.

---

## 5. Namespace `random-scheduler`

| Nom de la policy | Type | Description | Ports / Protocoles | Sources / Destinations |
|-----------------|------|-------------|------------------|----------------------|
| `deny-all-ingress` | Ingress | Bloque tout le trafic entrant vers le scheduler. | - | - |
| `deny-all-egress` | Egress | Bloque tout le trafic sortant des pods scheduler. | - | - |
| `allow-scheduler-to-jobs` | Egress | Autorise le trafic sortant vers les jobs. | Tous ports | Pods des namespaces avec `component: jobs` |
| `allow-dns-egress` | Egress | Permet les requêtes DNS sortantes. | UDP 53 | Pods du namespace avec `name: kube-system` |

**Remarques :**  
- Le scheduler n'accepte aucune connexion entrante.
- Le scheduler peut uniquement déclencher des jobs et faire des requêtes DNS.
- Tout autre trafic est bloqué par défaut.

---

## Résumé

- Chaque namespace possède une **politique de blocage par défaut** (deny-all-ingress et deny-all-egress) pour sécuriser les pods selon le principe Zero Trust.
- Seules les communications explicitement autorisées sont permises.
- Le trafic DNS sortant est autorisé pour tous les namespaces afin d'assurer la résolution de noms.
- Cette stratégie limite le "blast radius" et améliore la sécurité globale de l'application.