# Kubernetes Pods, ReplicaSets & Deployments: Homework (Session 10)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> Manifests: [`session10-k8s-core-objects/`](../../session10-k8s-core-objects/)

---

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Reproduce all 12 pod lifecycle states and explain each | ✅ |
| 2 | ReplicaSet: scaling, and what it cannot do | ✅ |
| 3 | DaemonSet: one pod per node | ✅ |
| 4 | StatefulSet: ordered creation, stable identity, per-pod storage | ✅ |
| 5 | RollingUpdate strategy + rollback via revision history | ✅ |
| 6 | Recreate strategy, with the downtime window measured | ✅ |
| 7 | Blue-green cutover by label switch | ✅ |
| 8 | Canary with the real traffic split measured over 200 requests | ✅ |
| 9 | Troubleshooting: broken image + selector mismatch | ✅ |

**Environment:** minikube v1.39.0 (docker driver), Kubernetes v1.37.0, single node, macOS arm64.

---

## Contents
1. [Task 1 - Pod lifecycle: all 12 states](#task-1-pod-lifecycle-all-12-states)
2. [Task 2 - ReplicaSet](#task-2-replicaset)
3. [Task 3 - DaemonSet](#task-3-daemonset)
4. [Task 4 - StatefulSet](#task-4-statefulset)
5. [Tasks 5-8 - The four deployment strategies](#tasks-5-8-the-four-deployment-strategies)
6. [Task 9 - Troubleshooting](#task-9-troubleshooting)
7. [What I took away](#what-i-took-away)

---

## Task 1: Pod lifecycle - all 12 states

```bash
cd session10-k8s-core-objects/pod-lifecycle
kubectl apply -f .
```

All twelve applied at once, then left to settle for ~80 seconds:

```console
lifecycle-crashloop                  0/1     Error              3 (82s ago)   2m21s   10.244.0.24
lifecycle-failed                     0/1     Error              0             2m21s   10.244.0.23
lifecycle-image-error                0/1     ImagePullBackOff   0             2m21s   10.244.0.25
lifecycle-init                       1/1     Running            0             2m21s   10.244.0.29
lifecycle-liveness                   1/1     Running            1 (30s ago)   2m21s   10.244.0.27
lifecycle-multi-container            2/2     Running            0             2m21s   10.244.0.30
lifecycle-pending                    0/1     Pending            0             2m21s   <none>
lifecycle-readiness                  1/1     Running            0             2m21s   10.244.0.26
lifecycle-running                    1/1     Running            0             2m21s   10.244.0.21
lifecycle-startup                    1/1     Running            0             2m21s   10.244.0.28
lifecycle-succeeded                  0/1     Completed          0             2m21s   10.244.0.22
lifecycle-termination                1/1     Running            0             2m21s   10.244.0.31
```

Note `lifecycle-pending` has **no IP and no node** - it was never scheduled, so no network was ever
set up for it. Every other pod got an IP even when its container failed, because the sandbox is
created before the container is started.

### Phase vs. STATUS - an important distinction

A Pod has only **five** phases: `Pending`, `Running`, `Succeeded`, `Failed`, `Unknown`.
`CrashLoopBackOff` and `ImagePullBackOff` are **not phases** - they are container *waiting reasons*
that `kubectl get pods` prints in the STATUS column because they are more useful. Both of those
pods are technically in phase `Pending`/`Running`.

### Why Pending

```console
Events:
  Warning  FailedScheduling  105s (x3 over 2m26s)  default-scheduler  0/1 nodes are available: 1 Insufficient memory. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

requests: {"cpu":"1","memory":"9Gi"}
node allocatable: 10  8025424Ki
```

It asked for **9Gi**; the node has **~7.65Gi** allocatable. The scheduler is comparing the request
against allocatable and finds no fit, so the pod sits unassigned forever. The message comes from
`default-scheduler`, which tells you immediately this is a *scheduling* problem, not an image or
runtime problem.

Also worth noting: the scheduler compares against **requests**, not actual usage. A node with 8Gi
free RAM will still reject this pod if existing pods have *requested* the memory, even if they are
using almost none of it.

### Why ImagePullBackOff

```console
  Warning  Failed     52s (x3 over 95s)   kubelet  Failed to pull image "jakwehrgkaejw:kahsdfgkhj": failed to resolve reference "docker.io/library/jakwehrgkaejw:kahsdfgkhj": pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
  Warning  Failed     52s (x3 over 95s)   kubelet  Error: ErrImagePull
  Normal   BackOff    15s (x5 over 94s)   kubelet  Back-off pulling image "jakwehrgkaejw:kahsdfgkhj"
  Warning  Failed     15s (x5 over 94s)   kubelet  Error: ImagePullBackOff
```

`ErrImagePull` is the *first* failure; `ImagePullBackOff` is what it becomes once the kubelet starts
backing off between retries. A trap worth knowing: **"repository does not exist **or may require
authorization**"** - a private image with a missing `imagePullSecret` produces this same message.
A genuinely mistyped name and a permissions problem are indistinguishable from the error text.

### Why CrashLoopBackOff

```console
restartCount=4
lastState=Error exitCode=1
state={"terminated":{"exitCode":1,"reason":"Error",...}}

$ kubectl logs lifecycle-crashloop --tail=4
Application started
Application crashed
```

The container runs, prints, exits 1, and the default `restartPolicy: Always` restarts it - forever.
The backoff doubles each time (10s, 20s, 40s ... capped at 5 minutes), which is why a pod that has
been crashing for an hour seems to "do nothing" for minutes at a stretch.

The two commands that actually diagnose this:
- `kubectl logs <pod> --previous` - logs of the *crashed* instance, not the current one
- `.lastState.terminated.exitCode` - exit 1 = app error, **137** = OOMKilled/SIGKILL, **143** = SIGTERM

### Succeeded vs Failed - the same end, different exit code

```console
phase=Succeeded exitCode=0
phase=Failed    exitCode=1
```

Both containers stopped. The *only* difference is the exit code, and `lifecycle-failed` sets
`restartPolicy: Never` - which is why it stays `Failed` instead of becoming a crash loop. Same
program, same crash; the restart policy alone decides whether you see `Failed` or
`CrashLoopBackOff`.

### Liveness probe - a restart you asked for

The container touches `/tmp/healthy`, sleeps 20s, then deletes it. The probe tests for that file.

```console
  Warning  Unhealthy  12s (x4 over 77s)  kubelet  Liveness probe failed:
  Normal   Killing    12s (x2 over 72s)  kubelet  Container app failed liveness probe, will be restarted
restartCount: 1
```

**Liveness vs readiness**, the distinction that matters most in practice:

| | Liveness | Readiness |
|---|---|---|
| On failure | **Kills and restarts** the container | Removes the pod from Service endpoints |
| Recovers from | A wedged process (deadlock, hung thread) | A temporary dependency outage, slow warm-up |
| Danger | Too aggressive → restart loops under load | none really - it just stops traffic |

A liveness probe that is stricter than it needs to be is actively harmful: under heavy load the app
responds slowly, the probe fails, Kubernetes kills it, the remaining pods get more load, and the
whole deployment cascades. Readiness is the safe default; reach for liveness only for states the
process genuinely cannot recover from on its own.

### Init container - ordering guarantee

```console
init: Completed exitCode=0
app : 2026-09-17T18:24:00Z

$ kubectl logs lifecycle-init -c setup
Init container running
Init complete
```

The init container ran to completion **before** the app container was started. Init containers run
sequentially and must each exit 0; if one fails it is retried and the app container never starts.
That is the ordering guarantee you use for "wait for the database" or "fetch config before boot".

### Multi-container pod

```console
app     -> nginx:1.27
sidecar -> busybox:1.36
pod IP: 10.244.0.30        <- ONE IP for BOTH containers
```

`2/2 Running`. Both containers share one network namespace and one IP, so they reach each other on
`localhost` - and they cannot both bind the same port. That shared namespace is what makes the
sidecar pattern (log shipper, proxy) work at all.

---

## Task 2: ReplicaSet

```bash
kubectl apply -f replicaset/backend-rs.yaml
kubectl scale rs yatri-backend-rs --replicas=5
```

```console
NAME               DESIRED   CURRENT   READY   AGE
yatri-backend-rs   3         3         3       25s

--- scale to 5 ---
NAME               DESIRED   CURRENT   READY   AGE
yatri-backend-rs   5         5         5       37s
```

Scaling works fine. But:

```console
$ kubectl rollout history rs/yatri-backend-rs
error: no history viewer has been implemented for "ReplicaSet.apps"
```

**That error is the whole point of the exercise.** A ReplicaSet maintains a replica count and
nothing more - it has no concept of revisions, no rollout, no rollback. Change its image and it
does *not* gradually replace pods; you would have to delete them yourself.

A Deployment is a controller *on top of* ReplicaSets that adds exactly that missing layer: it keeps
one ReplicaSet per revision and shifts replicas between them. That is why you write Deployments and
essentially never write ReplicaSets by hand.

---

## Task 3: DaemonSet

```console
NAME                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
node-logging-agent   1         1         1       1            1           <none>          21s

NAME                       READY   STATUS    RESTARTS   AGE   IP            NODE
node-logging-agent-rjn6v   1/1     Running   0          21s   10.244.0.37   minikube

node count: 1

[Thu Sep 17 18:26:24 UTC 2026] Collecting host system metrics on node-logging-agent-rjn6v
```

`DESIRED 1` because the cluster has exactly 1 node. Nobody wrote `replicas: 1` - **a DaemonSet has
no `replicas` field at all.** Its desired count *is* the node count, so adding a node automatically
gets a pod and removing one automatically cleans up.

That is the right shape for anything that is a property of the *machine* rather than of the
application: log collectors, metrics agents, CNI plugins, storage drivers. `kube-proxy` and
`kindnet` from Session 9 are both DaemonSets for exactly this reason.

---

## Task 4: StatefulSet

### First attempt: the repo manifest fails on arm64

```bash
kubectl apply -f k8s-core-objects/statefulset.yml     # image: mysql:5.7
```

```console
NAME    READY   AGE
mysql   0/3     61s

NAME      READY   STATUS             RESTARTS   AGE
mysql-0   0/1     ImagePullBackOff   0          61s

  Warning  Failed  10s (x3 over 56s)  kubelet  Failed to pull image "mysql:5.7":
           rpc error: code = NotFound desc = failed to pull and unpack image
           "docker.io/library/mysql:5.7": no match for platform in manifest: not found
```

**`no match for platform in manifest`** is a different failure from the Task 1 ImagePullBackOff.
The repository and tag both exist - Docker Hub simply publishes no `linux/arm64` build of
`mysql:5.7`. The node is arm64:

```console
$ kubectl get node minikube -o jsonpath='{.status.nodeInfo.architecture}'
arm64 / linux
```

This is a pure Apple-Silicon problem; the manifest is fine on an amd64 cloud instance.

### The interesting part: what that failure proves about StatefulSets

```console
===== consequence: mysql-1 and mysql-2 were NEVER created =====
NAME      READY   STATUS         RESTARTS   AGE
mysql-0   0/1     ErrImagePull   0          68s

--- but the PVC for mysql-0 WAS provisioned ---
NAME                               STATUS   VOLUME                     CAPACITY   ACCESS MODES   STORAGECLASS
mysql-persistent-storage-mysql-0   Bound    pvc-f8ffa278-...           5Gi        RWO            standard

replicas=1 ready=
```

`replicas: 3` was requested and **only one pod exists**. A StatefulSet creates pods strictly in
ordinal order and waits for each to become Ready before starting the next, so a stuck `mysql-0`
blocks `mysql-1` and `mysql-2` indefinitely.

A Deployment would have created all three immediately and shown three broken pods. The difference
is not cosmetic: if you are debugging a StatefulSet that is "missing pods", the answer is almost
always that a lower ordinal is unhealthy.

Note also that the PVC was **bound anyway** - storage is provisioned before the container is even
pulled, and it will outlive the pod.

### Fixed version

I wrote [`manifests/statefulset-arm64.yaml`](manifests/statefulset-arm64.yaml): `mysql:8.0` instead
of `5.7`, smaller footprint for a single node, and the **headless Service the original references
via `serviceName: "mysql"` but never actually defines**.

```console
service/mysql created
statefulset.apps/mysql created
partitioned roll out complete: 2 new pods have been updated...

--- stable ordinal names, created in order ---
NAME      READY   STATUS    RESTARTS   AGE   IP
mysql-0   1/1     Running   0          40s   10.244.0.39
mysql-1   1/1     Running   0          0s    10.244.0.40

--- one PVC per pod, bound to its ordinal ---
NAME                               STATUS   CAPACITY   ACCESS MODES   STORAGECLASS
mysql-persistent-storage-mysql-0   Bound    1Gi        RWO            standard
mysql-persistent-storage-mysql-1   Bound    1Gi        RWO            standard

--- per-pod DNS via the headless service ---
Name:	mysql-0.mysql.default.svc.cluster.local
Address: 10.244.0.39
```

`mysql-0` is 40s old and `mysql-1` is 0s old - ordered creation, visible in the AGE column.
Names are `mysql-0`/`mysql-1`, not the random hashes a Deployment produces.

### Stable identity: data survives pod deletion

```console
--- write into mysql-0 ---
msg
written to mysql-0

--- old pod UID ---
uid=94a26384-9101-46fb-b063-6020889593e1

$ kubectl delete pod mysql-0
pod "mysql-0" deleted

--- NEW pod: different UID, SAME name, SAME PVC ---
uid=91b6e5be-7d69-4287-8c7a-b0471e3df7db
pvc=mysql-persistent-storage-mysql-0

--- data still there? ---
msg
written to mysql-0
```

Different UID - it is genuinely a **new pod**, exactly like the Session 9 self-healing demo. But
unlike a Deployment's replacement, it came back with the *same name* and was reattached to the
*same PVC*, so the data is still there.

That is the entire value proposition of a StatefulSet, and it is why databases go in StatefulSets
and stateless web tiers go in Deployments.

---

## Tasks 5-8: The four deployment strategies

### 5. RollingUpdate (`maxSurge: 1, maxUnavailable: 0`)

Sampling pod counts every 2 seconds *during* the v1→v2 update:

```console
t+02s     1 ContainerCreating    4 Running  | total=5
t+04s     5 Running  | total=5
t+14s     5 Running  | total=6
t+16s     5 Running  | total=5
...
deployment "app-rolling" successfully rolled out
```

Desired count is 4. **Running never dropped below 4, and total peaked at 6.** `maxUnavailable: 0`
guarantees the floor; `maxSurge: 1` allows the temporary extra pod. Zero downtime - but you are
briefly paying for extra capacity, and **both versions serve traffic simultaneously**, so v1 and v2
must be mutually compatible (same API contract, same database schema).

```console
===== revision history =====
REVISION  CHANGE-CAUSE
1         <none>
2         <none>

NAME                     DESIRED   CURRENT   READY   AGE
app-rolling-56bff6d88c   4         4         4       27s     <- v2, scaled up
app-rolling-86d7d44d5b   0         0         0       71s     <- v1, scaled to zero but KEPT
```

The old ReplicaSet is kept at 0 replicas. That is what makes rollback instant - nothing is rebuilt,
it just scales back up:

```console
$ kubectl rollout undo deployment/app-rolling --to-revision=1
deployment.apps/app-rolling rolled back
...
app-rolling-86d7d44d5b-2smqg   1/1   Running   0   24s   version=v1

REVISION  CHANGE-CAUSE
2         <none>
3         <none>
```

Two things worth noticing:
- The **same** ReplicaSet hash `86d7d44d5b` came back - it reused the existing object.
- Revision 1 **disappeared and became revision 3**. A rollback is recorded as a *new* revision, not
  a rewind. Roll back twice and you are back where you started.

There is also a real warning here:

```console
Warning: resource deployments/app-rolling was previously managed with 'kubectl apply'. Rolling back will not update the kubectl.kubernetes.io/last-applied-configuration annotation, which may cause unexpected behavior on future 'kubectl apply' operations.
```

Mixing `kubectl apply` (declarative) with `rollout undo` (imperative) leaves the cluster
disagreeing with your YAML. The next `apply` from the unchanged v2 file would silently undo the
rollback. In practice: roll back in an emergency, then immediately fix the file in git.

### 6. Recreate - the downtime made visible

```console
t+02s  running=0   total=3   endpoints= 0        <-- OUTAGE
t+04s  running=3   total=3   endpoints= 3
t+06s  running=3   total=3   endpoints= 3
```

At t+02s: **zero running pods and zero Service endpoints.** Every request in that window fails.
Compare with the rolling update above, where Running never left 4.

`Recreate` tears everything down before building anything up. You accept that outage when the two
versions genuinely cannot coexist - an incompatible schema migration, or a `ReadWriteOnce` volume
that only one pod can hold at a time.

### 7. Blue-green - cutover by label

Both versions fully deployed and running at the same time:

```console
app-blue-5c69d7785c-4wgtc          Running   blue   v1
app-blue-5c69d7785c-7db6m          Running   blue   v1
app-blue-5c69d7785c-q9djx          Running   blue   v1
app-green-84df7f978-czcz8          Running   green  v2
app-green-84df7f978-j85bj          Running   green  v2
app-green-84df7f978-ltqwd          Running   green  v2
```

The Service selects `{"app":"myapp","slot":"blue"}`, so its endpoints are the blue pod IPs only:

```console
myapp-service   10.244.0.62:80,10.244.0.64:80,10.244.0.66:80
blue IPs:       10.244.0.64 10.244.0.66 10.244.0.62          <- exact match
```

The cutover is one label patch:

```bash
kubectl patch svc myapp-service -p '{"spec":{"selector":{"app":"myapp","slot":"green"}}}'
```

```console
{"app":"myapp","slot":"green"}
myapp-service   10.244.0.63:80,10.244.0.65:80,10.244.0.67:80
green IPs:      10.244.0.65 10.244.0.63 10.244.0.67          <- exact match

===== instant rollback: flip it back =====
myapp-service   10.244.0.62:80,10.244.0.64:80,10.244.0.66:80
```

The endpoint list swaps wholesale. **No pod was created or destroyed during the cutover** - that is
why rollback is instant and total, and why blue-green is the strategy of choice when a bad release
must be undone in seconds. The cost is running 2× the infrastructure for the whole window.

### 8. Canary - measuring the real traffic split

9 stable pods + 1 canary, both sharing the label the Service selects on:

```console
--- pod split by version ---
   9 v1
   1 v2
--- service selects on the COMMON label only ---
selector={"app":"myapp-canary"}
total endpoints: 10
```

Then 200 requests through the Service from inside the cluster:

```console
     16 CANARY v2
    184 STABLE v1
```

**8% canary against the 10% the replica ratio predicts.** kube-proxy picks a backend at random per
connection, so with n=200 that spread is exactly what you would expect (±2pp is well within
sampling noise at this sample size).

Which is also the honest limitation: **the traffic split is controlled only by the replica ratio.**
Want 1%? You need 99 stable pods. Want to route by user ID, header, or cookie? A plain Service
cannot do it - that needs an ingress controller with canary annotations, or a service mesh.

### Strategy comparison

| | Downtime | Extra capacity | Rollback speed | Both versions live? |
|---|---|---|---|---|
| **RollingUpdate** | none | +`maxSurge` | minutes (roll forward) | yes, briefly |
| **Recreate** | **yes, full** | none | slow (full redeploy) | never |
| **Blue-green** | none | **2×** | instant (one patch) | yes, but only one serves |
| **Canary** | none | +canary | instant (delete canary) | yes, deliberately |

---

## Task 9: Troubleshooting

### Broken image

```console
NAME                             READY   STATUS             RESTARTS   AGE
yatri-backend-77dbb657cd-brzf9   0/1     ImagePullBackOff   0          42s
yatri-backend-77dbb657cd-c6xr9   0/1     ErrImagePull       0          42s
yatri-backend-77dbb657cd-jhmkk   0/1     ErrImagePull       0          42s

  Warning  Failed  kubelet  Failed to pull image "yatri-backend:non-existent-tag-v999": ... pull access denied, repository does not exist or may require authorization

--- the deployment never becomes available ---
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
yatri-backend   0/3     3            0           42s
```

`UP-TO-DATE 3` but `AVAILABLE 0`. The Deployment controller did its job - it created the ReplicaSet
and the three pods. The failure is entirely below it, at the kubelet. Reading those three columns
separately tells you which layer to go look at.

### Selector mismatch - caught before anything is created

```console
$ kubectl apply -f selector-mismatch.yaml
The Deployment "selector-error-demo" is invalid: spec.template.metadata.labels: Invalid value:
{"app":"wrong-app-name"}: `selector` does not match template `labels`
exit code: 1

$ kubectl get deploy selector-error-demo
Error from server (NotFound): deployments.apps "selector-error-demo" not found
```

This one never reaches the cluster at all - the **API server** rejects it during validation, so
nothing is created and the exit code is non-zero (which is what makes it safe to gate CI on
`kubectl apply --dry-run=server`).

Worth contrasting with the Session 11 empty-endpoints drill: a *Service* with a selector matching
nothing is perfectly valid and gets created happily, failing silently at runtime instead. Deployment
selectors are validated; Service selectors are not.

Also note `spec.selector` is **immutable** on a Deployment - you cannot fix a wrong selector with
`kubectl apply`, you have to delete and recreate.

---

## Cleanup

```bash
kubectl delete -f pod-lifecycle/
kubectl delete -f 01-rolling-update/ -f 02-blue-green/ -f 03-canary/ -f 04-recreate/
kubectl delete -f homework/10-k8s-core-objects/manifests/statefulset-arm64.yaml
kubectl delete pvc --all
```

```console
$ kubectl get all -n default
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   2d6h
```

Note PVCs need deleting **explicitly** - `kubectl delete statefulset` deliberately leaves them
behind so you do not lose a database by deleting a workload.

---

## What I took away

**The STATUS column is a summary, not the diagnosis.** Four of the twelve lifecycle pods showed a
STATUS that is not even a real pod phase. Pending, ImagePullBackOff and CrashLoopBackOff all mean
"not working" but they fail at three different layers - scheduler, image pull, and application - and
`kubectl describe`'s Events block, specifically its `From` column, is what tells you which.

**Controllers stack, and each layer adds exactly one thing.** ReplicaSet adds a replica count to
bare Pods. Deployment adds revisions to ReplicaSets - and `rollout history` failing outright on a
ReplicaSet is the cleanest possible demonstration of where that boundary sits.

**Ordering is a feature you opt into.** A Deployment starts everything at once; a StatefulSet
refuses to start pod *n+1* until pod *n* is Ready. The arm64 image failure made that visible by
accident - one broken pod blocked the other two entirely.

**Every deployment strategy is trading downtime against capacity against blast radius.** Recreate
is cheap and has an outage I measured at t+02s. Blue-green has no outage and instant rollback but
costs 2× the fleet. Canary limits blast radius to the replica ratio - and *only* the replica ratio,
which is a real ceiling on how fine-grained it can get.

**Validation happens at very different times.** A Deployment with a mismatched selector is rejected
by the API server before anything exists. A Service with a selector matching nothing is accepted
without complaint and fails silently in production. Knowing which failures are caught at apply-time
is what decides how much a `--dry-run=server` check in CI is actually worth.
