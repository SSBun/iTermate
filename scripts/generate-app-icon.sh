#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
source_image="${1:-$project_dir/artwork/app-icon-variants/terminal-sidekick-dark-transparent.png}"
output_set="${2:-$project_dir/iTermate/Assets.xcassets/AppIcon.appiconset}"

if [[ ! -f "$source_image" ]]; then
  echo "Source image not found: $source_image" >&2
  exit 1
fi

case "$output_set" in
  *.appiconset) ;;
  *)
    echo "Output path must end in .appiconset: $output_set" >&2
    exit 1
    ;;
esac

width="$(sips -g pixelWidth "$source_image" | awk '/pixelWidth/ { print $2 }')"
height="$(sips -g pixelHeight "$source_image" | awk '/pixelHeight/ { print $2 }')"
if [[ "$width" != "$height" || "$width" -lt 1024 ]]; then
  echo "Source image must be square and at least 1024x1024: ${width}x${height}" >&2
  exit 1
fi

catalog_dir="$(dirname "$output_set")"
mkdir -p "$catalog_dir"
temporary_set="$(mktemp -d "$catalog_dir/.AppIcon.appiconset.XXXXXX")"
trap 'rm -rf "$temporary_set"' EXIT

render() {
  local pixels="$1"
  local filename="$2"
  sips --resampleHeightWidth "$pixels" "$pixels" "$source_image" --out "$temporary_set/$filename" >/dev/null
}

render 16 icon_16x16.png
render 32 icon_16x16@2x.png
render 32 icon_32x32.png
render 64 icon_32x32@2x.png
render 128 icon_128x128.png
render 256 icon_128x128@2x.png
render 256 icon_256x256.png
render 512 icon_256x256@2x.png
render 512 icon_512x512.png
render 1024 icon_512x512@2x.png

cat > "$temporary_set/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

if [[ ! -f "$catalog_dir/Contents.json" ]]; then
  printf '{\n  "info" : { "author" : "xcode", "version" : 1 }\n}\n' > "$catalog_dir/Contents.json"
fi

rm -rf "$output_set"
mv "$temporary_set" "$output_set"
echo "Generated $output_set"
