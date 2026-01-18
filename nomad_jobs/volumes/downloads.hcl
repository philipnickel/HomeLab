id        = "downloads"
name      = "downloads"
type      = "csi"
plugin_id = "nfs"
external_id = "downloads"

capability {
  access_mode     = "multi-node-multi-writer"
  attachment_mode = "file-system"
}

mount_options {
  fs_type     = "nfs"
  mount_flags = ["nfsvers=4", "soft", "timeo=300"]
}

parameters {
  server = "192.168.0.202"
  share  = "/srv/dev-disk-by-uuid-fafcd3fd-ef44-41b5-b164-ab4c78d16505/downloads"
}
