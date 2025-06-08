#!/bin/bash

# Set the target directory to the provided argument or default to today's date
DIR="${1:-$HOME/Downloads/screenshots/$(date +%Y-%m-%d)}"
SUMMARY="$DIR/summary.txt"
> "$SUMMARY"

# Find all PNG images in the directory and process them
find "$DIR" -type f -iname "*.png" | sort | while read -r IMG; do
  TXT="${IMG%.*}.txt"
  if [ -f "$TXT" ]; then
    echo "Skipping existing OCR: $TXT"
  else
    tesseract "$IMG" "$TXT" -l eng
  fi
  echo "---- $IMG ----" >> "$SUMMARY"
  cat "$TXT" >> "$SUMMARY"
  echo >> "$SUMMARY"
done

# Send a notification confirming the OCR process is complete
notify-send "OCR complete" "Summary saved to $SUMMARY"
