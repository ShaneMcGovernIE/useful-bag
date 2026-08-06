# Changelog

## [2.4.1] - 2026-08-06

### Fixed

- TM ticker duplicated the pinned prefix: the scrolled text re-ran "TM01 "
  ("TM01 TM01 MEGA PUNCH"). Only the move name scrolls now — the pinned
  "TM01 " part is drawn once.

## [2.4.0] - 2026-08-06

### Added

- Full TM/HM names in the bag and the PC: machine items label as
  "TM14 BLIZZARD" instead of just "TM14". The TM/number part stays pinned;
  when the move name is too wide for the row it scrolls as a horizontal
  ticker (the MoveRelearn pacing) instead of bleeding over the count.

## [2.3.0] - 2026-08-06

### Added

- PC SELECT-swap: the WITHDRAW / DEPOSIT / TOSS item lists in the player's
  PC now support the vanilla item-swap (press SELECT to mark an item, a
  second SELECT — or A — swaps it with the cursor row). Withdraw and Toss
  reorder the PC storage (`save.pcOrder`); Deposit reorders the bag
  (`save.bagOrder`), matching the original game. The lists also open in
  the stored order instead of alphabetical, so a reorder persists across
  reopening.

## [2.2.0] - 2026-08-05

### Added

- PC item storage now holds 999 distinct stacks instead of 50:
  `field.pcItemCap` is patched alongside `constants.bagSize`, so "No room
  left to store items." stops appearing.

## [2.1.0] - 2026-08-05

### Added

- Battle-aware pockets: the in-battle bag now opens on the BATTLE ITEMS
  pocket (or the first non-empty usable pocket) and its LEFT / RIGHT
  cycling skips TMs / HMs and KEY ITEMS, which can't be used mid-battle.

## [2.0.0] - 2026-08-05

### Changed

- Renamed the mod from "999 Bag Slots" to "Useful Bag" (mod id `bag_999` -> `useful_bag`).

### Added

- The bag auto-sorts into six pockets: ITEMS, MEDICINE, POKé BALLS, TMs / HMs, BATTLE ITEMS and KEY ITEMS, cycled with LEFT/RIGHT (wrapping at both ends).
- A hidden bag (the flat inventory) stays the active bag underneath the pockets, so key items keep working no matter which pocket the bag was closed on; PC deposits and item uses are mirrored into every pocket automatically.

## [1.2.0] - 2026-08-03

### Added

- The bag cursor wraps around: Up on the first item lands on the last,
  Down on the last lands on the first, in and out of battle. No more
  scrolling back through hundreds of slots to reach the other end.

## [1.1.0] - 2026-08-02

### Added

- Bag sort shortcut: TAB (keyboard) or R3 / right stick click
  (controller) opens a SORT BY NAME / SORT BY COUNT prompt while the bag
  is open. Count sort puts the biggest stacks first. The order persists
  in the save. Shift keys still perform the vanilla SELECT item swap;
  TAB is repurposed from SELECT while the bag is open.

## [1.0.0] - 2026-08-01

### Added

- `constants.bagSize` patched 20 -> 999, raising the bag's distinct-item
  capacity. Quantity cap per slot (99) unchanged.
