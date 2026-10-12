#!/usr/bin/env bash
# Zoom in: double cursor:zoom_factor (min 1) — extracted from binds.lua for DMS-safe quoting
factor=$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {f=$2; if (f<1) {f=1}; print f*2.0}')
hyprctl eval "hl.config({ cursor = { zoom_factor = $factor } })"
