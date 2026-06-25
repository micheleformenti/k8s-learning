# KodeKloud Challenge 1 Notes

This challenge builds a small Jekyll app on Kubernetes with persistent storage, a NodePort Service, and namespace-scoped RBAC for user `martin`.

## Objects Created

| File | Object | Purpose |
| --- | --- | --- |
| `pv.yaml` | `PersistentVolume/jekyll-site` | Provides 1Gi of hostPath-backed storage from `/mnt/data`. |
| `pvc.yaml` | `PersistentVolumeClaim/jekyll-site` | Requests the `jekyll-site` PV in the `development` namespace. |
| `pod.yaml` | `Pod/jekyll` | Runs the Jekyll app and mounts the PVC at `/site`. |
| `service.yaml` | `Service/jekyll-node-service` | Exposes the Jekyll pod on NodePort `30097`. |
| `role.yaml` | `Role/developer-role` | Allows access to pods, services, and PVCs in the `development` namespace. |
| `rolebinding.yaml` | `RoleBinding/developer-rolebinding` | Binds `developer-role` to user `martin`. |
| `setup_user.sh` | kubectl config commands | Adds credentials and a kubectl context for user `martin`. |

## Storage

The persistent storage is split into a PV and PVC.

The PV:

- Name: `jekyll-site`
- Capacity: `1Gi`
- Access mode: `ReadWriteMany`
- Storage class: `local-storage`
- Backend: `hostPath` at `/mnt/data`
- Pre-bound to claim `development/jekyll-site` with `claimRef`

The PVC:

- Name: `jekyll-site`
- Namespace: `development`
- Requests `1Gi`
- Uses `ReadWriteMany`
- Uses storage class `local-storage`
- Binds directly to PV `jekyll-site` with `volumeName`

Useful checks:

```sh
kubectl get pv jekyll-site
kubectl get pvc jekyll-site -n development
kubectl describe pvc jekyll-site -n development
```

## Pod

The `jekyll` pod runs in the `development` namespace and uses label `run: jekyll`.

It has:

- An init container named `copy-jekyll-site`
- A main container named `jekyll`
- A shared volume named `site`
- A PVC mount at `/site`

The init container creates the Jekyll site content in `/site`. The main container serves the site on port `4000`.

Useful checks:

```sh
kubectl get pod jekyll -n development
kubectl describe pod jekyll -n development
kubectl logs jekyll -n development
```

## Service

The Service exposes the Jekyll pod through a NodePort.

- Name: `jekyll-node-service`
- Namespace: `development`
- Type: `NodePort`
- Selector: `run: jekyll`
- Service port: `4000`
- Target port: `4000`
- NodePort: `30097`

Useful checks:

```sh
kubectl get svc jekyll-node-service -n development
kubectl describe svc jekyll-node-service -n development
```

Access pattern:

```text
http://<node-ip>:30097
```

## RBAC

The Role is namespace-scoped to `development`.

`developer-role` allows all verbs on these core resources:

- `pods`
- `services`
- `persistentvolumeclaims`

The RoleBinding assigns this Role to user `martin`.

Useful checks:

```sh
kubectl get role developer-role -n development
kubectl get rolebinding developer-rolebinding -n development
kubectl describe role developer-role -n development
kubectl describe rolebinding developer-rolebinding -n development
```

Permission checks:

```sh
kubectl auth can-i get pods --as martin -n development
kubectl auth can-i create services --as martin -n development
kubectl auth can-i delete pvc --as martin -n development
```

## RBAC Lessons Learned

The main new concept in this challenge was RBAC.

RBAC separates identity from permissions:

- `setup_user.sh` configures the Kubernetes user identity `martin`.
- `role.yaml` defines what actions are allowed.
- `rolebinding.yaml` assigns those permissions to `martin`.

The Role is namespace-scoped. Because `developer-role` is created in namespace `development`, it only grants permissions inside `development`.

The Role grants access to three resource types:

- `pods`
- `services`
- `persistentvolumeclaims`

It does not grant access to cluster-scoped resources like `persistentvolumes`, and it does not grant access in other namespaces.

The RoleBinding is the link between the user and the Role:

```text
User martin -> RoleBinding developer-rolebinding -> Role developer-role
```

To check RBAC, use `kubectl auth can-i`:

```sh
kubectl auth can-i get pods --as martin -n development
kubectl auth can-i get persistentvolumes --as martin
kubectl auth can-i get pods --as martin -n default
```

Expected result:

- `martin` can manage pods, services, and PVCs in `development`.
- `martin` cannot manage PVs because PVs are cluster-scoped.
- `martin` cannot manage resources in another namespace unless another RoleBinding grants access there.

## Kubectl User Configuration

The user setup script configures credentials for `martin`:

```sh
kubectl config set-credentials martin \
  --client-certificate=/root/martin.crt \
  --client-key=/root/martin.key
```

It then creates and switches to a context named `developer`:

```sh
kubectl config set-context developer \
  --user=martin \
  --namespace=development

kubectl config use-context developer
```

The context namespace is `development`, matching the namespace used by the manifests.

Check the active context:

```sh
kubectl config current-context
kubectl config view --minify
```

## Suggested Apply Order

Create the namespace first if it does not already exist:

```sh
kubectl create namespace development
```

Then apply the manifests:

```sh
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml
kubectl apply -f pod.yaml
kubectl apply -f service.yaml
kubectl apply -f role.yaml
kubectl apply -f rolebinding.yaml
```

Configure the user context:

```sh
sh setup_user.sh
```

## Troubleshooting Checklist

- PV and PVC should both show `Bound`.
- Pod should show `Running`.
- Service selector `run: jekyll` must match the pod label.
- NodePort `30097` must be reachable from the node network.
- User `martin` should be able to manage pods, services, and PVCs only inside namespace `development`.
- If commands run as `martin` cannot find resources, check that the active context namespace is `development`.
