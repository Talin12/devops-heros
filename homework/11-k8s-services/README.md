# Kubernetes Networking & Services: Homework (Session 11)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.
> Manifests: [`session-11-kubernetes-services/`](../../session-11-kubernetes-services/)
> Concept notes: [`service.md`](../../session-11-kubernetes-services/service.md) · [`fqdn.md`](../../session-11-kubernetes-services/fqdn.md)

---

## Tasks

| # | Task | Status |
|---|---|---|
| 1 | ClusterIP - internal-only service | ✅ |
| 2 | NodePort - external access via node IP | ✅ |
| 3 | LoadBalancer - cloud-provisioned external LB | ✅ |
| 4 | ExternalName - DNS alias to an external host | ✅ |
| 5 | Headless service - direct per-pod DNS | ✅ |
| 6 | FQDN / CoreDNS resolution test | ✅ |
| 7 | Troubleshooting - empty endpoints from a selector mismatch | ✅ |

**Environment:** minikube v1.39.0 (docker driver), Kubernetes v1.37.0, single node, macOS arm64.

---

## Why a Service has to exist at all

From [Session 9](../09-k8s-fundamentals/README.md): deleting a pod under a ReplicaSet gets you a
*new* pod with a *new* IP. Pod IPs are not stable, and there are usually several of them. A Service
is the stable name and virtual IP that sits in front of a set of pods, and it keeps its membership
up to date by matching **labels**.

That label match is the single mechanism behind all of this, and Task 7 shows what happens when it
is wrong.

---

## 1. ClusterIP

```bash
kubectl apply -f 01-clusterip/app-deployment.yaml -f 01-clusterip/service.yaml -f 01-clusterip/client-pod.yaml
kubectl exec curl-client -- curl -s web-service-clusterip:8080
```

```console
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
web-service-clusterip   ClusterIP   10.101.202.250   <none>        8080/TCP   80s

NAME                    ENDPOINTS                                      AGE
web-service-clusterip   10.244.0.88:80,10.244.0.90:80,10.244.0.91:80   80s

--- reach it from inside the cluster by service NAME ---
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>

--- and by FQDN ---
HTTP 200
```

Three things in that output:

- **`EXTERNAL-IP <none>`** - this is unreachable from outside the cluster, by design.
- **`8080/TCP`** but endpoints on **`:80`** - `port: 8080` is what clients dial, `targetPort: 80` is
  what the container listens on. They are allowed to differ and here they do.
- **Three endpoints** - one per pod. The ClusterIP `10.101.202.250` is a *virtual* IP that nothing
  actually listens on; kube-proxy's iptables rules rewrite it to one of those three pod IPs.

### Task 6: FQDN and how the short name resolves

```console
$ kubectl exec curl-client -- nslookup web-service-clusterip
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	web-service-clusterip.default.svc.cluster.local
Address: 10.101.202.250

** server can't find web-service-clusterip.svc.cluster.local: NXDOMAIN
** server can't find web-service-clusterip.cluster.local: NXDOMAIN
```

Those NXDOMAINs look alarming but are harmless - busybox's `nslookup` prints an answer for *every*
entry in the search list, and only the first one matched. The reason is here:

```console
$ kubectl exec curl-client -- cat /etc/resolv.conf
search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
```

- `nameserver 10.96.0.10` is CoreDNS (itself a ClusterIP Service).
- The `search` list is why bare `web-service-clusterip` works - the resolver appends
  `default.svc.cluster.local` first and hits immediately.
- `ndots:5` means any name with fewer than 5 dots gets the search list tried **first**. This is why
  looking up an external name like `api.github.com` from inside a pod costs several wasted DNS
  queries before the absolute lookup succeeds - a well-known source of DNS load in busy clusters.

The full form is `<service>.<namespace>.svc.cluster.local`, which is what you need when calling
across namespaces, since the search list only covers your own.

---

## 2. NodePort

```console
NAME                   TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
web-service-nodeport   NodePort   10.109.10.56   <none>        80:30080/TCP   0s

type=NodePort clusterIP=10.109.10.56 nodePort=30080
```

**A NodePort is a superset of ClusterIP** - it still has a ClusterIP (`10.109.10.56`) and still
works internally. It just *additionally* opens port 30080 on every node.

```console
--- NodePort reachable on the node itself, port 30080 ---
HTTP 200
--- also on the node's real IP ---
HTTP 200
--- from the macOS host it is NOT routable ---
HTTP 000
timed out (exit 28)
--- minikube service gives a working host-side tunnel URL ---
http://127.0.0.1:61194
! Because you are using a Docker driver on darwin, the terminal needs to be open to run it.
```

Same macOS caveat I hit in [Session 12](../08-k8s-ingress-configmaps-secrets/README.md): with the
docker driver the node lives inside the Docker VM, so `192.168.49.2:30080` times out from the Mac
even though it answers `HTTP 200` from inside. `minikube service --url` opens a tunnel and prints a
`127.0.0.1` URL that does work - it has to stay running, which is why the command blocks.

NodePort's real-world problems: the port range is restricted to **30000-32767**, you must track
port assignments yourself, and clients need a node IP - so if that node dies, that address is dead.
It is a building block, not usually a production front door.

---

## 3. LoadBalancer

```console
NAME                       TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
web-service-loadbalancer   LoadBalancer   10.106.245.174   <pending>     80:31536/TCP   13s

type=LoadBalancer externalIP=
clusterIP=10.106.245.174 nodePort=31536
```

**`EXTERNAL-IP` sits at `<pending>` forever, and that is the correct result here.** A LoadBalancer
Service does not implement a load balancer - it asks the *cloud controller manager* to go
provision one (an AWS ELB, a GCP forwarding rule). Bare minikube has no cloud provider, so nothing
ever answers and the field stays pending. `minikube tunnel` fakes it if you need one.

Note it also allocated `nodePort=31536` on top of a ClusterIP. The layering is strictly additive:

```
ClusterIP  ─┬─ internal VIP
NodePort   ─┼─ internal VIP + port on every node
LoadBalancer┴─ internal VIP + port on every node + external cloud LB
```

---

## 4. ExternalName

```console
NAME                        TYPE           CLUSTER-IP   EXTERNAL-IP        PORT(S)   AGE
external-database-service   ExternalName   <none>       nencyravaliya.me   <none>    1s

type=ExternalName clusterIP= externalName=nencyravaliya.me

$ kubectl get endpoints external-database-service
Error from server (NotFound): endpoints "external-database-service" not found
```

ExternalName is the odd one out: **no ClusterIP, no endpoints, no selector, no proxying.** It is
purely a CoreDNS CNAME record.

```console
external-database-service.default.svc.cluster.local	canonical name = nencyravaliya.me
```

No traffic passes through Kubernetes at all - the pod resolves the name, gets the external host
back, and connects directly. Which means: **no load balancing, no health checks, and the target
port is whatever the client asks for.**

Its real use is indirection. Point your app at `database-service` in every environment; in
production the Service is an ExternalName to an RDS endpoint, in dev it is a normal ClusterIP in
front of a local pod. The application config never changes.

---

## 5. Headless service (`clusterIP: None`)

```console
NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
web-service-headless   ClusterIP   None         <none>        80/TCP    6s

web-stateful-0 Running 10.244.0.99
web-stateful-1 Running 10.244.0.100
web-stateful-2 Running 10.244.0.101
```

```console
--- headless DNS returns ALL pod IPs (no VIP) ---
Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.0.101
Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.0.100
Name:	web-service-headless.default.svc.cluster.local
Address: 10.244.0.99
```

**This is the contrast that matters.** Task 1's ClusterIP resolved to exactly one address
(`10.101.202.250`), a virtual IP owned by nobody. This one resolves to **three A records - the
actual pod IPs**. There is no VIP and kube-proxy programs no rules; the client gets the full
membership list and decides for itself.

And because it is backed by a StatefulSet, each pod also gets its own permanent name:

```console
Name:	web-stateful-0.web-service-headless.default.svc.cluster.local
Address: 10.244.0.99
Name:	web-stateful-1.web-service-headless.default.svc.cluster.local
Address: 10.244.0.100
Name:	web-stateful-2.web-service-headless.default.svc.cluster.local
Address: 10.244.0.101
```

`<pod>.<headless-service>.<namespace>.svc.cluster.local`. That is what lets clustered software work
on Kubernetes: a Kafka or Cassandra or MySQL replica needs to address *a specific peer*, not "some
pod behind a VIP". Random load balancing would be actively wrong for a write to a primary.

---

## 6. Troubleshooting: empty endpoints

```console
NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
broken-backend-service   ClusterIP   10.99.55.250   <none>        80/TCP    6s

--- service exists and has a ClusterIP, but ZERO endpoints ---
NAME                     ENDPOINTS   AGE
broken-backend-service   <none>      6s

Selector:                 app=wrong-backend-name
Endpoints:

service selector: {"app":"wrong-backend-name"}
$ kubectl get pods -l app=wrong-backend-name
No resources found in default namespace.
```

The Service was **created without complaint**, got a ClusterIP, and resolves in DNS. It simply
matches no pods, so connections to it hang or are refused.

This is the single most common Service bug, and the diagnosis is always the same three commands:

```bash
kubectl get endpoints <service>            # empty? -> the selector is the problem
kubectl describe svc <service>             # read the Selector line
kubectl get pods -l <that exact selector>  # returns nothing -> confirmed
```

Worth contrasting with the [Session 10](../10-k8s-core-objects/README.md) selector-mismatch drill: a
**Deployment** whose selector disagrees with its own pod template is *rejected by the API server*
before anything is created. A **Service** whose selector matches nothing is completely valid and
fails silently at runtime. Same class of mistake, opposite failure modes - so `kubectl get
endpoints` is the check that has no apply-time equivalent.

Other things that produce empty endpoints even when the labels are right: the pods are not `Ready`
(a failing readiness probe removes them), or `targetPort` names a port the container never declared.

---

## The five types side by side

| Type | ClusterIP | Endpoints | Reachable from | Load balanced | Use for |
|---|---|---|---|---|---|
| **ClusterIP** | yes | pod IPs | inside only | yes (kube-proxy) | internal service-to-service |
| **NodePort** | yes | pod IPs | inside + `<nodeIP>:30000-32767` | yes | dev, or behind an external LB |
| **LoadBalancer** | yes | pod IPs | inside + node port + cloud LB | yes | production ingress on a cloud |
| **ExternalName** | **none** | **none** | DNS CNAME only | **no** | aliasing an out-of-cluster host |
| **Headless** | **None** | pod IPs via DNS | inside only | **no - client decides** | StatefulSets, peer discovery |

---

## Cleanup

```bash
kubectl delete -f 01-clusterip/ -f 02-nodeport/ -f 03-loadbalancer/
kubectl delete -f 04-externalname/ -f 05-headless/ -f troubleshooting/ -f dns-test/
```

```console
$ kubectl get all -n default
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   2d6h
```

---

## What I took away

**The four "real" service types are one feature stacked four times.** ClusterIP is the base;
NodePort adds a port on every node; LoadBalancer adds a cloud LB on top of that. Seeing
`web-service-loadbalancer` report a ClusterIP *and* a nodePort *and* a pending external IP
simultaneously made that layering concrete in a way the diagram never did.

**Headless is the genuine exception, not a fifth variant.** Everything else hands you one virtual IP
and hides the pods. `clusterIP: None` does the opposite - it hands you every pod IP and gets out of
the way. Which is exactly right when the client needs to address a *specific* peer rather than any
healthy one.

**`<pending>` is not always a bug.** The LoadBalancer sitting pending forever on minikube is the
system behaving correctly with no cloud controller to answer. Knowing the difference between "this
is broken" and "this is waiting for something that does not exist here" saved me from debugging a
non-problem.

**Labels are the only thing holding any of this together, and nothing validates them.** The Service
in Task 7 was accepted, got an IP, and resolved in DNS while pointing at nothing at all. `kubectl
get endpoints` is the one command that would have caught it, and there is no apply-time check that
substitutes for it.
