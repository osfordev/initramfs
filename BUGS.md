# Bugs 🐛

## 2024-06-12

`mkfs.ext4` - broken link to `/usr/sbin/mke2fs` instead `/sbin/mke2fs`

## 2024-05-06

Symptoms: command `vgchange -ay` hungs infinitely.

- `vgchange --version`
  - LVM: 2.03.22(2) (2023-08-02)
  - Library version: 1.02.196 (2023-08-02)
  - Driver version: 4.45.0
- `udevadm --version`
  - 254

Solved by completely remove udev from initramfs