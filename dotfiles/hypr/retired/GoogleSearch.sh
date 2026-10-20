#!/usr/bin/env bash
# GoogleSearch.sh — type a query, pick engine, opens in Brave
# Brave Search is the default engine; everything opens in Brave browser.
QUERY=$(rofi -dmenu -i -p "Search")
[[ -z "$QUERY" ]] && exit 0

ENGINE=$(printf "Brave Search\nDuckDuckGo\nGoogle\nWikipedia\nYouTube\nGitHub\nNixpkgs" | rofi -dmenu -i -p "Engine")
[[ -z "$ENGINE" ]] && exit 0

case "$ENGINE" in
  "Brave Search") URL="https://search.brave.com/search?q=" ;;
  DuckDuckGo)     URL="https://duckduckgo.com/?q=" ;;
  Google)         URL="https://www.google.com/search?q=" ;;
  Wikipedia)      URL="https://en.wikipedia.org/wiki/Special:Search?search=" ;;
  YouTube)        URL="https://www.youtube.com/results?search_query=" ;;
  GitHub)         URL="https://github.com/search?q=" ;;
  Nixpkgs)        URL="https://search.nixos.org/packages?query=" ;;
  *)              URL="https://search.brave.com/search?q=" ;;
esac

# URL-encode the query, open in Brave
brave "${URL}$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$QUERY")"
