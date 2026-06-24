# Fix cluster

### api-server
* k get pods --> connection refused
* jorunalctl -u kubelet --> lots of noise
* crictl ps -a --> api-server in exited status
* crictl logs <containerid> --> "command failed" err="open /etc/kubernetes/pki/ca-authority.crt: no such file or directory"
* ls /etc/kubernetes/pki/ --> file is called ca.crt
* grep "ca-authority.crt" -r /etc/kubernetes --> /etc/kubernetes/manifests/kube-apiserver.yaml:    - --client-ca-file=/etc/kubernetes/ pki/ca-authority.crt
* sed -i 's/ca-authority.crt/ca.crt/g' /etc/kubernetes/manifests/kube-apiserver.yaml
* crictl ps -> api-server running

### kubectl config
* k get pods --> fails "The connection to the server controlplane:6433 was refused - did you specify the right host or port?"
ss -tlnp --> correct port is 6443
kubectl config view --> server: https://controlplane:6433 --> wrong port
kubectl config set clusters.kubernetes.server https://controlplane:6443
k get pods --> works now!


### test node
k run nginx --image nginx:latest --> test cluster --> pending
k describe pod nginx --> 0/2 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 1 node(s) were unschedulable. preemption: 0/2 nodes are available: 2 Preemption is not helpful for scheduling.
k get nodes --> node01  Ready,SchedulingDisabled
kubectl uncordon node01 --> node01  Ready
k get pods -> nginx running
k delete pod nginx

### coredns
k get pods -A -> coredns ImagePullBackOff
k describe pod coredns-84bfc864f-kbtvl -n kube-system --> registry.k8s.io/kubedns:1.3.1: not found
k get deploy -A
k describe deploy coredns -n kube-system
k edit deploy coredns -n kube-system --> replace kubedns image with coredns
k rollout restart deploy coredns -n kube-system
k get pods -A -> coredns runs!