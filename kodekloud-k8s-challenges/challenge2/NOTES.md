# Challenge 2 Notes

This lab covers a broken Kubernetes cluster plus a small file-server workload.
The goal is not only to create the final resources, but to troubleshoot each
layer in the right order.

## Scope

- Repair control plane access.
- Fix local `kubectl` connectivity.
- Restore workload scheduling on `node01`.
- Fix the cluster add-on issue affecting CoreDNS.
- Deploy a file server backed by a PVC.
- Copy the provided files into the mounted storage.

## Files

- `cluster-troubleshooting-lessons.md`: step-by-step notes for the broken
  cluster issues.
- `copy-files-troubleshooting.md`: why direct `kubectl cp` failed and how the
  helper pod solved the PVC copy.
- `yaml/pv.yaml`: static `hostPath` PersistentVolume using `/web`.
- `yaml/pvc.yaml`: claim bound to the static PV.
- `yaml/pod.yaml`: `kodekloud/fileserver` pod mounting the PVC at `/web`.
- `yaml/service.yaml`: ClusterIP Service exposing the file server on port 8080.

## Troubleshooting Path

Follow symptoms by layer:

1. If `kubectl` cannot reach the API server, inspect kubelet and static pods.
2. If the API server is running but `kubectl` still fails, check kubeconfig.
3. If pods stay `Pending`, inspect scheduler events and node state.
4. If system pods fail, check `kube-system`, especially CoreDNS.
5. If the app runs but files are missing, check the PVC mount and file copy path.

## Storage Note

The PV uses `hostPath`, so the data lives on the node filesystem at `/web`.
That storage is node-local, even though the PVC requests `ReadWriteMany`.

For the file copy, direct `kubectl cp` into the app container failed because the
custom `kodekloud/fileserver` image does not include `tar`. The workaround is a
temporary helper pod on `node01` that mounts the same PVC.