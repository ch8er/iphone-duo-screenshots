#!/usr/bin/env bats
# Tests for bin/duo-shots. The Simulator and hinge are replaced by stubs in tests/stubs,
# so these run anywhere that has bash, bats, sips (macOS) and python3.

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export DUO_SHOTS="$ROOT/bin/duo-shots"
  export STUB_DIR="$BATS_TEST_TMPDIR/stub"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  export PATH="$ROOT/tests/stubs:$PATH"
  export DUO_SHOTS_SETTLE=0 DUO_SHOTS_STABLE_GAP=0 DUO_SHOTS_RETRIES=2
  export DUO_SHOTS_OUT="$BATS_TEST_TMPDIR/out"
  mkdir -p "$STUB_DIR"
  : >"$STUB_LOG"
  PNG="python3 $ROOT/tests/helpers/make_png.py"
}

# fixtures: outer = 1398x2034, inner = 2853x2007, both RGB and not black
good_displays() {
  $PNG 1398 2034 "$STUB_DIR/display-1.png"
  $PNG 2853 2007 "$STUB_DIR/display-3.png"
}

@test "help lists every command" {
  run "$DUO_SHOTS" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"duo-shots boot"* ]]
  [[ "$output" == *"duo-shots shoot"* ]]
  [[ "$output" == *"duo-shots check"* ]]
}

@test "version prints a version" {
  run "$DUO_SHOTS" version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^duo-shots\ [0-9]+\.[0-9]+\.[0-9]+$ ]]
}

@test "no command is a usage error (exit 2)" {
  run "$DUO_SHOTS"
  [ "$status" -eq 2 ]
}

@test "unknown command is a usage error (exit 2)" {
  run "$DUO_SHOTS" frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown command"* ]]
}

# ------------------------------------------------------------------ check

@test "check accepts the four Apple sizes" {
  mkdir -p "$BATS_TEST_TMPDIR/ok"
  $PNG 1398 2034 "$BATS_TEST_TMPDIR/ok/outer-01-a.png"
  $PNG 2034 1398 "$BATS_TEST_TMPDIR/ok/outer-02-b.png"
  $PNG 2007 2853 "$BATS_TEST_TMPDIR/ok/inner-01-a.png"
  $PNG 2853 2007 "$BATS_TEST_TMPDIR/ok/inner-02-b.png"
  run "$DUO_SHOTS" check "$BATS_TEST_TMPDIR/ok"
  [ "$status" -eq 0 ]
  [[ "$output" == *"4 checked: 4 ok, 0 failed (outer 2, inner 2)"* ]]
}

@test "check rejects a wrong size" {
  $PNG 1206 2622 "$BATS_TEST_TMPDIR/outer-01-a.png"
  run "$DUO_SHOTS" check "$BATS_TEST_TMPDIR/outer-01-a.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not an iPhone Duo size"* ]]
}

@test "check rejects an alpha channel" {
  $PNG 1398 2034 "$BATS_TEST_TMPDIR/outer-01-a.png" --alpha
  run "$DUO_SHOTS" check "$BATS_TEST_TMPDIR/outer-01-a.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"alpha channel"* ]]
}

@test "check rejects an all-black frame" {
  $PNG 1398 2034 "$BATS_TEST_TMPDIR/outer-01-a.png" --black
  run "$DUO_SHOTS" check "$BATS_TEST_TMPDIR/outer-01-a.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"all-black"* ]]
}

@test "check rejects a file named for the wrong display" {
  $PNG 2853 2007 "$BATS_TEST_TMPDIR/outer-01-a.png"
  run "$DUO_SHOTS" check "$BATS_TEST_TMPDIR/outer-01-a.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"has the inner size but is named outer"* ]]
}

@test "check rejects more than 10 screenshots per display" {
  mkdir -p "$BATS_TEST_TMPDIR/many"
  $PNG 1398 2034 "$BATS_TEST_TMPDIR/seed.png"
  for i in 01 02 03 04 05 06 07 08 09 10 11; do
    cp "$BATS_TEST_TMPDIR/seed.png" "$BATS_TEST_TMPDIR/many/outer-$i-x.png"
  done
  run "$DUO_SHOTS" check "$BATS_TEST_TMPDIR/many"
  [ "$status" -eq 1 ]
  [[ "$output" == *"at most 10"* ]]
}

@test "check without arguments is a usage error" {
  run "$DUO_SHOTS" check
  [ "$status" -eq 2 ]
}

@test "check on a missing path is a usage error" {
  run "$DUO_SHOTS" check "$BATS_TEST_TMPDIR/nope"
  [ "$status" -eq 2 ]
}

@test "check says so when a file is not an image" {
  echo "hello" >"$BATS_TEST_TMPDIR/outer-01-a.png"
  run "$DUO_SHOTS" check "$BATS_TEST_TMPDIR/outer-01-a.png"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not a readable image"* ]]
}

# ------------------------------------------------------------------ shoot

@test "shoot captures both displays with --mask=black, folds, and names the files" {
  good_displays
  run "$DUO_SHOTS" shoot "Home Screen"
  [ "$status" -eq 0 ]
  [ -f "$DUO_SHOTS_OUT/outer-01-home-screen.png" ]
  [ -f "$DUO_SHOTS_OUT/inner-01-home-screen.png" ]
  grep -q 'screenshot --display=1 --mask=black' "$STUB_LOG"
  grep -q 'screenshot --display=3 --mask=black' "$STUB_LOG"
  # 9:41, full battery
  grep -q 'status_bar 11111111-2222-3333-4444-555555555555 override --time 9:41 --batteryState charged --batteryLevel 100' "$STUB_LOG"
  # fold order: close (outer), open (inner), close again
  run grep '^hinge' "$STUB_LOG"
  [ "${lines[0]}" = "hinge -d 11111111-2222-3333-4444-555555555555 close" ]
  [ "${lines[1]}" = "hinge -d 11111111-2222-3333-4444-555555555555 open" ]
  [ "${lines[2]}" = "hinge -d 11111111-2222-3333-4444-555555555555 close" ]
}

@test "shoot numbers files in sequence" {
  good_displays
  "$DUO_SHOTS" shoot one
  "$DUO_SHOTS" shoot two
  [ -f "$DUO_SHOTS_OUT/outer-02-two.png" ]
  [ -f "$DUO_SHOTS_OUT/inner-02-two.png" ]
}

@test "shoot --index sets the number" {
  good_displays
  run "$DUO_SHOTS" shoot --index 7 settings
  [ "$status" -eq 0 ]
  [ -f "$DUO_SHOTS_OUT/outer-07-settings.png" ]
}

@test "shoot --only outer does not unfold" {
  good_displays
  run "$DUO_SHOTS" shoot --only outer home
  [ "$status" -eq 0 ]
  [ -f "$DUO_SHOTS_OUT/outer-01-home.png" ]
  [ ! -e "$DUO_SHOTS_OUT/inner-01-home.png" ]
  ! grep -q 'hinge .* open' "$STUB_LOG"
}

@test "shoot --no-fold never calls hinge" {
  good_displays
  run "$DUO_SHOTS" shoot --no-fold home
  [ "$status" -eq 0 ]
  ! grep -q '^hinge' "$STUB_LOG"
}

@test "shoot --no-status-bar leaves the status bar alone" {
  good_displays
  run "$DUO_SHOTS" shoot --no-status-bar home
  [ "$status" -eq 0 ]
  ! grep -q 'status_bar' "$STUB_LOG"
}

@test "shoot honours --out" {
  good_displays
  run "$DUO_SHOTS" shoot --out "$BATS_TEST_TMPDIR/elsewhere" home
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/elsewhere/outer-01-home.png" ]
}

@test "shoot fails (exit 1) when a display stays black" {
  $PNG 1398 2034 "$STUB_DIR/display-1.png"
  $PNG 2853 2007 "$STUB_DIR/display-3.png" --black
  run "$DUO_SHOTS" shoot home
  [ "$status" -eq 1 ]
  [[ "$output" == *"all-black"* || "$output" == *"black"* ]]
}

@test "shoot flags a frame with the wrong size" {
  $PNG 1206 2622 "$STUB_DIR/display-1.png"
  $PNG 2853 2007 "$STUB_DIR/display-3.png"
  run "$DUO_SHOTS" shoot home
  [ "$status" -eq 1 ]
  [[ "$output" == *"not an iPhone Duo size"* ]]
}

@test "shoot needs a name" {
  good_displays
  run "$DUO_SHOTS" shoot
  [ "$status" -eq 2 ]
}

@test "shoot rejects a bad --only value" {
  good_displays
  run "$DUO_SHOTS" shoot --only middle home
  [ "$status" -eq 2 ]
}

@test "shoot stops when hinge is missing" {
  good_displays
  # a PATH with the xcrun stub but without hinge
  mkdir -p "$BATS_TEST_TMPDIR/bin-no-hinge"
  cp "$ROOT/tests/stubs/xcrun" "$BATS_TEST_TMPDIR/bin-no-hinge/xcrun"
  PATH="$BATS_TEST_TMPDIR/bin-no-hinge:/usr/bin:/bin:/usr/sbin:/sbin" run "$DUO_SHOTS" shoot home
  [ "$status" -eq 3 ]
  [[ "$output" == *"hinge not found"* ]]
}

@test "shoot reports a failing hinge" {
  good_displays
  STUB_HINGE_FAIL=1 run "$DUO_SHOTS" shoot home
  [ "$status" -eq 1 ]
  [[ "$output" == *"hinge close failed"* ]]
}

@test "shoot refuses an ambiguous simulator choice" {
  good_displays
  # second Duo booted: stub prints one Duo only, so simulate via --device on a non-Duo
  run "$DUO_SHOTS" --device AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE shoot home
  [ "$status" -eq 3 ]
  [[ "$output" == *"not a booted iPhone Duo"* ]]
}

# ------------------------------------------------------------------ boot / status-bar

@test "boot reuses an existing iPhone Duo simulator" {
  run "$DUO_SHOTS" boot
  [ "$status" -eq 0 ]
  [[ "$output" == *"ready: 11111111-2222-3333-4444-555555555555"* ]]
  ! grep -q 'simctl create' "$STUB_LOG"
}

@test "boot creates one when none exists" {
  STUB_NO_DUO=1 run "$DUO_SHOTS" boot
  # the stub's created device is not a Duo, so boot reports it clearly
  grep -q 'simctl create iPhone Duo com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-1' "$STUB_LOG"
}

@test "boot explains a missing iOS 27.1 runtime" {
  STUB_NO_DUO=1 STUB_NO_RUNTIME=1 run "$DUO_SHOTS" boot
  [ "$status" -eq 3 ]
  [[ "$output" == *"no iOS 27.1+ simulator runtime"* ]]
}

@test "status-bar set and clear" {
  run "$DUO_SHOTS" status-bar set
  [ "$status" -eq 0 ]
  grep -q 'override --time 9:41' "$STUB_LOG"
  run "$DUO_SHOTS" status-bar clear
  [ "$status" -eq 0 ]
  grep -q 'status_bar 11111111-2222-3333-4444-555555555555 clear' "$STUB_LOG"
}
