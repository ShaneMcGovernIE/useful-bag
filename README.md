# Useful Bag

A 999-capacity bag auto-sorted into six pockets — ITEMS, MEDICINE, POKé
BALLS, TMs / HMs, BATTLE ITEMS and KEY ITEMS — that you cycle with
LEFT/RIGHT.

## What you get

- **Capacity.** `constants.bagSize` is patched from 20 to 999 distinct item
  slots, and `field.pcItemCap` raises the PC storage from 50 to 999 stacks,
  so "This is too full!" and "No room left to store items." go away.
- **Six pockets.** Items are auto-sorted into ITEMS, MEDICINE, POKé BALLS,
  TMs / HMs, BATTLE ITEMS and KEY ITEMS. Cycle pockets with LEFT/RIGHT,
  wrapping around at both ends.
- **Battle-aware bag.** In battle the bag opens on BATTLE ITEMS (or the
  first non-empty usable pocket) and LEFT/RIGHT skips TMs / HMs and KEY
  ITEMS, which can't be used mid-battle — no more scrolling through TMs
  when you need a Hyper Potion.
- **A hidden bag.** The pockets are filtered projections of the flat
  inventory (`save.inventory` + `bagOrder`); nothing is moved out of it. So
  key items keep working no matter which pocket the bag was closed on — PC
  deposit a key item and it leaves the hidden bag and the KEY ITEMS pocket
  together, and using a potion decrements the same count the MEDICINE
  pocket shows.
- **Sort.** TAB (keyboard) or R3 / right stick click (controller) opens a
  SORT BY NAME / SORT BY COUNT prompt while the bag is open. Shift keys
  still perform the vanilla SELECT item swap.
- **PC SELECT-swap.** In the PC's WITHDRAW / DEPOSIT / TOSS item lists,
  press SELECT to mark an item, then SELECT (or A) again on another row to
  swap them — the vanilla reorder that was missing. Withdraw/Toss reorder
  the PC storage and Deposit reorders the bag, and the lists open in your
  stored order.
- **Full TM/HM names.** Machine items read "TM14 BLIZZARD" (not just
  "TM14") in the bag and the PC. "TM14" stays put and the move name
  scrolls as a horizontal ticker — hold at the start, scroll across, hold,
  scroll back — so long ones like "TM15 HYPER BEAM" stay readable instead
  of bleeding over the count.
- **Cursor wrap.** The bag cursor wraps at the first/last item: Up on the
  first goes to the last and vice versa.

## How it works

The engine reads the capacity from `Data.constants.bagSize`
(`src/inventory/Bag.lua`) and the PC cap from `Data.field.pcItemCap`
(`src/ui/PlayerPC.lua`); this mod patches both to 999 and projects the
flat inventory into the six pockets at the bag screen.

## Install

Copy the `useful_bag` folder into your install's `mods/` directory (one
level deep, alongside the other discovered mods), or use `modkit.py`:

```sh
python3 tools/modkit.py pack mods/useful_bag
```

## Compatibility

- Per-slot stack cap of 99 is untouched.
- Legacy Gen 1 save imports read at most 20 bag items; the new cap applies
  to fresh native saves.
