Debugging in a Kubernetes Pod
=====================

Replace pods of an existing deployment in Kubernetes and make it a vscode remote ssh server so that we can debug things.


## Usage

1. replace target deployment:

```sh
./debug.sh kong-mesh-control-plane control-plane --mount-ssh-keys
```


2. setup port forward from local to pod:

```sh
./ssh-port-forward.sh kong-mesh-control-plane 8022
```


3. Open your vscode and connect to localhost:

```
ssh root@127.0.0.1 -p 8022
```

4. After usage, terminate ssh-port-forward.sh and restore deployment:

```
./debug.sh kong-mesh-control-plane RESTORE_BACKUP
```

