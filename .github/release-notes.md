English version of **O HUB 1.0.10**, the Windows driver app for Misiom (觅声) headsets: Scorpio, Scorpio base edition, Alpha Pro, Aries, Sparks.

Built automatically from Misiom's official installer, which the build verifies by hash. Only interface text is changed.

### Which file?

- **`OHUB-English-Portable-1.0.10.exe`**: no installation. Run it and approve the administrator prompt (O HUB always asks for this; it installs Misiom's audio driver on first launch). The first launch unpacks O HUB to `%LOCALAPPDATA%\Misiom-EN`, which takes about a minute. Later launches start straight away.
- **`OHUB-English-1.0.10.zip`**: for an O HUB 1.0.10 you've already installed from misiom.cn. Unzip it and run `Install-English.bat`. `Restore-Chinese.bat` undoes it.

Plug in the 2.4G dongle or USB cable before opening O HUB. The driver doesn't work over Bluetooth.
Checksums are in `SHA256SUMS.txt`.
