#!/bin/bash
#

source /etc/profile

if [ -z "${GENTOO_ARCH}" ]; then
	echo "Look like you have wrong build container. The container should present an evironment variable GENTOO_ARCH."
	exit 1
fi

if [ -z "${KERNEL_VERSION}" ]; then
	echo "Look like you have wrong build container. The container should present an evironment variable KERNEL_VERSION."
	exit 1
fi

set -e

echo "Building initramfs..."
echo

# Normalize SCRIPT_DIR
SCRIPT_DIR=$(dirname "$0")
cd "${SCRIPT_DIR}"
SCRIPT_DIR=$(pwd -LP)
cd - > /dev/null

BUILD_DIR="${SCRIPT_DIR}/.build"
if [ -d "${BUILD_DIR}" ]; then
	echo "Removing previous build directory..."
	rm -rf "${BUILD_DIR}"
	echo
fi
mkdir "${BUILD_DIR}"

CPIO_TMP_LIST_FILE=$(mktemp --suffix=.gen_init_cpio)

echo "Initialize initramfs configuration in ${CPIO_TMP_LIST_FILE} ..."
echo

COMMON_INITRAMFS_LIST_FILE="${SCRIPT_DIR}/initramfs/initramfs_list.${GENTOO_ARCH}"
if [ ! -f "${COMMON_INITRAMFS_LIST_FILE}" ]; then
	echo "Common initramfs_list file '${COMMON_INITRAMFS_LIST_FILE}' not found." >&2
	exit 1
fi

cat "${COMMON_INITRAMFS_LIST_FILE}" >> "${CPIO_TMP_LIST_FILE}"
echo >> "${CPIO_TMP_LIST_FILE}"


echo "file /etc/group ${SCRIPT_DIR}/misc/group 644 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /etc/ld.so.conf /etc/ld.so.conf 644 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /etc/mdadm.conf ${SCRIPT_DIR}/misc/mdadm.conf 644 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /etc/nsswitch.conf ${SCRIPT_DIR}/misc/nsswitch.conf 644 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /etc/passwd ${SCRIPT_DIR}/misc/passwd 644 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /init ${SCRIPT_DIR}/initramfs/init 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /init-base.functions ${SCRIPT_DIR}/initramfs/init-base.functions 644 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /uncrypt ${SCRIPT_DIR}/initramfs/uncrypt 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "dir /usr/share/udhcpc 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /usr/share/udhcpc/default.script /usr/share/udhcpc/default.script 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo >> "${CPIO_TMP_LIST_FILE}"

echo "# Software" >> "${CPIO_TMP_LIST_FILE}"
SOFT_ITEMS=""

# Busybox
SOFT_ITEMS="${SOFT_ITEMS} /bin/busybox"

# # Strace
# SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/strace"

# Curl requires for stratum download
SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/curl"

# Filesystem tools
SOFT_ITEMS="${SOFT_ITEMS} /sbin/e2fsck /sbin/fsck /sbin/fsck.ext4 /sbin/mke2fs /sbin/mkfs /sbin/mkfs.ext4 /sbin/resize2fs"

# Disk partition tools
SOFT_ITEMS="${SOFT_ITEMS} /sbin/fdisk /sbin/sfdisk /usr/sbin/gdisk /usr/sbin/parted"

# LVM stuff
SOFT_ITEMS="${SOFT_ITEMS} /sbin/dmsetup /sbin/lvm /usr/bin/lvm /sbin/lvcreate /sbin/lvdisplay /sbin/lvextend /sbin/lvremove /sbin/lvresize /sbin/lvs /sbin/pvcreate /sbin/pvdisplay /sbin/pvresize /sbin/vgchange /sbin/vgcreate /sbin/vgdisplay /sbin/vgextend /sbin/vgscan"
echo "dir /etc/lvm 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
echo "file /etc/lvm/lvm.conf /etc/lvm/lvm.conf 644 0 0" >> "${CPIO_TMP_LIST_FILE}"

# Tool for running RAID systems
SOFT_ITEMS="${SOFT_ITEMS} /sbin/mdadm"

# Cryptsetup
SOFT_ITEMS="${SOFT_ITEMS} /sbin/cryptsetup"

# Dropbear SSH Server
SOFT_ITEMS="${SOFT_ITEMS} /usr/bin/dbclient /usr/bin/dropbearkey /usr/sbin/dropbear"

case "${GENTOO_ARCH}" in
	amd64)
		ELF_IGNORE="linux-vdso"
		;;
	i686)
		ELF_IGNORE="linux-gate"
		;;
	*)
		echo "Unsupported GENTOO_ARCH: ${GENTOO_ARCH}" >&2
		exit 62
		;;
esac

declare -a LIB_ITEMS

# libgcc_s.so.1 for cryptsetup
echo "dir /usr/lib/gcc 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
case "${GENTOO_ARCH}" in
	amd64)
		echo "dir /usr/lib/gcc/x86_64-pc-linux-gnu 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
		;;
	i686)
		echo "dir /usr/lib/gcc/i686-pc-linux-gnu 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
		;;
esac
LIBGCC_FILE=$(find /usr/lib/gcc -maxdepth 3 -name libgcc_s.so.1 | head -n 1)
if [ -z "${LIBGCC_FILE}" ]; then
	echo "Unable to resolve libgcc_s.so.1" >&2
	exit 71
fi
LIBGCC_DIR=$(dirname "${LIBGCC_FILE}")
echo "dir ${LIBGCC_DIR} 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
case "${GENTOO_ARCH}" in
	amd64)
		echo "file /lib64/libgcc_s.so.1 ${LIBGCC_FILE} 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
		;;
	i686)
		echo "file /lib/libgcc_s.so.1 ${LIBGCC_FILE} 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
		;;
esac


for SOFT_ITEM in ${SOFT_ITEMS}; do
	if [ -e "${SOFT_ITEM}" ]; then
		if [ ! -L "${SOFT_ITEM}" ]; then
			declare -a DIRECT_LIBS_ARRAY=($(ldd "${SOFT_ITEM}" 2>/dev/null | grep -v "${ELF_IGNORE}" | grep -v '=>' | awk '{print $1}'))
			declare -a LINKED_LIBS_ARRAY=($(ldd "${SOFT_ITEM}" 2>/dev/null | grep '=>' | awk '{print $3}'))
			for LIB in ${DIRECT_LIBS_ARRAY[@]} ${LINKED_LIBS_ARRAY[@]}; do
				if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${LIB}"); then
					LIB_ITEMS+=("${LIB}")
				fi

				if [ -L "${LIB}" ]; then
					TARGET_LIB=$(readlink -f "${LIB}")
					if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${TARGET_LIB}"); then
						LIB_ITEMS+=("${TARGET_LIB}")
					fi
				fi
			done
		fi
	else
		echo "Bad soft file: ${SOFT_ITEM}" >&2
		exit 2
	fi
done

for NSSLIB in $(ls -1 /lib/libnss_*); do
	if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${NSSLIB}"); then
		LIB_ITEMS+=("${NSSLIB}")
	fi
done

case "${GENTOO_ARCH}" in
	amd64)
		for NSSLIB in $(ls -1 /lib64/libnss_*); do
			if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${NSSLIB}"); then
				LIB_ITEMS+=("${NSSLIB}")
			fi
		done
		;;
esac

for RESOLVLIB in $(ls -1 /lib/libresolv*); do
	if ! (printf '%s\n' "${LIB_ITEMS[@]}" | grep -xq "${RESOLVLIB}"); then
		LIB_ITEMS+=("${RESOLVLIB}")
	fi
done

for LIB_ITEM in ${LIB_ITEMS[@]}; do
	if [ -e "${LIB_ITEM}" ]; then
		# # Right now pass all libs as files (without symlinks)
		# echo "file ${LIB_ITEM} ${LIB_ITEM} 755 0 0" >> "${CPIO_TMP_LIST_FILE}"

		if [ -L "${LIB_ITEM}" ]; then
			TARGET_LIB_ITEM=$(readlink -f "${LIB_ITEM}")
			echo "slink ${LIB_ITEM} ${TARGET_LIB_ITEM} 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
		else
			echo "file ${LIB_ITEM} ${LIB_ITEM} 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
		fi
	else
		echo "Bad soft file: ${LIB_ITEM}" >&2
		exit 2
	fi
done

for SOFT_ITEM in ${SOFT_ITEMS}; do
	if [ -e "${SOFT_ITEM}" ]; then
		if [ -L "${SOFT_ITEM}" ]; then
			TARGET_SOFT_ITEM=$(readlink -f "${SOFT_ITEM}")
			echo "slink ${SOFT_ITEM} ${TARGET_SOFT_ITEM} 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
		else
			echo "file ${SOFT_ITEM} ${SOFT_ITEM} 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
		fi
	else
		echo "Bad soft file: ${SOFT_ITEM}" >&2
		exit 2
	fi
done

echo >> "${CPIO_TMP_LIST_FILE}"


echo "# Modules" >> "${CPIO_TMP_LIST_FILE}"
echo >> "${CPIO_TMP_LIST_FILE}"

if [ -d "/data/cache/lib/modules" ]; then
	cd "/data/cache/lib/modules"
	for n in $(find *); do
		echo "Adding module $n..."
		[ -d $n ] && echo "dir /lib/modules/$n 700 0 0" >> "${CPIO_TMP_LIST_FILE}"
		[ -f $n ] && echo "file /lib/modules/$n /data/cache/lib/modules/$n 600 0 0" >> "${CPIO_TMP_LIST_FILE}"
	done
fi

echo >> "${CPIO_TMP_LIST_FILE}"
find /lib/udev -type d | while read D; do
	echo "dir $D 755 0 0" >> "${CPIO_TMP_LIST_FILE}"
done
find /lib/udev -type f | while read F; do 
	MODE=$(stat -c %a $F)
	echo "file $F $F $MODE 0 0" >> "${CPIO_TMP_LIST_FILE}"
done

INITRAMFS_FILE="initramfs-${KERNEL_VERSION}"

echo "Generating initramfs file ${INITRAMFS_FILE}.cpio.gz..."
(cd "/usr/src/linux" && /usr/src/linux/usr/gen_initramfs.sh -o "${BUILD_DIR}/${INITRAMFS_FILE}.cpio" "${CPIO_TMP_LIST_FILE}")
gzip --best --stdout "${BUILD_DIR}/${INITRAMFS_FILE}.cpio" > "${BUILD_DIR}/${INITRAMFS_FILE}.cpio.gz"
#ln --symbolic --force "${INITRAMFS_FILE}.cpio.gz" /${BUILD_DIR}/initramfs.cpio.gz
echo

if [ "${DEBUG}" == "yes" ]; then
	# Double check initramfs integrity by unpack
	echo "Unpack final image for debug purposes ..."
	mkdir -p "${BUILD_DIR}/${INITRAMFS_FILE}"
	(cd "${BUILD_DIR}/${INITRAMFS_FILE}" && cat "${BUILD_DIR}/${INITRAMFS_FILE}.cpio.gz" | gzip --decompress | cpio --extract)

	if [ "${DEBUG_CHROOT}" == "yes" ]; then
		# Debugging
		#mount --bind /dev "${BUILD_DIR}/${INITRAMFS_FILE}/dev"
		(cd "${BUILD_DIR}/${INITRAMFS_FILE}" && chroot . /bin/busybox sh -i)
		#(cd "${BUILD_DIR}/${INITRAMFS_FILE}" && exec /bin/busybox sh)
		# set +e
		# umount "${BUILD_DIR}/${INITRAMFS_FILE}"
		# set -e
		#umount "${BUILD_DIR}/${INITRAMFS_FILE}/dev"
	fi
fi
