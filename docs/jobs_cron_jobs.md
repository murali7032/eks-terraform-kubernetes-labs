# Jobs and CronJobs

> Use a **Job** for finite work that must run to completion. Use a **CronJob** to create Jobs on a schedule.

## Introduction

A [Job](https://kubernetes.io/docs/concepts/workloads/controllers/job/) creates one or more Pods and retries failures until the success criteria (or `backoffLimit`) is met. A [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) creates Jobs according to a cron schedule.

## Explanation

### Job

- `.spec.template.spec.restartPolicy` must be `Never` or `OnFailure` (not `Always`).
- With `restartPolicy: Never`, a failed container leaves a failed Pod; the Job controller may create a **new** Pod to retry (up to `backoffLimit`, default **6**).
- Completed Pods often remain so you can inspect logs until TTL / manual cleanup.

### CronJob

- `.spec.schedule` uses standard cron syntax (example: `*/2 * * * *` = every two minutes).
- History: `successfulJobsHistoryLimit` (default 3), `failedJobsHistoryLimit` (default 1).
- `startingDeadlineSeconds` limits how late a missed run may start.
- `concurrencyPolicy`: `Allow` | `Forbid` | `Replace`.

## Architecture / flow

```text
CronJob (schedule)
    |
    | creates
    v
  Job
    |
    | creates / retries Pods
    v
 Pod(s) run to completion
```

## Official references

- [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/) (Kubernetes)
- [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) (Kubernetes)
- [Run Automated Tasks with a CronJob](https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/) (Kubernetes)

## Lab setup

From the **repo root**.

### 1. One-shot Job

```powershell
kubectl apply -f manifests/hello-job.yaml
kubectl get jobs
kubectl get pods -l job-name=hello-job
kubectl get job hello-job
kubectl logs job/hello-job
```

### 2. CronJob

```powershell
kubectl apply -f manifests/hello-cronjob.yaml
kubectl get cronjob hello-cron
kubectl get jobs --sort-by=.metadata.creationTimestamp
```

### 3. Job retries (`backoffLimit`)

```powershell
kubectl apply -f manifests/job-retry.yaml
kubectl get job retry-demo
kubectl get pods -l job-name=retry-demo
kubectl describe job retry-demo
```

## Cleanup

```powershell
kubectl delete -f manifests/hello-job.yaml --ignore-not-found
kubectl delete -f manifests/hello-cronjob.yaml --ignore-not-found
kubectl delete -f manifests/job-retry.yaml --ignore-not-found
```
