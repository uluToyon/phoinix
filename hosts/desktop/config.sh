# Desktop: Ryzen 7 7800X3D, 30 GB RAM, Radeon RX 7900 XT, UEFI.
# Target disk by stable ID — never /dev/nvme1n1, enumeration order drifts across boots.
DISK="/dev/disk/by-id/nvme-Samsung_SSD_980_1TB_S649NX0T343303X"

# Data disks, mounted by filesystem label under /mnt/<label>.
# These are NEVER formatted by any stage script — they only get fstab entries.
DATA_LABELS=(Games Video Downloads FilesMusic)
