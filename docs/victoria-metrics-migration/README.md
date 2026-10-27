# kube-prometheus-stack → victoria-metrics-k8s-stack (2026-10-27)

Replaces kube-prometheus-stack on the rpi cluster with victoria-metrics-k8s-stack, and
scrapes the k3s control plane properly instead of relabeling the kubelet scrape.

Decided: clean cutover (old 10d of history dropped), vmsingle on longhorn, 30d / 20Gi.

---

## Why

- Prometheus was using ~1.7Gi RAM with 359k head series. ~225k of those came from the
  kubelet `/metrics` scrape, because k3s serves every embedded component's metrics on
  every endpoint (apiserver alone was 153k).
- `KubeAPIDown`, `KubeSchedulerDown` and `KubeProxyDown` had been firing since 2026-06-27.
  Their components were `enabled: true` with `serviceMonitor.enabled: false`, so the
  `absent(up{job=...})` rules shipped with no targets. Relabeling `job` on the kubelet
  scrape doesn't create `up` series.
- etcd was never actually scraped (there was no `up{job="kube-etcd"}`), so the etcd alerts
  could not fire.

## Pieces

| Where | What |
|---|---|
| `apps/templates/victoria-metrics.yaml` | Argo app, chart `victoria-metrics-k8s-stack` 0.97.0 |
| `apps-values/victoria-metrics.yaml` | values; per-component keep/drop relabeling for k3s |
| `apps/templates/prometheus-operator-crds.yaml` | takes over the `monitoring.coreos.com` CRDs from kube-prometheus-stack |
| `charts/prometheus-resources` | unchanged; its PrometheusRules/ScrapeConfigs are converted by the VM operator |
| homelab ansible `playbooks/k3s-metrics.yml` | k3s drop-in exposing scheduler/controller-manager/kube-proxy metrics on node IPs |

Grafana keeps its name (`prometheus-grafana`) so it reuses the `storage-prometheus-grafana-0`
PVC. The datasource UIDs `prometheus` and `alertmanager` are kept, so existing dashboards still resolve.

## Gotchas

- **The CRDs belong to the old Argo app**, which has the cascade finalizer. If you delete the app
  without annotating the CRDs first, it deletes all 10 `monitoring.coreos.com` CRDs, and every
  ServiceMonitor/PodMonitor/PrometheusRule/ScrapeConfig in the cluster goes with them.
- **The root `apps` app has `prune=false`.** Removing the app file from git does nothing to the
  cluster, so the old app has to be deleted by hand.
- **Both stacks' node-exporters bind hostPort 9100.** They can't run side by side.
- **`test-alert` is not in git.** It was applied by hand, but it survives because nothing tracks it,
  and it gets converted to a VMRule.

## Cutover

0. **Nodes (any time before step 5):** run `playbooks/k3s-metrics.yml` from the homelab ansible repo
   (`--limit node1` first if you want to test one node). Old Prometheus is unaffected.
   Check: `curl -s http://192.168.100.52:10249/metrics | head` returns metrics.
1. **PR 1:** delete `apps/templates/prometheus-stack.yaml` and `apps-values/prometheus-stack.yaml`, then merge.
   Nothing happens in the cluster, because the root has `prune=false`.
2. **Protect the CRDs:**
   ```sh
   kubectl --context=rpi get crd -o name | grep monitoring.coreos.com \
     | xargs kubectl --context=rpi annotate argocd.argoproj.io/sync-options=Delete=false
   ```
3. **Delete the old stack:** `kubectl --context=rpi -n argocd delete application prometheus`
   (cascades everything except the annotated CRDs and the StatefulSet PVCs).
   Check: all 10 CRDs still exist, `kubectl get servicemonitors -A` still lists the argocd/longhorn/loki/garage
   monitors, and `storage-prometheus-grafana-0` is still Bound.
4. **PR 2:** add `prometheus-operator-crds.yaml`, `victoria-metrics.yaml` and `apps-values/victoria-metrics.yaml`, then merge.
5. **Verify:** see the next section.
6. **Cleanup (once satisfied):** delete the old NFS PVC
   `prometheus-prometheus-kube-prometheus-prometheus-db-prometheus-prometheus-kube-prometheus-prometheus-0`.
   Leave the `Delete=false` annotation on the CRDs.

Rollback: revert PR 2, then PR 1. Argo recreates kube-prometheus-stack and the old Prometheus PVC is
still there.

## Verify

```sh
# every component target is up (look for kube-scheduler, kube-controller-manager, kube-proxy, kube-etcd, apiserver)
kubectl --context=rpi -n monitoring port-forward svc/vmagent-vm 8429 &
curl -s localhost:8429/api/v1/targets | jq -r '.data.activeTargets[] | "\(.labels.job) \(.health)"' | sort | uniq -c

# converted objects (counts should match the source objects)
kubectl --context=rpi get servicemonitors,podmonitors,scrapeconfigs,prometheusrules -A --no-headers | wc -l
kubectl --context=rpi get vmservicescrapes,vmpodscrapes,vmscrapeconfigs,vmrules -A --no-headers | wc -l

# alert rules: diff against the pre-cutover inventory
kubectl --context=rpi -n monitoring port-forward svc/vmalert-vm 8080 &
curl -s localhost:8080/api/v1/rules | jq -r '.data.groups[].rules[] | select(.type=="alerting") | .name' | sort -u > /tmp/after.txt
cut -f1 alert-rules-before.tsv | sort -u | comm -23 - /tmp/after.txt   # rules that disappeared
```

Rules that disappear because their component went away (Prometheus*, PrometheusOperator*,
ConfigReloaderSidecarErrors) are expected. The VM chart has its own equivalents for vmagent,
vmsingle, vmalert and the operator. Anything else that disappears needs a look.

## Pre-cutover inventory

All alert rules as of 2026-10-27 are in [`alert-rules-before.tsv`](alert-rules-before.tsv):
alert name, severity and source, 142 alerts. The custom ones:

| Rule | Source | Alerts |
|---|---|---|
| `gpu-health-alerts` | `charts/prometheus-resources` | GPUHighTemperature, GPUMetricsMissing |
| `pvc-fill-alerts` | `charts/prometheus-resources` | PVCFillWarning, PVCFillCritical |
| `test-alert` | applied by hand, **not in git** | TestAlert |
| 7 ScrapeConfigs | `charts/prometheus-resources` | opnsense, pi-hole, pve-apps1, smig-inference-gpu, smig-inference-node-exporter, smig-lab-proxmox, smig-zima |

Alerts firing at cutover, and what should happen to each afterwards:

| Alert | Target | Expected after cutover |
|---|---|---|
| KubeAPIDown, KubeSchedulerDown, KubeProxyDown | k3s control plane | **resolves** (real targets now) |
| NodeFilesystemAlmostOutOfSpace (crit+warn) | smig-lab-proxmox `/`, 0% free | keeps firing: real |
| NodeSystemdServiceFailed | smig-lab-proxmox `man-db.service` | keeps firing: real |
| NodeSystemdServiceFailed | rpi3-ubuntu `systemd-networkd-wait-online.service` | keeps firing: real |
| TargetDown | longhorn-system/longhorn-backend | keeps firing until looked at |
| KubeJobFailed ×2 | kube-system/helm-install-traefik(-crd) | keeps firing: stale k3s jobs |
| PVCFillCritical/Warning | monitoring prometheus PVC | resolves (PVC no longer mounted) |
| PVCFillCritical/Warning | nfs-stuff/pvc-nfs-subdir-external-provisioner | keeps firing: NFS reports the whole share's usage, a false positive in the rule |
| TestAlert | n/a | keeps firing (`vector(1)`) |
| Watchdog | n/a | keeps firing (by design) |

Newly possible after cutover: the etcd* alerts, because etcd is actually scraped now.

## Sources

- https://docs.victoriametrics.com/helm/victoria-metrics-k8s-stack/
- https://docs.victoriametrics.com/operator/migration/
- https://docs.k3s.io/installation/configuration#configuration-file
- https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/#no-resource-deletion
