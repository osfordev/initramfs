ARG KERNEL_VERSION=5.15.151

# Target container with Gentoo Linux + necessary tools to build kernel and initramfs
FROM --platform=linux/amd64 theanurin/gentoo-sources-bundle:amd64-${KERNEL_VERSION} as stage
COPY BANNER /BANNER
ENTRYPOINT [ "/work/build-initramfs.sh" ]
RUN \
  emerge-webrsync \
  && \
  echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf \
  && \
  echo 'FEATURES="-ipc-sandbox -network-sandbox -pid-sandbox -sandbox -usersandbox"' >> /etc/portage/make.conf \
  && \
  echo 'USE="-pam static static-libs -su -udev"' >> /etc/portage/make.conf \
  && \
  echo "We need busybox to embed into initramfs" \
  && \
  emerge --quiet sys-apps/busybox \
  && \
  echo "We need cpio to pack initramfs" \
  && \
  emerge --quiet app-arch/cpio \
  && \
  echo "We need mdadm to embed into initramfs" \
  && \
  emerge --quiet sys-fs/mdadm \
  && \
  echo "We need LVM to embed into initramfs" \
  && \
  USE="lvm readline -thin" emerge --quiet sys-fs/lvm2 \
  && \
  echo "We need cryptsetup to embed into initramfs" \
  && \
  USE="openssl" emerge --quiet sys-fs/cryptsetup \
  && \
  echo "We need dropbear to embed into initramfs" \
  && \
  USE="minimal -shadow -syslog" emerge --quiet net-misc/dropbear \
  && \
  echo "GPT disk tools" \
  && \
  emerge --quiet sys-apps/gptfdisk sys-block/parted \
  && \
  emerge --quiet dev-vcs/git \
  && \
  emerge --quiet dev-lang/go \
  && \
  emerge --quiet dev-vcs/git-lfs \
  && \
  (cd /usr/src/linux && make -C usr/ gen_init_cpio && chmod +x usr/gen_init_cpio usr/gen_initramfs.sh) \
  && \
  sed -i 's/use_lvmetad = 1/use_lvmetad = 0/g' /etc/lvm/lvm.conf \
  && \
  echo 'GENTOO_ARCH="amd64"' > /etc/env.d/99gentooarch \
  && \
  env-update \
  && \
  rm -rf /run/* && \
  rm -rf /tmp/* && \
  rm -rf /usr/share/man && \
  rm -rf /var/cache/* && \
  rm -rf /var/db/* && \
  rm -rf /var/log/* && \
  rm -rf /var/tmp/*

# # Use OS For Developer overlay
# COPY docker/osfordev-repo.conf /etc/portage/repos.conf/osfordev-repo.conf
# RUN \
#   emerge --sync osfordev
