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
- One of:
  - **Magisk v20.4+** (the installer loads `/data/adb/magisk/util_functions.sh`)
  - **KernelSU**
  - **KernelSU Next**
- On KernelSU and KernelSU Next builds that mount modules through a
  metamodule, a mount metamodule that supports the **product** partition has
  to be installed as well. The official
  [meta-overlayfs](https://github.com/KernelSU-Modules-Repo/meta-overlayfs)
  metamodule does. Magisk mounts `system/product` onto `/product` itself and
  does not need one.

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

`update-binary` is the upstream Magisk
[`module_installer.sh`](https://github.com/topjohnwu/Magisk/blob/master/scripts/module_installer.sh),
unchanged. The Magisk app replaces that file with its own copy during
install. Module-specific steps belong in `customize.sh`.

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

- Magisk mounts `system/product` onto `/product` whether or not `/product` is
  a separate partition, and creates the `product` symlink in the module
  directory itself.
- KernelSU and KernelSU Next, when `/product` is a real directory, move
  `system/product` to `product/` during install and leave
  `system/product` as a symlink to `../product`. `meta-overlayfs` mounts that
  `product/` tree.

`customize.sh` checks that the four placeholder files were extracted and sets
their permissions. It does not move the tree; each manager does that for its
own mount implementation.

## Limitations

- Overlay mount behavior on a real ColorOS `/product` still has to be checked
  on a device. This repository can only check that the zip matches the module
  format.
- The placeholders overlay the system copies. A copy of either package already
  installed under `/data` is left alone.
- The `vdex` placeholders cover the `arm64` oat directory shipped by the
  original module. The APK placeholders are what stop the clients from loading.
- A mount metamodule that mishandles the installer's `system/product` →
  `product/` relocation can fail to mount this module. `meta-overlayfs`
  supports the product partition.

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

- Magisk：模块 → 从本地安装。需要 Magisk v20.4 或更高版本。
- KernelSU / KernelSU Next：在模块页安装该 zip。若当前版本把模块挂载交给
  metamodule，需要先安装支持 product 分区的挂载 metamodule（官方
  meta-overlayfs 可以）。
- Recovery 刷入只适用于已经安装 Magisk 的设备，因为 `update-binary` 会加载
  `/data/adb/magisk/util_functions.sh`。KernelSU 与 KernelSU Next 请用各自的
  管理器安装。

安装后重启。可用下面的命令确认占位文件已生效（大小应为 0）：

```sh
su -c 'ls -l /product/app/RegService/RegService.apk /product/priv-app/CTAutoRegist/CTAutoRegist.apk'
```
