# ALB Ingress (AWS Load Balancer Controller)

> An [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) describes HTTP routing. With `ingressClassName: alb`, the **AWS Load Balancer Controller** creates an Application Load Balancer.

## Introduction

Ingress is a Kubernetes API object. A **controller** implements it on real infrastructure. On EKS, the [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) provisions ALB/NLB from Ingress (and other) resources.

## Explanation

- This lab uses annotations such as `alb.ingress.kubernetes.io/scheme: internet-facing` and `target-type: ip`.
- IP target mode registers Pod IPs (requires VPC CNI reachability from the ALB).
- Sample IAM JSON for the controller: `aws/iam_policy.json`, `aws/lbc-trust-policy.json`.
- PVC-backed nginx app depends on [storage.md](storage.md) (gp3).

## Architecture / flow

```text
Client
  |
  v
ALB (internet-facing)
  |
  v
Ingress rules → Service → Pods
```

## Official references

- [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) (Kubernetes)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) (project docs)
- [Ingress annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/ingress/annotations/) (LBC)

## Lab setup

Prerequisites: AWS Load Balancer Controller installed; gp3 StorageClass available.

From the **repo root**:

```powershell
kubectl apply -f manifests/gp3-storageclass.yaml
kubectl apply -f manifests/nginx-pvc.yaml
kubectl apply -f manifests/nginx-deployment.yaml
kubectl apply -f manifests/nginx-service.yaml
kubectl apply -f manifests/nginx-ingress.yaml

kubectl get ingress nginx
kubectl describe ingress nginx

kubectl get ingress nginx -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"; Write-Host
# curl http://<hostname>/ when ADDRESS is set
```

## Cleanup

Delete the Ingress **before** destroying the cluster so ALBs are not orphaned.

```powershell
kubectl delete -f manifests/nginx-ingress.yaml --ignore-not-found
kubectl delete -f manifests/nginx-service.yaml --ignore-not-found
kubectl delete -f manifests/nginx-deployment.yaml --ignore-not-found
kubectl delete -f manifests/nginx-pvc.yaml --ignore-not-found
```

ALB deletion can take several minutes after the Ingress is removed.
