#!/usr/bin/env bash
# Build the portable English O HUB (single .exe) after ./build.sh.
#   ./portable.sh "O HUB-win-1.0.10-x64.exe"
# Needs: 7z, makensis (apt install p7zip-full nsis). Output: out/OHUB-English-Portable-1.0.10.exe
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
INSTALLER=$(realpath "${1:?usage: ./portable.sh <O HUB installer .exe>}")
ORIG_ASAR_SHA=491e6a5091d5d8555d5c598d344777baa68fbe10e9d1fce3cada0aa8edc4e658
OUT=$ROOT/out; P=$OUT/portable
EN_ASAR=$OUT/OHUB-English-1.0.10/app.asar
[ -f "$EN_ASAR" ] || { echo "Run ./build.sh first."; exit 1; }

rm -rf "$P" && mkdir -p "$P"
7z x -y -o"$P/nsis" "$INSTALLER" '$PLUGINSDIR/app-64.7z' uninstallerIcon.ico >/dev/null
7z x -y -o"$P/app" "$P/nsis/\$PLUGINSDIR/app-64.7z" >/dev/null
rm -f "$P/nsis/\$PLUGINSDIR/app-64.7z"
echo "$ORIG_ASAR_SHA  $P/app/resources/app.asar" | sha256sum -c --quiet - || { echo "Not O HUB 1.0.10."; exit 1; }
cp "$EN_ASAR" "$P/app/resources/app.asar"

# UTF-8 locale: some file names are non-ASCII and makensis crashes on them under the C locale.
LC_ALL=C.UTF-8 makensis -V2 -DAPPDIR="$P/app" -DICON="$P/nsis/uninstallerIcon.ico" \
  -DOUTFILE="$OUT/OHUB-English-Portable-1.0.10.exe" "$ROOT/portable/OHUB-Portable.nsi"
rm -rf "$P"
ls -la "$OUT/OHUB-English-Portable-1.0.10.exe"
