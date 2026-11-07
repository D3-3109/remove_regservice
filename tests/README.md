# Installer compatibility harness

`install-compat.sh` builds the module zip and runs the official installer
scripts in a private user and mount namespace. The chroot's `/data`,
`/system`, and `/product` are tmpfs fixtures. The host paths with those names
are not created.

```sh
tests/install-compat.sh
```

What is executed:

- Magisk v31.1 `module_installer.sh` (`update-binary`) plus the v31.1 APK's
  `util_functions.sh`, under Magisk v31.1 BusyBox ash in standalone mode.
- KernelSU and KernelSU Next `installer.sh` from the tags in
  `upstream/SOURCES.md`, invoked as `sh -c '. ./installer.sh; install_module'`,
  which is how `module.rs` starts an install.
- `customize.sh` from this repo, sourced by those installers.
- Syntax checks with `dash -n` and BusyBox `sh -n`.

What is not executed:

- Android `ksud`, Magisk app, or a recovery.
- Magic mount, OverlayFS mount, or a metamodule `metamount.sh`. A passing
  case means the module directory was installed with the layout that
  installer version produces. It does not mean a ColorOS `/product` was
  overlaid.
- SELinux policy. BusyBox `chcon` still runs; this VM has no policy to apply.

`BOOTMODE` is set by the harness because this host has no `zygote`. The
chroot `/system/build.prop` supplies SDK 34 and `arm64-v8a` so the scripts do
not call Android `getprop`.

BusyBox is extracted from
`https://github.com/topjohnwu/Magisk/releases/download/v31.1/Magisk-v31.1.apk`
(`lib/x86_64/libbusybox.so`, sha256
`060844b0769f7a50262854af027c4d6076a212d160a51309b53057cfb7122900`)
into `tests/.cache/`, which is gitignored.

`RESULTS.md` is rewritten by a successful or failed run.
