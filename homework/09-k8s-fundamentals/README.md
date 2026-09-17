# Kubernetes Fundamentals: Homework (Session 9)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> Session resources: [`session9-k8s/Readme.md`](../../session9-k8s/Readme.md)

---

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | Bring up a local cluster with minikube | ✅ |
| 2 | Inspect the control plane and worker components | ✅ |
| 3 | Run a first Pod imperatively and trace what happened to it | ✅ |
| 4 | Show that a bare Pod does not self-heal, but a Deployment's Pod does | ✅ |
| 5 | Trace the ownership chain Deployment → ReplicaSet → Pod | ✅ |

---

## Environment

| | |
|---|---|
| Host | macOS (Darwin 26.6.2, arm64) |
| minikube | v1.39.0, `--driver=docker` |
| Kubernetes | v1.37.0 |
| Container runtime | containerd 2.3.4 |
| Node OS image | Debian GNU/Linux 12 (bookworm) |

```bash
minikube start --driver=docker
```

---

## Task 1 & 2: The cluster and its components

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -n kube-system -o wide
kubectl get namespaces
```

```console
===== cluster-info =====
Kubernetes control plane is running at https://127.0.0.1:59343
CoreDNS is running at https://127.0.0.1:59343/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

===== nodes -o wide =====
NAME       STATUS   ROLES           AGE    VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                         KERNEL-VERSION             CONTAINER-RUNTIME
minikube   Ready    control-plane   2d5h   v1.37.0   192.168.49.2   <none>        Debian GNU/Linux 12 (bookworm)   6.10.14-linuxkit (arm64)   containerd://2.3.4

===== control plane components (kube-system) =====
NAME                               READY   STATUS    RESTARTS        AGE    IP             NODE       NOMINATED NODE   READINESS GATES
coredns-559f6c778d-k8hwp           1/1     Running   1 (8m17s ago)   2d5h   10.244.0.5     minikube   <none>           <none>
etcd-minikube                      1/1     Running   1 (8m17s ago)   2d5h   192.168.49.2   minikube   <none>           <none>
kindnet-cl5pq                      1/1     Running   1 (8m17s ago)   2d5h   192.168.49.2   minikube   <none>           <none>
kube-apiserver-minikube            1/1     Running   1 (8m17s ago)   2d5h   192.168.49.2   minikube   <none>           <none>
kube-controller-manager-minikube   1/1     Running   1 (8m17s ago)   2d5h   192.168.49.2   minikube   <none>           <none>
kube-proxy-kbxhh                   1/1     Running   1 (8m17s ago)   2d5h   192.168.49.2   minikube   <none>           <none>
kube-scheduler-minikube            1/1     Running   1 (8m17s ago)   2d5h   192.168.49.2   minikube   <none>           <none>
storage-provisioner                1/1     Running   3 (7m44s ago)   2d5h   192.168.49.2   minikube   <none>           <none>

===== namespaces =====
NAME              STATUS   AGE
default           Active   2d5h
ingress-nginx     Active   8m10s
kube-node-lease   Active   2d5h
kube-public       Active   2d5h
kube-system       Active   2d5h
```

### What each of those components actually does

| Component | Role | Notes from the output above |
|---|---|---|
| `kube-apiserver` | The only door into the cluster. Every `kubectl` command, every controller, every kubelet talks to this and nothing else. | Has the node IP `192.168.49.2`, not a pod IP |
| `etcd` | The database. The entire cluster state - every object - lives here. | Also on the host network |
| `kube-scheduler` | Decides *which node* an unassigned Pod goes to. It only writes `nodeName`; it never starts anything. | |
| `kube-controller-manager` | Runs the reconcile loops (ReplicaSet, Deployment, Node, Endpoints, ...) that drive actual state toward desired state. | |
| `kube-proxy` | Programs the node's iptables/IPVS rules so a Service ClusterIP resolves to a real pod. | |
| `coredns` | Cluster DNS. Resolves Service names to ClusterIPs. | The only one with a **pod** IP `10.244.0.5` |
| `kindnet` | The CNI plugin - gives every pod its IP and wires pod-to-pod routing. | |
| `storage-provisioner` | minikube addon that dynamically satisfies PersistentVolumeClaims. | |

The four host-networked ones (`apiserver`, `etcd`, `scheduler`, `controller-manager`) are **static
pods** - the kubelet reads their manifests straight off disk in `/etc/kubernetes/manifests`, which
is how the control plane can start before there is an API server to ask.

On minikube everything is one node: `ROLES control-plane`, and workloads still schedule onto it
because minikube removes the usual `NoSchedule` taint. On a real cluster the control plane would be
separate and would refuse to run your pods.

### The four namespaces you get for free

- **`default`** - where your objects go when you do not say otherwise.
- **`kube-system`** - the cluster's own machinery, listed above.
- **`kube-public`** - world-readable; holds cluster info needed before you are authenticated.
- **`kube-node-lease`** - one Lease object per node, heartbeated constantly. Node health is judged
  by whether the lease keeps getting renewed, which is far cheaper than updating the Node object.

(`ingress-nginx` is not a default - it appeared when I enabled the ingress addon for Session 12.)

---

## Task 3: A first Pod, and what actually happened to it

```bash
kubectl run hello-k8s --image=nginx:1.25-alpine --port=80
kubectl get pod hello-k8s -o wide
kubectl describe pod hello-k8s
```

```console
===== imperative: first pod =====
pod/hello-k8s created
pod/hello-k8s condition met
NAME        READY   STATUS    RESTARTS   AGE   IP            NODE       NOMINATED NODE   READINESS GATES
hello-k8s   1/1     Running   0          1s    10.244.0.17   minikube   <none>           <none>

===== where did the scheduler put it / what happened =====
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  1s    default-scheduler  Successfully assigned default/hello-k8s to minikube
  Normal  Pulled     0s    kubelet            spec.containers{hello-k8s}: Container image "nginx:1.25-alpine" already present on machine and can be accessed by the pod
  Normal  Created    0s    kubelet            spec.containers{hello-k8s}: Container created
  Normal  Started    0s    kubelet            spec.containers{hello-k8s}: Container started
```

**That Events block is the whole architecture in four lines**, and it is the single most useful
output in this session. Read the `From` column:

1. `default-scheduler` → **Scheduled**. The scheduler picked the node and wrote `nodeName`. It did
   not create a container - that is not its job.
2. `kubelet` → **Pulled** → **Created** → **Started**. The kubelet on that node noticed a pod was
   assigned to it, pulled the image, and asked containerd to run it.

Nobody issued an order to anybody. The scheduler wrote a field; the kubelet was watching for that
field and reacted. That is the level-triggered reconciliation model the whole system is built on,
and it is why `kubectl describe` is the first thing to run when something is stuck - the Events
tell you *which component* stopped making progress.

### `kubectl explain` - the docs are in the binary

```console
$ kubectl explain pod.spec.containers.image
KIND:       Pod
VERSION:    v1

FIELD: image <string>

DESCRIPTION:
    Container image name. More info:
    https://kubernetes.io/docs/concepts/containers/images This field is optional
    to allow higher level config management to default or override container
    images in workload controllers like Deployments and StatefulSets.
```

Worth knowing because it reads the **live API server's** schema, so it is always correct for the
version you are actually running - unlike a web page.

---

## Task 4: A bare Pod does not come back

```console
===== scale it: pod alone cannot self-heal, delete it and it is gone =====
pod "hello-k8s" deleted from default namespace
No resources found in default namespace.
```

Gone. Nothing recreates it, because nothing owns it. Now the same test under a Deployment:

```bash
kubectl create deployment self-heal --image=nginx:1.25-alpine --replicas=2
kubectl delete pod <one of them>
kubectl get pods -l app=self-heal
```

```console
--- pods before ---
NAME                         READY   STATUS    RESTARTS   AGE
self-heal-7b8f469ff7-8psq5   1/1     Running   0          0s
self-heal-7b8f469ff7-zqw8w   1/1     Running   0          0s
--- deleting self-heal-7b8f469ff7-8psq5 ---
pod "self-heal-7b8f469ff7-8psq5" deleted from default namespace
--- pods after (replacement scheduled automatically) ---
NAME                         READY   STATUS    RESTARTS   AGE
self-heal-7b8f469ff7-xvxvw   1/1     Running   0          6s
self-heal-7b8f469ff7-zqw8w   1/1     Running   0          7s
```

Still two pods. But look closely - `8psq5` is not back. **`xvxvw` is a brand new pod.** Kubernetes
did not resurrect anything; the ReplicaSet controller observed `current=1, desired=2` and created a
replacement. Pods are disposable, and the guarantee is on the *count*, not on any individual pod.

This is why you almost never create a bare Pod outside of a debugging session.

---

## Task 5: The ownership chain

```console
===== the ownership chain: Deployment -> ReplicaSet -> Pod =====
NAME                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/self-heal   2/2     2            2           7s

NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/self-heal-7b8f469ff7   2         2         2       7s

NAME                             READY   STATUS    RESTARTS   AGE
pod/self-heal-7b8f469ff7-xvxvw   1/1     Running   0          6s
pod/self-heal-7b8f469ff7-zqw8w   1/1     Running   0          7s

ReplicaSet/self-heal-7b8f469ff7      <- pod's ownerReferences
```

Three objects, three controllers, one job each:

```
Deployment  self-heal              "I want 2 replicas of THIS version, updated THIS way"
    │  owns
ReplicaSet  self-heal-7b8f469ff7   "I want 2 pods matching THIS exact template"
    │  owns
Pods        ...-xvxvw, ...-zqw8w   the actual containers
```

That `7b8f469ff7` suffix is not random - it is the `pod-template-hash`, a hash of the pod template.
Change the image and you get a *different* hash, therefore a *different* ReplicaSet, and the
Deployment scales the new one up while scaling the old one down. That one detail is the mechanism
behind rolling updates and rollbacks, both of which I work through in
[Session 10](../10-k8s-core-objects/README.md).

The `ownerReferences` field is also what makes `kubectl delete deployment` clean up everything
underneath it - garbage collection follows those pointers down.

---

## Cleanup

```bash
kubectl delete deployment self-heal
```

---

## What I took away

**The control plane is a set of independent loops around one database.** No component commands
another. The scheduler writes `nodeName` and stops; the kubelet was already watching for it. Every
piece only reads desired state from the API server and nudges reality toward it. This is why the
`Events` block reads like a relay race, and why reading the `From` column tells you exactly which
loop has stalled.

**Desired state is a count, not an identity.** Deleting a pod under a ReplicaSet gets you a *new*
pod with a new name and new IP - not the old one back. Anything you cared about inside that pod is
gone. That single fact is the reason Services exist (you cannot depend on a pod IP), the reason
ConfigMaps and Secrets exist (config cannot live in the pod), and the reason StatefulSets exist
(when you genuinely do need stable identity).

**`kubectl describe` before `kubectl logs`.** Logs only exist if the container actually started.
When a pod is Pending, ImagePullBackOff, or stuck, there are no logs - the Events block is the
only thing that will tell you why, and it names the responsible component.
