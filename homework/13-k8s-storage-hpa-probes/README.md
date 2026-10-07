# Kubernetes Storage, HPA & Probes: Homework (Session 13)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> Manifests: [`session-13-storage-hpa-probes/`](../../session-13-storage-hpa-probes/)

---

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | `emptyDir` - survives a container restart, dies with the pod | ✅ |
| 2 | `hostPath` - survives pod deletion, lives on the node | ✅ |
| 3 | Static PV + PVC - and why the given PVC never bound to the given PV | ✅ |
| 4 | `Retain` reclaim policy - data outlives the claim | ✅ |
| 5 | StorageClass - dynamic provisioning | ✅ |
| 6 | Liveness, readiness and startup probes - and breaking two of them | ✅ |
| 7 | Mini project: PVC + probes + HPA in `production-webapp` | ✅ |
| 8 | HPA load test at 50% (did **not** scale - and why) | ✅ |
| 9 | Bonus challenge 1: HPA at 30% - scale out 2 → 3, then back to 2 | ✅ |

**Environment:** minikube v1.39.0 (docker driver, containerd), Kubernetes v1.37.0, single node, macOS arm64, `metrics-server` addon enabled.

---

## 1. `emptyDir`

```console
$ kubectl apply -f 01-volumes/emptydir-pod.yaml
pod/emptydir-demo created

$ kubectl exec emptydir-demo -- sh -c 'echo "written at $(date -u +%H:%M:%S) by Talin" > /data/message.txt && cat /data/message.txt'
written at 12:08:48 by Talin
```

First I killed only the **container** (stopping nginx makes PID 1 exit, kubelet restarts it in the same pod):

```console
$ kubectl exec emptydir-demo -- sh -c 'nginx -s stop'
2026/10/07 12:08:48 [notice] 52#52: signal process started

$ kubectl get pod emptydir-demo
NAME            READY   STATUS    RESTARTS     AGE
emptydir-demo   1/1     Running   1 (8s ago)   9s

$ kubectl exec emptydir-demo -- cat /data/message.txt
written at 12:08:48 by Talin
```

`RESTARTS 1` and the file is still there. Then I deleted the **pod**:

```console
$ kubectl delete pod emptydir-demo
pod "emptydir-demo" deleted from default namespace

$ kubectl apply -f 01-volumes/emptydir-pod.yaml
pod/emptydir-demo created

$ kubectl exec emptydir-demo -- cat /data/message.txt
cat: /data/message.txt: No such file or directory
command terminated with exit code 1

$ kubectl exec emptydir-demo -- ls -la /data
total 8
drwxrwxrwx 2 root root 4096 Oct  7 12:08 .
drwxr-xr-x 1 root root 4096 Oct  7 12:08 ..
```

**An `emptyDir` lives exactly as long as the pod, not the container.** That makes it right for
scratch space and for sharing files between containers in one pod, and wrong for anything you want
to keep.

## 2. `hostPath`

```console
$ kubectl exec hostpath-demo -- sh -c 'echo hello-from-pod > /data/host.txt'

$ minikube ssh -- cat /tmp/hostpath-data/host.txt
hello-from-pod

$ kubectl delete pod hostpath-demo
pod "hostpath-demo" deleted from default namespace

$ kubectl apply -f 01-volumes/hostpath-pod.yaml
pod/hostpath-demo created

$ kubectl exec hostpath-demo -- cat /data/host.txt
hello-from-pod
```

The file is on the **node's** disk (`minikube ssh` reads it directly), so it survived. The catch is
that it only survives *on that node*. On a multi-node cluster a rescheduled pod can land somewhere
the file does not exist. It also lets a pod write into the host filesystem, so it is a security
concern as well as a portability one.

---

## 3. Static PV + PVC - the binding surprise

I applied `pv.yaml` (1Gi, no `storageClassName`) and `pvc.yaml` (500Mi, no `storageClassName`)
exactly as given, expecting the claim to bind to `student-pv`:

```console
$ kubectl apply -f 02-persistent-storage/pv.yaml
persistentvolume/student-pv created

$ kubectl apply -f 02-persistent-storage/pvc.yaml
persistentvolumeclaim/student-pvc created

$ kubectl get pv,pvc
NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                 STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/pvc-02f5ff83-5789-496e-944a-278660485dff   500Mi      RWO            Delete           Bound       default/student-pvc   standard       <unset>                          4s
persistentvolume/student-pv                                 1Gi        RWO            Retain           Available                                        <unset>                          4s

NAME                                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/student-pvc   Bound    pvc-02f5ff83-5789-496e-944a-278660485dff   500Mi      RWO            standard       <unset>                 4s
```

(Two older `Released` PVs from an earlier attempt also showed in this listing; I removed them
from the output above. Everything else is verbatim.)

The claim is `Bound`, but **not to `student-pv`**, which is still `Available`. A brand-new
`pvc-02f5…` volume was created instead. The reason:

```console
$ kubectl get pvc student-pvc -o jsonpath='storageClassName={.spec.storageClassName}{"\n"}'
storageClassName=standard
```

I never wrote `standard` in the claim. Because minikube has a **default StorageClass**, the
admission controller filled it in. A claim with class `standard` can only bind to a PV with class
`standard`, and `student-pv` has none. So the provisioner made a new one.

**Fix:** `storageClassName: ""` (an explicit empty string, not just leaving it out) opts out of the
default class:

```console
$ cat <<'Y' | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: student-pvc
spec:
  storageClassName: ""
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
Y
persistentvolumeclaim/student-pvc created

$ kubectl get pv,pvc
NAME                          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
persistentvolume/student-pv   1Gi        RWO            Retain           Bound    default/student-pvc                  <unset>                          9s

NAME                                STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/student-pvc   Bound    student-pv   1Gi        RWO                           <unset>                 3s
```

Now it binds to `student-pv`. Note the claim asked for **500Mi** and got **1Gi**: binding picks a
PV that is *at least* as big, and the whole PV goes to that one claim.

### Data survives pod deletion

```console
$ kubectl exec storage-demo -- sh -c 'echo "Student: Talin Daga" > /data/message.txt; cat /data/message.txt'
Student: Talin Daga

$ kubectl delete pod storage-demo
pod "storage-demo" deleted from default namespace

$ kubectl apply -f 02-persistent-storage/pod.yaml
pod/storage-demo created

$ kubectl exec storage-demo -- cat /data/message.txt
Student: Talin Daga

$ minikube ssh -- cat /tmp/student-data/message.txt
Student: Talin Daga
```

## 4. `Retain` reclaim policy

```console
$ kubectl delete pod storage-demo
pod "storage-demo" deleted from default namespace

$ kubectl delete pvc student-pvc
persistentvolumeclaim "student-pvc" deleted from default namespace

$ kubectl get pv student-pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM                 STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
student-pv   1Gi        RWO            Retain           Released   default/student-pvc                  <unset>                          17s

$ minikube ssh -- cat /tmp/student-data/message.txt
Student: Talin Daga
```

The claim is gone and the data is still on disk. The PV goes to `Released`, **not** `Available`. It
still remembers its old claim (`default/student-pvc`), so a new claim will not bind to it until an
admin clears `spec.claimRef` by hand. That is on purpose: Kubernetes will not hand someone else's
data to a new claim automatically.

## 5. StorageClass - dynamic provisioning

```console
$ kubectl get storageclass
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  21d

$ kubectl apply -f 03-storageclass/pvc.yaml
persistentvolumeclaim/dynamic-pvc created

$ kubectl get pvc dynamic-pvc
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
dynamic-pvc   Bound    pvc-d3fdf2c3-d63c-439d-85d7-fcf8e2dce664   500Mi      RWO            standard       <unset>                 4s

$ kubectl get pv $(kubectl get pvc dynamic-pvc -o jsonpath='{.spec.volumeName}') -o jsonpath='{.spec.hostPath.path}{"\n"}'
/tmp/hostpath-provisioner/default/dynamic-pvc

$ kubectl delete pvc dynamic-pvc
persistentvolumeclaim "dynamic-pvc" deleted from default namespace
```

No PV was written by hand. The claim alone caused one to be created, sized exactly 500Mi this time
(compare the static case, which got 1Gi). After the claim was deleted, the `pvc-d3fd…` volume
disappeared from `kubectl get pv`, because the class's reclaim policy is `Delete`.

---

## 6. Probes

```console
$ kubectl apply -f 05-probes/liveness.yaml -f 05-probes/readiness.yaml -f 05-probes/startup.yaml
pod/liveness-demo created
pod/readiness-demo created
pod/startup-demo created

$ kubectl get pods liveness-demo readiness-demo startup-demo
NAME             READY   STATUS    RESTARTS   AGE
liveness-demo    1/1     Running   0          6s
readiness-demo   1/1     Running   0          6s
startup-demo     1/1     Running   0          6s

$ kubectl describe pod startup-demo | grep -E 'Liveness|Readiness|Startup'
    Liveness:       http-get http://:80/ delay=0s timeout=1s period=5s successThreshold=1 failureThreshold=3
    Readiness:      http-get http://:80/ delay=0s timeout=1s period=5s successThreshold=1 failureThreshold=3
    Startup:        http-get http://:80/ delay=0s timeout=1s period=2s successThreshold=1 failureThreshold=30
```

The startup probe gives the app up to `30 × 2s = 60s` to come up. Liveness and readiness do not run
at all until it passes, so a slow-starting app is not killed for being slow.

### Breaking readiness - the pod leaves the Service, but is not restarted

Instead of editing YAML I broke the running app: deleting `index.html` makes `GET /` fail.

```console
$ kubectl expose pod readiness-demo --name=readiness-service --port=80
service/readiness-service exposed

$ kubectl get endpoints readiness-service
NAME                ENDPOINTS        AGE
readiness-service   10.244.0.13:80   2s

$ kubectl exec readiness-demo -- rm /usr/share/nginx/html/index.html

$ kubectl get pod readiness-demo
NAME             READY   STATUS    RESTARTS   AGE
readiness-demo   0/1     Running   0          22s

$ kubectl get endpoints readiness-service
NAME                ENDPOINTS   AGE
readiness-service               16s

$ kubectl describe pod readiness-demo | sed -n '/Events:/,$p'
  ...
  Warning  Unhealthy  1s (x4 over 11s)  kubelet            spec.containers{nginx}: Readiness probe failed: HTTP probe failed with statuscode: 403
```

`Running` but `0/1`, `RESTARTS 0`, and the endpoint list is **empty**. Note it is a **403, not
a 404**. With no index file, nginx treats `/` as a directory listing request, and directory listing
is off. Putting the file back:

```console
$ kubectl exec readiness-demo -- sh -c 'echo back > /usr/share/nginx/html/index.html'

$ kubectl get pod readiness-demo
NAME             READY   STATUS    RESTARTS   AGE
readiness-demo   1/1     Running   0          30s

$ kubectl get endpoints readiness-service
NAME                ENDPOINTS        AGE
readiness-service   10.244.0.13:80   24s
```

Traffic comes back on its own, with no restart.

### Breaking liveness - the container is restarted, and that fixes it

```console
$ kubectl exec liveness-demo -- rm /usr/share/nginx/html/index.html

$ kubectl get pod liveness-demo
NAME            READY   STATUS    RESTARTS      AGE
liveness-demo   1/1     Running   1 (11s ago)   56s

$ kubectl describe pod liveness-demo | sed -n '/Events:/,$p'
  ...
  Warning  Unhealthy  11s (x3 over 21s)  kubelet            spec.containers{nginx}: Liveness probe failed: HTTP probe failed with statuscode: 403
  Normal   Killing    11s                kubelet            spec.containers{nginx}: Container nginx failed liveness probe, will be restarted

$ kubectl exec liveness-demo -- ls /usr/share/nginx/html/
50x.html
index.html
```

Three failures (`failureThreshold: 3`), then kubelet killed and restarted the container. And
`index.html` is **back**: the new container got a fresh copy of the image's filesystem, so the
damage I did was wiped. That is exactly the case liveness is for: a process in a bad state that a
clean restart fixes. Same failure, two probes, opposite reactions:

| Probe | What it did when `/` returned 403 |
|---|---|
| Readiness | Pulled the pod out of the Service. No restart. Recovered when the app recovered. |
| Liveness | Killed and restarted the container. Recovered *because* of the restart. |

---

## 7. Mini project: PVC + probes + HPA

```console
$ kubectl apply -f namespace.yaml -f pvc.yaml -f deployment.yaml -f service.yaml -f hpa.yaml
namespace/production-webapp created
persistentvolumeclaim/web-data created
deployment.apps/web-app created
service/web-service created
horizontalpodautoscaler.autoscaling/web-app-hpa created

$ kubectl get pvc,pods,svc -n production-webapp -o wide
NAME                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE   VOLUMEMODE
persistentvolumeclaim/web-data   Bound    pvc-b164f637-fa1c-4b93-bab9-48feec25b9c3   500Mi      RWO            standard       <unset>                 9s    Filesystem

NAME                          READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
pod/web-app-d45775485-rkcpk   1/1     Running   0          9s    10.244.0.15   minikube   <none>           <none>
pod/web-app-d45775485-xvlth   1/1     Running   0          9s    10.244.0.16   minikube   <none>           <none>

NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/web-service   ClusterIP   10.103.246.237   <none>        80/TCP    9s    app=web-app

$ kubectl get hpa -n production-webapp
NAME          REFERENCE            TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
web-app-hpa   Deployment/web-app   cpu: <unknown>/50%   2         5         2          54s

$ kubectl top pods -n production-webapp
NAME                      CPU(cores)   MEMORY(bytes)
web-app-d45775485-rkcpk   2m           8Mi
web-app-d45775485-xvlth   2m           8Mi
```

`<unknown>` for the first minute is normal. metrics-server needs a scrape or two before the HPA
has a number (it changes to `1%` in the load-test log below).

### Task 1: storage persistence

```console
$ POD_NAME=$(kubectl get pods -n production-webapp -l app=web-app -o jsonpath='{.items[0].metadata.name}'); echo $POD_NAME; kubectl exec -n production-webapp $POD_NAME -- sh -c 'echo "Student: Talin Daga (24BCS10321)" > /data/student.txt'; kubectl exec -n production-webapp $POD_NAME -- cat /data/student.txt; kubectl delete pod -n production-webapp $POD_NAME
web-app-d45775485-rkcpk
Student: Talin Daga (24BCS10321)
pod "web-app-d45775485-rkcpk" deleted from production-webapp namespace

$ kubectl get pods -n production-webapp
NAME                      READY   STATUS    RESTARTS   AGE
web-app-d45775485-pk9b4   1/1     Running   0          9s
web-app-d45775485-xvlth   1/1     Running   0          64s

$ for p in $(kubectl get pods -n production-webapp -l app=web-app -o name); do echo "$p: $(kubectl exec -n production-webapp $p -- cat /data/student.txt)"; done
pod/web-app-d45775485-pk9b4: Student: Talin Daga (24BCS10321)
pod/web-app-d45775485-xvlth: Student: Talin Daga (24BCS10321)
```

The replacement pod `pk9b4` sees the file. So does the *other* replica `xvlth`, even though the
claim is `ReadWriteOnce`. **RWO means one *node*, not one pod.** On single-node minikube every
replica shares the volume. On a real multi-node cluster, a second replica scheduled elsewhere would
be stuck waiting to attach it. That is also why this Deployment uses `strategy: Recreate`: a
rolling update would briefly need old and new pods attached at once.

### Task 2: service

```console
$ kubectl port-forward -n production-webapp svc/web-service 8080:80 &
$ curl -s http://localhost:8080 | head -5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
```

---

## 8. Task 3: HPA load test at 50% - it did not scale

```console
$ kubectl run load-generator -n production-webapp --image=busybox:1.36 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://web-service >/dev/null; done"
pod/load-generator created

$ kubectl get hpa -n production-webapp -w   (sampled every 15s, with timestamps)
17:42:33  web-app-hpa   Deployment/web-app   cpu: <unknown>/50%   2     5     2     75s
17:42:48  web-app-hpa   Deployment/web-app   cpu: 1%/50%   2     5     2     90s
17:43:34  web-app-hpa   Deployment/web-app   cpu: 1%/50%   2     5     2     2m16s
17:43:49  web-app-hpa   Deployment/web-app   cpu: 40%/50%   2     5     2     2m31s
17:44:50  web-app-hpa   Deployment/web-app   cpu: 43%/50%   2     5     2     3m32s
17:46:06  web-app-hpa   Deployment/web-app   cpu: 43%/50%   2     5     2     4m48s
17:46:51  web-app-hpa   Deployment/web-app   cpu: 43%/50%   2     5     2     5m33s

$ kubectl top pods -n production-webapp
NAME                      CPU(cores)   MEMORY(bytes)
load-generator            796m         10Mi
web-app-d45775485-pk9b4   43m          8Mi
web-app-d45775485-xvlth   43m          8Mi
```

(18 samples were taken; repeated identical lines are trimmed.)

The README promised `110%` and a scale-out. I got a flat **43%**, so the HPA correctly did nothing.
`kubectl top` shows why: **the load generator is the bottleneck, not nginx.** One single-threaded
`wget` loop is burning 796m of CPU just to produce requests, and nginx serving a static page needs
only 43m (43% of its 100m request) to keep up. Utilization is measured against the **request**, so
43m / 100m = 43%, which is under the 50% target.

The lesson is about load testing, not about the HPA: if your client is weaker than your server, you
are measuring the client.

## 9. Bonus challenge 1: lower the target to 30%

```console
$ kubectl patch hpa web-app-hpa -n production-webapp --type=json -p='[{"op":"replace","path":"/spec/metrics/0/resource/target/averageUtilization","value":30}]'
horizontalpodautoscaler.autoscaling/web-app-hpa patched

$ kubectl get hpa -n production-webapp -w   (sampled every 15s)
17:57:38  web-app-hpa   Deployment/web-app   cpu: 1%/30%   2     5     2     16m
17:57:53  web-app-hpa   Deployment/web-app   cpu: 40%/30%   2     5     2     16m
17:58:08  web-app-hpa   Deployment/web-app   cpu: 40%/30%   2     5     3     16m
17:58:54  web-app-hpa   Deployment/web-app   cpu: 35%/30%   2     5     3     17m
17:59:55  web-app-hpa   Deployment/web-app   cpu: 29%/30%   2     5     3     18m
18:00:25  web-app-hpa   Deployment/web-app   cpu: 29%/30%   2     5     3     19m

$ kubectl top pods -n production-webapp
NAME                      CPU(cores)   MEMORY(bytes)
load-generator            795m         8Mi
web-app-d45775485-mhzgh   29m          8Mi
web-app-d45775485-pk9b4   29m          8Mi
web-app-d45775485-xvlth   29m          8Mi

$ kubectl describe hpa web-app-hpa -n production-webapp | sed -n '/Events:/,$p' | grep -v Failed
  Normal   SuccessfulRescale             2m51s              horizontal-pod-autoscaler  New size: 3; reason: cpu resource utilization (percentage of request) above target
```

The arithmetic matches the HPA formula exactly:

```text
desired = ceil( current × currentUtilization / target )
        = ceil( 2 × 40 / 30 ) = ceil(2.67) = 3
```

And the per-pod numbers show the **same total work spread thinner**: before, 2 × 43m = 86m;
after, 3 × 29m = 87m. The third pod did not add throughput, because the generator was still the
limit. It split the same load three ways until the average (29%) dropped under target (30%), and
then it stopped.

### Scale-down and the stabilization window

```console
$ kubectl delete pod load-generator -n production-webapp
pod "load-generator" deleted from production-webapp namespace

$ kubectl get hpa -n production-webapp -w   (sampled every 30s after load stopped)
18:01:11  web-app-hpa   Deployment/web-app   cpu: 29%/30%   2     5     3     19m
18:02:11  web-app-hpa   Deployment/web-app   cpu: 18%/30%   2     5     3     20m
18:03:12  web-app-hpa   Deployment/web-app   cpu: 1%/30%   2     5     3     21m
18:04:12  web-app-hpa   Deployment/web-app   cpu: 1%/30%   2     5     3     22m
18:05:12  web-app-hpa   Deployment/web-app   cpu: 1%/30%   2     5     3     23m
18:06:13  web-app-hpa   Deployment/web-app   cpu: 1%/30%   2     5     3     24m
18:06:43  web-app-hpa   Deployment/web-app   cpu: 1%/30%   2     5     3     25m
18:07:13  web-app-hpa   Deployment/web-app   cpu: 1%/30%   2     5     2     25m

$ kubectl describe hpa web-app-hpa -n production-webapp | sed -n '/Events:/,$p' | grep -v Failed
  Normal   SuccessfulRescale             10m                horizontal-pod-autoscaler  New size: 3; reason: cpu resource utilization (percentage of request) above target
  Normal   SuccessfulRescale             99s                horizontal-pod-autoscaler  New size: 2; reason: All metrics below target
```

CPU hit 1% at 18:03, but the scale-down only happened at ~18:07. That 5-minute delay is the
default `scaleDown.stabilizationWindowSeconds: 300`: the HPA uses the *highest* recommendation
from the last 5 minutes, so a short dip in traffic cannot make it drop pods it will need again a
minute later. Scale-up has no such window, which is why 2 → 3 happened 15 seconds after the load
arrived.

---

## Cleanup

```bash
kubectl delete namespace production-webapp
kubectl delete pod emptydir-demo hostpath-demo liveness-demo readiness-demo startup-demo storage-demo --ignore-not-found
kubectl delete svc readiness-service --ignore-not-found
```

---

## What I took away

**The default StorageClass silently rewrites your PVC.** Leaving `storageClassName` out does not
mean "no class". It means "the default class", and that one change decides whether you get your
hand-built PV or a brand-new dynamic one. `storageClassName: ""` is the only way to say "none".

**`Running` is not "healthy", and the two probes disagree on purpose.** The same 403 made
readiness quietly remove the pod from traffic and made liveness restart it. Choosing which probe
to point at which endpoint is a decision about which of those reactions you want.

**RWO is per node.** Two replicas writing to one "ReadWriteOnce" volume looked like a bug until I
remembered minikube has only one node.

**My first load test measured the load generator.** The HPA was right not to scale at 43%. Getting
it to move meant changing the target, and even then `kubectl top` showed it just spread a fixed
load across more pods: 86m total before and 87m after.
