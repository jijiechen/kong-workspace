
### 1. no debug info found:

`Warning: no debug info found, some functionality will be missing such as stack traces and variable evaluation.`

Check if your build flags contains following, if so, remove them to enable debugging and to be able attached: 

```
--trimpath  -ldflags '-s -w'
```

If build manually, make sure do the following:
1. change build.mk to remove the flags mentioned above

2. Add these extra flags:

```sh
EXTRA_GOFLAGS='-gcflags=all="-N -l"' make build
```


### 2. can't match breakpoint in kuma:
   # kong mesh go.mod:
   # replace github.com/kumahq/kuma => /root/go/src/github.com/Kong/kuma


### 3. Attach to a process (a known issue):

      Failed to attach: Could not attach to pid 88049: 
      this could be caused by a kernel security setting, try writing "0" to /proc/sys/kernel/yama/ptrace_scope

      https://github.com/MicrosoftDocs/azure-docs/issues/79825

      "securityContext": {
         "privileged": true,
         "capabilities": {
            "add": [ "SYS_PTRACE" ]
         }
      },




