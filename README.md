# TRIBES · Three.js recreation

A real-time WebGL reinterpretation of **Tribes**, the 1997 PC demo by **Pulse & Melon Dezign**. Public GitHub Pages edition.

**[Watch the recreation](https://skirep.github.io/tribes-threejs/)** · [Original recording](https://www.youtube.com/watch?v=enVUWlUNk-c) · [Original release and credits](https://demozoo.org/productions/19311/)

## What is recreated

An 8:46 cinematic sequence: the boy and his companion, flying wooden ships, desert pursuit, encounter, tattoo, eye tunnel, hands, lost city, temple, 10,000 animated particles, well, vision, return, and closing credits. Original exported meshes are decoded into Three.js BufferGeometry; original texture coordinates and material assignments are retained. Desert and temple geometry, camera paths, particle choreography and character movement are newly implemented. The original two soundtracks play as local MP3 files.

This is **not a frame-exact port**. Only the uncompressed UEXP scenes have been decoded. The proprietary compressed scenes and original keyframe engine are not reproduced. Character poses come from the exported meshes, with new object animation. Camera cuts and music alignment are approximate, and the second track is shortened to match the reference video's duration. No YouTube player is used for playback.

## Controls

Click **Iniciar la demo** to unlock browser audio. Space pauses, ←/→ seek 10 seconds, M toggles sound. Transport controls include a chapter selector, timeline, fullscreen, and a low-resolution mode. Controls fade out during playback and return on touch or pointer movement. Resizing does not restart the demo. Playback pauses when the page is hidden.

## Run locally

```sh
npm ci
npm start
# http://localhost:8000
npm run check
```

No build is required. The pinned Three.js 0.180.0 runtime is vendored under `vendor/`, so playback does not depend on a JavaScript CDN. Google Fonts are optional and have local font fallbacks. GitHub Pages serves the root of `main`.

## Original resources and attribution

- Original final release: https://files.scene.org/view/demos/groups/pulse/tribesfi.zip
- Extraction: `python tools/extract_assets.py /path/to/TRIBES.TP7`
- Music **Tribes** by Scorpik: https://modarchive.org/module.php?162817
- Music **The Stories II** by Falcon / Scorpik: https://modarchive.org/module.php?162737
- Audio rendered with FFmpeg/libopenmpt to MP3. Original modules remain the work of their composers.
- Direction: Alex Garnier and Wojtek Podgorski (Unreal).
- Original code: Unreal and Camel (Marek Borzykowski).
- Original graphics: Antony Squizzato.
- Original music: Adam Skorupa (Scorpik) and Jacek Dojwa (Falcon).

Original graphics, meshes, and music remain the property of their authors; public archival availability is not a blanket commercial licence. This is an unofficial credited fan recreation. Three.js is MIT licensed; its licence is included in `vendor/THREE-LICENSE.txt`.

## Meta Quest / Android VR

A native **Godot 4.6.2 + OpenXR** port lives in [`quest/`](quest/README.md). It loads the same corrected models, textures and soundtrack as the Three.js edition. It renders stereo 3D around the viewer with headset tracking, rather than displaying the website on a flat Android WebView.

The [Android + Meta Quest APK workflow](../../actions/workflows/quest-apk.yml) builds a signed arm64 APK for sideloading. Run it manually with **Run workflow**, or push a change to the Quest/shared asset files. Download the **TribesVR-MetaQuest-arm64** artifact from the successful run.

### Normal Android phones

The workflow also publishes **Tribes360-Android-arm64**, with an APK that opens as a normal Android app. Move the phone to look around the 3D scenes, drag with a finger, or use **Centrar** to reset the view. Touch controls cover playback, chapters, seeking, sound and the gyro toggle. It uses the same shared scene resources and works without a VR headset.
