# RBAC (Role-Based Access Control)

> After authentication answers “who are you?”, RBAC answers “what are you allowed to do?” on the Kubernetes API.

## Introduction

Kubernetes [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) authorizes API requests using **Roles** / **ClusterRoles** (permissions) bound to users, groups, or **ServiceAccounts** via **RoleBindings** / **ClusterRoleBindings**.

## Explanation

| Object | Scope | Purpose |
|--------|--------|---------|
| `Role` | Namespace | Verbs on resources in one namespace |
| `ClusterRole` | Cluster | Cluster-wide permissions (or reusable set bound into a namespace) |
| `RoleBinding` | Namespace | Binds a Role or ClusterRole to subjects in a namespace |
| `ClusterRoleBinding` | Cluster | Binds a ClusterRole cluster-wide |
| `ServiceAccount` | Namespace | Identity Pods use to call the API |

Common verbs: `get`, `list`, `watch`, `create`, `update`, `patch`, `delete`.

## Architecture / flow

```text
kubectl / Pod
      |
      v
 API Server
      |
      +--> Authentication  (who?)
      |
      +--> Authorization   (RBAC: what?)
      |
      v
 Allow or deny
```

Lab binding:

```text
ServiceAccount: rbac-reader
        |
        | RoleBinding
        v
Role: (configmap reader)
        |
        v
get, list ConfigMaps in default only
```

## Official references

- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) (Kubernetes)
- [Configure Service Accounts for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) (Kubernetes)
- [kubectl auth can-i](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_auth/kubectl_auth_can-i/) (Kubernetes)

## Lab setup

From the **repo root**:

```powershell
kubectl apply -f manifests/rbac-reader.yaml

kubectl auth can-i get configmaps -n default --as=system:serviceaccount:default:rbac-reader
kubectl auth can-i list configmaps -n default --as=system:serviceaccount:default:rbac-reader
kubectl auth can-i delete configmaps -n default --as=system:serviceaccount:default:rbac-reader
kubectl auth can-i get secrets -n default --as=system:serviceaccount:default:rbac-reader
kubectl auth can-i get configmaps -n kube-system --as=system:serviceaccount:default:rbac-reader
```

Expect: `get`/`list` ConfigMaps in `default` → **yes**; `delete`, Secrets, and `kube-system` → **no**.

## Cleanup

```powershell
kubectl delete -f manifests/rbac-reader.yaml
```
