#!/system/bin/sh
# Sourced by the Magisk, KernelSU, and KernelSU Next module installers
# after the zip is extracted. Do not call exit; the installer cleans up.

ui_print "- Remove Carrier DM (RegService + CTAutoRegist)"
ui_print "- Zero-byte overlays for:"
ui_print "  /product/app/RegService (com.coloros.regservice)"
ui_print "  /product/priv-app/CTAutoRegist (com.oppo.ctautoregist)"

OVERLAYS="
system/product/app/RegService/RegService.apk
system/product/app/RegService/oat/arm64/RegService.vdex
system/product/priv-app/CTAutoRegist/CTAutoRegist.apk
system/product/priv-app/CTAutoRegist/oat/arm64/CTAutoRegist.vdex
"

for rel in $OVERLAYS; do
  if [ ! -f "$MODPATH/$rel" ]; then
    abort "! Missing overlay file: $rel"
  fi
done

# Keep the placeholders world-readable. Partition relocation (system/product
# -> product/ when /product is its own directory) is done by the KernelSU and
# KernelSU Next installers after this script returns. Magisk mounts
# system/product onto /product itself. Leave the zip layout unchanged.
set_perm_recursive "$MODPATH/system/product" 0 0 0755 0644 u:object_r:system_file:s0

ui_print "- Overlay files ready"
ui_print "- Reboot to apply"
