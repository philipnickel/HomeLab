id        = "jellyseerr-config"
name      = "jellyseerr-config"
type      = "csi"
plugin_id = "nfs"
namespace = "default"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

context {
  server  = "192.168.0.26"
  share   = "/mnt/user/appdata"
  subDir  = "jellyseerr"
}

mount_options {
  fs_type     = "nfs"
  mount_flags = ["noatime", "nfsvers=4"]
}
