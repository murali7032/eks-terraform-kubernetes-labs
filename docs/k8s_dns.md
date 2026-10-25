# Kubernetes DNS

> Services get stable DNS names resolved by **CoreDNS**. Pods use `/etc/resolv.conf` search domains so short names like `my-service` resolve inside the cluster.

## Introduction

Cluster DNS (CoreDNS on most clusters, including EKS) publishes records for Services and Pods. The default Service DNS form is:

```text
<service>.<namespace>.svc.cluster.local
```

## Explanation

- Pods typically use `dnsPolicy: ClusterFirst`.
- Search list often includes `default.svc.cluster.local`, `svc.cluster.local`, `cluster.local`.
- Resolving a Service name returns its **ClusterIP**; traffic then goes to Endpoints/EndpointSlices.
- DNS success ≠ HTTP success: check ports, NetworkPolicies, and that backends are Ready.

## Architecture / flow

```text
App Pod
  |  lookup: my-service
  v
/etc/resolv.conf  →  nameserver (kube-dns Service)
  v
CoreDNS Pods
  v
Service ClusterIP  →  Endpoints / Pods
```

## Official references

- [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) (Kubernetes)
- [Debugging DNS Resolution](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/) (Kubernetes)
- [CoreDNS on Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html) (AWS)

## Lab setup

From the **repo root**:

```powershell
kubectl run dns-client --image=busybox:1.36 --restart=Never --command -- sh -c "sleep 3600"
kubectl wait --for=condition=Ready pod/dns-client --timeout=90s

kubectl exec dns-client -- cat /etc/resolv.conf
kubectl exec dns-client -- nslookup kubernetes.default.svc.cluster.local
kubectl exec dns-client -- nslookup kubernetes

kubectl logs -n kube-system -l k8s-app=kube-dns --tail=30
```

## Cleanup

```powershell
kubectl delete pod dns-client --ignore-not-found
```
