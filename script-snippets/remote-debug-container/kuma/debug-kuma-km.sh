==================================================
@kong-mesh (use local kuma; klog levels)
==================================================

diff --git a/app/kuma-cp/main.go b/app/kuma-cp/main.go
index 1191c0f2..881df43a 100644
--- a/app/kuma-cp/main.go
+++ b/app/kuma-cp/main.go
@@ -1,6 +1,7 @@
 package main
 
 import (
+       "flag"
        "os"
 
        _ "crypto/tls/fipsonly"
@@ -22,9 +23,16 @@ import (
        _ "github.com/Kong/kong-mesh/plugins/policies/opa"
        "github.com/kumahq/kuma/app/kuma-cp/cmd"
        "github.com/kumahq/kuma/pkg/tokens/builtin/zone"
+
+       "k8s.io/klog/v2"
 )
 
 func main() {
+       set := flag.NewFlagSet("debugger", flag.ContinueOnError)
+       klog.InitFlags(set)
+       _ = set.Set("v", "10")
+       _ = set.Set("logtostderr", "true")
+
        gui.CustomizeGUI()
        kuma_cp.CustomizeDefaultKumaConfig()
        migrations.CustomizeDefaultKumaMigration(kuma_cp.DeploymentType(os.Getenv("KMESH_DEPLOYMENT_TYPE")), os.Getenv("KMESH_KONNECT_POSTGRES_RLS_USER"))
diff --git a/go.mod b/go.mod
index 25c65bcb..d797e124 100644
--- a/go.mod
+++ b/go.mod
@@ -2,6 +2,8 @@ module github.com/Kong/kong-mesh
 
 go 1.21.5
 
+replace github.com/kumahq/kuma => /root/go/src/github.com/Kong/kuma
+
 require (
        github.com/Kong/kauth-api v1.124.0
        github.com/Kong/shared-go/kauth v1.3.6


==================================================
@kuma (use customized http client backed by klog)
==================================================

diff --git a/pkg/plugins/bootstrap/k8s/plugin.go b/pkg/plugins/bootstrap/k8s/plugin.go
index c3fa637de..1dc5f58af 100644
--- a/pkg/plugins/bootstrap/k8s/plugin.go
+++ b/pkg/plugins/bootstrap/k8s/plugin.go
@@ -51,10 +51,11 @@ func (p *plugin) BeforeBootstrap(b *core_runtime.Builder, cfg core_plugins.Plugi
                return err
        }
        restClientConfig := kube_ctrl.GetConfigOrDie()
        restClientConfig.QPS = float32(b.Config().Runtime.Kubernetes.ClientConfig.Qps)
        restClientConfig.Burst = b.Config().Runtime.Kubernetes.ClientConfig.BurstQps
 
        systemNamespace := b.Config().Store.Kubernetes.SystemNamespace
+       httpClient, _ := rest.HTTPClientFor(restClientConfig)
        mgr, err := kube_ctrl.NewManager(
                restClientConfig,
                kube_ctrl.Options{
@@ -79,6 +80,9 @@ func (p *plugin) BeforeBootstrap(b *core_runtime.Builder, cfg core_plugins.Plugi
                        Metrics: kube_metricsserver.Options{
                                BindAddress: "0",
                        },
+                       Client: kube_client.Options{
+                               HTTPClient: httpClient,
+                       },
                },
        )
        if err != nil {