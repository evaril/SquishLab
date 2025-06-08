#!/bin/bash

echo "-------------------- REMOVE: $1"
sudo pacman -Rns $1

echo "-------------------- -Qdtq: "
sudo pacman -Qdtq
echo "-------------------- Removing -Qdtq: "
sudo pacman -Rns $(pacman -Qdtq)
