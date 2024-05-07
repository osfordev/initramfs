# Initramfs

This repo provides toolkit and automation to build `initramfs`

## Tag Names Convention

Following tags will trigger CI job to build:

- `rcABC-X.Y.Z` - Build toolchain image `ghcr.io/osfordev/initramfs/amd64/5.15.151:rcABC-X.Y.Z` and release https://github.com/osfordev/initramfs/releases/tag/rcABC-X.Y.Z
- `release-X.Y.Z` - Build toolchain image `osfordev/initramfs/amd64/X.Y.Z` and release https://github.com/osfordev/initramfs/releases/tag/release-X.Y.Z

## Build initramfs

```shell
#IMAGE=ghcr.io/osfordev/initramfs/i686/X.Y.Z
IMAGE=ghcr.io/osfordev/initramfs/amd64/5.15.151
#IMAGE="osfordev-initramfs-${GENTOO_ARCH}:${KERNEL_VERSION}"

docker pull "${IMAGE}"

docker run \
  --rm --interactive --tty \
  --mount type=bind,source="$(pwd)",target=/work \
  --env DEBUG=yes \
  "${IMAGE}"
```


## Build Toolchain Image Locally

```shell
DOCKER_PLATFORM=linux/386
GENTOO_ARCH=i686
# or
DOCKER_PLATFORM=linux/amd64
GENTOO_ARCH=amd64

KERNEL_VERSION=5.15.151

DOCKER_BUILDKIT=1 docker build \
  --progress plain \
  --platform "${DOCKER_PLATFORM}" \
  --tag "${IMAGE}" \
  --build-arg "KERNEL_VERSION=${KERNEL_VERSION}" \
  --file "docker/${GENTOO_ARCH}/Dockerfile" \
  .
```
