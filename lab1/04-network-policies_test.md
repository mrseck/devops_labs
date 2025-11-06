# Tests de Connectivité NetworkPolicies

## Tests qui DOIVENT FONCTIONNER ✅

### Test 1 : Backend → Database (port 5432)
```bash
kubectl run test-pod -n random-backend --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv postgres-service.random-db 5432
```
**Résultat attendu :** ✅ `Connection to postgres-service.random-db (10.x.x.x) 5432 port [tcp/postgresql] succeeded!`

---

### Test 2 : Jobs → Database (port 5432)
```bash
kubectl run test-pod -n random-jobs --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv postgres-service.random-db 5432
```
**Résultat attendu :** ✅ `Connection to postgres-service.random-db (10.x.x.x) 5432 port [tcp/postgresql] succeeded!`

---

### Test 3 : Frontend → Backend (port 8080)
```bash
kubectl run test-pod -n random-frontend --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv backend-service.random-backend 8080
```
**Résultat attendu :** ✅ `Connection to backend-service.random-backend (10.x.x.x) 8080 port [tcp/http-alt] succeeded!`

---

### Test 4 : Scheduler → Jobs (port 8080)
```bash
kubectl run test-pod -n random-scheduler --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv jobs-service.random-jobs 8080
```
**Résultat attendu :** ✅ `Connection to jobs-service.random-jobs (10.x.x.x) 8080 port [tcp/http-alt] succeeded!`

---

## Tests qui DOIVENT ÉCHOUER ❌

### Test 5 : Frontend → Database (BLOQUÉ)
```bash
kubectl run test-pod -n random-frontend --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv -w 3 postgres-service.random-db 5432
```
**Résultat attendu :** ❌ `nc: connect to postgres-service.random-db port 5432 (tcp) timed out: Operation in progress`

---

### Test 6 : Backend → Frontend (BLOQUÉ)
```bash
kubectl run test-pod -n random-backend --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv -w 3 frontend-service.random-frontend 80
```
**Résultat attendu :** ❌ `nc: connect to frontend-service.random-frontend port 80 (tcp) timed out: Operation in progress`

---

### Test 7 : Jobs → Backend (BLOQUÉ)
```bash
kubectl run test-pod -n random-jobs --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv -w 3 backend-service.random-backend 8080
```
**Résultat attendu :** ❌ `nc: connect to backend-service.random-backend port 8080 (tcp) timed out: Operation in progress`

---

### Test 8 : Scheduler → Database (BLOQUÉ)
```bash
kubectl run test-pod -n random-scheduler --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv -w 3 postgres-service.random-db 5432
```
**Résultat attendu :** ❌ `nc: connect to postgres-service.random-db port 5432 (tcp) timed out: Operation in progress`

---

### Test 9 : Scheduler → Backend (BLOQUÉ)
```bash
kubectl run test-pod -n random-scheduler --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv -w 3 backend-service.random-backend 8080
```
**Résultat attendu :** ❌ `nc: connect to backend-service.random-backend port 8080 (tcp) timed out: Operation in progress`

---

### Test 10 : Frontend → Jobs (BLOQUÉ)
```bash
kubectl run test-pod -n random-frontend --image=nicolaka/netshoot --rm -it -- /bin/bash
```
Dans le pod :
```bash
nc -zv -w 3 jobs-service.random-jobs 8080
```
**Résultat attendu :** ❌ `nc: connect to jobs-service.random-jobs port 8080 (tcp) timed out: Operation in progress`

---

## Résumé

**Tests qui doivent fonctionner (4) :**
- ✅ Backend → Database:5432
- ✅ Jobs → Database:5432
- ✅ Frontend → Backend:8080
- ✅ Scheduler → Jobs:8080

**Tests qui doivent échouer (6) :**
- ❌ Frontend → Database
- ❌ Backend → Frontend
- ❌ Jobs → Backend
- ❌ Scheduler → Database
- ❌ Scheduler → Backend
- ❌ Frontend → Jobs

---

## Note
Pour sortir du pod de test, tapez `exit` ou appuyez sur `Ctrl+D`

