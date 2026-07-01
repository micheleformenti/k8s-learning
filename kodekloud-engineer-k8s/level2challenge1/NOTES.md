### Shared volume between containers

Two containers in the same Pod mounted the same `emptyDir` volume at different paths:

- `volume-container-nautilus-1`: `/tmp/blog`
- `volume-container-nautilus-2`: `/tmp/cluster`

Creating a file from one container made it visible from the other container because both paths point to the same Pod-local volume.

#### Learning
`emptyDir` is useful for simple shared storage between containers in one Pod, but its data only lives as long as the Pod exists.
