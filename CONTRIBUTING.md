# Contributing

Small, focused pull requests are welcome: bug fixes, Xcode compatibility, clearer messages, docs.

## Ground rules

- Keep it one dependency-light bash script that runs on the stock macOS bash 3.2 (no associative arrays, no `mapfile`).
- Facts about Apple's sizes and requirements need a source: link the App Store Connect Help page or an Apple developer page in the pull request.
- Every behaviour change needs a bats test in `tests/duo-shots.bats`. The Simulator and `hinge` are stubbed in `tests/stubs`, so tests run without Xcode.

## Run the checks

```sh
brew install bats-core shellcheck
make lint test
```

## Reporting a problem

Open an issue with: Xcode version (`xcodebuild -version`), `hinge --version`, the command you ran, and the output. For a black or wrong-display capture, add the output of `xcrun simctl io <udid> enumerate`.
