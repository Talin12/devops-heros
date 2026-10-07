# Helm: Homework (Session 15)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> My chart: [`notes-chart/`](notes-chart/) · Assignment: [`session-15-helm/mini-project`](../../session-15-helm/mini-project/README.md)

**Environment:** Helm v4.3.0, minikube v1.39.0, Kubernetes v1.37.0, namespace `s15`.

---

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Build `notes-chart` (Chart.yaml, values.yaml, values-prod.yaml, 3 templates) | ✅ |
| 2 | `helm lint` + `helm template` | ✅ |
| 3 | `helm install` (dev values) | ✅ |
| 4 | `helm upgrade` with `values-prod.yaml` → 3 replicas | ✅ |
| 5 | `helm history` | ✅ |
| 6 | Bad upgrade (`image.tag=broken-tag-does-not-exist`) | ✅ |
| 7 | `helm rollback` to revision 2 | ✅ |
| 8 | Extra: the same bad upgrade with `--wait --rollback-on-failure` | ✅ |
| 9 | Extra: ConfigMap change not reaching pods, fixed with a checksum annotation | ✅ |
| 10 | `helm uninstall` | ✅ |

---

## 1–2. Lint and render

```console
$ helm lint notes-chart
==> Linting notes-chart
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm template notes-dev notes-chart
---
# Source: notes-chart/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: notes-dev-config
data:
  APP_NAME: "notes-app"
  ENVIRONMENT: "development"

---
# Source: notes-chart/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: notes-dev-svc
spec:
  type: NodePort
  selector:
    app: notes-dev
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30090

---
# Source: notes-chart/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: notes-dev-deploy
  labels:
    app: notes-dev
    environment: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: notes-dev
  template:
    metadata:
      labels:
        app: notes-dev
    spec:
      containers:
        - name: notes
          image: "nginx:1.24"
          ports:
            - containerPort: 80
          envFrom:
            - configMapRef:
                name: notes-dev-config

$ helm template notes-dev notes-chart -f notes-chart/values-prod.yaml | grep -E 'replicas|image:|ENVIRONMENT|environment:'
  ENVIRONMENT: "production"
    environment: production
  replicas: 3
          image: "nginx:1.25"

$ helm template notes-dev notes-chart --set replicaCount=5 --set image.tag=1.27 | grep -E 'replicas|image:'
  replicas: 5
          image: "nginx:1.27"
```

Precedence, lowest to highest: `values.yaml` < `-f values-prod.yaml` < `--set`.

## 3. Install

```console
$ helm install notes-dev notes-chart
NAME: notes-dev
LAST DEPLOYED: Wed Oct  7 18:07:34 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
TEST SUITE: None

$ kubectl get pods,svc,configmap
NAME                                    READY   STATUS    RESTARTS   AGE
pod/notes-dev-deploy-74956bd987-ztwvx   1/1     Running   0          46s

NAME                    TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
service/notes-dev-svc   NodePort   10.100.113.237   <none>        80:30090/TCP   46s

NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      47s
configmap/notes-dev-config   2      46s

$ kubectl exec deploy/notes-dev-deploy -- printenv APP_NAME ENVIRONMENT
notes-app
development

$ minikube ssh -- curl -s -o /dev/null -w 'NodePort-30090-HTTP-%{http_code}' localhost:30090
NodePort-30090-HTTP-200
```

(Curling `$(minikube ip):30090` from the Mac returned `000`. With the docker driver on macOS, the
node IP is not routable from the host, so I tested the NodePort from inside the node.)

## 4–5. Upgrade to production + history

```console
$ helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml
Release "notes-dev" has been upgraded. Happy Helming!
NAME: notes-dev
LAST DEPLOYED: Wed Oct  7 18:09:46 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 2
DESCRIPTION: Upgrade complete
TEST SUITE: None

$ kubectl get pods -o 'custom-columns=NAME:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image'
NAME                               STATUS    IMAGE
notes-dev-deploy-bbcc464b4-4zl56   Running   nginx:1.25
notes-dev-deploy-bbcc464b4-b8sxm   Running   nginx:1.25
notes-dev-deploy-bbcc464b4-vdwnt   Running   nginx:1.25

$ kubectl exec deploy/notes-dev-deploy -- printenv ENVIRONMENT
production

$ helm history notes-dev
REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION
1       	Wed Oct  7 18:07:34 2026	superseded	notes-chart-0.1.0	1.0        	Install complete
2       	Wed Oct  7 18:09:46 2026	deployed  	notes-chart-0.1.0	1.0        	Upgrade complete
```

## 6. Bad upgrade - Helm says "deployed"

```console
$ helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --set image.tag=broken-tag-does-not-exist
Release "notes-dev" has been upgraded. Happy Helming!
NAME: notes-dev
LAST DEPLOYED: Wed Oct  7 18:10:52 2026
NAMESPACE: s15
STATUS: deployed
REVISION: 3
DESCRIPTION: Upgrade complete
TEST SUITE: None

$ kubectl get pods
NAME                                READY   STATUS             RESTARTS   AGE
notes-dev-deploy-79b4dbdffd-5h5b5   0/1     ImagePullBackOff   0          25s
notes-dev-deploy-bbcc464b4-4zl56    1/1     Running            0          41s
notes-dev-deploy-bbcc464b4-b8sxm    1/1     Running            0          41s
notes-dev-deploy-bbcc464b4-vdwnt    1/1     Running            0          92s

$ minikube ssh -- curl -s -o /dev/null -w 'app-still-serving-HTTP-%{http_code}' localhost:30090
app-still-serving-HTTP-200

$ kubectl get deploy notes-dev-deploy -o jsonpath='strategy maxSurge={.spec.strategy.rollingUpdate.maxSurge} maxUnavailable={.spec.strategy.rollingUpdate.maxUnavailable}{"\n"}'
strategy maxSurge=25% maxUnavailable=25%
```

Two things differ from the expected output in the assignment:

- **Helm reported `STATUS: deployed` / `Upgrade complete`.** Without `--wait`, Helm only checks that
  the API server *accepted* the manifests. It never checks whether the pods came up.
- **Only one broken pod, and the app kept serving.** With 3 replicas, `maxUnavailable: 25%` rounds
  *down* to 0 and `maxSurge: 25%` rounds *up* to 1. So the rollout created 1 new pod and is not
  allowed to kill any old pod until a new one is Ready, which never happens. The rolling update
  protected the app even though Helm did not.

## 7. Rollback

```console
$ helm rollback notes-dev 2
Rollback was a success! Happy Helming!

$ kubectl get pods -o 'custom-columns=NAME:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image'
NAME                                STATUS    IMAGE
notes-dev-deploy-79b4dbdffd-5h5b5   Pending   nginx:broken-tag-does-not-exist
notes-dev-deploy-bbcc464b4-4zl56    Running   nginx:1.25
notes-dev-deploy-bbcc464b4-b8sxm    Running   nginx:1.25
notes-dev-deploy-bbcc464b4-vdwnt    Running   nginx:1.25

# a few seconds later, once the broken pod had been terminated:
$ kubectl get pods -o 'custom-columns=NAME:.metadata.name,STATUS:.status.phase,IMAGE:.spec.containers[0].image'
NAME                               STATUS    IMAGE
notes-dev-deploy-bbcc464b4-4zl56   Running   nginx:1.25
notes-dev-deploy-bbcc464b4-b8sxm   Running   nginx:1.25
notes-dev-deploy-bbcc464b4-vdwnt   Running   nginx:1.25

$ helm history notes-dev
REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION
1       	Wed Oct  7 18:07:34 2026	superseded	notes-chart-0.1.0	1.0        	Install complete
2       	Wed Oct  7 18:09:46 2026	superseded	notes-chart-0.1.0	1.0        	Upgrade complete
3       	Wed Oct  7 18:10:52 2026	superseded	notes-chart-0.1.0	1.0        	Upgrade complete
4       	Wed Oct  7 18:11:18 2026	deployed  	notes-chart-0.1.0	1.0        	Rollback to 2
```

A rollback does not delete revision 3. It creates **revision 4** with revision 2's content, so the
history is append-only.

## 8. The same bad upgrade, done safely

```console
$ helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --set image.tag=broken-tag-does-not-exist --wait --timeout 45s --rollback-on-failure
level=WARN msg="upgrade failed" name=notes-dev error="resource Deployment/s15/notes-dev-deploy not ready. status: InProgress, message: Updated: 1/3\ncontext deadline exceeded"
Error: UPGRADE FAILED: release notes-dev failed, and has been rolled back due to rollback-on-failure being set: resource Deployment/s15/notes-dev-deploy not ready. status: InProgress, message: Updated: 1/3
context deadline exceeded

$ helm history notes-dev
REVISION	UPDATED                 	STATUS    	CHART            	APP VERSION	DESCRIPTION
...
4       	Wed Oct  7 18:11:18 2026	superseded	notes-chart-0.1.0	1.0        	Rollback to 2
5       	Wed Oct  7 18:11:19 2026	failed    	notes-chart-0.1.0	1.0        	Upgrade "notes-dev" failed: resource Deployment/s15/notes-dev-deploy not ready. status: InProgress, message: Updated: ...
6       	Wed Oct  7 18:12:04 2026	deployed  	notes-chart-0.1.0	1.0        	Rollback to 4
```

`--wait` makes Helm actually wait for readiness, and `--rollback-on-failure` (Helm 4's name for
Helm 3's `--atomic`) undoes the release on its own. This is the flag set a CI pipeline should use.

## 9. Extra: a config change that never reaches the pods

```console
$ helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --set app.environment=staging
Release "notes-dev" has been upgraded. Happy Helming!
...
REVISION: 7

$ kubectl get pods -o name | sort | diff /tmp/before - && echo 'same 3 pods - nothing restarted'
same 3 pods - nothing restarted

$ kubectl exec deploy/notes-dev-deploy -- printenv ENVIRONMENT
production
```

The ConfigMap now says `staging`, but the pods still say `production`. Env vars from `envFrom` are
read once, at container start, and changing a ConfigMap does not restart anything. The fix
(chart **v0.2.0**) is a hash of the ConfigMap on the pod template:

```yaml
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

```console
$ helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --set app.environment=staging --wait --timeout 120s | grep -E 'STATUS|REVISION'
STATUS: deployed
REVISION: 8

$ kubectl exec deploy/notes-dev-deploy -- printenv ENVIRONMENT
staging

$ kubectl get deploy notes-dev-deploy -o jsonpath='{.spec.template.metadata.annotations.checksum/config}'; echo
df2ecde977e28c7a0774a4116896f10a11bc009606b4df5f0368f3580a7e1445

$ helm upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --wait --timeout 120s | grep -E 'STATUS|REVISION'
STATUS: deployed
REVISION: 9

$ kubectl exec deploy/notes-dev-deploy -- printenv ENVIRONMENT
production

$ kubectl get deploy notes-dev-deploy -o jsonpath='{.spec.template.metadata.annotations.checksum/config}'; echo
41f9b88c185a82ef0b101645c30d0c6d889a8196eae3f7bb7e8ff57145b5fb71
```

The hash changes, so the pod template changes, so the Deployment rolls new pods that read the new
env.

## 10. Package and uninstall

```console
$ helm package notes-chart -d /tmp && tar tzf /tmp/notes-chart-0.2.0.tgz
Successfully packaged chart and saved it to: /tmp/notes-chart-0.2.0.tgz
notes-chart/Chart.yaml
notes-chart/values.yaml
notes-chart/templates/configmap.yaml
notes-chart/templates/deployment.yaml
notes-chart/templates/service.yaml
notes-chart/values-prod.yaml

$ helm uninstall notes-dev
release "notes-dev" uninstalled

$ kubectl get all,configmap
NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      5m17s
```

## What I took away

- **"deployed" means "the API server accepted it", not "it works".** Without `--wait`, Helm reported
  a successful upgrade to an image that does not exist.
- **Rollback is a new revision, not an undo.** History only grows, which is what makes it an audit
  trail.
- **Helm templates the ConfigMap, but nothing restarts the pods.** The checksum annotation is the
  standard way to link the two.
