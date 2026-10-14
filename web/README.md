# Tiecards in a web browser

The same game, running in the browser (tablets and phones included). Nothing to
download or install for the player.

## Build

You need pas2js 3.x with its runtime library (the Arch `fpc` package has none;
see `TODO.md`). Unpack `pas2js-linux-x86_64-3.0.1.zip` somewhere and run:

    PAS2JS_DIR=/path/to/pas2js-linux-x86_64-3.0.1 web/build.sh

That fills `web/dist/` with plain static files (about 3 MB: the page, the
compiled game, the pictures, the story text).

## Try it

    cd web/dist && python3 -m http.server 8765

then open http://127.0.0.1:8765/ (use a server; do not open index.html as a file).

## Put it on a website

Copy everything inside `web/dist/` to a folder on the site. All paths are
relative, so any folder works (for example `https://example.com/tiecards/`).
Use https if the site has it.

## Offline play

`build.sh` also writes `web/dist/sw.js`, a service worker that keeps every file of
the game on the device the first time it is opened, so it then opens and plays with
no connection (and the cache is replaced by the next build's, automatically).
Browsers only run service workers on **https** pages (and localhost), so the site
must be served over https for this to switch on; over plain http the game still
works, just online only. Players get updates the next time they open the page with a
connection. The service worker was checked in a stand-in for the browser environment
(install, clean-up of old caches, answering offline); try it for real over https:
open the page once, put the device in aeroplane mode, and reopen it.

## Saved data

Progress (coins, cards, the campaign, the saved hands) is kept in the browser's
local storage on that device, not on the website. It is separate from the
desktop game and from other devices, and clearing the browser's site data
erases it.

On an iPad, Safari deletes a site's saved data after seven days of Safari use
with no visit to that site, but a page added to the Home Screen is exempt. So
tell tablet players: open the page, tap Share, then "Add to Home Screen", and
start the game from that icon. (The game also asks the browser to keep its data.)

## How it is put together

* `src/` (shared with the desktop game): all the rules and the game flow
  (`GameController`).
* `web/src/webview.pas`: drawing on the canvas (the table, cards, scenes, panel).
* `web/src/tiecardsweb.pas`: the page's glue (loading, sizing, taps, buttons).
* `web/glue.js`: the few browser calls the Pascal code asks for by name
  (pictures, sound, storage).
* `web/index.html`: the buttons and dialogs.
