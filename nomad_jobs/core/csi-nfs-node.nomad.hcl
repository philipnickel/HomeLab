job "csi-nfs-node" {
  datacenters = ["homelab"]
  type        = "system"
  node_pool   = "default"

  group "node" {
    task "plugin" {
      driver = "docker"

      config {
        image = "registry.k8s.io/sig-storage/nfsplugin:v4.9.0"

        args = [
          "--v=5",
          "--nodeid=${node.unique.name}",
          "--endpoint=unix:///csi/csi.sock",
          "--drivername=nfs.csi.k8s.io",
        ]

        privileged = true
      }

      csi_plugin {
        id        = "nfs"
        type      = "node"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}
