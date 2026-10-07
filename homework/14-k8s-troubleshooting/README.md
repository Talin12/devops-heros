# Kubernetes Troubleshooting: Homework (Session 14)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> Broken manifests: [`session-14-kubernetes-troubleshooting/`](../../session-14-kubernetes-troubleshooting/) · My fixes: [`fixes/`](fixes/)

**Environment:** minikube v1.39.0, Kubernetes v1.37.0, namespace `s14`.

---

## 1. Mini project: deploy and check the healthy app

```console
$ kubectl get pods -o wide
NAME                                   READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
troubleshooting-app-59d4957864-b4vxq   1/1     Running   0          0s    10.244.0.22   minikube   <none>           <none>
troubleshooting-app-59d4957864-lsd99   1/1     Running   0          0s    10.244.0.21   minikube   <none>           <none>

$ kubectl exec $P -- curl -s -o /dev/null -w 'curl localhost -> HTTP %{http_code}\n' localhost
curl localhost -> HTTP 200

$ kubectl describe service troubleshooting-service | grep -E 'Selector|TargetPort|Endpoints'
Selector:                 app=troubleshooting-app
TargetPort:               80/TCP
Endpoints:                10.244.0.22:80,10.244.0.21:80
```

## 2. Broken pod (image problem)

```console
$ kubectl get pod project-broken-pod
NAME                 READY   STATUS             RESTARTS   AGE
project-broken-pod   0/1     ImagePullBackOff   0          20s

$ kubectl describe pod project-broken-pod
...
    Image:          nginx:this-tag-does-not-exist
    State:          Waiting
      Reason:       ImagePullBackOff
Events:
  Warning  Failed     3s (x2 over 19s)  kubelet  Failed to pull image "nginx:this-tag-does-not-exist": rpc error: code = NotFound desc = failed to pull and unpack image "docker.io/library/nginx:this-tag-does-not-exist": failed to resolve reference "docker.io/library/nginx:this-tag-does-not-exist": docker.io/library/nginx:this-tag-does-not-exist: not found

$ kubectl logs project-broken-pod
Error from server (BadRequest): container "app" in pod "project-broken-pod" is waiting to start: trying and failing to pull image
```

`kubectl logs` is useless here: the container never started, so there are no logs. The answer
is only in `describe` → Events.

| Question | Answer |
|---|---|
| 1. Pod status? | `ImagePullBackOff` (it alternates with `ErrImagePull` while retrying) |
| 2. Actual error? | `NotFound` - `docker.io/library/nginx:this-tag-does-not-exist: not found` |
| 3. Command that found it? | `kubectl describe pod project-broken-pod` (Events section) |
| 4. What is wrong with the image? | The repository `nginx` exists, the **tag** does not |
| 5. Fix? | Use a real tag (`nginx:1.27`) and re-create the pod. A pod's image can't be changed in place |

```console
$ kubectl delete pod project-broken-pod; sed 's/nginx:this-tag-does-not-exist/nginx:1.27/' broken-pod.yaml | kubectl apply -f -
pod "project-broken-pod" deleted from s14 namespace
pod/project-broken-pod created

$ kubectl get pod project-broken-pod
NAME                 READY   STATUS    RESTARTS   AGE
project-broken-pod   1/1     Running   0          1s
```

## 3. Service selector problem

```console
$ kubectl exec client -- curl -s -m 4 -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service
HTTP 200

$ kubectl patch service troubleshooting-service -p '{"spec":{"selector":{"app":"wrong-app"}}}'
service/troubleshooting-service patched

$ kubectl get endpoints troubleshooting-service
NAME                      ENDPOINTS   AGE
troubleshooting-service   <none>      22s

$ kubectl exec client -- curl -s -m 4 -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service; echo "curl exit code: $?"
HTTP 000
command terminated with exit code 7
curl exit code: 7

$ kubectl exec client -- nslookup troubleshooting-service | grep -A1 Name
Name:	troubleshooting-service.s14.svc.cluster.local
Address: 10.109.178.36

$ kubectl get pods --show-labels
NAME                                   READY   STATUS    RESTARTS   AGE   LABELS
troubleshooting-app-59d4957864-b4vxq   1/1     Running   0          30s   app=troubleshooting-app,pod-template-hash=59d4957864
troubleshooting-app-59d4957864-lsd99   1/1     Running   0          30s   app=troubleshooting-app,pod-template-hash=59d4957864

$ kubectl describe service troubleshooting-service | grep -E 'Selector|Endpoints'
Selector:                 app=wrong-app
Endpoints:
```

DNS still resolves and the Service still has its IP. Only the endpoints are empty, so curl fails
with exit 7 (connection refused). Labels say `app=troubleshooting-app` and the selector says
`app=wrong-app`. Re-applying the original `service.yaml`:

```console
$ kubectl apply -f service.yaml
service/troubleshooting-service configured

$ kubectl get endpoints troubleshooting-service
NAME                      ENDPOINTS                       AGE
troubleshooting-service   10.244.0.21:80,10.244.0.22:80   32s

$ kubectl exec client -- curl -s -m 4 -o /dev/null -w 'HTTP %{http_code}\n' http://troubleshooting-service
HTTP 200
```

### Troubleshooting table

| Problem | What I Saw | Command I Used | Root Cause | Fix |
|---|---|---|---|---|
| **Broken Pod** | `0/1 ImagePullBackOff` | `kubectl describe pod` | Image could not be pulled | Re-create with a valid image |
| **Service Problem** | `ENDPOINTS <none>`, curl exit 7 | `kubectl get endpoints`, `get pods --show-labels` | Selector `app=wrong-app` matches no pod labels | Selector back to `app=troubleshooting-app` |
| **Image Problem** | `nginx:this-tag-does-not-exist: not found` | `kubectl describe pod` → Events | Tag does not exist in the registry | Pin a real tag, `nginx:1.27` |

---

## 4. Triage gauntlet: 5 broken pods

```console
$ ./triage_all.sh
...
=== CURRENT CLUSTER CARNAGE ===
NAME                     READY   STATUS         RESTARTS     AGE
fail-1-crashloop-pod     0/1     Error          1 (4s ago)   5s
fail-2-imagepull-pod     0/1     ErrImagePull   0            5s
fail-3-pending-pod       0/1     Pending        0            5s
fail-4-dns-failure-pod   1/1     Running        0            5s
fail-5-oomkilled-pod     0/1     OOMKilled      1 (4s ago)   5s
```

### Diagnosis

**1 - CrashLoop:** `logs` gives the answer straight away.
```console
$ kubectl logs fail-1-crashloop-pod
[FATAL ERROR]: DATABASE_URL environment variable is MISSING!
```

**2 - ImagePull:** the image doesn't exist at all.
```console
  Warning  Failed  1s (x3 over 44s)  kubelet  Failed to pull image "yatri-api-service:v999-invalid-tag-does-not-exist": ... pull access denied, repository does not exist or may require authorization
```

**3 - Pending:** no IP, no node, so nothing ran. Only the scheduler event explains it.
```console
$ kubectl describe pod fail-3-pending-pod | sed -n '/Events:/,$p'
  Warning  FailedScheduling  46s   default-scheduler  0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory. preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

$ kubectl describe node minikube | sed -n '/Allocatable:/,/pods:/p'
Allocatable:
  cpu:                10
  memory:             8025424Ki
```
It asks for 500 CPUs and 1000Gi of memory. The node has 10 CPUs and about 7.6Gi.

**4 - DNS:** the sneaky one. It says `1/1 Running`, and its logs show nothing wrong:
```console
$ kubectl logs fail-4-dns-failure-pod
Attempting connection to internal database...
Process sleeping...

$ kubectl exec fail-4-dns-failure-pod -- curl -sS --connect-timeout 3 http://postgres-db-wrong-name.production.svc.cluster.local:5432; echo "curl exit: $?"
curl: (6) Could not resolve host: postgres-db-wrong-name.production.svc.cluster.local
command terminated with exit code 6

$ kubectl get svc -A | grep -i -E 'postgres|NAME'
NAMESPACE           NAME                                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE
```
The script runs `curl -s ... || true`. `-s` hides the error and `|| true` hides the exit code, so
the failure is invisible to `get` and to `logs`. Running the same call without `-s` (or with
`-sS`) shows it can't resolve the name. And no postgres Service exists anywhere in the cluster.

**5 - OOMKilled:**
```console
$ kubectl describe pod fail-5-oomkilled-pod | grep -E -A5 'Last State'
    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137
```
Exit 137 = 128 + 9 (SIGKILL from the kernel OOM killer). The comment in the YAML says it
allocates "200MB", but the loop is `range(100)` × 10 MiB = **1000 MiB**, against a 20Mi limit.

### Fixes, and one fix that was not a fix

**Scenario 1, first attempt:** only add `DATABASE_URL` ([`1a-crashloop-env-only.yaml`](fixes/1a-crashloop-env-only.yaml)):

```console
$ kubectl get pod fail-1-crashloop-pod
NAME                   READY   STATUS      RESTARTS      AGE
fail-1-crashloop-pod   0/1     Completed   3 (26s ago)   41s

$ kubectl logs fail-1-crashloop-pod
Application started successfully!

$ kubectl describe pod fail-1-crashloop-pod | grep -E -A3 '^    (State|Last State)'
    State:          Terminated
      Reason:       Completed
      Exit Code:    0
```

The error is gone and it **still restarts**. The script prints and exits 0, and a pod's default
`restartPolicy: Always` restarts even a successful exit, so it would end up in `CrashLoopBackOff`
with exit code 0. The real fix ([`1b-crashloop-fixed.yaml`](fixes/1b-crashloop-fixed.yaml))
supplies the env var from a ConfigMap **and** keeps the process running like a real server.

All five fixed manifests applied:

```console
$ kubectl apply -f 1b-crashloop-fixed.yaml -f 2-imagepull-fixed.yaml -f 3-pending-fixed.yaml -f 4-dns-fixed.yaml -f 5-oomkilled-fixed.yaml
configmap/app-config created
pod/fail-1-crashloop-pod created
pod/fail-2-imagepull-pod created
pod/fail-3-pending-pod created
namespace/production created
deployment.apps/postgres-db created
service/postgres-db created
pod/fail-4-dns-failure-pod created
pod/fail-5-oomkilled-pod created

$ kubectl logs fail-5-oomkilled-pod
Allocating 100 MiB...
Done. Peak RSS: 107 MiB

$ kubectl get pod fail-5-oomkilled-pod -o jsonpath='{.status.containerStatuses[0].state.terminated.reason} exit={.status.containerStatuses[0].state.terminated.exitCode} restarts={.status.containerStatuses[0].restartCount}{"\n"}'
Completed exit=0 restarts=0
```

Scenario 4 failed once more for a different reason: the client started while `postgres:16-alpine`
was still being pulled, so `nc` found nothing listening, exited 1 and went into backoff. Once
Postgres was Ready, I re-created the client:

```console
$ kubectl get pods,svc,endpoints -n production
NAME                              READY   STATUS    RESTARTS   AGE
pod/postgres-db-b9d94d958-zlbt7   1/1     Running   0          2m30s

NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/postgres-db   ClusterIP   10.111.218.96   <none>        5432/TCP   2m30s

NAME                    ENDPOINTS          AGE
endpoints/postgres-db   10.244.0.38:5432   2m30s

$ kubectl logs fail-4-dns-failure-pod
Attempting connection to internal database...
postgres-db.production.svc.cluster.local (10.111.218.96:5432) open
Process sleeping...

$ kubectl get pods -l tier=triage-gauntlet
NAME                     READY   STATUS      RESTARTS   AGE
fail-1-crashloop-pod     1/1     Running     0          2m40s
fail-2-imagepull-pod     1/1     Running     0          2m40s
fail-3-pending-pod       1/1     Running     0          2m40s
fail-4-dns-failure-pod   1/1     Running     0          9s
fail-5-oomkilled-pod     0/1     Completed   0          2m40s
```

`fail-5` is meant to show `Completed`: it is a one-shot job, now with `restartPolicy: OnFailure`.

| # | Root cause | Fix |
|---|---|---|
| 1 | Missing `DATABASE_URL`; also exits 0 under `restartPolicy: Always` | Env from ConfigMap + long-running process |
| 2 | Image repo/tag does not exist | `nginx:1.27-alpine` |
| 3 | Requests 500 CPU / 1000Gi | `100m` / `64Mi` requests, with limits |
| 4 | Wrong hostname, no such Service, error hidden by `-s` and `|| true` | Create `postgres-db` in `production`, use the right name, let failure exit 1 |
| 5 | Allocates 1000 MiB under a 20Mi limit | Allocate what is needed (100 MiB), limit 192Mi, `restartPolicy: OnFailure` |

---

## README questions

1. **`kubectl get`** - a one-line status per object: is it there, is it ready, how many restarts.
2. **`get` vs `describe`** - `get` is the summary; `describe` adds the config, the conditions and,
   most importantly, the **Events**, which is where scheduling and image errors show up.
3. **`kubectl logs`** - what the app itself printed. `--previous` shows the last crashed container.
   Useless if the container never started (scenario 2).
4. **`kubectl exec`** - to test from *inside* the pod's network and filesystem: curl, nslookup, env.
5. **`CrashLoopBackOff`** - the container keeps exiting and kubelet waits longer between restarts
   (10s, 20s, 40s… up to 5 min). Exit code 0 still counts under `restartPolicy: Always`.
6. **`ImagePullBackOff`** - the image could not be pulled (bad name/tag, private repo, no network),
   and kubelet is backing off between retries.
7. **`Pending`** - the scheduler found no node that fits: not enough CPU/memory, taints, node
   selectors, or an unbound PVC.
8. **No endpoints** - the selector matches no *ready* pods: wrong labels, wrong namespace, or the
   pods are failing readiness.
9. **Selector ↔ labels** - the Service's selector is a label query. Every ready pod whose labels
   match becomes an endpoint. Nothing checks that it matches anything.
10. **Kubernetes DNS** - CoreDNS gives every Service the name `<svc>.<ns>.svc.cluster.local`,
    pointing at its ClusterIP, so pods find each other by name instead of by IP.

## What I took away

**`Running 1/1` can be a lie, and the app is the one lying.** Scenario 4 hid its failure with
`curl -s … || true`. No probe or event could see it, because nothing failed as far as Kubernetes
knew.

**Fixing the error message is not fixing the pod.** Scenario 1's obvious fix removed the error and
left it restarting forever with exit code 0.
