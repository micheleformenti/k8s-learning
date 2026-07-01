### Sidecar container for shared logs

#### Goal
Run an nginx container and a helper container in the same Pod so the helper can read nginx log files from shared storage.

#### Setup
The Pod uses an `emptyDir` volume named `shared-logs`.

Both containers mount the same volume at:

```text
/var/log/nginx
```

The nginx container writes its access and error logs there. The sidecar container reads those files in a loop:

```sh
while true; do cat /var/log/nginx/access.log /var/log/nginx/error.log; sleep 30; done
```

#### Important detail
The sidecar is defined under `initContainers`, but it is not a normal init container.

Normal init containers must finish before the main application container starts. A logging sidecar needs to keep running, so it must use:

```yaml
restartPolicy: Always
```

Without `restartPolicy: Always`, Kubernetes treats it like a regular init container. Since the command runs forever, the Pod stays stuck in the init phase and the main nginx container never starts.

#### Learning
Restartable init containers can be used for the sidecar pattern. They start before the app container and keep running alongside it, which makes them useful for log forwarding, file syncing, or other helper processes that support the main container.
