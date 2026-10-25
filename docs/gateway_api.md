# Gateway API on EKS (AWS Load Balancer Controller)

> Use Kubernetes **Gateway API** (`GatewayClass`, `Gateway`, `HTTPRoute`) with the **AWS Load Balancer Controller** so an Application Load Balancer fronts your Services.

## Introduction

[Gateway API](https://gateway-api.sigs.k8s.io/) is the portable traffic API that many controllers implement instead of (or alongside) classic Ingress. On Amazon EKS, the [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) can reconcile Gateway API resources when you use the ALB GatewayClass (`gateway.k8s.aws/alb`).

CRDs alone do nothing. You need:

1. Gateway API CRDs  
2. AWS Load Balancer Controller (with IAM / Pod Identity)  
3. `GatewayClass` → `Gateway` → app Service → `HTTPRoute`

## Explanation

| Resource | Role |
|----------|------|
| `GatewayClass` | Selects which controller implements Gateways (`controllerName: gateway.k8s.aws/alb`) |
| `Gateway` | Cluster entry point: listeners (protocol/port); controller provisions the ALB |
| `HTTPRoute` | Matches paths/hosts and forwards to backend Services |
| Controller | Watches these objects and configures AWS ALB / target groups |

Subnet requirements for an internet-facing ALB:

- Public subnets tagged `kubernetes.io/role/elb=1`
- Cluster tag `kubernetes.io/cluster/<cluster-name>=shared` (or `owned`)

This repo’s manifests:

| File | Purpose |
|------|---------|
| `manifests/gatewayclass.yaml` | `GatewayClass` named `aws-alb` |
| `manifests/gateway.yaml` | `Gateway` `app-gateway` (HTTP :80) |
| `manifests/gateway-demo.yaml` | Demo Deployment + NodePort Service |
| `manifests/httproute.yaml` | Route `/` → `gateway-demo:80` |
| `aws/iam_policy.json`, `aws/lbc-trust-policy.json` | Sample IAM for the controller |

## Architecture / flow

### Control plane (what you apply)

```text
GatewayClass (aws-alb)
        │  controllerName: gateway.k8s.aws/alb
        ▼
AWS Load Balancer Controller
        │
        ▼
     Gateway (listeners)
        │
        ▼
    HTTPRoute (matches / backends)
        │
        ▼
     Service → Pods
```

### Data plane (request path)

```text
Client
  │
  ▼
ALB (provisioned by controller)
  │
  ▼
Target group → NodePort / Pod targets
  │
  ▼
gateway-demo Pods (:80)
```

### IAM (Pod Identity)

```text
ServiceAccount: kube-system/aws-load-balancer-controller
        │
        ▼
  EKS Pod Identity association
        │
        ▼
IAM role (e.g. AWSLoadBalancerControllerRole)
        │
        ▼
IAM policy (ALB / EC2 / ELB permissions)
```

## Official references

- [Gateway API](https://gateway-api.sigs.k8s.io/) (SIG Network)
- [API overview](https://gateway-api.sigs.k8s.io/concepts/api-overview/) (SIG Network)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/) (project docs)
- [Gateway API support (LBC)](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/guide/gateway/) (LBC)
- [EKS Pod Identity](https://docs.aws.amazon.com/eks/latest/userguide/pod-identities.html) (AWS)
- [Subnet tagging for load balancers](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/subnet_discovery/) (LBC)

## Lab setup

Run commands from the **repo root**. Replace `<cluster-name>`, `<region>`, `<profile>`, `<account-id>`, `<vpc-id>`, and subnet IDs.

### 1. Install Gateway API CRDs

```powershell
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml

kubectl get crd gateways.gateway.networking.k8s.io
kubectl get crd httproutes.gateway.networking.k8s.io
kubectl get crd gatewayclasses.gateway.networking.k8s.io
```

### 2. IAM role and policy for the controller

If the role does not exist yet, create it from the sample policy/trust docs under `aws/` (or the [upstream IAM policy](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json)).

```powershell
aws iam get-role --role-name AWSLoadBalancerControllerRole --profile <profile>
```

### 3. ServiceAccount, then Pod Identity association

Create the ServiceAccount **before** Helm install when `serviceAccount.create=false`.

```powershell
kubectl create serviceaccount aws-load-balancer-controller -n kube-system
kubectl get serviceaccount aws-load-balancer-controller -n kube-system

aws eks create-pod-identity-association `
  --cluster-name <cluster-name> `
  --namespace kube-system `
  --service-account aws-load-balancer-controller `
  --role-arn arn:aws:iam::<account-id>:role/AWSLoadBalancerControllerRole `
  --region <region> `
  --profile <profile>

aws eks list-pod-identity-associations `
  --cluster-name <cluster-name> `
  --region <region> `
  --profile <profile>
```

### 4. Install AWS Load Balancer Controller

Use the real **VPC ID** (`vpc-...`), not a CIDR.

```powershell
aws eks describe-cluster `
  --name <cluster-name> `
  --region <region> `
  --profile <profile> `
  --query "cluster.resourcesVpcConfig.vpcId" `
  --output text

helm repo add eks https://aws.github.io/eks-charts
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller `
  --namespace kube-system `
  --set clusterName=<cluster-name> `
  --set serviceAccount.create=false `
  --set serviceAccount.name=aws-load-balancer-controller `
  --set region=<region> `
  --set vpcId=<vpc-id>

kubectl get deployment aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=50
```

### 5. Tag public subnets for the ALB

```powershell
aws ec2 describe-subnets `
  --filters "Name=vpc-id,Values=<vpc-id>" `
  --query "Subnets[].{SubnetId:SubnetId,AZ:AvailabilityZone,Tags:Tags}" `
  --output table `
  --profile <profile>

aws ec2 create-tags `
  --resources <public-subnet-id-1> <public-subnet-id-2> `
  --tags Key=kubernetes.io/role/elb,Value=1 `
  --region <region> `
  --profile <profile>

aws ec2 create-tags `
  --resources <public-subnet-id-1> <public-subnet-id-2> `
  --tags Key=kubernetes.io/cluster/<cluster-name>,Value=shared `
  --region <region> `
  --profile <profile>
```

### 6. Apply GatewayClass, then Gateway

```powershell
kubectl apply -f manifests/gatewayclass.yaml
kubectl get gatewayclass
kubectl describe gatewayclass aws-alb

kubectl apply -f manifests/gateway.yaml
kubectl describe gateway app-gateway -n default
```

Wait until the Gateway shows conditions such as `Accepted` and `Programmed`, and an ALB address appears.

```powershell
kubectl get gateway app-gateway -n default
```

### 7. Deploy the demo app, then HTTPRoute

```powershell
kubectl apply -f manifests/gateway-demo.yaml
kubectl get pods -l app=gateway-demo
kubectl get svc gateway-demo

kubectl apply -f manifests/httproute.yaml
kubectl get httproute gateway-demo-route
kubectl describe httproute gateway-demo-route
```

Confirm the Gateway listener reports an attached route, then test:

```powershell
kubectl get gateway app-gateway -n default -o jsonpath="{.status.addresses[0].value}"; Write-Host

curl.exe http://<alb-dns-name>/
```

Healthy Gateway status looks like:

```text
Gateway app-gateway
  ├── Accepted=True
  ├── Programmed=True
  └── Listener :80
        ├── Accepted=True
        ├── ResolvedRefs=True
        ├── Programmed=True
        └── attachedRoutes=1
              └── HTTPRoute → Service gateway-demo → Pods
```

## Cleanup

Delete routes and the Gateway **before** uninstalling the controller so the ALB is torn down.

```powershell
kubectl delete -f manifests/httproute.yaml --ignore-not-found
kubectl delete -f manifests/gateway.yaml --ignore-not-found
kubectl delete -f manifests/gatewayclass.yaml --ignore-not-found
kubectl delete -f manifests/gateway-demo.yaml --ignore-not-found

helm uninstall aws-load-balancer-controller -n kube-system
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

Optional — remove Gateway API CRDs only if nothing else depends on them:

```powershell
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/standard-install.yaml --ignore-not-found
```
