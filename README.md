# 999 Bag Slots

Raises the bag's capacity from 20 to 999 distinct item slots, so the
"This is too full!" refusal goes away.

Try it: enable the mod, then collect a 21st distinct item — it is accepted.
Each item still stacks to 99 per slot (that cap is unchanged).

## How it works

The engine reads the capacity from `Data.constants.bagSize`
(`src/inventory/Bag.lua`); this mod patches that constant to 999. It is pure
data — no engine seams.

## Install

Copy the `bag_999` folder into your install's `mods/` directory (one level
deep, alongside the other discovered mods), or use `modkit.py`:

```sh
python3 tools/modkit.py pack mods/bag_999
```

## Compatibility

- Per-slot stack cap of 99 is untouched.
- Legacy Gen 1 save imports read at most 20 bag items; the new cap applies
  to fresh native saves.
