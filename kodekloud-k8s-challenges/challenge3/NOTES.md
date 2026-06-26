# Challenge 3 Notes

This lab deployed the example voting app as a small asynchronous architecture:

- `vote` receives user votes through a NodePort Service.
- `redis` stores incoming votes temporarily.
- `worker` reads votes from Redis and writes the processed result to Postgres.
- `db` stores the final vote counts.
- `result` reads from Postgres and exposes the result UI through a NodePort Service.

The useful part of this design is seeing the worker in the middle. The frontend does not write directly to the database. Instead, it drops work into Redis, and the worker handles the database write separately. That makes the architecture asynchronous and decouples the vote intake path from the persistence path.

The worker does not need a Service because no other component calls into it. It is an internal background process that initiates outbound connections to Redis and Postgres. Services are needed for components that other Pods or users need to reach through a stable network endpoint.

## `emptyDir`

This lab used `emptyDir` volumes for both Redis and Postgres:

- Redis mounts `emptyDir` at `/data`.
- Postgres mounts `emptyDir` at `/var/lib/postgresql/data`.

An `emptyDir` volume is created when the Pod is assigned to a node and exists only for the lifetime of that Pod on that node. It is useful for ephemeral scratch data, caches, temporary files, or lab exercises where persistence is not the focus.

It is not a good production storage choice for databases or durable Redis data. If the Pod is deleted, rescheduled, or replaced, the data in the `emptyDir` is lost. For real database persistence, a PersistentVolumeClaim backed by durable storage would be the better approach.

## Takeaways

- `emptyDir` is Pod-lifetime ephemeral storage.
- It can be useful for temporary data, but it should not be treated as durable storage.
- Redis and Postgres normally need persistent storage when their data matters.
- A worker-based flow is a clean way to separate request handling from background processing.
- A worker does not need a Service unless something else needs to connect to it.
- Internal Services let the app components communicate by stable DNS names like `redis` and `db`.
