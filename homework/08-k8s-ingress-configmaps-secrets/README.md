# Kubernetes Ingress, ConfigMaps & Secrets: Homework (Session 12)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> Source lab: [`session-12-ingress-configmaps-secrets/lab.md`](../../session-12-ingress-configmaps-secrets/lab.md)
> Manifests used: [`session-12-ingress-configmaps-secrets/04-full-demo/`](../../session-12-ingress-configmaps-secrets/04-full-demo/)

---

## Lab Completion Checklist

| # | Task | Status |
|---|---|---|
| 1 | Applied `configmap.yaml` and read a key using `-o jsonpath` | ✅ |
| 2 | Applied `secret.yaml` and decoded `POSTGRES_PASSWORD` with `base64 --decode` | ✅ |
| 3 | Applied `backend.yaml` and verified env vars inside the pod with `kubectl exec` | ✅ |
| 4 | Applied `frontend.yaml` and confirmed both services are `ClusterIP` | ✅ |
| 5 | Enabled the NGINX Ingress Controller, controller pod `Running` | ✅ |
| 6 | Applied `ingress.yaml` and confirmed an `ADDRESS` appeared | ✅ |
| 7 | Path `/` returns Nginx HTML via `curl -H "Host: yatri.local"` | ✅ |
| 8 | Path `/api/` returns the backend config values | ✅ |
| 9 | Demonstrated the `echo` vs `echo -n` newline bug | ✅ |
| 10 | Rolling restart after a ConfigMap update loads the new value | ✅ |
| 11 | **Bonus:** host-based routing + TLS termination (`03-ingress/ingress-tls.yaml`) | ✅ |

---

## Contents
1. [Environment](#environment)
2. [Part 1 - ConfigMap](#part-1-configmap)
3. [Part 2 - Secret](#part-2-secret)
4. [Part 3 - Backend: injecting ConfigMap + Secret](#part-3-backend-injecting-configmap--secret)
5. [Part 4 - Frontend](#part-4-frontend)
6. [Part 5 - Ingress](#part-5-ingress)
7. [Part 6 - Testing the routing](#part-6-testing-the-routing)
8. [Part 7 - Everything at once](#part-7-everything-at-once)
9. [Part 8 - The newline bug](#part-8-the-newline-bug)
10. [Part 9 - Updating a ConfigMap](#part-9-updating-a-configmap)
11. [Part 10 (bonus) - Host-based routing + TLS](#part-10-bonus-host-based-routing--tls)
12. [Cleanup](#cleanup)
13. [What I took away](#what-i-took-away)

---

## Environment

| | |
|---|---|
| Host | macOS (Darwin 26.6.2, arm64) |
| minikube | v1.39.0, `--driver=docker` |
| Kubernetes | v1.37.0 (containerd 2.3.4) |
| kubectl | v1.37.0 |
| Docker | 28.4.0 |
| Ingress controller | `registry.k8s.io/ingress-nginx/controller:v1.15.1` (minikube `ingress` addon) |

### One deviation from the lab, and why

The lab tests the Ingress with `curl http://$(minikube ip)/`. That works on a Linux cloud
instance, but **not** on macOS with the docker driver: `minikube ip` (`192.168.49.2`) lives on a
bridge network *inside* the Docker VM, and macOS has no route to it. Proof:

```console
$ curl -s -m 8 -H "Host: yatri.local" http://192.168.49.2/ -o /dev/null -w "%{http_code}\n"
000
FAILED (exit 28)          # exit 28 = connection timed out
```

So every `curl` below goes through a port-forward onto the ingress controller service instead.
Same controller, same Ingress object, same routing rules - only the transport to the node differs:

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80 &
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8443:443 &
```

The `Host:` header is still what selects the Ingress rule, which is the whole point of the exercise.

---

## Part 1: ConfigMap

Five plain-text key/value pairs. No credentials.

```bash
kubectl apply -f configmap.yaml
kubectl get configmap yatri-app-config
kubectl describe configmap yatri-app-config
kubectl get configmap yatri-app-config -o jsonpath='{.data.ENVIRONMENT}'
```

```console
### apply configmap
configmap/yatri-app-config created
### get configmap
NAME               DATA   AGE
yatri-app-config   5      0s
### describe configmap
Name:         yatri-app-config
Namespace:    default
Labels:       app=yatri-app
Annotations:  <none>

Data
====
APP_PORT:
----
5000

DEFAULT_CURRENCY:
----
INR

ENVIRONMENT:
----
production

LOG_LEVEL:
----
INFO

MAX_BOOKING_DAYS:
----
30


BinaryData
====

Events:  <none>
### jsonpath ENVIRONMENT
production
```

`DATA 5` confirms all five keys landed. `describe` prints the values in the clear - that is the
whole difference between a ConfigMap and a Secret.

---

## Part 2: Secret

```bash
echo    "mypassword" | base64      # wrong - trailing \n
echo -n "mypassword" | base64      # correct
kubectl apply -f secret.yaml
kubectl get secret yatri-db-secret
kubectl describe secret yatri-db-secret
kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode
```

```console
### echo vs echo -n
bXlwYXNzd29yZAo=
bXlwYXNzd29yZA==

### apply secret
secret/yatri-db-secret created
### get secret
NAME              TYPE     DATA   AGE
yatri-db-secret   Opaque   3      0s
### describe secret
Name:         yatri-db-secret
Namespace:    default
Labels:       app=yatri-app
Annotations:  <none>

Type:  Opaque

Data
====
POSTGRES_DB:        19 bytes
POSTGRES_PASSWORD:  14 bytes
POSTGRES_USER:      11 bytes
### decode password
secretpassword
```

Two things worth pointing at:

- `describe` shows **`14 bytes`**, not the value. Nothing leaks to someone reading over your shoulder.
- But `kubectl get secret -o jsonpath | base64 --decode` hands the password straight back.
  **Base64 is encoding, not encryption.** The actual protection is RBAC on `get secret`, plus
  encryption-at-rest on etcd.

---

## Part 3: Backend - injecting ConfigMap + Secret

`backend.yaml` uses both injection styles at once:

```yaml
envFrom:
  - configMapRef:
      name: yatri-app-config     # all 5 ConfigMap keys in one line

env:
  - name: POSTGRES_PASSWORD      # Secret keys picked one at a time
    valueFrom:
      secretKeyRef:
        name: yatri-db-secret
        key: POSTGRES_PASSWORD
```

```bash
kubectl apply -f backend.yaml
kubectl rollout status deployment/yatri-backend
kubectl get pods -l app=yatri-backend
kubectl exec deployment/yatri-backend -- env | grep -E "ENVIRONMENT|LOG_LEVEL|DEFAULT_CURRENCY|POSTGRES"
```

```console
### apply backend
deployment.apps/yatri-backend created
service/yatri-backend-service created
### wait for rollout
Waiting for deployment "yatri-backend" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "yatri-backend" rollout to finish: 1 of 2 updated replicas are available...
deployment "yatri-backend" successfully rolled out
### get pods
NAME                             READY   STATUS    RESTARTS   AGE
yatri-backend-6c58cb99c7-qxlh4   1/1     Running   0          41s
yatri-backend-6c58cb99c7-r5jnd   1/1     Running   0          41s
### env inside pod
LOG_LEVEL=INFO
DEFAULT_CURRENCY=INR
POSTGRES_USER=yatri_admin
POSTGRES_PASSWORD=secretpassword
POSTGRES_DB=yatri_production_db
ENVIRONMENT=production
```

Inside the container, ConfigMap values and Secret values are indistinguishable - both are just
environment variables. The separation is entirely about *who can read them from the API server*,
not about how the app consumes them.

`envFrom` vs `env`:

| | `envFrom` + `configMapRef` | `env` + `secretKeyRef` |
|---|---|---|
| Grabs | every key in the object | one named key |
| Name control | key name = env var name, no choice | you pick the env var name |
| Good for | bulk non-secret config | credentials, where you want to be explicit about each one |

---

## Part 4: Frontend

```bash
kubectl apply -f frontend.yaml
kubectl rollout status deployment/yatri-frontend
kubectl get pods -l app=yatri-frontend
kubectl get svc yatri-frontend-service yatri-backend-service
```

```console
### apply frontend
deployment.apps/yatri-frontend created
service/yatri-frontend-service created
Waiting for deployment "yatri-frontend" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "yatri-frontend" rollout to finish: 1 of 2 updated replicas are available...
deployment "yatri-frontend" successfully rolled out
### get pods
NAME                             READY   STATUS    RESTARTS   AGE
yatri-frontend-ddcfc4b5f-2hlmw   1/1     Running   0          1s
yatri-frontend-ddcfc4b5f-5z679   1/1     Running   0          1s
### get svc
NAME                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
yatri-frontend-service   ClusterIP   10.109.119.228   <none>        80/TCP    1s
yatri-backend-service    ClusterIP   10.110.91.191    <none>        80/TCP    47s
```

Both services are `ClusterIP` with `EXTERNAL-IP <none>`. Nothing outside the cluster can reach
either one. That is the setup the Ingress exists to solve - and note the alternative: two
`NodePort`/`LoadBalancer` services would mean two IPs/ports to hand out. Ingress gives one.

---

## Part 5: Ingress

```bash
minikube addons enable ingress
kubectl get pods -n ingress-nginx
kubectl apply -f ingress.yaml
kubectl get ingress yatri-ingress
kubectl describe ingress yatri-ingress
```

```console
### ingress controller pods
NAME                                       READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-jg9r2       0/1     Completed   0          64s
ingress-nginx-admission-patch-vdqw7        0/1     Completed   0          64s
ingress-nginx-controller-d7cd8c989-ttp9n   1/1     Running     0          64s
### apply ingress
ingress.networking.k8s.io/yatri-ingress created
### get ingress
NAME            CLASS   HOSTS         ADDRESS   PORTS   AGE
yatri-ingress   nginx   yatri.local             80      20s
### describe ingress
Name:             yatri-ingress
Labels:           app=yatri-app
Namespace:        default
Address:
Ingress Class:    nginx
Default backend:  <default>
Rules:
  Host         Path  Backends
  ----         ----  --------
  yatri.local
               /api(/|$)(.*)   yatri-backend-service:80 (10.244.0.10:5000,10.244.0.9:5000)
               /               yatri-frontend-service:80 (10.244.0.11:80,10.244.0.12:80)
Annotations:   nginx.ingress.kubernetes.io/rewrite-target: /$2
               nginx.ingress.kubernetes.io/ssl-redirect: false
               nginx.ingress.kubernetes.io/use-regex: true
Events:
  Type    Reason  Age   From                      Message
  ----    ------  ----  ----                      -------
  Normal  Sync    20s   nginx-ingress-controller  Scheduled for sync
```

`ADDRESS` was **empty** on the first read. It is populated asynchronously by the controller after
it syncs; ~30s later:

```console
### get ingress (after address assigned)
NAME            CLASS   HOSTS         ADDRESS        PORTS   AGE
yatri-ingress   nginx   yatri.local   192.168.49.2   80      55s
```

Also note `describe` lists the resolved **pod IPs** behind each backend, not the service ClusterIP
(`10.244.0.9:5000` etc.). ingress-nginx load-balances to pods directly, bypassing kube-proxy.
That is why a mismatched selector shows up here as an empty backend list.

### Reading `/api(/|$)(.*)` with `rewrite-target: /$2`

| Capture group | Matches | Example on `/api/health` |
|---|---|---|
| `$1` | `/` or end-of-string | `/` |
| `$2` | everything after | `health` |

`rewrite-target: /$2` means the backend receives `/health`, not `/api/health` - the `/api` prefix
is stripped before forwarding. `use-regex: "true"` plus `pathType: ImplementationSpecific` are both
required for the capture groups to be honoured.

---

## Part 6: Testing the routing

```bash
curl -s -H "Host: yatri.local" http://127.0.0.1:8080/      | grep -i "<title>"
curl -s -H "Host: yatri.local" http://127.0.0.1:8080/api/
curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Host: wrong.local" http://127.0.0.1:8080/
```

```console
### Test 1: root path -> frontend (nginx)
<title>Welcome to nginx!</title>
### Test 2: /api/ -> backend (python)
Yatri Backend API
=================
ENVIRONMENT     : production
LOG_LEVEL       : INFO
DEFAULT_CURRENCY: INR
POSTGRES_USER   : yatri_admin
POSTGRES_DB     : yatri_production_db
### Test 3: wrong Host header -> 404 from default backend
HTTP 404
```

One IP, one controller pod, two backends. Test 3 is the extra one I added: the *same* IP with a
`Host` header that matches no rule returns 404 from the default backend - proof the routing
decision is made on the `Host` header, not on the address.

Test 2 is also an end-to-end confirmation of Parts 1-3: those values came out of the ConfigMap and
the Secret, through the pod's environment, into an HTTP response body.

---

## Part 7: Everything at once

```console
### Part 7: all resources
NAME               DATA   AGE
yatri-app-config   5      2m18s
NAME              TYPE     DATA   AGE
yatri-db-secret   Opaque   3      2m14s
NAME                             READY   STATUS    RESTARTS   AGE
yatri-frontend-ddcfc4b5f-2hlmw   1/1     Running   0          83s
yatri-frontend-ddcfc4b5f-5z679   1/1     Running   0          83s
NAME                             READY   STATUS    RESTARTS   AGE
yatri-backend-6c58cb99c7-qxlh4   1/1     Running   0          2m9s
yatri-backend-6c58cb99c7-r5jnd   1/1     Running   0          2m9s
NAME                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
yatri-frontend-service   ClusterIP   10.109.119.228   <none>        80/TCP    83s
yatri-backend-service    ClusterIP   10.110.91.191    <none>        80/TCP    2m9s
NAME            CLASS   HOSTS         ADDRESS        PORTS   AGE
yatri-ingress   nginx   yatri.local   192.168.49.2   80      77s
```

---

## Part 8: The newline bug

I added `od -c` and `wc -c` to the lab's steps, because "watch your cursor jump to the next line"
is hard to paste into a README - the byte dump is not.

```bash
echo "secretpassword" | base64
echo "c2VjcmV0cGFzc3dvcmQK" | base64 --decode | od -c
echo -n "secretpassword" | base64
echo "secretpassword"    | wc -c
echo -n "secretpassword" | wc -c
```

```console
--- echo "secretpassword" | base64  (wrong)
c2VjcmV0cGFzc3dvcmQK
--- decode it back and pipe through od to see the hidden byte
0000000    s   e   c   r   e   t   p   a   s   s   w   o   r   d  \n
0000017
--- echo -n "secretpassword" | base64  (correct)
c2VjcmV0cGFzc3dvcmQ=
--- decode the correct one
0000000    s   e   c   r   e   t   p   a   s   s   w   o   r   d
0000016
--- byte counts
      15
      14
```

There it is in the dump: a literal `\n` byte at the end, `15` bytes vs `14`. The encoded string
ends `...AK` instead of `...A=`.

Why it hurts so much in practice: the Secret applies cleanly, the pod starts `Running` with no
errors, and the only symptom is `password authentication failed` from the database. Nothing in
`kubectl describe` points at it, because Kubernetes never validates the *contents* of a Secret.

This also lines up with Part 2's `describe` output: `POSTGRES_PASSWORD: 14 bytes`. **The byte count
in `describe secret` is the cheapest way to catch this** - if it reads one byte longer than the
password you meant to store, you encoded a newline.

---

## Part 9: Updating a ConfigMap

```bash
kubectl patch configmap yatri-app-config --type merge -p '{"data":{"ENVIRONMENT":"staging"}}'
kubectl exec deployment/yatri-backend -- env | grep ENVIRONMENT
kubectl rollout restart deployment/yatri-backend
kubectl exec deployment/yatri-backend -- env | grep ENVIRONMENT
```

```console
### patch ConfigMap to staging
configmap/yatri-app-config patched
### ConfigMap now says:
staging
### but the running pod still says:
ENVIRONMENT=production
### rolling restart
deployment.apps/yatri-backend restarted
Waiting for deployment "yatri-backend" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "yatri-backend" rollout to finish: 1 old replicas are pending termination...
deployment "yatri-backend" successfully rolled out
### now the pod says:
ENVIRONMENT=staging
```

The ConfigMap changed instantly; the pod did not. Environment variables are baked into the
container's process at start-up - there is no mechanism by which a running process's `environ`
gets rewritten. (A ConfigMap mounted as a **volume** *does* update in place, within a kubelet sync
period. That is the main reason to prefer volume mounts for config you want to be able to reload.)

### Something the lab does not mention

Immediately after `rollout status` reported success, I curled the API and still got `production`:

```console
### and the API reflects it too:
ENVIRONMENT     : production
```

Which looked wrong. The cause:

```console
NAME                             READY   STATUS        RESTARTS   AGE
yatri-backend-6747d7cf96-lg7tl   1/1     Running       0          16s
yatri-backend-6747d7cf96-trc4b   1/1     Running       0          17s
yatri-backend-6c58cb99c7-qxlh4   1/1     Terminating   0          2m31s
yatri-backend-6c58cb99c7-r5jnd   1/1     Terminating   0          2m31s

pod/yatri-backend-6747d7cf96-lg7tl -> ENVIRONMENT=staging
pod/yatri-backend-6747d7cf96-trc4b -> ENVIRONMENT=staging
pod/yatri-backend-6c58cb99c7-qxlh4 -> ENVIRONMENT=production
pod/yatri-backend-6c58cb99c7-r5jnd -> ENVIRONMENT=production
```

`rollout status` returns as soon as the **new** replicas are Ready - the old ones are still
`Terminating`, still `1/1 READY`, and therefore still in the ingress controller's upstream list.
For a few seconds the Ingress load-balances across *both generations*. Once they finished
terminating, every request returned the new value:

```console
### after termination completes, all replicas serve staging:
ENVIRONMENT     : staging
ENVIRONMENT     : staging
ENVIRONMENT     : staging
ENVIRONMENT     : staging
```

The lesson: `rollout status` success ≠ old version fully drained. It is the same window that makes
a `preStop` hook plus a sane `terminationGracePeriodSeconds` matter in production.

Then patched back:

```console
### patch back to production
configmap/yatri-app-config patched
deployment.apps/yatri-backend restarted
deployment "yatri-backend" successfully rolled out
ENVIRONMENT=production
```

---

## Part 10 (bonus): Host-based routing + TLS

From the updated [`03-ingress/README.md`](../../session-12-ingress-configmaps-secrets/03-ingress/README.md)
and [`03-ingress/ingress-tls.yaml`](../../session-12-ingress-configmaps-secrets/03-ingress/ingress-tls.yaml).
Two hosts on one Ingress: `portal.campus.local` → frontend, `api.campus.local/api/*` → backend, both over HTTPS.

### Steps 1-3: cert, Secret, Ingress

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=campus.local/O=CampusDevOps"

kubectl create secret tls campus-tls-cert --cert=tls.crt --key=tls.key
kubectl apply -f session-12-ingress-configmaps-secrets/03-ingress/ingress-tls.yaml
```

```console
### Step 2: create TLS secret
secret/campus-tls-cert created
NAME              TYPE                DATA   AGE
campus-tls-cert   kubernetes.io/tls   2      0s
### Step 3: apply TLS ingress
ingress.networking.k8s.io/campus-ingress-tls created
NAME                 CLASS   HOSTS                                  ADDRESS   PORTS     AGE
campus-ingress-tls   nginx   portal.campus.local,api.campus.local             80, 443   25s
```

`TYPE kubernetes.io/tls` with `DATA 2` - `kubectl create secret tls` is a typed helper that stores
exactly `tls.crt` and `tls.key` and base64-encodes them for you (no `echo -n` trap here).
`PORTS 80, 443` confirms the TLS block was accepted.

### Step 4: test - and the bug the lab's openssl command walks into

Routing worked immediately:

```console
### Test Host 1: portal.campus.local over HTTPS -> frontend
<title>Welcome to nginx!</title>
### Test Host 2: api.campus.local/api/ over HTTPS -> backend
Yatri Backend API
=================
ENVIRONMENT     : production
LOG_LEVEL       : INFO
DEFAULT_CURRENCY: INR
POSTGRES_USER   : yatri_admin
POSTGRES_DB     : yatri_production_db
```

But when I checked *which certificate* was actually being served:

```console
* SSL connection using TLSv1.3 / AEAD-AES256-GCM-SHA384
*  subject: O=Acme Co; CN=Kubernetes Ingress Controller Fake Certificate
*  issuer:  O=Acme Co; CN=Kubernetes Ingress Controller Fake Certificate
```

**That is not my certificate.** `curl -k` had been silently hiding it. The controller logs said why:

```console
W  Unexpected error validating SSL certificate "default/campus-tls-cert" for server "portal.campus.local":
   x509: certificate is not valid for any names, but wanted to match portal.campus.local
W  SSL certificate "default/campus-tls-cert" does not contain a Common Name or Subject Alternative
   Name for server "portal.campus.local"
W  Using default certificate
```

The cert itself:

```console
$ openssl x509 -in tls.crt -noout -subject -ext subjectAltName
No extensions in certificate
subject=CN=campus.local, O=CampusDevOps
```

Two problems with `-subj "/CN=campus.local/..."` alone:

1. It generates **no SAN extension at all**, and Go's x509 verifier (which ingress-nginx uses) has
   ignored CN-as-hostname since Go 1.15 - hence *"not valid for any names"*.
2. Even if CN were honoured, `campus.local` does not match `portal.campus.local` or
   `api.campus.local` - a plain CN is not a wildcard.

The Ingress silently falls back to the built-in fake cert. Nothing fails; `kubectl get ingress`
looks perfectly healthy. In production that is a browser-wide TLS error with a green-looking
`kubectl` output.

**Fix** - add a SAN covering both hosts:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=campus.local/O=CampusDevOps" \
  -addext "subjectAltName=DNS:portal.campus.local,DNS:api.campus.local"

kubectl delete secret campus-tls-cert
kubectl create secret tls campus-tls-cert --cert=tls.crt --key=tls.key
```

```console
X509v3 Subject Alternative Name:
    DNS:portal.campus.local, DNS:api.campus.local
secret "campus-tls-cert" deleted from default namespace
secret/campus-tls-cert created
### certificate served now:
* SSL connection using TLSv1.3 / AEAD-AES256-GCM-SHA384
*  subject: CN=campus.local; O=CampusDevOps
*  issuer:  CN=campus.local; O=CampusDevOps
### routing still correct over HTTPS:
<title>Welcome to nginx!</title>
Yatri Backend API
=================
ENVIRONMENT     : production
```

Now my own cert is served. Note the controller picked up the replaced Secret **without** restarting
the Ingress or the controller pod - ingress-nginx watches the Secret and hot-reloads certs.

### `ssl-redirect: "true"`

Unlike `yatri-ingress`, this one sets `ssl-redirect: "true"`, so plain HTTP is bounced:

```console
### ssl-redirect true: plain HTTP on portal.campus.local should 308 to HTTPS
HTTP 308 -> https://portal.campus.local/
```

`308 Permanent Redirect` rather than `301`, because 308 is the one that guarantees the method and
body survive the redirect - a `POST` stays a `POST`.

---

## Cleanup

```bash
kubectl delete ingress campus-ingress-tls
kubectl delete secret  campus-tls-cert
bash cleanup.sh
```

```console
### TLS cleanup
ingress.networking.k8s.io "campus-ingress-tls" deleted from default namespace
secret "campus-tls-cert" deleted from default namespace
### bash cleanup.sh
[INFO] Deleting Ingress...
ingress.networking.k8s.io "yatri-ingress" deleted from default namespace
[INFO] Deleting Backend Deployment and Service...
deployment.apps "yatri-backend" deleted from default namespace
service "yatri-backend-service" deleted from default namespace
[INFO] Deleting Frontend Deployment and Service...
deployment.apps "yatri-frontend" deleted from default namespace
service "yatri-frontend-service" deleted from default namespace
[INFO] Deleting Secret...
secret "yatri-db-secret" deleted from default namespace
[INFO] Deleting ConfigMap...
configmap "yatri-app-config" deleted from default namespace
[INFO] All demo resources removed.
### verify everything is gone
No resources found in default namespace.
Error from server (NotFound): configmaps "yatri-app-config" not found
Error from server (NotFound): secrets "yatri-db-secret" not found
Error from server (NotFound): ingresses.networking.k8s.io "yatri-ingress" not found
```

`cleanup.sh` deletes in reverse dependency order (Ingress first, ConfigMap/Secret last) so nothing
is ever left referencing a deleted object.

---

## What I took away

**ConfigMap vs Secret is an access-control boundary, not a technical one.** Both arrive in the
container as identical environment variables. The difference is who can read them from the API
server, whether they show up in `describe`, and whether etcd encrypts them at rest. Putting a
password in a ConfigMap is not "wrong" mechanically - it just deletes the boundary.

**Base64 is encoding, not encryption**, and the `echo` vs `echo -n` trap is nasty precisely
because everything downstream *succeeds*: the Secret applies, the pod runs, and the only symptom
is an auth failure from the database. `describe secret`'s byte count is the fastest tell.

**Ingress collapses N external IPs into one.** Two `ClusterIP` services that nothing outside could
reach became reachable through a single address, with the `Host` header and path prefix doing the
routing - and a `Host` that matches no rule getting a 404.

**Env vars are frozen at container start.** A ConfigMap change needs `kubectl rollout restart`;
only a volume-mounted ConfigMap updates in place.

**"Success" output is not the same as "done".** Twice in this lab something reported healthy while
the real state differed: `rollout status` returned while old pods were still serving traffic, and
the TLS Ingress looked perfectly fine while quietly serving the controller's fake certificate.
Both were only visible by checking the thing itself - `kubectl get pods` for the first, `curl -v`
plus the controller logs for the second.
