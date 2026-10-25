# Persistent storage on EKS (EBS gp3 and EFS)

> **PVCs** request storage; a **StorageClass** (or static **PV**) binds backend volumes. This lab uses **EBS CSI** (gp3, RWO) and **EFS CSI** (RWX).

## Introduction

Kubernetes [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) decouple Pods from disk lifecycle. On EKS, the [Amazon EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) and [Amazon EFS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html) provision or attach cloud storage.

## Explanation

| Mode | Typical backend | Use |
|------|-----------------|-----|
| `ReadWriteOnce` (RWO) | EBS gp3 | Single-node writer (databases, local data) |
| `ReadWriteMany` (RWX) | EFS | Shared filesystem across Pods/nodes |

- `volumeBindingMode: WaitForFirstConsumer` delays binding until a Pod is scheduled (AZ-aware).
- Terraform in this repo provisions EBS CSI, EFS CSI with Pod Identity, an encrypted EFS filesystem, and mount targets in the private subnets. The EFS resources are deleted by `terraform destroy`.

## Architecture / flow

```text
Pod
 └── volumeMount
      └── PersistentVolumeClaim
           └── StorageClass / PersistentVolume
                └── EBS (gp3) or EFS
```

## Official references

- [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) (Kubernetes)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/) (Kubernetes)
- [Amazon EBS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html) (AWS)
- [Amazon EFS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html) (AWS)

## Lab setup

From the **repo root**.

### A. Dynamic gp3 (EBS)

```powershell
kubectl apply -f manifests/gp3-storageclass.yaml
kubectl get storageclass gp3

kubectl apply -f manifests/nginx-pvc.yaml
kubectl get pvc nginx-pvc

# Bound after a consumer Pod is scheduled (WaitForFirstConsumer)
kubectl apply -f manifests/nginx-deployment.yaml
kubectl get pvc nginx-pvc
kubectl get pv
```

### B. Static EFS PV + PVC

1. Get the file system ID from Terraform:

```powershell
cd terraform
terraform output -raw efs_file_system_id
cd ..
```

2. Replace `REPLACE_WITH_EFS_FILE_SYSTEM_ID` in `manifests/efs-pv.yaml` with that value. The PV and PVC both use `efs-sc`; no StorageClass object is needed for this static PV.
3. Confirm the EFS CSI controller and node Pods are ready in `kube-system`.

```powershell
kubectl apply -f manifests/efs-pv.yaml
kubectl apply -f manifests/efs-pvc.yaml
kubectl get pv efs-pv
kubectl get pvc efs-pvc
```

Continue with [StatefulSet lab](statefulset.md) to mount `efs-pvc`.

## Cleanup

```powershell
kubectl delete -f manifests/nginx-deployment.yaml --ignore-not-found
kubectl delete -f manifests/nginx-pvc.yaml --ignore-not-found
kubectl delete -f manifests/efs-pvc.yaml --ignore-not-found
kubectl delete -f manifests/efs-pv.yaml --ignore-not-found
# Optionally: kubectl delete -f manifests/gp3-storageclass.yaml
```
