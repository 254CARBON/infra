# GitOps with ArgoCD

ArgoCD now ships with the platform overlays and manages both the `local` and `dev` environments. This doc captures the moving parts, bootstrap steps, and the promotion workflow between environments.

## Components

- **Namespace & install** — `infra/platform/argocd` kustomize package installs ArgoCD v3.1.8 plus the ApplicationSet controller.
- **Applications**
  - `infra-local` (Application): tracks `infra/k8s/overlays/local` at `HEAD`. Labels identify it as the `local` promotion tier.
  - `infra-dev` (ApplicationSet entry): tracks `infra/k8s/overlays/dev` at `main`. Annotated with `gitops.254carbon.io/promotion-source=local`.
- **Sync options** — Both apps use automated sync, pruning, `CreateNamespace=true`, and `ApplyOutOfSyncOnly=true`. The ApplicationSet applies a sync-wave of `0` for `local` and `1` for `dev` so local changes converge first when both apps target the same cluster.

## Bootstrapping

1. Build or reuse a cluster: `make k3d-up` (or `CLUSTER_PROVIDER=kind make cluster-up`).
2. Apply the platform overlay: `make k8s-apply-platform` (this now includes ArgoCD).
3. Wait for ArgoCD pods to go Ready:
   ```bash
   kubectl -n argocd get pods
   ```
4. Port-forward the UI and log in:
   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:443
   argocd login localhost:8080 \
     --username admin \
     --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)"
   ```
   You can then open `https://localhost:8080` in a browser or use the CLI exclusively.

## Promotion Workflow (local ➜ dev)

1. **Iterate locally**
   - Edit manifests under `infra/k8s/base` or `infra/k8s/platform`.
   - Run `make validate` to render, lint, and apply policies.
   - Commit to your feature branch. ArgoCD (`infra-local`) continuously reconciles `HEAD`, so the local cluster reflects your branch as soon as it lands upstream.
2. **Smoke-test via Argo**
   - Watch status: `argocd app get infra-local`.
   - Optionally force a sync: `argocd app sync infra-local`.
3. **Promote to dev**
   - Open a PR and merge to `main`.
   - The ApplicationSet renders `infra-dev` against `infra/k8s/overlays/dev` at `main`; once your PR merges, ArgoCD detects the new commit and syncs automatically.
   - Accelerate the rollout with `argocd app sync infra-dev`.
4. **Verify**
   - Compare states: `argocd app diff infra-dev`.
   - Cluster checks: `make verify` (local) or environment-specific probes for dev.

> Note: Manual `kubectl apply -k ...` is still available for experiments or hotfixes, but treat it as a temporary override and backfill changes through Git to avoid drift.

## Useful Commands

```bash
# List applications
argocd app list

# Tail sync events
argocd app history infra-dev
argocd app wait infra-dev --timeout 120

# Pause automated sync (if needed)
argocd app set infra-dev --sync-policy=none
```

## Future Extensions

- Add a `staging` entry in the ApplicationSet once that overlay stabilises.
- Externalise repo credentials/SSH deploy keys when running in a hosted controller.
- Introduce per-environment ArgoCD Projects for tighter RBAC.
