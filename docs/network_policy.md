# NetworkPolicy

> Control which Pods can talk to each other (and to external endpoints) at L3/L4. Policies are enforced only when your CNI supports them—on EKS that is typically Amazon VPC CNI with network policy enabled.

## Introduction

By default, Kubernetes allows Pod-to-Pod traffic within the cluster network. A [NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/) selects Pods with labels and defines allowed **ingress** and/or **egress**. Once any NetworkPolicy selects a Pod, traffic not explicitly allowed is denied for that direction.

## Explanation

- NetworkPolicies are **namespace-scoped**.
- They use **pod selectors**, optional **namespace selectors**, and **IP blocks**.
- Rules are additive: if multiple policies select a Pod, allowed traffic is the union of those rules.
- On Amazon EKS, enable NetworkPolicy support in the **VPC CNI** add-on (`enableNetworkPolicy`), then verify the `aws-node` DaemonSet.

## Architecture / flow

```text
Frontend Pod
      |
      |  allowed (NetworkPolicy ingress/egress)
      v
Backend Pod
      |
      |  denied unless another allow rule matches
      v
Database Pod
```

## Official references

- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/) (Kubernetes)
- [Declare Network Policy](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/) (Kubernetes)
- [Configure network policy for Amazon VPC CNI](https://docs.aws.amazon.com/eks/latest/userguide/cni-network-policy.html) (AWS EKS)

## Lab setup

Run commands from the **repo root**. Replace `<cluster-name>` and `<region>`.

### 1. Enable VPC CNI network policy

```powershell
kubectl get ds aws-node -n kube-system -o yaml |
  Select-String -Pattern "enable-network-policy|NETWORK_POLICY" -Context 2,2

aws eks describe-addon `
  --cluster-name <cluster-name> `
  --addon-name vpc-cni `
  --region <region> `
  --query "addon.{Status:status,Version:addonVersion,Config:configurationValues}" `
  --output json

aws eks update-addon `
  --cluster-name <cluster-name> `
  --addon-name vpc-cni `
  --region <region> `
  --configuration-values file://manifests/vpc-cni-config.json `
  --resolve-conflicts PRESERVE

kubectl get pods -n kube-system -l k8s-app=aws-node
```

### 2. Ingress lab

```powershell
kubectl create deployment np-server --image=nginx
kubectl expose deployment np-server --port=80
kubectl rollout status deployment/np-server

kubectl run np-client --image=busybox:1.36 --restart=Never -- sleep 3600
kubectl wait --for=condition=Ready pod/np-client --timeout=120s
kubectl exec np-client -- wget -qO- --timeout=5 http://np-server

kubectl apply -f manifests/deny-server-ingress.yaml
kubectl exec np-client -- wget -qO- --timeout=5 http://np-server

kubectl apply -f manifests/allow-client-to-server.yaml
kubectl run np-client-other --image=busybox:1.36 --restart=Never `
  --labels="run=other-client" --command -- sh -c "sleep 3600"
kubectl wait --for=condition=Ready pod/np-client-other --timeout=90s
kubectl exec np-client-other -- wget -qO- --timeout=5 http://np-server
```

Optional helpers: `manifests/np-client-same.yaml`, `manifests/allow-client-dns.yaml`.

### 3. Egress lab

```powershell
kubectl apply -f manifests/egress-lab.yaml
kubectl rollout status deployment/egress-client
kubectl rollout status deployment/egress-destination

kubectl apply -f manifests/deny-client-egress.yaml
kubectl apply -f manifests/allow-client-to-destination.yaml
```

## Cleanup

```powershell
kubectl delete networkpolicy deny-server-ingress allow-client-to-server --ignore-not-found
kubectl delete networkpolicy deny-client-egress allow-client-to-destination --ignore-not-found
kubectl delete -f manifests/egress-lab.yaml --ignore-not-found
kubectl delete pod np-client np-client-same np-client-other --ignore-not-found
kubectl delete deployment np-server --ignore-not-found
kubectl delete service np-server --ignore-not-found
```
