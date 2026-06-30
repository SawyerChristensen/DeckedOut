# Project Roadmap
---

## 🚀 Active Release Milestones

### Update 3.5.3 - July 4 National Cards release
- [x] Make national flag cards available in frontend
  - [x] Test region check
  - [x] Refactor & clean up LetterCardView
  - [x] Add all country flag IAPs to ASC
  - [x] Add Australia to storekit
  - [x] Further organize and alphabatize letter card view
  - [x] Add localized titles for EACH name (ie Old Glory) (50% done)
  - [x] Add emojis to the IAP title
  - [x] Undo return true for availability gate
- [ ] Advertise on App Store as July 4th for US Storefront, World Cup for others

### Update 3.6.0 - Crazy 8s QOL
- [ ] Finalize Mau Mau variant of Crazy 8s (Jack logo card)
  - [ ] Already done? Verify it works?
  - [ ] Review stacking 7s, and if we should change the stacking 2s rule in normal Crazy 8s
- [ ] Switch variant for Ireland/UK?
- [ ] Localized German title cards
- [ ] Add Indian Flag, Turkish Flag, Vietnamese Flag, others?
- [ ] Localize official full listing (relatively easy)
- [ ] Review legacy load states functions (pre-3.0 groupchat update)
  * *Note: Evaluate if keeping them is advisable to prevent crashes for stragglers, or if safe to deprecate.*

### Update 3.6.1
- [ ] Fully Deprecate references to "isSinglePlayer" referencing 1v1 play and replace with "is1v1"
  - *Note: This needs to be done slowly. Right now messages we carry a "isSinglePlayer" payload telling the game engine this is 1v1 play. For 1-2 update generations, there needs to be both "isSinglePlayer" and "is1v1" in the payload so the transition works smoothly***** with app versions who haven't updated yet. Detect both and remove isSinglePlayer in a future update.


### Update 4.0.0: 4th Game Expansion
- [ ] Implement Cribbage
  - [ ] Backend
  - [ ] Frontend

### Update 5.0.0: 5th Game & Progression
- [ ] Implement Spades
  - [ ] Backend
  - [ ] Frontend

### General Updates
- [ ] MAKE GAME CENTER WORK! 99% Done!
  - [x] Achievements are implemented in ASC
  - [x] Game Center is enabled in ASC
  - [x] Entitlements are present in both the extension and parent stub
  - [x] Game Center capability is enabled as an identifier in another ASC section somewhere (cant remember where)
  - [ ] Thought the bundle ID swizzle was working but it does not appear to work in production, and also messages with the bundled asset lookups. Work with apple to figure out a straightforward way to support Game Center achievements in iMessage
  - [ ] Get rid of jacks queens and kings explanation in golf master gc text (translate/upload with claude) (doesnt really matter now)
  - [ ] Change Game Center 1 & 2 win icons to be sunset and ocean
- [ ] Monetization Strategy
  - [ ] Add more Card Back IAPs
  - [ ] Add IAP localizations in App Store Connect (automate w/script?)
  - [ ] Integrate Ads mechanism ($$$)
  - [ ] Roll out more localized storefronts *(Post max-conversion rate design confirmed)*
- [ ] UI Polish
  - [ ] Create a unique, better win screen for each game
- [ ] Organize and refactor project structure

### Localization
- [ ] Polish
  - [ ] Migrate the translated Polish flag name from the English localization to a Polish localization
- [ ] Finnish
  - [ ] Migrate the translated Finnish flag name from the English localization to a Finnish localization
- [ ] RTL Support for:
  - [ ] Arabic
  - [ ] Hebrew
- [ ] Bengali
- [ ] Flags for India, Pakistan, Nepal, Bangladesh

---

## 🃏 Game Backlog

### Card Games
- [x] Gin Rummy
- [x] Crazy 8s
- [x] Golf
- [ ] Cribbage
- [ ] Spades (4 players)
- [ ] Hearts
- [ ] Euchre (4 players)
- [ ] Idiot
- [ ] Switch
- [ ] Scopa?
- [ ] Whot?
- [ ] Yaniv?

### Dice Games
- [ ] Farkle?
- [ ] Yacht?

---

## 🎨 Customization Shop & Aesthetics (IAP Roadmap)

### Monetization Tiers & Card Backs
- [ ] **Remove Ads ($0.99):** Core functionality *(Blocker: Requires ad integration first)*
- [ ] **Premium Card Backs ($0.99 - $1.99):** *(Includes Remove Ads bundle)*
  - [ ] Lantern Card Back *(Letters glow illumination effect)*
  - [ ] Team Trees charity theme
  - [ ] Honeycomb pattern *(Bee charity theme)*
  - [ ] Animated looping backgrounds?
  - [ ] Solid Gold texture
  - [ ] **Ultra Custom ($2.99):** Photo upload capabilities
- [ ] **Card Fronts**
  - [ ] *Free Tier:* Basic regional layout variations
  - [ ] *Free Tier:* Accessibility-friendly zoomed layout
  - [ ] *Paid Tier:* Queen Bee & unique royalty styles for bee charity *(Red assets color-shifted to orange)*
- [ ] Design a unique Ace of Spades card to accompany every custom card back style

### Additional Cosmetics
- [ ] Player Avatars
- [ ] Interactive table backgrounds / aesthetics matching card backs
- [ ] Custom card dealing animations and particle effects

---

## 🛑 Known Issues & Critical Bugs

### Core App & Framework Blocks
- [ ] **First Launch Hang:** Investigate why app goes to a white screen and fails to load when opened for the first time via the App Store.
- [ ] **Game Center Integration:** Resolve Game Center support limitations for iMessage-only apps *(Collaborate with Apple engineering / documentation).*

### UI Layout & Z-Index Artifacts
- [ ] Fix rendering hierarchy in group chat Crazy 8s: "Selected" text renders below opponent hand's Z value.
- [ ] Refactor opponent hand Z-index layers: Must sit lower than the deck layer, but drawn cards must dynamically spawn on top to prevent clipping.

### Animation Glitches
- [ ] **Crazy 8s:** Discarding a Queen and immediately executing another card as the final move skips the Queen's discard animation.
- [ ] **1v1 Mode:** If drawing cards causes a user to receive a Queen, play it, draw more, and discard again, animations break if drawing more than 3 cards.

### Accessibility Additions
- [ ] Enable Voice Control users to be able to send discard and automatically send messages the same way that discarding a card via touch does

---

## 🧠 Quality of Life (QOL) & UX Polish

### Gameplay Logic & Transitions
- [ ] Only highlight melded cards *after* a complete game win (1v1 10-card Gin Rummy).
- [ ] Allow players to rearrange their hand layout during an opponent's turn (disable draw interaction).
- [ ] Block against highly improbable first-turn wins (~1 in 300,000 edge case).
- [ ] Implement auto-sorting capability for player hands.
- [ ] Add a visual drag gesture interaction to the discard pile in Gin in addition to standard taps.
- [ ] Redesign win screen using an expressive Joker card asset (happy/sad dynamically based on outcome with colored drop shadows).

### Accessibility & System Preferences
- [ ] **Reduce Motion support:** Disable main menu card flips and themes menu entry animations when system flag is active *(Prefer cross-fade transitions).*
- [ ] **Differentiate Without Color support:** Revert main menu iconography back to clear white outlines when active.
- [ ] **Accessibility Show Numbers:** Fix vertical stacking behavior on card fans (should scale left-to-right).
- [ ] Dynamic card sizing: Grow card frame constraints when system accessibility text scaling is active.

### UI & Aesthetics Polish
- [ ] Replace feltBackgroundDark with the light one & a dark opacity overlay to save 1.4 MB of space
- [ ] Look into better transitions between the card fronts. (Move out of CardView, into discard piles in game views? Cards in opponents hand should instantly transition if they are starting to reveal themselves anyway)
- [ ] Rework themes menu to add a "Preview" button. (next to price?) (can push to later)
- [ ] When swiping between main title cards, sometimes the title animates in from the wrong direction if the user is swiping fast
- [ ] Adjust colors of default deck
- [ ] Have the main menu submenus revealed instead of pulled up
- [ ] Add a Game Center rocket shortcut button directly to the main menu view.
- [ ] Investigate why the arrow replace animation fails to mimic the native SF Symbols behavior.
- [ ] Display an optional "Tap card to play" reminder layout text with repeating opacity animations if main menu idle time is high.
- [ ] Dynamically update deck UI number count based on cards remaining. Shift visual style when deck drops below 5 cards.
- [ ] Resolve menu frame physics issue: Tapping rapidly between games increases the fan's upwards animation speed unnaturally.
- [ ] Randomize discard pile scattering layout slightly instead of keeping a perfectly straight vertical stack.
- [ ] Set max-width layout restrictions for transcript views to prevent clipping/stretching on iPad layouts.
- [ ] Add subtle white glow outline on active cards. Disable letter flipping; reveal user's hand directly when it becomes their turn to move.
- [ ] Update theme titles to visually match their respective configured fonts.
- [ ] Introduce a colored deck variant specifically for Crazy 8s.
- [ ] Experiment with rotating an HStack/VStack configuration in the Crazy 8s submenu for dynamic transitions.

---

## ⚙️ Refactoring & Code Optimization

### Architecture & Modernization
- [ ] Look into deprecating the `isSinglePlayer` flag globally across views and replacing it with direct `seats.count` checks.
- [ ] Refactor and organize main menu submenu layouts (minimize current dependency on opacity toggles for compact/extended view logic).
- [ ] Evaluate the exact utility of `isFromMe` in transcript views; evaluate if it can be stripped or if it is strictly required for legacy transcripts.
- [ ] Modify or duplicate the metadata file to just modify the local game center file, then we push manually after reviewing it
- [ ] Clean up `GameManager`: Audit and remove unnecessary occurrences of `self` for cleaner syntax.
- [ ] Review `GameManager` state variables: Identify exactly which properties require `@Published` attributes to optimize object-will-change cycles.
- [ ] Investigate background threading optimization for core game logic computation vs. keeping UI renders isolated to the Main Thread.
- [ ] Research transcript deep-linking behavior: Determine if tapping "Join" inside a standard transcript window can invoke a message layer or join active matches automatically.

### Component Cleans
- [ ] **Gin Rummy:** Look into removing explicit `cardHeight` parameter requirements passed directly to individual card subviews from the opponent hand layout.
- [ ] **Golf:** Review backend and remove `handRotation` properties if confirmed redundant (Golf hands are never rotated).
- [ ] Clean up player hand extensions by testing if default initialization structures can safely replace custom `init` methods.
- [ ] Consolidate shadow modifiers: Golf player shadows reside in the main game view while opponent shadows reside in `OpponentHandView`. Unify for layout consistency.
- [ ] Address differences in animation completion handlers for draw actions between Gin and Crazy 8s.
- [ ] Optimize state bindings: Check out the `.constant` binding logic implementation inside `ginPlayerView`.
- [ ] Implement groupchat configuration features to support user-entered usernames. (Custom or Game Center?)

### Minor Fixes & Data Optimization
- [ ] Shrink shipped Joker cards for storage optimization
- [ ] Review sound manager warning. It's init should still probably be on a background thread to keep main clear.
- [ ] Add an interface onboarding notice clarifying that Aces are not high cards in Gin Rummy.
- [ ] Force invite views to pause/wait when a "GIN!" state is declared.
- [ ] Add an immediate restart action path directly within the game win view overlay.
- [ ] Design an animation block handling deck reshuffling sequences when counts strike 0.
- [ ] Add a resume action item if a user exits out back to the main menu view mid-game.
- [ ] Polish discard transition speed/animations (Low priority—current instant response is highly performant).
- [ ] Investigate native behavior of `didCancelSending` to see if an Easter egg putting cards back on the deck is viable.
- [ ] Audit view hierarchy lifecycle: Confirm if an explicit `ginRootView` wrapper layer is required, or if direct initialization of `gameView` is sufficient.
- [ ] Check `presentView` logic to ensure active pop-up window dismissals are fully unlinking.
- [ ] Build handling logic to clear a mid-turn cloud save instance if the backend detects the user resumed the game state on a secondary device.
- [ ] Investigate local localization naming structures across card games (e.g., Switch vs. New Zealand's "Last Card").
- [ ] Internationalization: Alphabetize the game selection view dynamically according to localized strings, pinning the most popular variant dead center.
- [ ] Fix frame layout jitter bugs visible inside the invite transcript card layout.
- [ ] Verify why yellow win shadows are not properly animating into view on Gin and Crazy 8s end states.
- [ ] Clean up initialization code: Move custom `init` logic inside `PlayerHandView` out of the extension and into the main declaration body wrapper.
- [ ] Debug audio layer warning: Trace and eliminate the "audio session failure" print statement occurring in console streams.
- [ ] Does "isFaceUp" need to be a passed variable?

