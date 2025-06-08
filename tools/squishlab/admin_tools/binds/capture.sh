#!/bin/bash

# Define the directory path based on the current date and hour
DIR="$HOME/Downloads/screenshots/$(date +%Y-%m-%d)/$(date +%H)"
mkdir -p "$DIR"

# Define the filename with a timestamp
FILE="$DIR/capture_$(date +%H-%M-%S).png"

# Capture the selected screen region and save the screenshot
grim -g "$(slurp)" "$FILE"

# Send a notification confirming the screenshot has been saved
notify-send "Screenshot saved" "$FILE"

