#!/usr/bin/env bash
# Regenerates the README screenshots and GIF from the real app.
# Requires ImageMagick and ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf build/screenshots
flutter test screenshots/generate_test.dart

src=build/screenshots
out=docs/screenshots
mkdir -p "$out"

# ImageMagick 7 ships `magick`, version 6 only `convert`.
im=$(command -v magick || command -v convert)

# Rounded corners for each screen.
frame() {
  "$im" "$1" -resize 540x "$2"
  local w h
  read -r w h < <("$im" "$2" -format '%w %h\n' info:)
  "$im" "$2" \
    \( -size "${w}x${h}" xc:black -fill white \
       -draw "roundrectangle 0,0 $((w - 1)),$((h - 1)) 36,36" \) \
    -alpha off -compose CopyOpacity -composite "$2"
}

for shot in train_dark workout_dark exercise_dark progress_list_dark \
            train_light programs_light history_light summary_light settings_light; do
  frame "$src/$shot.png" "$out/$shot.png"
done

# Banner: four screens side by side.
"$im" -background none \
  "$out/train_dark.png" "$out/workout_dark.png" "$out/exercise_dark.png" "$out/summary_light.png" \
  -splice 32x0 +append -chop 32x0 +repage \
  -bordercolor none -border 56 -background '#1b1c21' -flatten \
  -resize 1600x "$out/banner.png"

# GIF of the quick set logging flow.
ffmpeg -loglevel error -y -framerate 2 -i "$src/gif_%02d.png" \
  -vf "scale=360:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse=dither=bayer" \
  "$out/logging.gif"

# Legacy launcher icons (Android < 8 does not use the adaptive icon).
for density in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  "$im" "$src/icon.png" -resize "${density#*:}x${density#*:}" \
    "android/app/src/main/res/mipmap-${density%%:*}/ic_launcher.png"
done
"$im" "$src/icon.png" -resize 128x128 "$out/icon.png"

ls -lh "$out"
