# Istio service mesh

> Istio is a **service mesh**: sidecar (or ambient) proxies manage retries, TLS, routing, and authorization so application code can stay focused on business logic.

## Introduction

Without a mesh, each service implements its own retries, timeouts, encryption, routing, and telemetry. [Istio](https://istio.io/latest/docs/overview/what-is-istio/) splits that into:

- **Control plane** (`istiod`) — discovery, certificates, and policy distribution
- **Data plane** (Envoy) — the proxy that actually carries traffic

This lab installs the **demo** Istio profile on EKS, injects sidecars into namespace `mesh-lab`, routes **backend v1/v2** through an **Istio Ingress Gateway**, then tightens **mTLS** and **AuthorizationPolicy**.

## Explanation

| Resource | Purpose |
|----------|---------|
| Sidecar injection | Pods in a labeled namespace get an Envoy container |
| `Gateway` | L4–L6 listener on the ingressgateway Pods (edge of the mesh) |
| `VirtualService` | How requests are routed (weights, hosts, matches) |
| `DestinationRule` | Subsets (`v1`/`v2`) and destination policies |
| `PeerAuthentication` | Incoming mTLS mode (`PERMISSIVE` / `STRICT` / `DISABLE`) |
| `AuthorizationPolicy` | Allow/deny by identity (SPIFFE principal), namespace, or IP |

Rule of thumb:

- **DestinationRule** = what versions exist  
- **VirtualService** = how to send traffic to them  
- **Gateway** = who may enter the mesh from outside  

This repo’s files:

| File | Purpose |
|------|---------|
| `manifests/backend-v1.yaml` | Deployment `backend-v1` (`version: v1`) |
| `manifests/backend-v2.yaml` | Deployment `backend-v2` (`version: v2`) |
| `manifests/backend-service.yaml` | Service `backend` (selects `app: backend`) |
| `manifests/backend-gateway.yaml` | Istio `Gateway` **CR** — config only; **does not create a Pod** |
| `manifests/backend-destinationrule.yaml` | Subsets `v1` / `v2` |
| `manifests/backend-virtualservice.yaml` | 50/50 split on ingress **and** in-mesh |
| `manifests/curl-client.yaml` | Pod + ServiceAccount `curl-test` |
| `manifests/mtls-strict.yaml` | Namespace `PeerAuthentication` STRICT |
| `manifests/backend-authz.yaml` | Allow only SA `curl-test` to `app: backend` |

## Architecture / flow

### What `backend-gateway.yaml` actually is

It is **not** a Deployment and **does not create a Pod**.

`istioctl install --set profile=demo` already created the edge proxy:

| Object (`istio-system`) | Kind | Created by |
|-------------------------|------|------------|
| `istiod` | Deployment / Pods | `istioctl install` |
| `istio-ingressgateway` | Deployment / Pods (Envoy) | `istioctl install` |
| `istio-ingressgateway` | Service (`LoadBalancer` on EKS) | `istioctl install` |

`kind: Gateway` is Istio **config**. `spec.selector: istio: ingressgateway` means: push this HTTP :80 listener onto Pods that **already** have that label. istiod programs those existing Envoy processes.

```text
istioctl install (demo)
        │
        ├── Deployment istiod
        └── Deployment istio-ingressgateway   ← real Pods (Envoy at the edge)
                    ▲
                    │  selector: istio: ingressgateway
                    │
            Gateway CR  backend-gateway.yaml
            (mesh-lab)  ← YAML only, no new Pod
                    │
            VirtualService binds to that Gateway
                    │
                    ▼
            Service backend → Pods backend-v1 / backend-v2
```

Confirm the Pods existed **before** you applied the Gateway:

```powershell
kubectl get deploy,po,svc -n istio-system -l app=istio-ingressgateway
kubectl get gateway backend-gateway -n mesh-lab
```

After apply you still have the same ingressgateway Pod count; only Envoy config inside those Pods changed.

### Cluster layout (this lab)

```text
                        AWS NLB / ELB
                   (from Service LoadBalancer)
                              │
                              ▼
                 ┌────────────────────────────┐
                 │ istio-system               │
                 │                            │
                 │  istiod                    │
                 │    (control plane)         │
                 │         │                  │
                 │         │ pushes config    │
                 │         ▼                  │
                 │  istio-ingressgateway Pod  │
                 │    Envoy  :80              │  ◄── Gateway CR attaches here
                 └────────────┬───────────────┘
                              │
                              ▼
                 ┌────────────────────────────┐
                 │ mesh-lab  (injection on)   │
                 │                            │
                 │  curl-client  [app|envoy]  │
                 │         │                  │
                 │         ▼  http://backend  │
                 │  Service backend           │
                 │         │                  │
                 │    ┌────┴────┐             │
                 │    ▼         ▼             │
                 │ backend-v1  backend-v2     │
                 │ [app|envoy] [app|envoy]    │
                 └────────────────────────────┘
```

### Control plane vs data plane

```text
                istiod (istio-system)
                      │
         config / certs / discovery
                      │
        ┌─────────────┼─────────────────┐
        ▼             ▼                 ▼
  ingressgateway   curl-client       backend
  Envoy (edge)     Envoy sidecar     Envoy sidecar
```

### Two request paths

**A — North-south (curl → LoadBalancer)**  
Uses the **Gateway CR** + VirtualService `gateways: backend-gateway`.

```text
You
  → NLB
    → istio-ingressgateway Pod (already running)
      → VirtualService 50/50
        → backend-v1 or backend-v2
```

**B — East-west (curl-client inside the mesh)**  
Does **not** need the Gateway CR. Uses VirtualService `gateways: mesh` and `host: backend`.

```text
curl-client sidecar
  → VirtualService 50/50
    → backend-v1 or backend-v2 sidecars
```

If you never apply `backend-gateway.yaml`, path B still works; path A has no listener binding from this Gateway/VirtualService pair.

### Request path (combined)

```text
External client                         curl-client (in mesh)
      │                                        │
      ▼                                        │
istio-ingressgateway Pod                       │
 (Envoy — created by install,                host: backend
  programmed by Gateway CR)                    │
      │                                        │
      └────────────┬───────────────────────────┘
                   ▼
            VirtualService (50/50)
                   │
            DestinationRule subsets
                   │
          ┌────────┴────────┐
          ▼                 ▼
     backend-v1        backend-v2
```

### mTLS between sidecars

```text
curl-client
   │
 Envoy  ── mTLS (certs from istiod) ──►  Envoy
   │                                       │
 app                                       backend
```

### Authorization after STRICT mTLS

```text
Request to backend
        │
        ▼
AuthorizationPolicy (selector app=backend)
        │
        ├── principal curl-test  → ALLOW
        └── anyone else          → DENY (403)
```

Ingress-gateway requests use the **ingressgateway** ServiceAccount, not `curl-test`. After the authz policy is applied, **external curl through the Gateway should fail**; in-mesh curl from `curl-client` should succeed.

## Official references

- [What is Istio?](https://istio.io/latest/docs/overview/what-is-istio/)
- [Install with istioctl](https://istio.io/latest/docs/setup/install/istioctl/)
- [Automatic sidecar injection](https://istio.io/latest/docs/setup/additional-setup/sidecar-injection/)
- [Traffic management](https://istio.io/latest/docs/concepts/traffic-management/)
- [Gateway](https://istio.io/latest/docs/reference/config/networking/gateway/)
- [VirtualService](https://istio.io/latest/docs/reference/config/networking/virtual-service/)
- [DestinationRule](https://istio.io/latest/docs/reference/config/networking/destination-rule/)
- [PeerAuthentication](https://istio.io/latest/docs/reference/config/security/peer_authentication/)
- [AuthorizationPolicy](https://istio.io/latest/docs/reference/config/security/authorization-policy/)
- [EKS: Istio webhook (port 15017)](https://istio.io/latest/docs/setup/platform-setup/amazon-eks/)

## Lab setup

Run `kubectl` from the **repo root**. Install `istioctl` from the [Istio release](https://github.com/istio/istio/releases) (on Windows you can use `.\istioctl.exe` if that is how you unpacked it).

Replace `<cluster-name>`, `<region>`, `<profile>`, and security-group IDs.

### 1. Cluster and Istio install

```powershell
kubectl get nodes
istioctl version
istioctl x precheck

istioctl install --set profile=demo -y

kubectl get pods -n istio-system
kubectl get svc -n istio-system
```

The demo profile includes `istiod` and `istio-ingressgateway`. Wait until both are Ready.

**EKS webhook (if injection/install hangs):** the control plane must reach Istio validating/mutating webhooks on **TCP 15017** on the node security group.

```powershell
aws eks describe-cluster `
  --name <cluster-name> `
  --region <region> `
  --profile <profile> `
  --query "cluster.resourcesVpcConfig.{ClusterSG:clusterSecurityGroupId,ControlPlaneSGs:securityGroupIds,VPC:vpcId}" `
  --output table

# Allow control-plane / cluster SG → node SG on 15017 (use YOUR group IDs)
aws ec2 authorize-security-group-ingress `
  --group-id <node-or-additional-sg> `
  --protocol tcp `
  --port 15017 `
  --source-group <cluster-security-group-id> `
  --region <region> `
  --profile <profile>
```

If `istiod` is OOMKilled on small nodes, either scale the node group or reinstall with smaller Pilot requests (optional):

```powershell
istioctl install --set profile=demo `
  --set components.pilot.k8s.resources.requests.cpu=200m `
  --set components.pilot.k8s.resources.requests.memory=256Mi `
  --set components.pilot.k8s.resources.limits.memory=512Mi `
  -y
```

### 2. Namespace with sidecar injection

```powershell
kubectl create namespace mesh-lab
kubectl label namespace mesh-lab istio-injection=enabled
kubectl get namespace mesh-lab --show-labels
```

### 3. Deploy backend v1, v2, and Service

```powershell
kubectl apply -f manifests/backend-v1.yaml
kubectl apply -f manifests/backend-v2.yaml
kubectl apply -f manifests/backend-service.yaml

kubectl get pods -n mesh-lab -o wide
kubectl get svc backend -n mesh-lab
```

Each Ready Pod should show **2/2** containers (app + `istio-proxy`). Confirm with:

```powershell
kubectl describe pod -n mesh-lab -l app=backend
istioctl proxy-status
```

### 4. In-mesh client

```powershell
kubectl apply -f manifests/curl-client.yaml
kubectl wait --for=condition=Ready pod/curl-client -n mesh-lab --timeout=120s

# Round-robin via Kubernetes Service (before VirtualService subsets apply to this client)
kubectl exec -n mesh-lab curl-client -c curl -- sh -c "for i in 1 2 3 4 5 6; do curl -s http://backend; echo; done"
```

### 5. DestinationRule, Gateway, VirtualService (50/50)

Apply **DestinationRule before** (or with) the VirtualService so subsets exist.

```powershell
kubectl apply -f manifests/backend-destinationrule.yaml
kubectl apply -f manifests/backend-gateway.yaml
kubectl apply -f manifests/backend-virtualservice.yaml

kubectl get gateway,virtualservice,destinationrule -n mesh-lab
```

In-mesh split:

```powershell
kubectl exec -n mesh-lab curl-client -c curl -- sh -c "for i in 1 2 3 4 5 6 7 8 9 10; do curl -s http://backend; echo; done"
```

You should see a mix of `Hello from backend-v1` and `Hello from backend-v2`.

Ingress Gateway (external):

```powershell
kubectl get svc istio-ingressgateway -n istio-system
```

On EKS the Service is typically a **LoadBalancer**. Wait for `EXTERNAL-IP` / hostname, then:

```powershell
# PowerShell: use the hostname from kubectl get svc
curl.exe http://<ingress-lb-hostname>/
```

To shift weights (canary-style), edit `manifests/backend-virtualservice.yaml` (for example 90/10) and re-apply.

### 6. STRICT mTLS

```powershell
kubectl apply -f manifests/mtls-strict.yaml
kubectl get peerauthentication -n mesh-lab

# Still works: both sides have sidecars
kubectl exec -n mesh-lab curl-client -c curl -- curl -sS http://backend

# Plain curl from a Pod *without* a sidecar should fail once STRICT is on
```

### 7. AuthorizationPolicy (only `curl-test`)

```powershell
kubectl apply -f manifests/backend-authz.yaml

# Allowed (SA curl-test)
kubectl exec -n mesh-lab curl-client -c curl -- curl -sS -o - -w "`nHTTP %{http_code}`n" http://backend

# Denied from ingress (different identity) — expect 403
curl.exe -sS -o - -w "`nHTTP %{http_code}`n" http://<ingress-lb-hostname>/
```

## Cleanup

Delete app and policy objects first, then the namespace, then Istio if you no longer need the mesh.

```powershell
kubectl delete -f manifests/backend-authz.yaml --ignore-not-found
kubectl delete -f manifests/mtls-strict.yaml --ignore-not-found
kubectl delete -f manifests/backend-virtualservice.yaml --ignore-not-found
kubectl delete -f manifests/backend-destinationrule.yaml --ignore-not-found
kubectl delete -f manifests/backend-gateway.yaml --ignore-not-found
kubectl delete -f manifests/curl-client.yaml --ignore-not-found
kubectl delete -f manifests/backend-v1.yaml --ignore-not-found
kubectl delete -f manifests/backend-v2.yaml --ignore-not-found
kubectl delete -f manifests/backend-service.yaml --ignore-not-found

kubectl delete namespace mesh-lab --ignore-not-found
```

Remove Istio from the cluster (LoadBalancer Service deletion also removes the AWS NLB/ELB):

```powershell
istioctl uninstall --purge -y
kubectl delete namespace istio-system --ignore-not-found
```
