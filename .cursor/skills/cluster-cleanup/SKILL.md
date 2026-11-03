---
name: cluster-cleanup
description: "Clean up the demo cluster, removing deployed operators and platform components."
---

# Cluster Cleanup

Remove all platform components from the cluster to reset it to a clean state.

**Full guide:** [docs/cluster-bootstrap.md](../../docs/cluster-bootstrap.md) (Teardown section)

## Prerequisites

- `oc` CLI authenticated against the target cluster
- Cluster admin permissions
- `helm` CLI installed (v3.x)

## Cleanup

Full stack (OpenShell + RHOAI + operators) — preferred after a demo reset:

```bash
make -C deploy undeploy-everything
make -C deploy validate-cleanup
```

RHOAI platform only:

```bash
make -C deploy undeploy-all
make -C deploy validate-cleanup
```

`make undeploy-all` handles the full RHOAI teardown in the correct order:

| Step | Make target | What it does |
|------|-------------|-------------|
| 1 | `undeploy-apps` | Helm uninstall evalhub/mlflow → **`purge-mlflow-instances`** → database → platform |
| 2 | `purge-mlflow-operator` | Wait for / force-remove Terminating `MLflowOperator` (protection finalizer) |
| 3 | `purge-dsci` | Delete DSCInitialization while operator can still process finalizers |
| 4 | `undeploy-operators` | Helm uninstall: operators |
| 5 | `cleanup-orphans` | Residual subscription/CSV, namespaces, orphan KServe/ODH webhooks |

`undeploy-everything` runs `undeploy-openshell` first, then `undeploy-all`.

### Why MLflow purge is mandatory

Observed **2026-10-30**: cleanup left `default-mlflowoperator` in `Terminating` with
finalizer `mlflow.opendatahub.io/mlflow-operator-protection`. The next
`deploy-all` created a `MLflow` CR while the operator was still deleting →
**deadlock** (operator will not delete while instances exist; instances will not
reconcile while the operator is deleting). `Available=False`, no `Service/mlflow`,
and the openclaw experiment Job fails with curl exit 6.

The Makefile now deletes every `MLflow` instance **before** platform/DSC tear-down
marks the operator for deletion, then waits (and strips the protection finalizer
if the controller is already gone). `validate-cleanup` **fails** if any
`MLflow` or `MLflowOperator` CR remains.

The order is also **critical** for DSCI: it must be deleted before the operator CSV
is removed. The Makefile enforces this and includes a finalizer patch fallback if
the DSCI delete times out.

## Validate

After cleanup, verify the cluster is clean:

```bash
make -C deploy validate-cleanup
```

`make validate-cleanup` checks:

- No `rhoai-*` / OpenShell / openclaw-ui-proxy Helm releases
- No DSCInitialization or DataScienceCluster
- **No `MLflow` or `MLflowOperator` CRs** (deadlock guard)
- Demo namespaces removed (`redhat-ods-operator`, `redhat-ods-applications`,
  `redhat-ods-monitoring`, `evaluation`, `models-as-a-service`,
  `rhoai-model-registries`, `agent-sandbox-system`, `openshell`)

Do **not** start `deploy-all` until `validate-cleanup` exits 0.

## Troubleshooting

Only use these steps when `make undeploy-all` or `make validate-cleanup` reports
failures. Do not run them as part of the normal flow.

### MLflowOperator stuck in Terminating / next install deadlocks

```bash
# 1) Drop every MLflow instance first
oc delete mlflow --all --all-namespaces --timeout=90s
# 2) If still blocked, strip protection finalizer
oc patch mlflowoperator default-mlflowoperator --type=merge \
  -p '{"metadata":{"finalizers":[]}}'
oc delete mlflowoperator default-mlflowoperator --wait=false
make -C deploy validate-cleanup
```

### DSCI stuck in Terminating

If the operator CSV was deleted before DSCI (should not happen with current Makefile):

```bash
oc patch dscinitialization default-dsci --type=merge -p '{"metadata":{"finalizers":[]}}'
```

### Namespace stuck in Terminating

Often caused by orphaned KServe validating webhooks pointing at a deleted
`llmisvc-webhook-server-service` in `redhat-ods-applications`.
`cleanup-orphans` deletes those webhooks; if a namespace is still stuck:

```bash
for ns in redhat-ods-operator redhat-ods-applications redhat-ods-monitoring evaluation models-as-a-service rhoai-model-registries agent-sandbox-system; do
  PHASE=$(oc get namespace "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [ "$PHASE" = "Terminating" ]; then
    echo "Removing finalizers from stuck namespace: $ns"
    oc get namespace "$ns" -o json | \
      jq '.spec.finalizers = []' | \
      oc replace --raw "/api/v1/namespaces/$ns/finalize" -f -
  fi
done
```

### Orphan pods still running

After removing the operator, some pods (dashboard-redirect, maas-controller) may linger:

```bash
oc delete deployment --all -n redhat-ods-applications 2>/dev/null || true
```

## Notes

- Cleanup order is enforced by Makefile dependencies
- After full cleanup, wait ~2 minutes for namespaces to finish terminating before re-bootstrapping
- `purge-dsci` / `purge-mlflow-operator` automatically patch finalizers if delete times out
