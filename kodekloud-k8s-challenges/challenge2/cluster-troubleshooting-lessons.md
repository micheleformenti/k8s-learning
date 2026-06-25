# KodeKloud Challenge 2: Cluster Troubleshooting Lessons

This lab is useful because it breaks the cluster at several different layers.
Each failure changes which tools are available and which part of the system you
need to inspect.

The main lesson is to avoid treating "Kubernetes is broken" as one kind of
problem. A cluster can fail at the kubelet/static-pod layer, the API access
layer, the scheduling layer, or the cluster add-on layer.

## Troubleshooting Ladder

Use this mental checklist when working through a broken cluster:

1. Can the kubelet run the control plane static pods?
2. Can the API server start?
3. Can `kubectl` reach the API server?
4. Can the scheduler place workloads on nodes?
5. Are system add-ons, such as CoreDNS, healthy?
6. Can application pods communicate through Services and DNS?

This lab walks through several of those layers in order.

## 1. API Server Broken

### Symptom

`kubectl` could not reach the cluster:

```sh
kubectl get pods
```

Result:

```text
connection refused
```

At this point, `kubectl` was not the right tool because the API server itself
was not running.

### Investigation

Move down to the node/container runtime level on the control plane node:

```sh
journalctl -u kubelet
```

The kubelet logs had a lot of noise, so the next useful step was checking the
containers directly:

```sh
crictl ps -a
```

The API server container was in an exited state.

Check the API server container logs:

```sh
crictl logs <container-id>
```

The useful error was:

```text
"command failed" err="open /etc/kubernetes/pki/ca-authority.crt: no such file or directory"
```

Check what certificate files actually exist:

```sh
ls /etc/kubernetes/pki/
```

The file was named:

```text
ca.crt
```

Search the Kubernetes configuration for the wrong filename:

```sh
grep "ca-authority.crt" -r /etc/kubernetes
```

Result:

```text
/etc/kubernetes/manifests/kube-apiserver.yaml:
  - --client-ca-file=/etc/kubernetes/pki/ca-authority.crt
```

### Fix

The API server is a static pod managed by kubelet from:

```text
/etc/kubernetes/manifests/kube-apiserver.yaml
```

Fix the bad certificate filename:

```sh
sed -i 's/ca-authority.crt/ca.crt/g' /etc/kubernetes/manifests/kube-apiserver.yaml
```

Then check the containers again:

```sh
crictl ps
```

The API server should now be running.

### Lesson

When the API server is down, Kubernetes object commands are not enough. You need
to troubleshoot from the node level:

```sh
systemctl status kubelet
journalctl -u kubelet
crictl ps -a
crictl logs <container-id>
```

The API server is itself a container. If it cannot start, the kubelet and
container runtime are your first useful sources of truth.

## 2. `kubectl` Config Broken

### Symptom

After the API server was fixed, `kubectl` still failed:

```sh
kubectl get pods
```

Result:

```text
The connection to the server controlplane:6433 was refused - did you specify the right host or port?
```

This was a different problem from the API server crash. The API server was now
running, but the client configuration was pointing to the wrong port.

### Investigation

Check which ports are actually listening:

```sh
ss -tlnp
```

The correct API server port was:

```text
6443
```

Check the kubeconfig:

```sh
kubectl config view
```

The configured server was wrong:

```text
server: https://controlplane:6433
```

### Fix

Set the Kubernetes cluster endpoint to the correct API server port:

```sh
kubectl config set clusters.kubernetes.server https://controlplane:6443
```

Verify:

```sh
kubectl get pods
```

This should work now.

### Lesson

Separate these two questions:

```text
Is the API server running?
Can my client reach the API server using the current kubeconfig?
```

A working API server does not guarantee that `kubectl` is configured correctly.

## 3. Scheduling Broken Because Worker Node Was Cordoned

### Symptom

Run a simple test pod:

```sh
kubectl run nginx --image nginx:latest
```

The pod stayed pending:

```sh
kubectl get pods
```

### Investigation

Describe the pending pod:

```sh
kubectl describe pod nginx
```

The scheduler explained why it could not place the pod:

```text
0/2 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 1 node(s) were unschedulable. preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.
```

Check the nodes:

```sh
kubectl get nodes
```

The worker node showed:

```text
node01  Ready,SchedulingDisabled
```

### Fix

Uncordon the worker node:

```sh
kubectl uncordon node01
```

Check the nodes again:

```sh
kubectl get nodes
```

Expected:

```text
node01  Ready
```

Check the test pod:

```sh
kubectl get pods
```

The `nginx` pod should now be running.

Clean up the test pod:

```sh
kubectl delete pod nginx
```

### Lesson

A working API server does not mean workloads can be scheduled.

For pending pods, use:

```sh
kubectl describe pod <pod-name>
kubectl get nodes
```

The pod phase tells you which subsystem to inspect next. `Pending` usually
points toward scheduling, taints, cordoned nodes, missing resources, or volume
binding problems.

## 4. CoreDNS Broken

### Symptom

After the cluster was otherwise usable, CoreDNS was still unhealthy:

```sh
kubectl get pods -A
```

CoreDNS showed:

```text
ImagePullBackOff
```

### Investigation

Describe the CoreDNS pod:

```sh
kubectl describe pod coredns-84bfc864f-kbtvl -n kube-system
```

The image was invalid:

```text
registry.k8s.io/kubedns:1.3.1: not found
```

Check deployments:

```sh
kubectl get deploy -A
```

Inspect the CoreDNS deployment:

```sh
kubectl describe deploy coredns -n kube-system
```

### Fix

Edit the CoreDNS deployment:

```sh
kubectl edit deploy coredns -n kube-system
```

Replace the bad `kubedns` image with the correct CoreDNS image used by the lab.

Restart the deployment:

```sh
kubectl rollout restart deploy coredns -n kube-system
```

Verify:

```sh
kubectl get pods -A
```

CoreDNS should now be running.

### Lesson

CoreDNS is not required for `kubectl get pods` to work, so the cluster can look
partially healthy even while DNS is broken.

Broken CoreDNS usually affects application behavior inside the cluster. Symptoms
can include:

- pods running but failing to connect to service names
- app logs showing name resolution failures
- `nslookup` failing from inside a test pod
- CoreDNS pods in `ImagePullBackOff` or `CrashLoopBackOff`

Useful checks:

```sh
kubectl get pods -n kube-system
kubectl describe pod <coredns-pod> -n kube-system
kubectl describe deploy coredns -n kube-system
```

## Recommended Repeat Flow

If repeating the lab for better practice, do not fix everything immediately.
Let each layer reveal itself.

1. Fix only the API server.
2. Then fix `kubectl` access.
3. Run a simple test pod and discover the scheduling issue.
4. Deploy the assignment objects.
5. Observe application or DNS symptoms caused by broken CoreDNS.
6. Then investigate and fix CoreDNS.

That order builds a better troubleshooting habit because it follows symptoms
instead of jumping straight to the known answers.

## General Lessons

### Use the right layer of tools

If the API server is down, use node and runtime tools:

```sh
journalctl -u kubelet
crictl ps -a
crictl logs <container-id>
```

If the API server is up but `kubectl` fails, check client configuration:

```sh
kubectl config view
ss -tlnp
```

If pods are pending, check scheduler feedback:

```sh
kubectl describe pod <pod-name>
kubectl get nodes
```

If system pods are failing, inspect `kube-system`:

```sh
kubectl get pods -n kube-system
kubectl describe pod <pod-name> -n kube-system
```

### Classify the failure before fixing it

Common symptoms point to different layers:

| Symptom | Likely Layer |
| --- | --- |
| `connection refused` before API server is running | control plane / static pod |
| API server container exited | kubelet / container runtime / static pod manifest |
| wrong port in kubeconfig | client configuration |
| pod stuck `Pending` | scheduler / node availability |
| `SchedulingDisabled` | cordoned node |
| `ImagePullBackOff` | image name, tag, registry, or pull credentials |
| service names do not resolve | CoreDNS / cluster DNS |

### Do not trust one green signal too much

`kubectl get nodes` working only proves that the API server can answer that
request. It does not prove that scheduling, DNS, networking, or application
traffic are healthy.

The stronger question is:

```text
Can this cluster actually run workloads and let them communicate normally?
```

