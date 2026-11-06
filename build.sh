#!/usr/bin/env bash
# Build the English O HUB kit from Misiom's official installer.
#   ./build.sh "O HUB-win-1.0.10-x64.exe"
# Needs: node 18+, npm, 7z (p7zip-full). Output: out/OHUB-English-1.0.10/ and out/OHUB-English-1.0.10.zip
# Nothing from Misiom's app is executed: the installer is only unpacked and the JS is only parsed.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
INSTALLER=$(realpath "${1:?usage: ./build.sh <O HUB installer .exe>}")
ORIG_ASAR_SHA=491e6a5091d5d8555d5c598d344777baa68fbe10e9d1fce3cada0aa8edc4e658   # O HUB 1.0.10 app.asar
OUT=$ROOT/out; WORK=$OUT/work; KIT=$OUT/OHUB-English-1.0.10
T=$ROOT/tools
ASAR="node $ROOT/node_modules/@electron/asar/bin/asar.js"

[ -d "$ROOT/node_modules" ] || (cd "$ROOT" && npm ci --silent)
rm -rf "$OUT" && mkdir -p "$WORK" "$KIT"

echo "== unpack installer"
7z x -y -o"$WORK/nsis" "$INSTALLER" '$PLUGINSDIR/app-64.7z' >/dev/null
7z x -y -o"$WORK/app" "$WORK/nsis/\$PLUGINSDIR/app-64.7z" resources/app.asar 'resources/app.asar.unpacked/*' >/dev/null
ORIG=$WORK/app/resources/app.asar
echo "$ORIG_ASAR_SHA  $ORIG" | sha256sum -c --quiet - || { echo "Not the O HUB 1.0.10 this translation was made for."; exit 1; }
$ASAR extract "$ORIG" "$WORK/src"

echo "== translate"
A=$WORK/patched/public/dist/assets
cp -a "$WORK/src" "$WORK/patched"
node "$T/extract-tables.js" "$WORK/src/public/dist/assets" "$WORK/tables.json"
node "$T/patch.js" report "$WORK/src/public/dist/assets" "$ROOT/translations/zh-to-en.json" | grep -q 'covers every' \
  || { node "$T/patch.js" report "$WORK/src/public/dist/assets" "$ROOT/translations/zh-to-en.json"; exit 1; }
node "$T/patch.js" apply "$WORK/src/public/dist/assets" "$ROOT/translations/zh-to-en.json" "$A" | tail -1
node "$T/postpatch.js" "$A" "$ROOT/translations/zh-to-en.json" "$WORK/tables.json"
sed -i 's/<html lang="zh-CN">/<html lang="en">/; s|<title></title>|<title>O HUB</title>|' "$WORK/patched/public/dist/index.html"
for f in "$A"/*.js; do node --check --input-type=module < "$f" >/dev/null || { echo "syntax error in $f"; exit 1; }; done

echo "== repack"
UNPACK_DIRS=$(node "$T/unpacked.js" "$ORIG" | node -e '
  const l=JSON.parse(require("fs").readFileSync(0));const d=[...new Set(l.map(p=>p.split("/").slice(0,2).join("/")))];
  process.stdout.write("{"+d.join(",")+"}")')
(cd "$WORK" && $ASAR pack patched "$KIT/app.asar" --unpack-dir "$UNPACK_DIRS")
node -e '
  const [a,b]=process.argv.slice(1).map(s=>JSON.parse(s).sort());
  if(JSON.stringify(a)!==JSON.stringify(b)){console.error("unpacked file set changed");process.exit(1)}
  console.log("unpacked files identical:",a.length)' "$(node "$T/unpacked.js" "$ORIG")" "$(node "$T/unpacked.js" "$KIT/app.asar")"
diff -rq "$WORK/app/resources/app.asar.unpacked" "$KIT/app.asar.unpacked" >/dev/null && rm -rf "$KIT/app.asar.unpacked"

echo "== kit"
NEW_SHA=$(sha256sum "$KIT/app.asar" | cut -d' ' -f1 | tr a-f A-F)
cp "$ROOT"/kit/* "$KIT/"
sed -i -E "s/^(\\\$EnglishHash  = ')[0-9A-F]{64}'/\1$NEW_SHA'/" "$KIT/Install-English.ps1"
grep -q "$NEW_SHA" "$KIT/Install-English.ps1" || { echo "failed to stamp hash into Install-English.ps1"; exit 1; }
(cd "$OUT" && rm -f OHUB-English-1.0.10.zip && 7z a -tzip OHUB-English-1.0.10.zip OHUB-English-1.0.10 >/dev/null)
echo "app.asar sha256 $NEW_SHA"
ls -la "$OUT/OHUB-English-1.0.10.zip"
