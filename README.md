# Remove Carrier DM (RegService + CTAutoRegist)

A Magisk, KernelSU, and KernelSU Next module that disables carrier
device-management and self-registration clients on ColorOS by overlaying them
with zero-byte files under `/product`.

## What it does

Two preinstalled ColorOS components are replaced with empty files:

| Path | Package |
| --- | --- |
| `/product/app/RegService` | `com.coloros.regservice` |
| `/product/priv-app/CTAutoRegist` | `com.oppo.ctautoregist` |

The overlay ships in the module's `system/product` tree, so both APKs and their
`vdex` companions are shadowed by 0-byte placeholders. The real `/product`
partition is not modified. Removing the module and rebooting restores the
original files.

## Requirements

- ColorOS / OPPO device where the packages above are present
- One of the managers below. Mount support is not the same on every version.

| Manager | Mount |
| --- | --- |
| Magisk v20.4+ | Magisk mounts `system/product` onto `/product` itself. No metamodule. The zip's `update-binary` is Magisk **v31.1** `module_installer.sh` (same bytes as current `master` at the time of v31.1). The app replaces it with the copy shipped in that Magisk build. |
| KernelSU v1.x and v2.x | Built-in OverlayFS. No metamodule. |
| KernelSU v3.0.0+ | The installer still extracts this zip. Mounting is done by whichever single mount metamodule is installed. [meta-overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs) is the reference and supports `product`. A magic-mount metamodule is a different choice, not a requirement to use meta-overlayfs. With no mount metamodule, the module installs and is not mounted. |
| KernelSU Next v1.x | Built-in Magic Mount or OverlayFS (`ksud_magic` / `ksud_overlayfs` in v1.1.1). No metamodule. |
| KernelSU Next v3.0.0+ | Same metamodule rule as KernelSU v3. `meta-overlayfs` is the reference, not the only mount implementation. |

## Build the zip

From the repository root, so `module.prop` sits at the root of the archive
(a zip of the parent folder will not install):

```sh
zip -r -X remove_regservice.zip META-INF customize.sh module.prop system
```

`*.zip` is gitignored. The command above is the install artifact. It contains:

```
META-INF/com/google/android/update-binary    Magisk module_installer.sh
META-INF/com/google/android/updater-script   the single line #MAGISK
customize.sh
module.prop
system/product/app/RegService/RegService.apk
system/product/app/RegService/oat/arm64/RegService.vdex
system/product/priv-app/CTAutoRegist/CTAutoRegist.apk
system/product/priv-app/CTAutoRegist/oat/arm64/CTAutoRegist.vdex
```

`update-binary` is Magisk v31.1
[`module_installer.sh`](https://github.com/topjohnwu/Magisk/blob/v31.1/scripts/module_installer.sh)
(git blob `28b48e580a9b605038bd3de15c5aba08d2258b14`), unchanged. The Magisk
app replaces that file with its own copy during install. Module-specific
steps belong in `customize.sh`. Provenance for the scripts exercised by the
harness is in `tests/upstream/SOURCES.md`.

## Install

Install the same zip from any of these managers, then reboot:

1. **Magisk** — Modules → Install from storage → select `remove_regservice.zip`.
2. **KernelSU** — install the zip from the module page.
3. **KernelSU Next** — install the zip from the module page.
4. **Custom recovery** — flash the zip on a device that already has Magisk
   v20.4+. Recovery runs `META-INF/com/google/android/update-binary`. KernelSU
   and KernelSU Next managers do not use that script; they install the zip
   with their own installer, which reads `module.prop` and `customize.sh` from
   the archive root and skips `META-INF`.

Verify after reboot:

```sh
su -c 'ls -l /product/app/RegService/RegService.apk /product/priv-app/CTAutoRegist/CTAutoRegist.apk'
# expect size 0
```

## Uninstall

Remove the module in the manager that installed it, then reboot. The original
APKs come back because `/product` itself was never written.

## Product partition

Keep overlay files under `system/product/` in the zip.

On a separate `/product` (the usual ColorOS layout, where `/system/product`
points at `/product`):

- Magisk's installer leaves the files at `system/product/`. Magisk creates
  the module `product` symlink when it mounts, not during unzip.
- KernelSU v1.0.5 moves the tree to `product/` and links `system/product` to
  `../product`.
- KernelSU v2.1.2, v3.x, KernelSU Next v1.1.1 OverlayFS, and KernelSU Next
  v3.x do that same move when `/product` is a real directory.
- KernelSU Next v1.1.1 Magic Mount does not move the tree. It links
  `product` to `./system/product`.

When `/product` is only a symlink into `/system/product`, those installers
leave the files at `system/product/`.

`customize.sh` checks that the four placeholder files were extracted and sets
their permissions. It does not move the tree.

## Limitations

- `tests/install-compat.sh` runs the installer scripts in a Linux mount
  namespace. It does not mount the overlay on a device. A ColorOS reboot is
  still required to confirm `/product/app/RegService/RegService.apk` is size 0.
- The placeholders overlay the system copies. A copy of either package already
  installed under `/data` is left alone.
- The `vdex` placeholders cover the `arm64` oat directory shipped by the
  original module. The APK placeholders are what stop the clients from loading.
- KernelSU v3 and KernelSU Next v3 mount only through the installed
  metamodule. A metamodule that mishandles the `system/product` → `product/`
  move can fail to apply this module. `meta-overlayfs` supports `product`.
  KernelSU v1/v2 and KernelSU Next v1 mount it themselves.

## Disclaimer

Carrier device-management clients may be required by your carrier's service
provisioning. Disabling them can affect VoLTE / carrier registration on some
networks. Use at your own risk.

## 中文说明

本模块通过 Magisk、KernelSU 或 KernelSU Next 的 systemless 挂载，把 ColorOS
预装的 `com.coloros.regservice`（运营商 DM 客户端）和 `com.oppo.ctautoregist`
（自动注册客户端）替换为 0 字节文件。模块只覆盖 `/product` 上的系统文件，卸载
并重启后原始 APK 会恢复。

在仓库根目录打包（`module.prop` 必须在 zip 根目录，不要把整个文件夹再套一层）：

```sh
zip -r -X remove_regservice.zip META-INF customize.sh module.prop system
```

用同一个 zip 安装：

- Magisk：模块 → 从本地安装。需要 Magisk v20.4 或更高版本。Magisk 自己挂载
  `system/product`，不需要 metamodule。
- KernelSU v1/v2、KernelSU Next v1：管理器内置挂载（OverlayFS，或 Next v1 的
  Magic Mount / OverlayFS），不需要 metamodule。
- KernelSU v3、KernelSU Next v3：安装器同样接受这个 zip，但挂载交给当前安装的
  那一个 mount metamodule。参考实现是支持 product 的 meta-overlayfs，不是唯一
  选择。没有 mount metamodule 时，模块能装上但不会挂载。
- Recovery 刷入只适用于已经安装 Magisk 的设备，因为 `update-binary` 会加载
  `/data/adb/magisk/util_functions.sh`。KernelSU 与 KernelSU Next 请用各自的
  管理器安装。

安装后重启。可用下面的命令确认占位文件已生效（大小应为 0）：

```sh
su -c 'ls -l /product/app/RegService/RegService.apk /product/priv-app/CTAutoRegist/CTAutoRegist.apk'
```
