# Changelog

What changed in each version. The newest is on top. The version number lives in
`src/version.pas` and is changed with `tools/set-version.sh` (see the README).

## 0.10.0 - 2026-10-24

- **VR mode for the Meta Quest** (and other headsets with WebXR), in the web version. Open the
  game in the headset's browser (the address must be https, or localhost) and press **Enter VR**.
  The cards lie on a tilted felt board on a Victorian slope-top table in a gothic parlour: a
  fireplace with the portraits of the three vampires, a moonlit window showing your Style moon,
  bookcases, candles and a chandelier. The toolbar and the duel panel float around the table.
  Point a controller (or a hand) and pull the trigger to tap; squeeze a grip to bring everything
  back in front of you. The menu, the Store, story scenes, dialogs and the win picture appear on
  one large flat panel in front of you. Your Style choices (card backs, table cloth, moon) are used.
- The VR code is loaded only when VR is used: other players download nothing extra.
- `?vrpreview` tries the same scene in an ordinary window with the mouse; `?vrdebug` shows the frame
  rate and draw counts, and says why VR is missing; `?vrroom=0` turns the parlour off.
- Includes three.js r160 (MIT licence), in `web/vendor/`, used only by the VR mode.

## 0.9.1 - 2026-10-20

- Relics work the moment they are equipped, in the hand you are playing too. Before,
  a hand kept the relics it was dealt with, so a relic equipped mid-hand did nothing.
  What a hand has already used stays used: the Pick's one chained card, the Moonstone's
  free hint, and the bite and missed move that the Garlic Wreath and the Steady Locket
  forgave (they forgive the first one that happens while they are equipped).
- A **Relics** button on the start menu, so relics can be equipped and removed in the
  middle of a hand (the Store is shut then). Buying is still only between hands.
- Taking the Pick out of a hand whose only move was a chained card loses the hand.
- The version number is shown on the start menu, and the Windows program carries it in
  its file properties.
- Saved hands no longer store which relics they were dealt with (old lines are ignored)
  and instead store what was used: `forgiven=`, `breakused=`.

## 0.9.0 - 2026-10-18

The game as it stood when versions began to be kept (commit 54c008f): Free Play and a
Campaign of duels against three vampires, each with a trick of his own; Fenwick Grimm's
Store with special cards; the silver cross; the Rules page; trophies; Style (card backs,
table cloths, the moon); relics (then fixed at the deal); saving, loading and deleting
saved games; Linux, Windows and web builds, the web one playable offline; MIT licence.
