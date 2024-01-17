## Problems solved

1. OpenSSH and environment variables
2. Override an existing workload in the cluster
3. Go development in vscode
  1). go/src/
  2). running go debugger
4. Setup port-forward to local


## Known issues

  1. can not attach to an existing process (requires ptrace capability)
  2. Only the Deployment kind is supported，没有其他工作负载类型（DaemonSet/StatefulSet 需要让用户选需要替换的实例）
  3. the approach of fixing environment variables is not compatible with multi-line environment variables; the Go path is not exported to vscode either.
  4. Still need to do some manual steps


## Known issues that are not in scope
  1. The remote debugger container is using a different image with the real workload, so they can behave differently
  2. We are not persistant anything, so everything is reset when the pod is restarted
  3. We have to edit the workload when we reach some constraints, and then the pods will be restarted 
  


## Current manual steps

### cluster setup
* K3D_FIX_DNS
* kuse
* kcd

### preparation
* create folder
* clone code

### debugging
* add launch.json
* edit launch.json
* export PATH, enable go
* install vscode go extension
* install the dlv tool


### Project specific operations
* make build
* kubectl  delete lease
* leader duration?