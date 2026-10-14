#!/bin/sh
# Regenerates the shipped card faces in assets/cards/ from assets/cards_src/:
#   1. recolour the suits  2. draw the vampire J/Q/K portraits  2b. age the cream
#      hearts and diamonds into old ivory (stains, yellowed edges)
#   3. build the win-screen picture (assets/win/win_screen.png)
#   4. build the vampire portraits for the duel scenes (assets/vampires/: each one
#      plain, with blood on his fangs, and with a goblet of your blood)
#   5. paint the house for the menu and the story's opening (assets/house/)
# Then rebuild (build-linux.sh / build-windows.sh embed assets/cards/).
set -e
cd "$(dirname "$0")/.."
python3 tools/recolor_cards.py
python3 tools/make_courts.py
python3 tools/age_cards.py
python3 tools/make_winscreen.py
python3 tools/make_portraits.py
python3 tools/make_house.py
