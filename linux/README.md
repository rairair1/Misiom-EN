# Misiom headsets on Linux

O HUB is Windows-only: it depends on Misiom's Windows driver and the Windows audio-effects (APO) system.
On Linux the headset is a standard USB audio device and works with the kernel's own driver. No Misiom
software is needed for sound and mic.

## Mic not working

```sh
curl -fsSLO https://raw.githubusercontent.com/rairair1/Misiom-EN/main/linux/misiom-mic-doctor.sh
bash misiom-mic-doctor.sh          # checks only, changes nothing
bash misiom-mic-doctor.sh --fix    # applies the safe fixes it finds, then run it again to re-check
```

It checks each layer where Linux mics usually fail:

1. **USB**: is the dongle or cable connected? Bluetooth mode has no USB mic.
2. **Kernel**: did the kernel create a sound card with a microphone stream?
3. **Mixer**: is the headset's capture control muted or near 0%? Only the capture side is changed, never sidetone.
4. **Sound profile**: PipeWire/PulseAudio often picks *Analog Stereo Output*, which has no mic. The fix
   switches to a profile with input. This is the most common cause.
5. **Default input**: is the headset mic the system's default input, unmuted and at a sensible volume?
6. **Live test**: talk for 3 seconds. If everything above passes but it hears silence, the mute is on the
   headset itself: press the mic-mute button or lower the boom. The headset announces mic on/off.
7. **Kernel errors** from the USB audio driver, if any.

The fixes work for your user only and need no root. You can change them back in your desktop's sound settings.

If the mic cuts out after a while, install `99-misiom.rules` to stop USB autosuspend on the dongle (instructions
are in the file).

Works with PipeWire (`pipewire-pulse`) and PulseAudio. Needs `pactl` (and `amixer` from `alsa-utils` for the mixer check).
