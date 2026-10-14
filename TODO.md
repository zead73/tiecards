# Tiecards to-do list

Ideas to review later.

## Next up

- [x] **High scores = personal Records.** Built 2026-10-08 (desktop and web). A
      "Records" button opens the page. Free Play: longest streak in one hand, most
      wins in a row (a hand that is dropped, or stuck, breaks the run; a fresh deal
      you never touched does not), perfect hands and total wins as counts.
      Campaign: longest streak, fewest lost hands to beat each vampire (counted
      over the whole duel: `Campaign.TotalLost`), campaigns completed and duel
      hands won. Only won hands count, and a streak of zero (a hand cleared by
      special cards alone) is no record. When a record is broken the game asks for
      initials (up to 3 letters or digits; the last ones are suggested; Skip gives
      "---") once the table is quiet. Stored in records.ini / browser storage;
      "Erase everything" clears the records (the warning says so). No timer, no
      points formula, as chosen. Ideas if wanted later: a points Top 10, fastest win.

- [x] **Open wrap is stocked late** (user, 2026-10-07: King and Ace are neighbours
      nearly always, so the card is only worth buying near the end). Fenwick
      puts Open wrap on the shelf from the first time the campaign reaches the
      King (the first vampire with no wrap; `FirstNoWrapVampire`); before that its
      row says "Not in stock yet" and he explains. It stays stocked for good
      (saved as `WrapUnlocked` in settings.ini), also after "Restart the
      campaign only"; "Erase everything" takes it off the shelf again. The Full deck
      is stocked the same way from the Queen (the first vampire with a smaller
      stock, `FirstSmallStockVampire`; saved as `StockUnlocked`). Dawn is on sale
      from the start (its stock half helps against the Queen).

- [x] **Special cards + the Store.** Built 2026-10-07 (desktop and web). Six cards
      (Full deck, Open wrap, Dawn, Wild card, Seer's eye, Wood Stake), sold singly
      by Fenwick Grimm in the Store at fixed prices (`src/specials.pas`:
      25 / 25 / 45 / 35 / 30 / 35 coins, tuned 2026-10-08, see the balance entry). The Store also sells the
      undo and hint packs (the Buy buttons are gone from the toolbar; the toolbar
      now has Store and My cards). The Store is open only between hands / on a fresh
      deal. Tapping Store mid-hand makes Fenwick say why. First visit: his
      introduction (tap through, once; Erase everything brings it back). My cards
      opens the tray; Wild card and Wood Stake then ask you to tap a free card
      (Esc, any other tap, or the Cancel button on the web cancels).
      Dawn / Full deck / Open wrap grey themselves out when the hand has nothing for
      them to soften (Free Play, Jack). Using a card forgets the undo and starts the
      hand (the Store shuts). A stuck hand is not lost while an undo card or a
      useful special card is held (`HasRescue`). Hands save the spare cards, reveal
      flag and stake count (old saves still load).
      Things to look at when playing: the prices and how fast coins come in
      (a win pays 20 / 30 / 40 coins in the campaign, 25 in Free Play), Fenwick's lines
      (`[fenwick]` in `assets/story/story.ini`), the card pictures
      (`tools/make_specials.py`), and the tiny row icons on a small desktop window.
      Not built: using a card by tapping a card button directly (only via My cards).
      Store rule (user, 2026-10-07): open whenever no card has been played or
      drawn yet in the hand (a fresh deal, or a hand that is over). Fenwick's
      mid-hand line now says so ("Not once you've played a card..."), and asking
      for the Store while a fresh deal is still being shown finishes the deal and
      opens it. The published web copy (~/html/tiecards) was updated with this fix on 2026-10-07.

## Planned duel changes (decided; details still to design)

- [x] **Five wins to beat each vampire.** Done (2026-10-07). A won hand is one hit,
      paid and saved at once. Per-win coins are 10 / 15 / 20 (Jack / Queen /
      King); the fifth win adds 25 / 35 / 50 as a kill bonus that nothing cuts.
      Wins 1-4 give +1 hint card; the kill gives +1 undo and +2 hints. A lost
      hand makes the NEXT win pay 5 less (floor 5), then resets; wins never go
      down. Wins 1-4 show a click-through hit scene (the hit sound is the
      fatal-blow sound for now); win 5 plays the fatal blow and defeat scenes.
      The panel shows five pips, "Wins N of 5", and the pay. A vampire already
      fought (some wins or lost hands) is not introduced again on reload.
      Things to look at when playing: the numbers (Jack's pay is now 20, so it
      takes three lost hands to reach the 5-coin floor), the new hit lines in `story.ini` (draft, edit
      them), and whether the hit scenes feel too long over 15 wins.
- [x] **Harder after each vampire.** Done (2026-10-07). Levels: Jack = ordinary
      rules (wrap on, 23 stock cards, about 98% of random deals winnable with
      perfect play); Queen = wrap on, 17 stock cards (82%); King = no wrap,
      23 stock cards (78%); changed 2026-10-08 to 20 stock cards (58%). Deals stay plain random; Free Play and the
      missed-move penalty are unchanged. The wrap and stock size are saved with
      each hand (old saves count as ordinary); the panel shows them in one line
      under the pay rows. The numbers live in `src/vampires.pas`
      (`VampireWrapRanks`, `VampireStockCards`). Other measured values: stock 20
      = 92%, 14 = 57%; no wrap with stock 20 = 58%, 17 = 39%. To play-test: is the
      King too hard for a person who cannot see face-down cards (the figures are
      for perfect play with every card visible)?
- [x] **The silver cross (the Easy-Vampire card), built 2026-10-13.** Design from the user:
      hidden on the Queen's and the King's games 1-3 (the game number is wins + 1), never
      on games 4-5; only a Wild card can claim it; once claimed the vampire plays at the
      lowest level until the Queen falls, or for 2 hands against the King. How it works
      (my reading of the gaps): exactly one of games 1-3 is chosen at random when the duel
      begins and saved (`TCampaign.CrossGame`; not re-rolled by loading or retrying); a
      lost game is dealt again with the cross in a new spot; the cross lies on a random
      tableau card (`MarkCross`, placed by `TTriPeaksGame.PlaceCross`; the first version put
      it under a peak, changed the same day after play-testing: bottom-row crosses are
      visible at the deal, so the Store, which is open until the first move, can supply a
      Wild card); playing it normally or Wood Staking it destroys it (the Wild card is the
      only claim), and tapping it normally first asks "Play it anyway?" (`UiState.AskCross`,
      `ActionAnswerCross`; QuestionDlg on the desktop, `dlgCross` on the web); the effect starts with the next hand dealt
      (Jack's level: wrap, 23 stock cards, no trick; the pay stays the vampire's); the
      King's 2 hands count won or lost, and the hand it was claimed in is not one of
      them. State: `Ease` (hands left, -1 = until he falls) and `EaseLive` in
      `campaign.ini` and the campaign save slots. The panel says what is going on
      (`CrossText` in `src/duelinfo.pas`); the card is a gold-ringed silver cross.
      Tests: `TestSilverCross` (testduel), plus tripeaks/hands round trips.
      `CrossCardsOn` (campaign.pas) switches the random cross off in tests. Not in the
      story file: the claim and destroyed notes are in `session.pas` / `duelsession.pas`.
      Play-test: is the Wild-card-only claim too fiddly (the Store is shut mid-hand, so
      you need a Wild card before the hand starts)?

## Web version (built 2026-10-07; first version works)

- [x] **Web port.** `web/build.sh` builds `web/dist/` (about 3 MB of static files:
      copy it to any folder on a website). It runs the same game as the desktop
      one (shared `GameController` in `src/`), drawn on a canvas, with taps,
      an on-screen Skip button during scenes, the panel under the table on tall
      screens (tablet held upright), sound through Web Audio (starts after the
      first tap), saves in the browser's local storage, and an app manifest +
      icons so it can be added to a tablet's Home Screen. Checked in the built-in
      browser at desktop, tablet (768x1024) and phone sizes: play, campaign,
      scenes, panel, save slots, Start over, reload-and-resume, no console errors.
      See `web/README.md`. Needs pas2js 3.x (now unpacked in
      `~/.local/share/tiecards-pas2js/`, the default path; set `PAS2JS_DIR` to use another).
- [ ] **Not yet tried on a real tablet or phone.** Things to look at: touch
      feel, the sound (it cannot be heard from here), the text sizes, the
      phone-sized panel strip (a little cramped under about 500 px wide).
- [x] **Offline play** done (service worker, 2026-10-10); needs https.
- [ ] **iPad saves:** Safari deletes a site's saved data after seven days of
      Safari use with no visit to the site; a page added to the Home Screen is
      exempt. Tell the tablet player to use Share > Add to Home Screen.
- [ ] Keep `tools/check-pas2js.sh` green after any change to `src/` or `web/src/`.

## Pronoun fix (2026-10-14)

- [x] Lines shown for every vampire no longer say "he" or "his": `lost.conceded` and
      `premise.5` in `story.ini`, the silver-cross panel text and claim message, and the
      Rules text now say "the vampire". Lines inside one vampire's own section may use his
      or her pronouns. Any new shared line (scenes, panel, messages) must stay neutral.

## Rules page and README (2026-10-14)

- [x] **Rules button on the start menu.** `src/rules.pas` holds the player's rules as
      sections, built with `Format` from the real constants. The menu has a Rules button
      (Campaign / Free Play / Save | Load / Rules | Quit); the controller sets
      `UiState.ShowRules` and the front end shows it: a scrolling modal window on the
      desktop (`ShowRulesDialog`), a scrolling `dlgRules` dialog on the web. `tests/testrules.pas`
      checks every card, vampire and number is in the text. Not built on the canvas, so no
      font-fitting and touch scrolling works.
- [x] **README.md** (build steps from the scripts, tests, layout, art). The License section
      now points to the MIT `LICENSE` (copyright line: "Zead", the GitHub profile name).

## Ideas

- [x] **Vampire panel.** Done: a framed panel on the left during campaign
      hands showing the duel number, portrait, name, title, what the kill pays
      now, and the lost-hand and missed-move cuts (plus the stuck prompt).
- [x] **Remember the mode.** Done: the game reopens where you left off (a
      finished campaign opens in Free Play).
- [x] **Start over.** Done: a "Start over" button with a warning dialog (Cancel
      is the default). "Erase everything" makes a brand-new player; "Restart the
      campaign only" redoes the story and keeps your coins and cards.
- [x] **All duel scenes wait for clicks.** Done: intro, free round, fatal blow,
      defeat and finale lines all wait for a click (Esc still skips a scene).
- [ ] **Story tweaks.** Play a duel or two, then mark up the dialogue
      (`assets/story/story.ini`) and adjust the pacing (line hold times in
      `src/scenes.pas` are now unused by the duel scenes).
- [x] **Mid-hand vampire effects.** Done 2026-10-12: bites, chains and hunger (see the
      tricks entry), and the silver cross (2026-10-13).
- [ ] **Items.** Jokers, gems, or similar things you can buy or win. Fixed
      prices and deterministic rewards only: no gambling mechanics.

- [x] **High scores.** Done as personal Records (see the entry near the top).
- [x] **Load / save game.** Done: the hand is saved automatically after every
      move (each mode keeps its own), and the game reopens exactly where you
      were, including the moves undo can still take back and your misses. Free Play also has
      three manual save slots (Save / Load buttons; hands only, not your coins).
      Each deal has an id, so a reloaded hand can't be won twice for the reward.

- [x] **Balance pass (2026-10-08).** Measured with simulated hands (real rules code,
      a "play the card that uncovers most" player, 6000 hands per row; a
      throw-away program, not kept). Win chance, greedy player / perfect play:
      wrap+23 stock 53% / 98%; wrap+17: 20% / 82%; no wrap+23: 21% / 78%;
      no wrap+20: 12% / 58%; no wrap+17: 5% / 39%. One special card used
      when stuck (wrap opened at the start): Full deck +33 points on Queen's hands,
      Open wrap +32 on no-wrap hands, Wild card +25 and Wood Stake +23 anywhere
      (a second one adds about +20 more), Dawn +40 where both are missing.
      Findings and changes: (1) Dawn was a dead card, since no vampire had both
      rules softened; King now has no wrap AND 20 stock cards (58% ceiling).
      (2) The campaign paid 10 / 15 / 20 per win against Free Play's 25 for a
      harder hand; now 20 / 30 / 40, kill bonus 30 / 45 / 60 (at a middling
      player's win rates that is about 15 to 19 coins per hand, Free Play
      about 19). (3) Wood Stake cost more than the stronger Wild card; both 35.
      (4) The Seer's eye cannot be measured this way (it changes no cards); left at
      30. Not changed: undo and hint pack prices (undo is stronger now that it goes
      back many moves; watch it in play). Cards stay a luxury, not an investment: one
      card adds about 25 points of one hand's chance, worth far less than its price in
      coins, so nothing snowballs. Design checks live in `TestBalanceShape`
      (`tests/testduel.pas`). To play-test: is King now too hard, and do cards feel
      affordable in the campaign?

- [x] **Menu, house, blood scenes, cheaper Store, softer losses (2026-10-10).**
      Start menu (Campaign / Free Play / Quit; Quit only on the desktop) over a
      picture of the house (`tools/make_house.py`, `assets/house/house.png`); the
      toolbar's old Campaign/Free Play toggle is now a Menu button that returns to it
      (Esc goes back to the table). Hidden cheat: type `coffeeisNOTblood` (any
      capitals) on the menu for +900 coins, every time; the web needs a keyboard
      for it. The campaign opening is told over the house picture, then in the dark
      room. A lost hand now shows the vampire drinking: blood on his fangs, then a
      goblet of your blood, alternating (`tools/make_portraits.py` makes
      `vampire_<name>_fangs.png` and `_cup.png`). The Store charged 50% / 75% /
      100% of list price (changed 2026-10-13 to 50% / 60% / 75%: the tricks cut the later win rates) (rounded up to 5) while you face Jack / Queen / King
      (`VampirePricePercent`; Free Play and a won campaign pay list price). Each lost
      hand cuts 2 coins off the next win, not 5 (`SpoilsStep`). Story: a fourth
      opening line says the vampire bleeds you for a lost hand, and the two
      lost-hand lines mention it.

- [x] **Stats moved into the side panel (2026-10-10).** Cards left, stock, streak
      (and best) and coins sit at the foot of the side panel in both modes, and the
      toolbar line now only carries messages ("You missed a move!", "Welcome back"
      ...). Free Play now has the panel too (title, what the hand pays, the stats),
      so its table sits to the right of it like the campaign's. With no room for a
      panel (a narrow window) the status line still carries the numbers; on a tall
      screen the web page shows them in the strip under the table. The vampire's
      portrait in the panel is a little smaller to make room.

- [x] **Red cards (2026-10-10).** Hearts and diamonds are now deep red on a cream
      card (clubs and spades stay bone on charcoal); the red-on-charcoal versions were
      still hard to read (tried a brighter red first, then this). Edit `PALETTE` in
      `tools/recolor_cards.py` and run `tools/make-art.sh` (all of it: running
      recolor_cards.py alone wipes the court portraits).
      Then aged to old ivory the same day (`tools/age_cards.py`, run by make-art.sh):
      tea-ring stains, yellowed edges and corners, mottling, foxing specks and fine
      grain on the paper only; the cream, the symbols and the portraits are untouched.
      Stains are seeded by card name, so a rebuild gives the same cards.

- [x] **Store open at the start of a restored hand (2026-10-10).** The user hit "can't
      buy" (probably a hand restored mid-play on start-up). A hand put back from a save
      now counts as a fresh start for shopping until its first move, undo or special
      card (`TGameSession.FRestored`); it still counts as a hand under way for the
      records. Tradeoff: closing and reopening the game lets you shop mid-hand.

- [x] **Offline web play and the house in the Free Play panel (2026-10-10).** The web build
      writes `sw.js` (service worker; template `web/sw.template.js`, filled in by
      `web/build.sh`): the first visit caches all ~80 files, later visits work with no
      connection, and each build gets a fresh cache (old ones deleted). It only
      works over https (or localhost). Verified only in a Node stand-in for the worker
      environment: the in-app browser pane refuses to register any service worker, so
      it still needs a real try over https on a tablet (see `web/README.md`). The
      empty middle of the Free Play side panel now shows the house (the middle of
      `assets/house/house.png`, framed), on desktop and web; the narrow strip on tall
      screens does not.

- [x] **Campaign save slots, and Save/Load on the menu (2026-10-11).** The start menu now has
      Save game and Load game (side by side) under Campaign and Free Play. Save lists
      the three slots of the mode you are playing (greyed when there is no hand that can
      be saved, e.g. during a story scene); Load lists Free Play's and the campaign's
      slots and can load either from anywhere, even straight from a fresh start. A
      campaign slot is `campaignslotN.save` (`src/campaignslots.pas`): the campaign's
      progress, your coins and cards, and the duel hand, so loading is a true rewind
      (nothing earned after the save is kept, and a win cannot be paid twice). A Free
      Play slot is still just the hand. The old toolbar Save/Load buttons and the web's
      slot dialog are gone. Erase everything deletes the campaign slots; Restart the
      campaign only keeps them.

- [x] **Mid-hand vampire tricks (2026-10-12).** Built as designed in chat. Lucien (Jack):
      3 *bitten* cards (bat mark): playing one costs 4 coins off the hand's reward
      (`BitePenaltyCoins`) and ends the streak. Carmilla (Queen): 3 *chained* cards
      (chain + padlock), never in the top row and never two side by side: a chained card
      cannot be played while a neighbour in its row is on the table (Wood Stake or Wild
      card get round it). Alaric (King): *hunger*, after every 4th draw (`FeedEvery`) the
      bottom stock card is eaten, into the unused cards, so a Full deck brings it back.
      Marks are placed at the deal (from the shuffle's randomness), hidden under face-down
      cards until they turn over (Seer's eye shows them), saved in the hand
      (`hazard=`, `marks=`, `bites=`, history flags B/F/X; old saves load plain), undone
      by undo, and the panel lists the trick, the bite cost and the pay. Campaign only.
      Levels changed to keep them fair (measured with `tools/trick-solver.pas`, perfect
      play / plain player): Lucien 98% / 52%; Carmilla wrap + 20 stock + chains 76% /
      18%; Alaric no wrap + FULL stock + hunger 48% / 8% (his stock went back from 20 to
      23, Carmilla's from 17 to 20). User chose "special cards sometimes needed", so
      the later vampires are hard without them. Tests switch tricks off with
      `Session.HazardsOn := False` (rigged hands); `TestBittenCards`, `TestChainedCards`,
      `TestHunger`, `TestTrickStates` etc. cover them.
      Each vampire says a `trick.1` line after his intro (`assets/story/story.ini`);
      polished with the rest of the story on 2026-10-12 at the user's request.

- [x] **Story polish (2026-10-12).** At the user's request: reworded the three trick
      lines (no numbers in them, so they cannot go stale), made the lost-hand taunts
      acknowledge the drinking, tied Fenwick's pitches to the tricks (Wild card, Seer's
      eye, Wood Stake), gave the Count and Lucien a closing line each, added a third
      finale line (the cursed cards go quiet), tidied the opening, and documented
      `trick.N` in the file's header. All keys, `%d` formats and line counts the
      code relies on are unchanged.

## Loose ends I know about

- [ ] Balance numbers are placeholders: coin rewards (20 / 30 / 40 per win in the campaign,
      25 in Free Play), the 2-coin step per lost hand, the 5-coin floor, the 4-coin bite,
      the Store percentages (50 / 60 / 75) and the pack prices and sizes. The numbers
      live in `src/inventory.pas`, `src/vampires.pas` and `src/specials.pas`; the
      player's Rules text (`src/rules.pas`) reads them, so it follows any change.
      (The 2-coin missed-move penalty and its sting sound are approved for now.)
- [ ] Listen to the duel sounds on Windows and Linux (bell toll, fatal blow, card
      deal flicks) and tell me if any need changing. The deal flicks can trail
      the cards a little on Linux because the sound player takes a moment to start.
- [x] Windows 11 check: the user ran the exe on Andrea's machine and it works (2026-10-08). Which build, and whether the scene font, sound and icon were looked at, was not said.
- [x] App icon for the Windows exe: the card-back moon, embedded as MAINICON
      (`assets/icon/tiecards.ico`, made by `tools/make-icon.sh`; small sizes are a
      simpler crescent so they read on a taskbar). Seen working on a real Windows 11 machine (Andrea's), 2026-10-08.
- [x] Undo goes back as many moves as you have undo cards for (one card per move
      taken back, as far as the deal; a special card forgets the history). Each
      draw's miss is refunded as it is undone.
