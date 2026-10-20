# Changelog

What changed in each version. The newest is on top. The version number lives in
`src/version.pas` and is changed with `tools/set-version.sh` (see the README).

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
