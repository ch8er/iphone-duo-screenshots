# iPhone Duo screenshots from the command line

`duo-shots` captures **App Store screenshots for iPhone Duo** from the iOS Simulator: the outer display and the inner display, with the clean 9:41 status bar, the right pixel sizes, no alpha channel, and file names that match the App Store Connect slot. One command per screen.

```console
$ duo-shots shoot home
ok   outer-01-home.png  outer 1398x2034 portrait
ok   inner-01-home.png  inner 2853x2007 landscape
```

It is one bash script (about 480 lines, no dependencies beyond Xcode and [`hinge`](https://github.com/artemnovichkov/hinge)), MIT licensed, and works on the stock macOS bash 3.2.

## Why this exists

An app that ships iPhone Duo screenshots gets the "optimized for iPhone Duo" badge on its App Store page, and Apple's screenshot specification says that from April 2027 screenshots are required for apps built with the iOS 27.1 SDK or later ([App Store Connect Help](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)). Taking them by hand is fiddly, because:

- `xcrun simctl io screenshot` fails on a foldable simulator unless you say which display to capture.
- The Simulator has no `simctl` command to fold or unfold the phone, so you drag a hidden slider in Device Hub.
- The unfolded phone switches displays 1–2.5 seconds after the hinge moves, so a screenshot taken straight away is often an all-black frame.
- App Store Connect rejects PNGs with an alpha channel and any size that is not on its list.

`duo-shots` handles those four things so a screenshot run is repeatable and can run in CI.

## Screenshot sizes for iPhone Duo

| Display | Pixels (portrait) | Pixels (landscape) | Simulator display | What the Simulator gives you |
| --- | --- | --- | --- | --- |
| Outer (cover) | 1398 × 2034 | 2034 × 1398 | `--display=1` | 1398 × 2034, portrait |
| Inner | 2007 × 2853 | 2853 × 2007 | `--display=3` | 2853 × 2007, landscape |

Both orientations of each display are accepted by App Store Connect. You can upload up to 10 screenshots per display size.

Source: [App Store Connect Help, "Screenshot specifications"](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), iPhone tab, iPhone Duo row. Apple's [news post of 5 October 2026](https://developer.apple.com/news/?id=kkphp5qo) says the page was updated to show apps across orientations. The Simulator's output sizes were measured with Xcode 27.1 and iOS 27.1 (the unfolded display is landscape, so the capture is already one of the accepted sizes and nothing is scaled or rotated).

More detail on sizes and the App Store side: [iPhone Duo screenshot sizes](https://duoscreenshots.com/guides/iphone-duo-screenshot-sizes?utm_source=github&utm_medium=readme&utm_campaign=iphone-duo-screenshots) and [how to take iPhone Duo screenshots](https://duoscreenshots.com/guides/iphone-duo-screenshots?utm_source=github&utm_medium=readme&utm_campaign=iphone-duo-screenshots).

## Requirements

- A Mac with **Xcode 27.1 or later** and the **iOS 27.1 (or later) simulator runtime**. Install the runtime in Xcode > Settings > Components, or run `xcodebuild -downloadPlatform iOS`.
- [`hinge`](https://github.com/artemnovichkov/hinge) by Artem Novichkov, which folds and unfolds the Simulator. It uses a private, undocumented protocol, so pin its version next to your Xcode version. Without it you can still use `--no-fold` and fold the phone yourself.

```sh
brew install artemnovichkov/tap/hinge
```

## Install

```sh
git clone https://github.com/ch8er/iphone-duo-screenshots.git
cd iphone-duo-screenshots
make install            # copies bin/duo-shots to /usr/local/bin (PREFIX=... to change)
```

Or just download the script:

```sh
curl -fsSL https://raw.githubusercontent.com/ch8er/iphone-duo-screenshots/main/bin/duo-shots -o /usr/local/bin/duo-shots
chmod +x /usr/local/bin/duo-shots
```

## Usage

```sh
duo-shots boot                       # create (if needed), boot and wait for an iPhone Duo simulator
xcrun simctl install booted MyApp.app && xcrun simctl launch booted com.example.MyApp
# ...bring the app to the screen you want...
duo-shots shoot home                 # outer-01-home.png + inner-01-home.png in ./duo-shots
duo-shots shoot -n 2 settings        # outer-02-settings.png + inner-02-settings.png
duo-shots check duo-shots            # validate every file in the folder
```

`shoot` does this, in order:

1. Sets the status bar override: 9:41, battery 100% and charged, 3 Wi-Fi bars, 4 cellular bars (`simctl status_bar override`).
2. Folds the phone (`hinge close`), waits for the display to switch, and captures the outer display with `simctl io screenshot --display=1 --mask=black`. `--mask=black` renders the rounded-corner mask black instead of transparent, so the PNG has no alpha channel.
3. Unfolds the phone (`hinge open`), waits, and captures the inner display (`--display=3`).
4. Retries when a frame is all black (the display had not woken up yet) and waits for two identical captures in a row, so a screenshot is not taken mid-animation.
5. Folds the phone closed again and validates both files.

`duo-shots` does not tap through your app. It captures the screen the app shows now. Put the app on the right screen first: a launch argument, `xcrun simctl openurl booted myapp://settings`, or an XCUITest that navigates and then runs `duo-shots shoot <name>`.

### Commands and options

| Command | What it does |
| --- | --- |
| `boot` | Finds or creates an iPhone Duo simulator (newest iOS 27.1+ runtime), boots it and waits. |
| `status-bar [set\|clear]` | Sets or clears the clean status bar. |
| `shoot [options] <name>` | Captures the outer and inner displays for one screen. |
| `check <file\|dir>...` | Validates Apple's sizes, no alpha, no all-black frame, at most 10 per display. Exit 1 on any problem. |

| `shoot` option | Meaning |
| --- | --- |
| `-o, --out <dir>` | Output folder. Default `./duo-shots`. |
| `-n, --index <number>` | File number NN. Default: next free number in the folder. |
| `--only outer\|inner\|both` | Which display to capture. Default both. |
| `--no-fold` | Do not call `hinge`; capture whichever display is active. |
| `--no-status-bar` | Leave the status bar alone. |
| `--settle <seconds>` | Wait after a fold or unfold. Default 2.5. |
| `-d, --device <udid\|name>` | Simulator to use. Default: the only booted iPhone Duo. |

Environment variables: `DUO_SHOTS_DEVICE`, `DUO_SHOTS_OUT`, `DUO_SHOTS_SETTLE`, `DUO_SHOTS_RETRIES` (default 4), `DUO_SHOTS_STABLE` (`0` skips the two-identical-captures check), `DUO_SHOTS_OUTER_DISPLAY` (1), `DUO_SHOTS_INNER_DISPLAY` (3).

Exit status: 0 ok, 1 a capture or check failed, 2 usage error, 3 a tool or simulator is missing.

### File names

`outer-<NN>-<name>.png` goes into the iPhone Duo outer-display slot and `inner-<NN>-<name>.png` into the inner-display slot. `NN` is the order in which the screenshots appear on the App Store page. `check` complains when a file's size does not match its prefix.

## Run it in CI

GitHub Actions needs a macOS runner that has Xcode 27.1 or later and the iOS 27.1 runtime. Check the [runner images list](https://github.com/actions/runner-images) for the current macOS images, or use a self-hosted Mac.

```yaml
name: duo-screenshots
on: workflow_dispatch
jobs:
  shots:
    runs-on: macos-latest   # use an image that ships Xcode 27.1+
    steps:
      - uses: actions/checkout@v4
      - name: Install tools
        run: |
          brew install artemnovichkov/tap/hinge
          curl -fsSL https://raw.githubusercontent.com/ch8er/iphone-duo-screenshots/main/bin/duo-shots -o duo-shots
          chmod +x duo-shots
      - name: Build the app for the simulator
        run: xcodebuild -scheme MyApp -destination 'generic/platform=iOS Simulator' -derivedDataPath build
      - name: Boot iPhone Duo
        run: ./duo-shots boot
      - name: Install and launch
        run: |
          xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/MyApp.app
          xcrun simctl launch booted com.example.MyApp
          sleep 3
      - name: Capture
        run: |
          ./duo-shots shoot home
          ./duo-shots check duo-shots
      - uses: actions/upload-artifact@v4
        with:
          name: duo-screenshots
          path: duo-shots/*.png
```

With fastlane, call it from a lane and keep the upload step you already use:

```ruby
lane :duo_screenshots do
  sh("duo-shots boot")
  sh("xcrun simctl install booted ../build/MyApp.app")
  sh("xcrun simctl launch booted com.example.MyApp")
  sh("duo-shots shoot home")
  sh("duo-shots check duo-shots")
end
```

This project does not claim that `fastlane deliver` accepts the Duo slots yet; if it does not, upload the folder in App Store Connect.

## FAQ

**What size are iPhone Duo screenshots?**
Outer display 1398 × 2034 (or 2034 × 1398), inner display 2007 × 2853 (or 2853 × 2007). See the table above and Apple's specification.

**Why is my inner screenshot 2853 × 2007, landscape?**
The unfolded iPhone Duo's inner display is landscape in the Simulator, even for an app that supports only portrait. 2853 × 2007 is one of the two accepted inner sizes, so you can upload it as it is. Do not rotate or scale the file.

**Why are my screenshots all black?**
The display you captured was not the active one, or the phone had not finished folding. `duo-shots` waits and retries. If a frame stays black, raise `--settle` (try 4), or run `hinge posture` (newer hinge versions) to see which display is active.

**Does it work on a real iPhone Duo?**
No. It drives the Simulator only. `hinge` supports the Simulator only.

**Does it work with Xcode 26?**
No. The iPhone Duo simulator needs Xcode 27.1 or later.

**Why `--mask=black`?**
App Store Connect rejects PNGs with transparency. `--mask=black` fills the display's rounded corners with black, so the PNG is plain RGB.

**Is the status bar really 9:41?**
Yes. It sets 9:41, 100% charged battery, 3 Wi-Fi bars and 4 cellular bars with `simctl status_bar override`. Clear it with `duo-shots status-bar clear`.

**`hinge` stopped working after an Xcode update.**
Its protocol is private. Pin the `hinge` version to the Xcode version, and file an issue with [hinge](https://github.com/artemnovichkov/hinge/issues) if it breaks. If the Simulator stops following fold events, shut it down and boot it again.

## Need it done for you?

If you would rather not script, run Xcode runtimes or keep a Mac busy, [Duo Screenshots](https://duoscreenshots.com/?utm_source=github&utm_medium=readme&utm_campaign=iphone-duo-screenshots) shoots the iPhone Duo set for you. This repository is the free, open-source version of the capture step.

## Development

```sh
brew install bats-core shellcheck
make lint test
```

The tests replace `xcrun` and `hinge` with stubs (see `tests/stubs`), so they need no Simulator. Pull requests are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). iPhone, iOS, Xcode and App Store are trademarks of Apple Inc. This project is not affiliated with Apple.
