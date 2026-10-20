# TimeSand environment assets

## Coastal sunrise photograph
The shipped `coastal-sunrise.jpg` is derived from [Sunrise Over the Ocean](https://commons.wikimedia.org/wiki/File:Sunrise_Over_the_Ocean.jpg), photographed by **Hommie09**, released under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). The reviewed original bytes are preserved in `tool/scene_sources/Sunrise_Over_the_Ocean.jpg` (MPO primary frame).

`tool/prepare_coastal_photo.py` checks the original SHA-256, resizes it, lifts shadows, reduces saturation, adds a soft cool-sky/warm-horizon/blue-water grade and removes metadata. It generates the bundled JPEG and `photo-source.json` with source, license, processing and hashes. Authoring uses Pillow 11.3.0 in GitHub Actions; runtime is entirely offline.

The photograph contains only natural sky, distant coast, sunlight and sea. No reference screenshot pixels, text, controls, logos or user data are used. Glass, sand, bottles, icons and all data/interaction remain live Flutter components. Its calm sea and wispy clouds differ from the reference's detailed waves and cloud forms.

## Original procedural fallback
`coastal-light.png` remains as a bundled fallback. It is original procedural artwork created by `tool/generate_coastal_scene.py` in GitHub Actions (seed 24015; Pillow 11.3.0), with no third-party image material.

These image notices do not add or change the repository's software license.
