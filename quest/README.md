# Tribes VR · Meta Quest and Android phones

Native Android/OpenXR edition of the Tribes recreation. The web edition remains Three.js; the headset renderer uses Godot 4.6.2 and OpenXR Vendors 5.1.0. Both use the same corrected original model JSON, UVs, textures, and local music.

## Viewing

- Stereo rendering and 6DoF head tracking through `XROrigin3D` / `XRCamera3D`.
- Turn your head freely through 360° and lean naturally.
- The observer stays stationary during each scene. Scene changes relocate the origin with a brief fade; the head camera's tracked rotation is never overridden by a cinematic path.
- Original 2D artwork (hands/vision) is displayed on planes inside the 3D environment. It is not converted into invented panoramic imagery.
- The native staging mirrors the web sequence, with simplified desert/temple geometry and 1,800 instanced particles for headset performance. It is not an exact port of the original DOS camera/animation engine.
- Works offline after installation. No account, Internet permission, microphone, passthrough or hand-tracking permission required.

## Build the APK

Open **Actions → Build Android and Meta Quest APKs → Run workflow** in the repository. After success, download **TribesVR-MetaQuest-arm64** from **Artifacts** and unzip it. It contains `TribesVR-Quest-debug.apk` plus its SHA-256 checksum. The workflow also saves build logs and checks that the APK is signed, includes arm64/OpenXR, and declares the Quest VR launch category.

This is a debug-signed sideload build, not a Meta Store release. The CI caches its debug key so subsequent builds can normally update an installed copy. If that cache is cleared, uninstall the older debug build before installing one signed with the new key.

## Install and launch

Enable developer mode on your Quest and use SideQuest to install the APK, or connect via USB/ADB and run:

```sh
adb install -r TribesVR-Quest-debug.apk
```

Launch **Tribes VR** from **Unknown Sources / Fonts desconegudes** in the headset library. The app starts paused with instructions. Quest 2, Quest 3/3S and Quest Pro are the intended arm64 targets. Actual device operation, performance and comfort require physical headset testing; a successful build is not a hardware certification.

## Controllers

| Input | Action |
| --- | --- |
| A / X / trigger click | Play or pause |
| B | Next chapter |
| Y | Previous chapter |
| Grip click | Toggle information |
| Right thumbstick left/right | 30° snap turn |
| Quest system menu / removing focus | Pause; resume manually |

Default OpenXR Touch-controller bindings are generated and checked into `openxr_action_map.tres`. Desktop development fallback: Space, left/right arrows, H.

## Local checks

```sh
python3 tools/prepare_quest.py
# Install Godot 4.6.2 and unpack the official OpenXR Vendors 5.1.0 addon into quest/addons.
godot --headless --xr-mode off --path quest --editor --import
godot --headless --xr-mode off --path quest -- --smoke-test
```

The smoke test constructs every scene, loads shared textures/music, and visits every chapter without needing an XR runtime. Assets are staged into `quest/assets/` at build time, so originals are not duplicated in git. Android SDK/Gradle and export-template setup is specified fully in `.github/workflows/quest-apk.yml`.

Original Pulse/Melon artwork, meshes and music retain their original authorship; see the root README for credits.

## Android phone edition · Tribes 360

The same workflow also creates **Tribes360-Android-arm64**. Install `Tribes360-Android-debug.apk` and open **Tribes 360** from the normal Android app library. It has a separate package ID (`cat.skirep.tribes360`) and a Regular Android export preset: no VR runtime or controller is needed. The current build targets arm64 Android 10 or newer.

Hold the phone in landscape orientation, tap **Centrar** while pointing at the scene, then move it to look around. Local quaternion integration uses Godot's screen-aligned gyroscope samples; gentle gravity correction reduces tilt drift. Heading is relative and can drift over time, so **Centrar** resets it. No compass/location permission is used.

You can always drag on the scene to look around, including when a device has no gyroscope. **Gir: ON/OFF** enables or disables sensor control. The touch interface has play/pause, previous/next chapter, a seek bar, sound and recenter controls. Playback pauses when the app loses focus. This mode changes the viewing direction, not the observer's location.

Additional checks:

```sh
godot --headless --xr-mode off --path quest --script res://scripts/test_phone_motion.gd
godot --headless --xr-mode off --path quest -- --phone-test
```

These test full turns, pitch/gravity fusion, recenter, touch fallback, disabled sensors, resume timing and actual playback/chapter controls. Real Android sensor-axis feel and device rendering still need physical phone testing.
