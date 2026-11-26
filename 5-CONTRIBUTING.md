# Contributing

- Bugs: open an issue with your macOS version and what happened. Say so in the title if a file ended up somewhere unexpected.
- Features: open an issue first for anything bigger than a small fix.
- Keep logic in `DustPilotCore` and add a test in `Tests/DustPilotCoreTests`; keep the SwiftUI layer thin. Run `scripts/test.sh` before a pull request.
- Please test on a throwaway folder, not your real files. The app only moves files to the Trash, but test safely anyway.
- No accounts, analytics or anything that sends data off the machine.
- Contributions are under the MIT license.
