#!/usr/bin/env bash
# Microphone doctor for Misiom headsets (Scorpio, Alpha Pro, Aries, ...) on Linux.
# Works with PipeWire (pipewire-pulse) and PulseAudio.
#
#   bash misiom-mic-doctor.sh          # check only, changes nothing
#   bash misiom-mic-doctor.sh --fix    # also apply the safe fixes it finds
#
# Fixes it can apply (all reversible, all per-user, no root):
#   - switch the headset's sound profile from "output only" to one with the mic
#   - unmute the mic and set capture levels (ALSA mixer and PipeWire/PulseAudio)
#   - make the headset mic the default input
set -u
FIX=0; [ "${1:-}" = "--fix" ] && FIX=1
VENDORS='3206 3a95 39a5'          # Misiom USB vendor IDs, from Misiom's Windows driver (.inf)
PROBLEMS=0; FIXED=0
ASOUND=${MISIOM_ASOUND:-/proc/asound}            # overridable for testing
USBDEVS=${MISIOM_USBDEVS:-/sys/bus/usb/devices}

say()  { printf '\n== %s\n' "$*"; }
ok()   { printf '  [ok] %s\n' "$*"; }
bad()  { printf '  [!!] %s\n' "$*"; PROBLEMS=$((PROBLEMS + 1)); }
info() { printf '       %s\n' "$*"; }
did()  { printf '  [fixed] %s\n' "$*"; FIXED=$((FIXED + 1)); }
have() { command -v "$1" >/dev/null 2>&1; }
is_misiom() { for v in $VENDORS; do [ "${1,,}" = "$v" ] && return 0; done; return 1; }

# ---------------------------------------------------------------- system
say "System"
info "$(uname -sr), $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown distro}")"
SERVER=""
if have pactl; then
  SERVER=$(LC_ALL=C pactl info 2>/dev/null | sed -n 's/^Server Name: //p')
  if [ -n "$SERVER" ]; then ok "Sound server: $SERVER"; else bad "pactl can't reach a sound server (is PipeWire/PulseAudio running for this user?)"; fi
else
  bad "pactl not found. Install it: Debian/Ubuntu 'pulseaudio-utils', Fedora 'pulseaudio-utils', Arch 'libpulse'"
fi

# ---------------------------------------------------------------- USB
say "USB device"
FOUND_USB=0
for d in "$USBDEVS"/*; do
  [ -f "$d/idVendor" ] || continue
  vid=$(cat "$d/idVendor"); pid=$(cat "$d/idProduct")
  if is_misiom "$vid"; then
    FOUND_USB=1
    ok "Found ${vid}:${pid}  $(cat "$d/manufacturer" 2>/dev/null) $(cat "$d/product" 2>/dev/null)"
    case "${vid}:${pid}" in
      3206:7015) info "Model: Scorpio (天蝎座)";;
      3a95:3ee3) info "Model: Scorpio base edition (天蝎座底座版)";;
      39a5:3ff1) info "Model: Alpha Pro";;
      39a5:3d21) info "Model: Aries Pro";;
      39a5:3d22) info "Model: Aries Ultra";;
    esac
    [ "$(cat "$d/power/control" 2>/dev/null)" = "auto" ] && \
      info "USB autosuspend is on for this device (if the mic drops out after a while, see README)"
  fi
done
[ $FOUND_USB = 1 ] || bad "No Misiom USB device found. Plug in the 2.4G dongle or USB cable (Bluetooth has no USB mic path) and run again."

# ---------------------------------------------------------------- ALSA
say "ALSA (kernel sound card)"
CARD=""; CARDS=""
for c in "$ASOUND"/card[0-9]*; do
  [ -f "$c/usbid" ] || continue
  vid=$(cut -d: -f1 "$c/usbid")
  is_misiom "$vid" || continue
  n=${c##*card}; CARDS="$CARDS $n"
  name=$(cat "$c/id" 2>/dev/null)
  if grep -qs '^Capture:' "$c"/stream*; then
    ok "Card $n ($name, $(cat "$c/usbid")) has a microphone (capture) stream"
    [ -z "$CARD" ] && CARD=$n
  else
    info "Card $n ($name, $(cat "$c/usbid")) is playback only"
  fi
done
if [ -z "$CARDS" ]; then
  bad "The kernel didn't create a sound card for the headset (snd-usb-audio). Check: journalctl -k | grep -i usb"
elif [ -z "$CARD" ]; then
  bad "The headset's sound card(s) expose no microphone. Is the mic boom attached / headset switched to 2.4G mode?"
fi

if [ -n "$CARD" ] && have amixer; then
  CTRLS=$(amixer -c "$CARD" scontrols 2>/dev/null | sed -n "s/^Simple mixer control '\(.*\)',[0-9]*$/\1/p")
  while IFS= read -r ctl; do
    [ -n "$ctl" ] || continue
    out=$(LC_ALL=C amixer -c "$CARD" sget "$ctl" 2>/dev/null)
    caps=$(printf '%s\n' "$out" | sed -n 's/^ *Capabilities: //p')
    case " $caps " in *" cvolume"*|*" cswitch"*) ;; *) continue;; esac   # also matches the -joined variants
    # only the capture half: controls like 'Mic' also have a Playback half (sidetone), which is normally off
    state=$(printf '%s\n' "$out" | grep -E '^ *(Mono|Front Left|Front Right|Capture)[^:]*:' | grep 'Capture' \
      | sed 's/.*Capture//' | grep -oE '\[[0-9]+%\]|\[(on|off)\]' | sort -u | tr '\n' ' ')
    if printf '%s' "$state" | grep -q '\[off\]' || printf '%s' "$state" | grep -qE '\[(0|[0-9])%\]'; then
      bad "ALSA capture control '$ctl' is muted or very low: $state"
      # 'capture' keyword: change only the capture half, never switch on sidetone
      if [ $FIX = 1 ] && amixer -c "$CARD" -q sset "$ctl" capture 80% cap 2>/dev/null; then did "'$ctl' capture set to 80% and switched on"; fi
    else
      ok "ALSA capture control '$ctl': $state"
    fi
  done <<< "$CTRLS"
elif [ -n "$CARD" ]; then
  info "amixer not installed (alsa-utils); skipping kernel mixer check"
fi

# ---------------------------------------------------------------- PipeWire / PulseAudio
SRC=""
if [ -n "$SERVER" ] && [ -n "$CARDS" ]; then
  say "PipeWire / PulseAudio"
  # find the card object(s) belonging to the Misiom ALSA card(s)
  CARDINFO=$(LC_ALL=C pactl list cards 2>/dev/null)
  for n in $CARDS; do
    PCARD=$(printf '%s\n' "$CARDINFO" | awk -v n="$n" '
      /^Card #/ {name=""} /^\tName: / {name=$2}
      $0 ~ "alsa.card = \"" n "\"" && name != "" {print name; exit}')
    [ -n "$PCARD" ] || { bad "Sound server has no card for ALSA card $n (try: systemctl --user restart wireplumber pipewire pipewire-pulse)"; continue; }
    BLOCK=$(printf '%s\n' "$CARDINFO" | awk -v c="$PCARD" '/^Card #/ {p=0} $0 == "\tName: " c {p=1} p')
    ACTIVE=$(printf '%s\n' "$BLOCK" | sed -n 's/^\tActive Profile: //p')
    if printf '%s' "$ACTIVE" | grep -q 'input'; then
      ok "$PCARD profile '$ACTIVE' includes the mic"
    else
      bad "$PCARD profile is '$ACTIVE' (no mic input)"
      CAND=$(printf '%s\n' "$BLOCK" | awk '/^\tProfiles:/ {p=1; next} /^\t[A-Z]/ {p=0}
        p && /output:/ && /input:/ && $0 !~ /available: no/ {sub(/^\t\t/, ""); sub(/: .*/, ""); print}' | head -1)
      [ -z "$CAND" ] && CAND=$(printf '%s\n' "$BLOCK" | awk '/^\tProfiles:/ {p=1; next} /^\t[A-Z]/ {p=0}
        p && /input:/ && $0 !~ /available: no/ {sub(/^\t\t/, ""); sub(/: .*/, ""); print}' | head -1)
      if [ -n "$CAND" ]; then
        info "Profile with the mic: $CAND"
        if [ $FIX = 1 ]; then pactl set-card-profile "$PCARD" "$CAND" && did "profile switched to $CAND"; sleep 1; fi
      else
        bad "No profile with a mic is offered for $PCARD"
      fi
    fi
    S=$(LC_ALL=C pactl list sources short 2>/dev/null | awk '{print $2}' | grep '^alsa_input\.' | grep -F "${PCARD#alsa_card.}" | head -1)
    [ -n "$S" ] && [ -z "$SRC" ] && SRC=$S
  done

  if [ -n "$SRC" ]; then
    ok "Headset mic source: $SRC"
    DEF=$(LC_ALL=C pactl info | sed -n 's/^Default Source: //p')
    if [ "$DEF" = "$SRC" ]; then ok "It is the default input"; else
      bad "Default input is '$DEF', not the headset"
      [ $FIX = 1 ] && pactl set-default-source "$SRC" && did "headset mic set as default input"
    fi
    SINFO=$(LC_ALL=C pactl list sources | awk -v s="$SRC" '/^Source #/ {p=0} $0 == "\tName: " s {p=1} p')
    if printf '%s\n' "$SINFO" | awk '/^\tMute: yes/ {f = 1} END {exit !f}'; then
      bad "Headset mic is muted in the sound server"
      [ $FIX = 1 ] && pactl set-source-mute "$SRC" 0 && did "mic unmuted"
    else ok "Not muted in the sound server"; fi
    VOL=$(printf '%s\n' "$SINFO" | sed -n 's/^\tVolume: .* \([0-9]*\)% .*/\1/p' | head -1)
    if [ -n "$VOL" ] && [ "$VOL" -lt 40 ]; then
      bad "Mic volume is low (${VOL}%)"
      [ $FIX = 1 ] && pactl set-source-volume "$SRC" 100% && did "mic volume set to 100%"
    elif [ -n "$VOL" ]; then ok "Mic volume ${VOL}%"; fi
  elif [ -n "$CARD" ]; then
    if [ $FIX = 1 ]; then bad "No input source for the headset yet. Run the script again now that the profile has changed."
    else bad "No input source for the headset in the sound server (run with --fix to switch the profile)"; fi
  fi
fi

# ---------------------------------------------------------------- live level tests
# raw s16le mono on stdin -> "<peak 0-32767> <non-zero samples> <samples>"
peak_stats() { od -An -v -t d2 | awk '{for (i = 1; i <= NF; i++) {n++; v = $i < 0 ? -$i : $i; if (v) nz++; if (v > m) m = v}}
  END {printf "%d %d %d", m, nz, n}'; }
# $1 label, $2 stats; returns 0 if sound was heard
judge() {
  local label=$1 peak nz n pct; read -r peak nz n <<< "$2"; pct=$(( ${peak:-0} * 100 / 32768 ))
  if [ "${n:-0}" = 0 ]; then bad "$label: no audio data at all (the recording didn't start)"; return 1
  elif [ "${nz:-0}" = 0 ]; then bad "$label: digital silence (all $n samples are exactly 0)"; return 1
  elif [ "$pct" -lt 5 ]; then bad "$label: very quiet (peak $peak/32767 = ${pct}%, $nz of $n samples non-zero)"; return 1
  else ok "$label: picking up sound (peak ${pct}%)"; return 0; fi
}
if [ -n "$SRC" ] && have parec; then
  say "Level test: keep talking into the mic until the tests finish..."
  if ! judge "Normal recording" "$(timeout 3 parec -d "$SRC" --raw --format=s16le --channels=1 --rate=16000 2>/dev/null | peak_stats)"; then
    PLAY=0; DIRECT=0
    # Some 2.4G dongles only send the mic while audio is also playing to the headset.
    SINK=$(LC_ALL=C pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -F "alsa_output.${SRC#alsa_input.}" | head -1)
    [ -z "$SINK" ] && SINK=$(LC_ALL=C pactl list sinks short 2>/dev/null | awk '{print $2}' | grep -F "alsa_output.$(printf '%s' "${SRC#alsa_input.}" | sed 's/\.[^.]*$//')" | head -1)
    if [ -n "$SINK" ] && have pacat; then
      pacat -d "$SINK" --raw --format=s16le --channels=2 --rate=48000 < /dev/zero 2>/dev/null & PACAT=$!
      sleep 1
      judge "While (silent) audio plays to the headset" \
        "$(timeout 3 parec -d "$SRC" --raw --format=s16le --channels=1 --rate=16000 2>/dev/null | peak_stats)" && PLAY=1
      kill "$PACAT" 2>/dev/null; wait "$PACAT" 2>/dev/null
    fi
    # Straight from the hardware, bypassing PipeWire/PulseAudio.
    if [ -n "$CARD" ] && have arecord; then
      DEV=$(LC_ALL=C arecord -l 2>/dev/null | sed -n "s/^card $CARD: .*, device \([0-9]*\):.*/\1/p" | head -1)
      info "Capture formats the headset reports:"
      sed -n '/^Capture:/,/^$/p' "$ASOUND/card$CARD/stream0" 2>/dev/null | sed 's/^/         /' | head -14
      info "Waiting for the sound server to release the mic..."; sleep 6
      ERRF=$(mktemp)
      STATS=$(timeout 5 arecord -q -D "plughw:$CARD,${DEV:-0}" -f S16_LE -c 1 -r 16000 -d 3 -t raw 2>"$ERRF" | peak_stats)
      if [ -s "$ERRF" ]; then info "arecord: $(head -2 "$ERRF" | tr '\n' ' ')"; fi
      rm -f "$ERRF"
      judge "Direct from the hardware (no PipeWire)" "$STATS" && DIRECT=1
    fi
    say "What this means"
    if [ $DIRECT = 1 ]; then info "The hardware works but PipeWire/PulseAudio gets silence: a sound-server problem. Paste this output."
    elif [ $PLAY = 1 ]; then info "The dongle only sends the mic while audio is playing. Paste this output and it can be worked around."
    else
      info "Nothing gets sound from the mic, even straight from the hardware, so it isn't a Linux setting."
      info "1. Press the headset's mic-mute button (or move the boom) and listen for the mic on/off announcement,"
      info "   then run this script again."
      info "2. Make sure the headset is in 2.4G mode (not Bluetooth) and connected to this dongle."
      info "3. If you can, check whether the mic works on Windows or another computer."
    fi
  fi
fi

# ---------------------------------------------------------------- kernel errors
if have journalctl; then
  ERRS=$(journalctl -k -b 0 --no-pager 2>/dev/null | grep -iE 'usb_set_interface failed|cannot (set|get) freq|snd-usb-audio.*(error|fail)|retire_capture_urb' | tail -5)
  if [ -n "$ERRS" ]; then say "Kernel USB audio errors (last 5)"; printf '%s\n' "$ERRS" | sed 's/^/       /'; PROBLEMS=$((PROBLEMS + 1)); fi
fi

say "Summary"
if [ $PROBLEMS = 0 ]; then echo "  No problems found."
elif [ $FIX = 1 ]; then echo "  $PROBLEMS problem(s) found, $FIXED fixed. Run again (without --fix) to re-check."
else echo "  $PROBLEMS problem(s) found. Run again with --fix to apply the safe fixes."; fi
echo "  Paste this whole output to get help."
