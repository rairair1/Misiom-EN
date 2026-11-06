O HUB in English (Misiom headset driver, version 1.0.10)
=========================================================

What this is
  An English version of the interface of Misiom's "O HUB" app (the 客户端驱动 /
  client driver from https://www.misiom.cn/download), used by the Scorpio (天蝎座),
  Scorpio base edition (天蝎座底座版), Alpha Pro, Aries and other Misiom headsets.
  Only the interface text changed. The audio driver, EQ, 7.1 surround, voice
  changer and lighting code are Misiom's originals, untouched.

How to install
  1. Install O HUB 1.0.10 from misiom.cn as usual and run it once.
  2. Unzip this folder anywhere.
  3. Double-click Install-English.bat. It finds O HUB, checks it is exactly
     version 1.0.10, closes it (including the tray icon), backs up the original
     file and puts the English one in place. Approve the admin prompt if Windows
     asks (only for installs under Program Files).
  4. Plug in the 2.4G dongle or USB cable, then open O HUB.
     (The driver does not work over Bluetooth. That's a limit of Misiom's driver.)

If it still opens in Chinese
  You used O HUB before, so it remembered Chinese. Click the gear icon at the top >
  常规设置 (General Settings) > 语言切换 (Language) > English.

To undo
  Double-click Restore-Chinese.bat, or reinstall O HUB from misiom.cn.

Notes
  - If O HUB updates itself to a newer version, the update replaces this file.
    The installer refuses to run on any version other than 1.0.10.
  - Windows may warn that the .bat came from the internet. That's expected for
    downloaded scripts. The .ps1 files are plain text if you want to read them.
