#!/usr/bin/bash
# Isolated install harness for remove_regservice.
#
# Executes official Magisk / KernelSU / KernelSU Next installer scripts with
# Magisk v31.1 BusyBox ash (standalone) inside a user+mount namespace and a
# chroot. Host /data, /product, and /system are never created.
#
# This does not boot Android and does not mount the overlay onto a real
# /product. See tests/README.md.
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
UPSTREAM="$ROOT/tests/upstream"
CACHE="$ROOT/tests/.cache"
ART="${ARTIFACT_DIR:-/opt/cursor/artifacts}"
BB_SHA=060844b0769f7a50262854af027c4d6076a212d160a51309b53057cfb7122900
APK_SHA=89cefac0a318afa39fb3880c45c87b036c05bc1ebf02a7a715b7f8d7c26ac6e7
APK_URL=https://github.com/topjohnwu/Magisk/releases/download/v31.1/Magisk-v31.1.apk
# Basename must be "busybox". BusyBox dispatches on argv[0] and rejects other names.
BB="$CACHE/busybox"

OVERLAYS="
system/product/app/RegService/RegService.apk
system/product/app/RegService/oat/arm64/RegService.vdex
system/product/priv-app/CTAutoRegist/CTAutoRegist.apk
system/product/priv-app/CTAutoRegist/oat/arm64/CTAutoRegist.vdex
"

failures=0
summary=$CACHE/summary.tsv
mkdir -p "$CACHE" "$ART/install-compat"
: > "$summary"

host_guard() {
  local label=$1
  for p in /data /product /system /data/adb; do
    if [ -e "$p" ]; then
      echo "HOST GUARD FAIL ($label): $p exists" >&2
      exit 2
    fi
  done
}

say() { printf '%s\n' "$*"; }

need_sha() {
  local file=$1 expect=$2
  local got
  got=$(sha256sum "$file" | awk '{print $1}')
  if [ "$got" != "$expect" ]; then
    echo "checksum mismatch for $file" >&2
    echo "  expected $expect" >&2
    echo "  got      $got" >&2
    exit 2
  fi
}

verify_upstream() {
  local line name sum
  while read -r sum name; do
    [ -n "$sum" ] || continue
    case $sum in \#*) continue ;; esac
    need_sha "$UPSTREAM/$name" "$sum"
  done < "$UPSTREAM/MANIFEST.sha256"
  if ! cmp -s "$ROOT/META-INF/com/google/android/update-binary" "$UPSTREAM/magisk-v31.1-module_installer.sh"; then
    echo "update-binary is not Magisk v31.1 module_installer.sh" >&2
    exit 2
  fi
  if [ "$(cat "$ROOT/META-INF/com/google/android/updater-script")" != "#MAGISK" ]; then
    echo "updater-script is not the single line #MAGISK" >&2
    exit 2
  fi
}

fetch_busybox() {
  if [ -f "$BB" ] && [ "$(sha256sum "$BB" | awk '{print $1}')" = "$BB_SHA" ]; then
    return
  fi
  say "Downloading Magisk v31.1 APK to extract BusyBox"
  curl -fsSL -o "$CACHE/Magisk-v31.1.apk" "$APK_URL"
  need_sha "$CACHE/Magisk-v31.1.apk" "$APK_SHA"
  unzip -p "$CACHE/Magisk-v31.1.apk" lib/x86_64/libbusybox.so > "$BB"
  chmod 755 "$BB"
  need_sha "$BB" "$BB_SHA"
}

syntax_checks() {
  say "Syntax checks"
  dash -n "$ROOT/customize.sh"
  dash -n "$ROOT/META-INF/com/google/android/update-binary"
  "$BB" sh -n "$ROOT/customize.sh"
  "$BB" sh -n "$ROOT/META-INF/com/google/android/update-binary"
  "$BB" sh -n "$ROOT/tests/ns-install.sh"
  local f
  for f in "$UPSTREAM"/*.sh; do
    "$BB" sh -n "$f" || return 1
  done
  if grep -q '^SKIPUNZIP=1$' "$ROOT/customize.sh"; then
    echo "customize.sh sets SKIPUNZIP=1" >&2
    return 1
  fi
  if grep -E -q '^[[:space:]]*exit([[:space:]]|$)' "$ROOT/customize.sh"; then
    echo "customize.sh calls exit" >&2
    return 1
  fi
}

build_zip() {
  local dest=$1
  rm -f "$dest"
  (cd "$ROOT" && zip -r -X "$dest" META-INF customize.sh module.prop system) >/dev/null
}

prepare_root() {
  local root=$1
  rm -rf "$root"
  mkdir -p "$root"/{bin,data,system,product,proc,tmp,dev,work/out}
  cp "$BB" "$root/bin/busybox"
  ln -s busybox "$root/bin/sh"
  cp "$ROOT/tests/ns-install.sh" "$root/work/ns-install.sh"
  cp "$ROOT/META-INF/com/google/android/update-binary" "$root/work/update-binary"
  cp "$UPSTREAM/magisk-v31.1-util_functions.sh" "$root/work/util_functions.sh"
  chmod 755 "$root/work/ns-install.sh" "$root/bin/busybox"
}

run_ns() {
  local root=$1
  # /proc is bind-mounted so recovery ui_print can write /proc/self/fd/$OUTFD.
  # /dev is not bind-mounted: a user namespace on this host rejects that mount.
  # SELinux chcon is the real Magisk BusyBox applet; this VM has no policy.
  unshare --user --map-root-user --mount --propagation private /bin/bash -c "
    mount --bind /proc '$root/proc'
    chroot '$root' /bin/busybox sh -o standalone /work/ns-install.sh
  "
}

record() {
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$summary"
}

fail_case() {
  local name=$1 msg=$2
  failures=$((failures + 1))
  record FAIL "$name" "$msg"
  say "FAIL $name — $msg"
}

pass_case() {
  record PASS "$1" "$2"
  say "PASS $1 — $2"
}

mod_base_for() {
  local adb=$1 bootmode=$2
  if [ "$bootmode" = true ]; then
    printf '%s\n' "$adb/modules_update/remove_regservice"
  else
    printf '%s\n' "$adb/modules/remove_regservice"
  fi
}

assert_empty_644() {
  local f=$1
  if [ ! -f "$f" ]; then
    echo "missing $f"
    return 1
  fi
  local sz mode
  sz=$(stat -c '%s' "$f")
  mode=$(stat -c '%a' "$f")
  if [ "$sz" != 0 ]; then
    echo "size $sz $f"
    return 1
  fi
  if [ "$mode" != 644 ]; then
    echo "mode $mode $f"
    return 1
  fi
}

assert_dir_755() {
  local d=$1
  if [ ! -d "$d" ]; then
    echo "missing dir $d"
    return 1
  fi
  local mode
  mode=$(stat -c '%a' "$d")
  if [ "$mode" != 755 ]; then
    echo "dir mode $mode $d"
    return 1
  fi
}

assert_props() {
  local prop=$1
  local id ver code
  id=$(sed -n 's/^id=//p' "$prop")
  ver=$(sed -n 's/^version=//p' "$prop")
  code=$(sed -n 's/^versionCode=//p' "$prop")
  if [ "$id" != remove_regservice ] || [ "$ver" != v1.2 ] || [ "$code" != 3 ]; then
    echo "module.prop id=$id version=$ver versionCode=$code"
    return 1
  fi
}

# expect: stay | move | link
assert_install_tree() {
  local name=$1 adb=$2 bootmode=$3 expect=$4
  local mod rel err dir
  mod=$(mod_base_for "$adb" "$bootmode")
  err=
  if [ ! -f "$mod/module.prop" ]; then
    echo "no module.prop at $mod"
    return 1
  fi
  assert_props "$mod/module.prop" || return 1
  if [ -e "$mod/META-INF" ] || [ -f "$mod/customize.sh" ]; then
    echo "META-INF or customize.sh left in the module directory"
    return 1
  fi
  case $expect in
    stay) dir=$mod ;;
    move) dir=$mod ;;
    link) dir=$mod ;;
  esac
  case $expect in
    stay)
      if [ -e "$mod/product" ]; then
        echo "Magisk/stay layout unexpectedly has product entry: $(ls -ld "$mod/product")"
        return 1
      fi
      for rel in $OVERLAYS; do
        assert_empty_644 "$mod/$rel" || return 1
      done
      assert_dir_755 "$mod/system/product/app/RegService" || return 1
      assert_dir_755 "$mod/system/product/priv-app/CTAutoRegist" || return 1
      ;;
    move)
      if [ "$(readlink "$mod/system/product")" != "../product" ]; then
        echo "system/product -> $(readlink "$mod/system/product" || echo NOT_A_LINK)"
        return 1
      fi
      for rel in $OVERLAYS; do
        local leaf=${rel#system/product/}
        assert_empty_644 "$mod/product/$leaf" || return 1
        assert_empty_644 "$mod/system/product/$leaf" || return 1
      done
      assert_dir_755 "$mod/product/app/RegService" || return 1
      ;;
    link)
      if [ "$(readlink "$mod/product")" != "./system/product" ]; then
        echo "product -> $(readlink "$mod/product" || echo NOT_A_LINK)"
        return 1
      fi
      for rel in $OVERLAYS; do
        assert_empty_644 "$mod/$rel" || return 1
      done
      assert_dir_755 "$mod/system/product/app/RegService" || return 1
      ;;
    *)
      echo "bad expect $expect"
      return 1
      ;;
  esac
  if [ "$bootmode" = true ]; then
    if [ ! -f "$adb/modules/remove_regservice/module.prop" ]; then
      echo "manager install did not publish module.prop"
      return 1
    fi
    if [ ! -f "$adb/modules/remove_regservice/update" ]; then
      echo "manager install did not create the update marker"
      return 1
    fi
  else
    if [ -e "$adb/modules_update/remove_regservice" ]; then
      echo "recovery install wrote modules_update"
      return 1
    fi
    if [ -f "$adb/modules/remove_regservice/update" ]; then
      echo "recovery install created an update marker"
      return 1
    fi
  fi
  return 0
}

run_case() {
  local name=$1 kind=$2 layout=$3 bootmode=$4 zip=$5 expect=$6 installer=${7:-} needle=${8:-}
  local root logdir
  root=$(mktemp -d /tmp/remove-regservice-ns.XXXXXX)
  logdir=$ART/install-compat/$name
  mkdir -p "$logdir"
  prepare_root "$root"
  cp "$zip" "$root/work/mod.zip"
  if [ "$kind" != magisk ]; then
    cp "$installer" "$root/work/installer.sh"
  fi
  cat > "$root/work/case.env" << EOF
KIND=$kind
LAYOUT=$layout
BOOTMODE=$bootmode
ZIPFILE=/work/mod.zip
EOF
  if ! run_ns "$root"; then
    fail_case "$name" "namespace/chroot failed"
    rm -rf "$root"
    return
  fi
  local ec=missing
  if [ -f "$root/work/out/exit" ]; then
    ec=$(cat "$root/work/out/exit")
  fi
  # Assert against the ext4 chroot copy. /opt/cursor/artifacts is a
  # store that rewrites modes (644 becomes 666), so permission checks
  # there would be false failures. modes.txt records the real bits.
  if [ -d "$root/work/out/adb" ]; then
    find "$root/work/out/adb" -printf '%m %y %p\n' | sed "s|$root/work/out/||" | sort > "$root/work/out/modes.txt"
  fi
  cp -a "$root/work/out/." "$logdir/" 2>/dev/null || true
  local tree="$root/work/out/adb"
  if [ "$expect" = abort ]; then
    if [ "$ec" = 0 ]; then
      fail_case "$name" "expected non-zero exit, got 0"
    elif ! grep -F -q "$needle" "$logdir/install.log"; then
      fail_case "$name" "exit $ec but log missing [$needle]"
    else
      local stray=0
      if [ -d "$tree/modules/remove_regservice" ] || [ -d "$tree/modules_update/remove_regservice" ]; then
        stray=1
      fi
      if [ "$stray" = 1 ]; then
        fail_case "$name" "abort left the module directory in place"
      else
        pass_case "$name" "exit $ec; log has: $needle"
      fi
    fi
  else
    if [ "$ec" != 0 ]; then
      fail_case "$name" "exit $ec"
      say "  log tail:"
      tail -n 20 "$logdir/install.log" | sed 's/^/    /'
    else
      local why
      if why=$(assert_install_tree "$name" "$tree" "$bootmode" "$expect" 2>&1); then
        if ! grep -E -q '^- Done$|^ui_print - Done$' "$logdir/install.log"; then
          fail_case "$name" "tree ok but log has no - Done"
        elif ! grep -F -q 'Overlay files ready' "$logdir/install.log"; then
          fail_case "$name" "customize.sh success line missing"
        else
          pass_case "$name" "exit 0; layout $expect; bootmode $bootmode"
        fi
      else
        fail_case "$name" "$(printf '%s' "$why" | head -n 1)"
      fi
    fi
  fi
  rm -rf "$root"
}

expect_for() {
  local id=$1 layout=$2
  case $id in
    magisk) printf stay ;;
    ksu-v1.0.5)
      if [ "$layout" = separate ]; then printf move; else printf stay; fi
      ;;
    ksun-v1.1.1-magic)
      if [ "$layout" = separate ]; then printf link; else printf stay; fi
      ;;
    *)
      if [ "$layout" = merged ]; then printf stay; else printf move; fi
      ;;
  esac
}

main() {
  host_guard before
  verify_upstream
  fetch_busybox
  if ! "$BB" sh -o standalone -c 'echo ok' >/dev/null; then
    echo "Magisk BusyBox standalone mode failed" >&2
    exit 2
  fi
  syntax_checks || exit 2

  local zip=$CACHE/remove_regservice.zip
  build_zip "$zip"
  cp -f "$zip" "$ART/remove_regservice-v1.2.zip"

  say "Running installer cases"
  local id script layout expect
  for id in \
    magisk \
    ksu-v1.0.5 \
    ksu-v2.1.2 \
    ksu-v3.0.0 \
    ksu-v3.3.1 \
    ksun-v1.1.1-magic \
    ksun-v1.1.1-overlayfs \
    ksun-v3.0.0 \
    ksun-v3.4.2
  do
    for layout in separate merged split; do
      expect=$(expect_for "$id" "$layout")
      if [ "$id" = magisk ]; then
        run_case "${id}-${layout}-manager" magisk "$layout" true "$zip" "$expect"
        if [ "$layout" = separate ]; then
          run_case "${id}-${layout}-recovery" magisk "$layout" false "$zip" "$expect"
        fi
      else
        script=$UPSTREAM/$id-installer.sh
        run_case "${id}-${layout}-manager" ksu "$layout" true "$zip" "$expect" "$script"
      fi
    done
  done

  say "Running abort paths"
  local bad
  bad=$CACHE/no-prop.zip
  rm -f "$bad"
  (cd "$ROOT" && zip -r -X "$bad" customize.sh system META-INF) >/dev/null
  run_case magisk-missing-prop magisk none true "$bad" abort "" "This zip is not a Magisk module!"
  run_case ksu-v3.3.1-missing-prop ksu none true "$bad" abort "$UPSTREAM/ksu-v3.3.1-installer.sh" "Unable to extract zip file!"
  run_case ksun-v3.4.2-missing-prop ksu none true "$bad" abort "$UPSTREAM/ksun-v3.4.2-installer.sh" "Unable to extract zip file!"

  bad=$CACHE/nested.zip
  rm -rf "$CACHE/nested" && mkdir -p "$CACHE/nested/wrapper"
  cp "$zip" "$CACHE/nested/wrapper/inner.zip"
  # A zip whose only module.prop is inside a parent folder.
  rm -rf "$CACHE/nested-src" && mkdir -p "$CACHE/nested-src/remove_regservice"
  (cd "$ROOT" && cp -a META-INF customize.sh module.prop system "$CACHE/nested-src/remove_regservice/")
  rm -f "$bad"
  (cd "$CACHE/nested-src" && zip -r -X "$bad" remove_regservice) >/dev/null
  run_case magisk-nested-prop magisk none true "$bad" abort "" "This zip is not a Magisk module!"
  run_case ksu-v1.0.5-nested-prop ksu none true "$bad" abort "$UPSTREAM/ksu-v1.0.5-installer.sh" "Unable to extract zip file!"

  bad=$CACHE/missing-overlay.zip
  rm -rf "$CACHE/missing-src" && mkdir -p "$CACHE/missing-src"
  (cd "$ROOT" && cp -a META-INF customize.sh module.prop system "$CACHE/missing-src/")
  rm -f "$CACHE/missing-src/system/product/priv-app/CTAutoRegist/CTAutoRegist.apk"
  rm -f "$bad"
  (cd "$CACHE/missing-src" && zip -r -X "$bad" META-INF customize.sh module.prop system) >/dev/null
  run_case magisk-missing-overlay magisk separate true "$bad" abort "" "Missing overlay file:"
  run_case ksun-v1.1.1-magic-missing-overlay ksu separate true "$bad" abort "$UPSTREAM/ksun-v1.1.1-magic-installer.sh" "Missing overlay file:"

  host_guard after

  {
    echo "# Install compatibility results"
    echo
    echo "Generated by \`tests/install-compat.sh\` on $(date -u +%Y-%m-%dT%H:%M:%SZ)."
    echo "Full per-case logs: \`$ART/install-compat/\`. Flashable zip: \`$ART/remove_regservice-v1.2.zip\`."
    echo
    echo "Runtime: Magisk v31.1 BusyBox ash standalone (sha256 \`$BB_SHA\`)."
    echo "BOOTMODE is set by the harness because this host has no zygote."
    echo "\`/system/build.prop\` in the chroot supplies SDK 34 and arm64-v8a so the installer does not call Android \`getprop\`."
    echo "Mounting the overlay onto a device \`/product\` is not executed."
    echo
    echo "| Result | Case | Detail |"
    echo "| --- | --- | --- |"
    while IFS=$(printf '\t') read -r status name detail; do
      detail=${detail//|/\\|}
      echo "| $status | \`$name\` | $detail |"
    done < "$summary"
    echo
    if [ "$failures" -eq 0 ]; then
      echo "All cases passed. This is a userspace installer test, not an on-device mount test."
    else
      echo "$failures case(s) failed."
    fi
  } > "$ROOT/tests/RESULTS.md"
  cp -f "$ROOT/tests/RESULTS.md" "$ART/install-compat/RESULTS.md"
  cp -f "$summary" "$ART/install-compat/summary.tsv"

  say "Wrote $ROOT/tests/RESULTS.md"
  if [ "$failures" -ne 0 ]; then
    say "$failures case(s) failed"
    exit 1
  fi
  say "All cases passed"
}

main "$@"
