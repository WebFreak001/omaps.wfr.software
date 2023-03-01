#!/bin/bash
# this is 450GB of space
dd if=/dev/zero of=dl-filesystem bs=1000000 count=450000
mkfs.btrfs dl-filesystem

echo "Add this to your /etc/fstab and then run 'mount /path/to/dl-filesystem"
echo "/srv/http/org.webfreak.omaps/dl-filesystem /srv/http/org.webfreak.omaps/dl btrfs loop,rw,relatime,ssd,space_cache,compress-force=zstd"

