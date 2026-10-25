# Lab troubleshooting

Use these checks before changing a manifest or deleting infrastructure. Most failures are visible in events or controller status.

## Start with object status and events

```powershell
kubectl get pods -A -o wide
kubectl get events -A --sort-by=.lastTimestamp | Select-Object -Last 30
kubectl describe pod <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --all-containers
```

## Common symptoms

| Symptom | Checks |
|---|---|
| Pod stuck `Pending` | `kubectl describe pod`; check scheduler events, node capacity/taints, PVC status, affinity, and topology constraints. |
| `ImagePullBackOff` | Check image name/tag, registry access, and `kubectl describe pod` events. |
| Service has no endpoints | Compare `kubectl get svc <name> -o yaml` selector with Pod labels; inspect readiness probes and EndpointSlices. |
| PVC stuck `Pending` | Check StorageClass, CSI controller Pods/logs, access mode, and `WaitForFirstConsumer` (a consumer Pod may be required). |
| EBS attach or mount failure | Confirm EBS CSI controller/node Pods are ready, the IAM/Pod Identity role is associated, and the volume's Availability Zone matches the scheduled node. |
| EFS mount failure | Check EFS CSI Pods and Pod Identity, mount targets in the node's AZ, NFS port 2049 from node security group, and the filesystem ID in the PV. |
| `kubectl top` unavailable / HPA metrics `<unknown>` | Check Metrics Server rollout, `kubectl get apiservice v1beta1.metrics.k8s.io`, and `kubectl top pods -A`. Ensure the target container has CPU requests. |
| AWS SDK reports missing credentials in a Pod | Check the ServiceAccount name, EKS Pod Identity association, Pod Identity Agent, role trust/policy, and recreate the Pod after changing identity configuration. |
| LoadBalancer / ALB not provisioned | Check controller installation and IAM permissions, subnet discovery/tags, controller logs, and Kubernetes events on the Service or Ingress/Gateway. |
| NetworkPolicy appears ineffective | Verify the CNI supports enforcement and the EKS VPC CNI NetworkPolicy feature is enabled; inspect policy and Pod selectors. |

For an AWS-backed resource that remains after deleting Kubernetes objects, inspect the relevant AWS service and Terraform state before manually removing it. EBS PVs using `Retain` may leave volumes behind by design.

## More references

- [Debugging Pods](https://kubernetes.io/docs/tasks/debug/debug-application/)
- [Debugging Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- [EKS troubleshooting](https://docs.aws.amazon.com/eks/latest/userguide/troubleshooting.html)
