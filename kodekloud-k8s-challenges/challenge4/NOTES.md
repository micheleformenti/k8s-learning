# Challenge 4 Notes

This challenge deploys a six-node Redis cluster with persistent storage.

The main idea is that a StatefulSet creates stable Redis pods, and each pod gets
its own PersistentVolumeClaim. The PVCs bind to pre-created hostPath
PersistentVolumes so every Redis replica has separate storage.

## Objects Created

| File | Object | Purpose |
| --- | --- | --- |
| `pv.yaml` | `PersistentVolume/redis01` through `redis06` | Provides six separate 1Gi hostPath volumes. |
| `configmap.yaml` | `ConfigMap/redis-cluster-configmap` | Stores `redis.conf` and the startup helper script exported from the cluster. |
| `statefulset.yaml` | `StatefulSet/redis-cluster` | Runs six Redis pods with stable names and per-pod PVCs. |
| `service.yaml` | `Service/redis-cluster-service` | Exposes Redis client and gossip ports inside the cluster. |
| `create_hostpath.sh` | shell script | Creates the local hostPath directories used by the PVs. |
| `init_cluster.sh` | kubectl command | Initializes the Redis cluster with three masters and three replicas. |

## Persistent Volumes

The challenge uses six static PersistentVolumes:

- `redis01`
- `redis02`
- `redis03`
- `redis04`
- `redis05`
- `redis06`

Each PV:

- Provides `1Gi`
- Uses access mode `ReadWriteOnce`
- Uses `storageClassName: ""`
- Has label `purpose: redis-storage`
- Uses a separate hostPath directory: `/redis01` through `/redis06`

The StatefulSet's `volumeClaimTemplates` requests `1Gi`, `ReadWriteOnce`, and
selects PVs with:

```yaml
selector:
  matchLabels:
    purpose: redis-storage
```

Because this is static provisioning, the empty storage class is important. It
keeps Kubernetes from trying to dynamically provision a volume through a default
StorageClass.

Useful checks:

```sh
kubectl get pv
kubectl get pvc
kubectl describe pvc data-redis-cluster-0
```

## StatefulSet

The StatefulSet is named `redis-cluster` and creates six pods:

- `redis-cluster-0`
- `redis-cluster-1`
- `redis-cluster-2`
- `redis-cluster-3`
- `redis-cluster-4`
- `redis-cluster-5`

Each pod runs `redis:5.0.1-alpine` and exposes:

- Client port `6379`
- Cluster gossip port `16379`

The ConfigMap is mounted at `/conf`, and the data PVC is mounted at `/data`.
Redis stores its cluster node file at `/data/nodes.conf`, so the cluster identity
is kept with the pod's persistent data.

Useful checks:

```sh
kubectl get statefulset redis-cluster
kubectl get pods -l app=redis-cluster
kubectl get pvc -l app=redis-cluster
kubectl logs redis-cluster-0
```

## ConfigMap

The ConfigMap already existed in the cluster and was exported into
`configmap.yaml` so the solution can be tracked in git.

It contains:

- `redis.conf`, enabling Redis cluster mode and append-only persistence.
- `update-node.sh`, which updates the pod IP in `/data/nodes.conf` before
  starting Redis.

The StatefulSet mounts this ConfigMap with `defaultMode: 0755` so
`update-node.sh` is executable.

## Service

The Service selects pods with:

```yaml
app: redis-cluster
```

It exposes two ports:

- `6379` named `client`
- `16379` named `gossip`

For StatefulSets, the `serviceName` field is the governing Service used for
stable network identity. If pod DNS or Redis cluster discovery fails, check that
the StatefulSet `serviceName` points at the intended Service.

Useful checks:

```sh
kubectl get svc redis-cluster-service
kubectl describe svc redis-cluster-service
kubectl get endpoints redis-cluster-service
```

## Cluster Initialization

After all six pods are running, initialize the Redis cluster:

```sh
./init_cluster.sh
```

The script runs:

```sh
kubectl exec -it redis-cluster-0 -- redis-cli --cluster create --cluster-replicas 1 $(kubectl get pods -l app=redis-cluster -o jsonpath='{range.items[*]}{.status.podIP}:6379 {end}')
```

`--cluster-replicas 1` means Redis creates three masters and assigns one replica
to each master.

Useful checks after initialization:

```sh
kubectl exec -it redis-cluster-0 -- redis-cli cluster info
kubectl exec -it redis-cluster-0 -- redis-cli cluster nodes
```

## Takeaways

- StatefulSets are the right controller when pods need stable names and stable
  storage.
- `volumeClaimTemplates` creates one PVC per pod.
- Static PV binding can be controlled with labels, selectors, and an empty
  storage class.
- Each Redis node needs its own durable `/data` volume because `nodes.conf` and
  append-only files are part of the node's state.
- Exporting pre-existing cluster resources into git makes the final solution
  reproducible.
