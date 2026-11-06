# Misiom-EN: O HUB in English

An English translation of **O HUB**, the Windows driver app for Misiom (觅声 / Mísiom) gaming headsets:
Scorpio (天蝎座), Scorpio base edition (天蝎座底座版), Alpha Pro, Aries, the Sparks speakers and the Nebula sound card.

The original app is the 客户端驱动 (client driver) download on [misiom.cn/download](https://www.misiom.cn/download).
Version 1.0.10 ships with a half-finished English mode and starts in Chinese. This project translates the rest of the
interface and makes English the default. It translates about 300 strings: menus, buttons, sliders, error and success
messages, the update and login screens, and the 7.1 speaker names.

Only interface text changes. The audio driver, EQ, virtual 7.1, voice changer and lighting code are Misiom's own, untouched.
Misiom's app is **not** in this repo. The build takes their official installer as input.

## Use it (Windows)

Download from [Releases](../../releases). There are two options.

### Portable: no installation

Run `OHUB-English-Portable-1.0.10.exe` and approve the administrator prompt. O HUB always asks for it, because it
installs Misiom's audio driver and effects on first launch. The first launch unpacks O HUB to
`%LOCALAPPDATA%\Misiom-EN\OHUB-1.0.10-en.1`, which takes about a minute. Later launches start straight away. To remove it,
delete that folder.

### Patch an installed O HUB

1. Install O HUB 1.0.10 from misiom.cn and run it once.
2. Download `OHUB-English-1.0.10.zip` and unzip it.
3. Double-click `Install-English.bat`. It finds O HUB, checks it is exactly the unmodified 1.0.10,
   closes it, backs up the original as `app.asar.chinese-original`, and puts the English file in place.
4. Plug in the 2.4G dongle or USB cable and open O HUB. (The driver doesn't work over Bluetooth.)

If it still opens in Chinese, click the gear icon → 常规设置 (General Settings) → 语言切换 (Language) → English.
To undo, run `Restore-Chinese.bat` or reinstall O HUB.

## Build it

Releases are built by GitHub Actions: **Actions → Build and release → Run workflow**. It downloads the official
installer from Misiom, checks its sha256 (`ed5d4743…da486251`), builds both files and publishes the release.

To build locally you need Linux or WSL with Node 18+, `7z` and `makensis` (`apt install p7zip-full nsis`).

```sh
npm ci
./build.sh    "O HUB-win-1.0.10-x64.exe"   # -> out/OHUB-English-1.0.10.zip
./portable.sh "O HUB-win-1.0.10-x64.exe"   # -> out/OHUB-English-Portable-1.0.10.exe (about 7 min)
```

The build only unpacks the installer and *parses* Misiom's JavaScript. It never runs it. It refuses any installer whose
`app.asar` isn't the 1.0.10 it was made for (sha256 `491e6a50…c4e658`). The output is reproducible:
`app.asar` sha256 `34bae2c6…bdd6fd47`.

## How it works

| Step | File | What it does |
| --- | --- | --- |
| Read built-in tables | `tools/extract-tables.js` | Reads the app's own zh-CN / zh-TW / en-US text tables. |
| Translate | `tools/patch.js` + `translations/zh-to-en.json` | Replaces Chinese string literals in the renderer with English. It skips anything the code uses as data: object keys, `name`/`value`/`type` fields, `===` comparisons, i18n keys, console logs, template comments and library locale tables. |
| Finish | `tools/postpatch.js` | Makes English the default for new installs. Adds English→Chinese entries so the Chinese language setting still works. Makes the EQ band labels always visible, since the English words are longer. |
| Repack | `build.sh` | Repacks `app.asar` with the same files kept outside the archive as the original (605 native-module files). Checks that, and stamps the hash into the installer script. |
| Portable | `portable.sh` + `portable/OHUB-Portable.nsi` | Wraps the full O HUB folder, with the English `app.asar`, in a single NSIS launcher that unpacks on first run and then starts `O HUB.exe`. |
| Check | `tools/shots.js` | Optional. Renders every page in headless Chromium with all network blocked and the Electron bridge stubbed, takes screenshots, and lists any visible Chinese. Needs `playwright`. |

`tools/inventory.js` lists every Chinese string in a new version's bundle, to start a translation for a future O HUB release.

## Known limits

- **Version-specific.** An O HUB update replaces the English file, and the installer script refuses other versions.
  New versions need `translations/zh-to-en.json` checked with `node tools/patch.js report …`.
- **Background process text.** O HUB's background program (`public/electron`) is obfuscated and wasn't translated. A few of its
  messages, possibly including the tray-icon menu, may still show in Chinese.
- **Voice prompts (announcer).** The power on/off, mic mute and Bluetooth announcements live in the headset's firmware.
  O HUB has no commands for them: it only sends lighting and battery commands to the headset. Its "voice prompt volume"
  slider is a placeholder that never sends anything to the headset. Changing the prompts needs Misiom's firmware support.

## Device IDs (from Misiom's driver .inf)

| Model | USB ID |
| --- | --- |
| Scorpio 天蝎座 | `VID_3206&PID_7015` |
| Scorpio base edition 天蝎座底座版 | `VID_3A95&PID_3EE3` |
| Alpha Pro | `VID_39A5&PID_3FF1` |
| Aries Pro 白羊座Pro | `VID_39A5&PID_3D21` |
| Aries Ultra 白羊座Ultra | `VID_39A5&PID_3D22` |

Not affiliated with Misiom. O HUB is Misiom's software.
