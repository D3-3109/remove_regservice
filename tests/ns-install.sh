#!/bin/busybox sh
# Run inside a private mount namespace and chroot. See tests/install-compat.sh.
# /work/case.env is sourced. Nothing here writes to the host's real /data,
# /product, or /system; those paths are the chroot.

. /work/case.env

mount -t tmpfs tmpfs /data || exit 90
mount -t tmpfs tmpfs /system || exit 91
mkdir -p /data/adb/magisk /data/adb/modules /system/bin /dev/tmp /work/out
printf 'ro.build.version.sdk=34\nro.product.cpu.abi=arm64-v8a\n' > /system/build.prop

case "$LAYOUT" in
  separate)
    mount -t tmpfs tmpfs /product || exit 92
    ln -sfn /product /system/product
    ;;
  merged)
    mkdir -p /system/product
    rm -rf /product
    ln -s /system/product /product
    ;;
  split)
    mount -t tmpfs tmpfs /product || exit 92
    mkdir -p /system/product
    ;;
  none)
    ;;
  *)
    echo "bad layout $LAYOUT" >&2
    exit 93
    ;;
esac

if [ "$KIND" = magisk ]; then
  cp /work/util_functions.sh /data/adb/magisk/util_functions.sh || exit 94
fi

# KernelSU's grep_prop ends in `xargs`, which execs `echo` from PATH.
# On device, ksud prepends its BusyBox applet directory. Install the same
# applets here so that lookup is real, not a stub.
/bin/busybox --install -s /bin > /work/out/applet-install.log 2>&1 || true
export PATH="/bin${PATH:+:$PATH}"

export ASH_STANDALONE=1
export BOOTMODE
export OUTFD=1
export ZIPFILE

set +e
if [ "$KIND" = magisk ]; then
  /bin/busybox sh -o standalone /work/update-binary dummy 1 "$ZIPFILE" > /work/out/install.log 2>&1
  ec=$?
else
  /bin/busybox sh -o standalone -c '. /work/installer.sh; install_module' > /work/out/install.log 2>&1
  ec=$?
fi
echo "$ec" > /work/out/exit

if [ -d /data/adb ]; then
  /bin/busybox cp -a /data/adb /work/out/adb
fi
{
  echo "probe system/product: $(/bin/busybox ls -ld /system/product 2>&1)"
  echo "probe /product: $(/bin/busybox ls -ld /product 2>&1)"
} >> /work/out/install.log
exit 0
