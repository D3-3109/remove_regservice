# Upstream installer pins

These files are the scripts the compatibility harness executes. They are copied
from upstream tags so the test does not depend on a moving branch.

| File | Origin |
| --- | --- |
| `magisk-v31.1-module_installer.sh` | Magisk **v31.1** (`0972f67d97f9b6302b67c5171283330c74114b4a`), `scripts/module_installer.sh`, git blob `28b48e580a9b605038bd3de15c5aba08d2258b14`. Identical to `assets/module_installer.sh` inside [Magisk-v31.1.apk](https://github.com/topjohnwu/Magisk/releases/download/v31.1/Magisk-v31.1.apk). The module zip's `update-binary` is this file. |
| `magisk-v31.1-util_functions.sh` | Same APK, `assets/util_functions.sh`. Built from git blob `a9d7bfd1db51881c5572461a361b7e796cf0a6cc` by replacing `#MAGISK_VERSION_STUB` with `MAGISK_VER='31.1'` and `MAGISK_VER_CODE=31100` (`app/build-logic/.../Setup.kt`). That substituted file is what a device loads from `/data/adb/magisk/util_functions.sh`. |
| `ksu-v1.0.5-installer.sh` | KernelSU **v1.0.5**, `userspace/ksud/src/installer.sh`. `module.rs` runs it as BusyBox `sh -c` with `install_module` appended. Built-in OverlayFS, no metamodule. `handle_partition` moves `system/product` only when `/system/product` is a symlink to `/product`. |
| `ksu-v2.1.2-installer.sh` | KernelSU **v2.1.2**, same path. Still built-in OverlayFS (`website/docs/guide/module.md`). `handle_partition` moves when `/product` is a real directory. |
| `ksu-v3.0.0-installer.sh` | KernelSU **v3.0.0**. First release whose module guide requires a mount metamodule. Same directory-based `handle_partition` as v2.1.2. |
| `ksu-v3.3.1-installer.sh` | KernelSU **v3.3.1** (current stable at the time of this test). Metamodule required for mounting. `meta-overlayfs` is the reference mount provider, not the only one. |
| `ksun-v1.1.1-magic-installer.sh` | KernelSU Next **v1.1.1**, `userspace/ksud_magic/src/installer.sh`. Built-in Magic Mount. Creates `product -> ./system/product` when `/system/product` points at `/product`. Does not move the tree. |
| `ksun-v1.1.1-overlayfs-installer.sh` | KernelSU Next **v1.1.1**, `userspace/ksud_overlayfs/src/installer.sh`. Built-in OverlayFS. Moves `system/product` when `/product` is a real directory. |
| `ksun-v3.0.0-installer.sh` | KernelSU Next **v3.0.0**, `userspace/ksud/src/installer.sh`. Metamodule mount era. |
| `ksun-v3.4.2-installer.sh` | KernelSU Next **v3.4.2** (current stable at the time of this test). Metamodule required for mounting. |

BusyBox used to execute them is `lib/x86_64/libbusybox.so` from Magisk-v31.1.apk
(sha256 `060844b0769f7a50262854af027c4d6076a212d160a51309b53057cfb7122900`).
KernelSU documents its BusyBox as the Magisk BusyBox. The Android `ksud`
binaries are not run here; the harness calls `install_module` the way
`module.rs` does.

SHA-256 of every vendored script is in `MANIFEST.sha256`.
