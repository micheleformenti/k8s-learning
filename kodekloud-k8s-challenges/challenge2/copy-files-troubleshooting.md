# Copying Files Into The PVC

The direct copy failed:

```sh
k cp /media/ gop-file-server:/web
```

Error:

```text
exec: "tar": executable file not found in $PATH
```

`kubectl cp` uses `tar` inside the target container. The `kodekloud/fileserver`
image does not include it, so the copy cannot be unpacked in the app container.

Use a temporary helper pod with the same PVC mounted instead:

```sh
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: pvc-helper-pod
spec:
  nodeName: node01
  containers:
  - name: helper
    image: alpine
    command: ["sh", "-c", "sleep 3600"]
    volumeMounts:
    - mountPath: /web
      name: web-storage
  volumes:
  - name: web-storage
    persistentVolumeClaim:
      claimName: data-pvc
EOF

kubectl cp /media/* pvc-helper-pod:/web/  

kubectl delete pod pvc-helper-pod
```

The helper pod runs on `node01` because the PV uses `hostPath`. That storage is
node-local, so the pod must mount the PVC on the same node that owns `/web`.
