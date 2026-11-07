# Remove Carrier DM (RegService + CTAutoRegist)

A Magisk / KernelSU module that disables carrier device-management and
self-registration clients on ColorOS by overlaying them with zero-byte files
under `/product`.

## What it does

Two preinstalled ColorOS components are replaced with empty files:

| Path | Package |
| --- | --- |
| `/product/app/RegService` | `com.coloros.regservice` |
| `/product/priv-app/CTAutoRegist` | `com.oppo.ctautoregist` |

The overlay is applied through the module's `system/product` tree, so both APKs
(and their `vdex` companions) are shadowed by 0-byte placeholders. Because the
module is mounted on top of `/product`, the clients stay gone across reboots and
are not re-installed after an OTA update.

## Requirements

- A rooted device with **Magisk** (systemless overlay) or **KernelSU**
- ColorOS / OPPO device where the above packages are present

## Install

1. Download or build the module zip
   (the repository root has `module.prop` directly, so zip the root folder).
2. Magisk app → **Modules** → *Install from storage* → select the zip.
3. Reboot.

Verify with:

```sh
su -c 'ls -l /product/app/RegService/RegService.apk'
# expect size 0
```

## Uninstall

Remove the module in the Magisk app and reboot. The original APKs reappear
immediately, since nothing on the real `/product` partition was modified.

## Layout

```
module.prop
system/product/app/RegService/RegService.apk                    (0 bytes)
system/product/app/RegService/oat/arm64/RegService.vdex         (0 bytes)
system/product/priv-app/CTAutoRegist/CTAutoRegist.apk           (0 bytes)
system/product/priv-app/CTAutoRegist/oat/arm64/CTAutoRegist.vdex (0 bytes)
```

## Disclaimer

Carrier device-management clients may be required by your carrier's service
provisioning. Disabling them can affect VoLTE / carrier registration on some
networks. Use at your own risk.

## 中文说明

本模块通过 Magisk / KernelSU 的 systemless 挂载，把 ColorOS 预装的
`com.coloros.regservice`（运营商 DM 客户端）和 `com.oppo.ctautoregist`
（自动注册客户端）替换为 0 字节文件，从而实现禁用，并且 OTA 升级后不会复活。
安装后重启即可，卸载后原始 APK 立即恢复。