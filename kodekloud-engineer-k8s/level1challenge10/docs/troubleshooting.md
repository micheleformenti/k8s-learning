### Volume not being created
#### Symptom
PVC in Pending state
#### Investigation
`k describe pvc pvc-log` -> pv-log was not created
`k describe pv pv-log` -> some property was missing (don't have error log now)
#### Solution
Defined hostPath -> pv-log created -> pvc-log happy
#### Learnings
PV needs specification where to store the volume


### Pod crashing
#### Symptom
Pod was crashing after creation
#### Investigation
`k describe pod time-check-sdffgsd` -> shell command was getting executed as binary
#### Solution
Added "/bin/sh" "-c" before "<mycommand>"
#### Learnings
You can't just type the shell command right into the command block