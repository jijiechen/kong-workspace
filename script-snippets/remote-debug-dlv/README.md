

# Steps

1. compile the binary with source path and symbols avaialbe
2. copy the binary into this directory
3. edit your workload and replace command+args with `sleep infinity`, remove readinessProbe/liveneesProbe
4. review path substitution config, change if needed
5. execute script `run-kuma-dp.sh`
6. setup port-forward: `dlv-port-forward.sh`
7. attach on JetBrains GoLand


## Example build:

```sh
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 GOEXPERIMENT=boringcrypto go build -gcflags=all="-N -l" -tags=opa_no_oci -ldflags="-X github.com/kumahq/kuma/pkg/version.version=2.5.3  -X github.com/kumahq/kuma/pkg/version.gitTag=2.5.3  -X github.com/kumahq/kuma/pkg/version.gitCommit=3c0e78779c2fe3d94d298ac0c6a53bbc6c3392d4  -X github.com/kumahq/kuma/pkg/version.buildDate=local-build  -X github.com/kumahq/kuma/pkg/version.Envoy=1.28.0 -X github.com/kumahq/kuma/pkg/version.basedOnKuma=2.5.1-preview.v51e90c350 -X github.com/kumahq/kuma/pkg/version.Product=KM" -o build/artifacts-linux-arm64/kuma-dp/kuma-dp ./app/kuma-dp
```


# Other helpful tools:

## verbose build

prepare dlv
```
go install github.com/go-delve/delve/cmd/dlv@latest
ls ~/go/bin/dlv
# copy to this folder!
```

## verbose build

```sh
go build -v -x -gcflags=all="-N -l -v"
```

## examine symbols and sources

```sh
gdb ./kuma-dp
> info functions start
> info sources agent.go
> info line /home/jaychen/go/src/github.com/Kong/kong-mesh/app/kuma-dp/pkg/opa/agent.go:180
> disassemble 0x823ac4d
```
