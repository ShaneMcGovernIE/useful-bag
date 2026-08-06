-- Standalone: luajit mods/useful_bag/tests/useful_bag_test.lua
-- Loads the mod through the real headless loader and asserts its stated
-- effects: the 999-capacity patch, the pocket classification, the hidden
-- bag that the pockets project from, L/R pocket wrap-around, and the sort
-- helpers.  Run from the engine checkout.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local run = T.sdk.loadMod("mods/useful_bag", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")

T.eq(Data.constants.bagSize, 999, "bagSize patched to 999")
T.eq(Data.field.pcItemCap, 999, "pcItemCap patched to 999 (PC storage cap)")

local Bag = require("src.inventory.Bag")
T.eq(Bag.capacity(Data), 999, "Bag.capacity reads the patched constant")

local save = { inventory = {}, bagOrder = {} }
for i = 1, 20 do
  Bag.add(save, "POTION" .. i, 1, Data)
end
T.check(Bag.add(save, "VANILLA_ITEM", 1, Data), "a 21st item is accepted")
T.eq(Bag.slots(save), 21, "bag holds 21 distinct items")

-- ------------------------------------------------ pocket classification

local ex = run.loader.exports.useful_bag
T.neq(ex, nil, "exports reachable")

-- seed item defs so classify has names + flags to read; the fixture only
-- carries one of each seam (FIX_POTION/FIX_BALL/FIX_TM/FIX_BADGE)
Data.items.POTION = { id = "POTION", name = "Potion" }
Data.items.POKE_BALL = { id = "POKE_BALL", name = "Poké Ball" }
Data.items.TM_01 = { id = "TM_01", name = "TM01" }
Data.items.HM_01 = { id = "HM_01", name = "HM01" }
Data.items.X_ATTACK = { id = "X_ATTACK", name = "X Attack" }
Data.items.REPEL = { id = "REPEL", name = "Repel" }
Data.items.BICYCLE = { id = "BICYCLE", name = "BICYCLE" }
Data.items.ITEMFINDER = { id = "ITEMFINDER", name = "ITEMFINDER", keyItem = true }
Data.items.ESCAPE_ROPE = { id = "ESCAPE_ROPE", name = "Escape Rope" }
Data.items.EXP_ALL = { id = "EXP_ALL", name = "EXP.ALL" }
Data.items.OLD_ROD = { id = "OLD_ROD", name = "Old Rod" }
Data.items.POKE_FLUTE = { id = "POKE_FLUTE", name = "POKé FLUTE" }
Data.items.SAFARI_BALL = { id = "SAFARI_BALL", name = "SAFARI BALL" }
Data.items.SURFBOARD = { id = "SURFBOARD", name = "SURFBOARD" }

T.eq(ex.classify(Data, "POTION"), "medicine", "POTION -> medicine")
T.eq(ex.classify(Data, "POKE_BALL"), "balls", "POKE_BALL -> balls")
T.eq(ex.classify(Data, "TM_01"), "tms", "TM_01 -> tms")
T.eq(ex.classify(Data, "HM_01"), "tms", "HM_01 -> tms")
T.eq(ex.classify(Data, "FIX_TM"), "tms", "machine field -> tms")
T.eq(ex.classify(Data, "X_ATTACK"), "battle", "X_ATTACK -> battle")
T.eq(ex.classify(Data, "REPEL"), "items", "REPEL -> generic items")
T.eq(ex.classify(Data, "BICYCLE"), "key", "fallback key set -> key")
T.eq(ex.classify(Data, "ITEMFINDER"), "key", "keyItem flag -> key")
T.eq(ex.classify(Data, "FIX_BALL"), "balls", "ball field -> balls")

-- regression: the key set mirrors the game's KeyItemFlags, so ESCAPE_ROPE
-- and EXP_ALL are standard items, while the rods/flute/board are key
T.eq(ex.classify(Data, "ESCAPE_ROPE"), "items",
  "ESCAPE_ROPE is not a key item (KeyItemFlags FALSE)")
T.eq(ex.classify(Data, "EXP_ALL"), "items",
  "EXP_ALL is not a key item (KeyItemFlags FALSE)")
T.eq(ex.classify(Data, "OLD_ROD"), "key", "OLD_ROD -> key (KeyItemFlags TRUE)")
T.eq(ex.classify(Data, "POKE_FLUTE"), "key",
  "POKE_FLUTE -> key from the fallback list, no flag set")
T.eq(ex.classify(Data, "SAFARI_BALL"), "key",
  "SAFARI_BALL -> key (KeyItemFlags TRUE), despite being a ball")
T.eq(ex.classify(Data, "SURFBOARD"), "key", "SURFBOARD -> key")

-- ------------------------------------------------ the hidden bag

-- the hidden bag is the flat acquisition order; pockets are projections
-- of it, so the union of all six pockets is the hidden bag with no
-- overlap, and every engine write (PC deposit, item use) shows up in both
local order = { "POTION", "POKE_BALL", "TM_01", "X_ATTACK",
                "ITEMFINDER", "REPEL", "BICYCLE" }
local union, seen = {}, {}
for _, p in ipairs(ex.POCKETS) do
  local ids = ex.pocketItems(order, Data, p.id)
  for _, id in ipairs(ids) do
    T.check(not seen[id], "no item spans two pockets: " .. id)
    seen[id] = true
    table.insert(union, id)
  end
end
table.sort(union)
local sorted = {}
for _, id in ipairs(order) do table.insert(sorted, id) end
table.sort(sorted)
T.eq(table.concat(union, ","), table.concat(sorted, ","),
  "pockets partition the hidden bag exactly")

local s = { inventory = { POTION = 5, BICYCLE = 1 }, bagOrder = { "POTION", "BICYCLE" } }
T.eq(table.concat(ex.hiddenOrder(s), ","), "POTION,BICYCLE",
  "hiddenOrder returns the flat acquisition order")

-- PC-deposit the key item: Bag.remove writes the real inventory, so it
-- leaves the hidden bag and the KEY ITEMS pocket together
Bag.remove(s, "BICYCLE", 1)
T.eq(table.concat(ex.hiddenOrder(s), ","), "POTION",
  "hidden bag drops the deposited key item")
T.eq(#ex.pocketItems(ex.hiddenOrder(s), Data, "key"), 0,
  "KEY ITEMS pocket drops the deposited key item")

-- use a potion: the count shrinks in the hidden bag and the MEDICINE
-- pocket reads the same inventory
Bag.remove(s, "POTION", 2)
T.eq(s.inventory.POTION, 3, "hidden inventory after a potion use")
T.eq(#ex.pocketItems(ex.hiddenOrder(s), Data, "medicine"), 1,
  "MEDICINE pocket still lists the potion")

-- ------------------------------------------------ L/R wrap-around

T.eq(ex.adjacentPocket(1, -1), #ex.POCKETS, "LEFT on the first pocket wraps to the last")
T.eq(ex.adjacentPocket(#ex.POCKETS, 1), 1, "RIGHT on the last pocket wraps to the first")
T.eq(ex.adjacentPocket(2, 1), 3, "RIGHT advances one pocket")

-- ------------------------------------------------ the pocketed bag menu

-- game.ready installs the bag-session state; the stub game needs a working
-- stack so the sort-prompt push can be observed
local StateStack = require("src.core.StateStack")
local stack = setmetatable({}, { __index = StateStack })
stack:init()
local stub = {
  save = { inventory = {}, bagOrder = {}, money = 0 },
  data = Data,
  stack = stack,
  input = { wasPressed = function() return false end,
            isDown = function() return false end },
}
run.loader.events:emit("game.ready", { game = stub })

-- the mod registers a BagMenu screen, so the list is resolved through the
-- screens registry (Screens.get), not by requiring the builtin directly
local Screens = require("src.ui.Screens")
local list = Screens.get(stub, "BagMenu").new(stub)
T.check(list.wrap, "bag list wraps up/down at the ends")
T.eq(list.__pocketIndex, 1, "opens on the ITEMS pocket")
T.eq(list.title, "ITEMS", "title is the pocket label")

stub.save.inventory.POTION = 2
stub.save.bagOrder = { "POTION" }
ex.switchPocket(list, 1) -- ITEMS -> MEDICINE
T.eq(list.__pocketIndex, 2, "RIGHT moved to MEDICINE")
T.eq(list.title, "MEDICINE", "title follows the pocket")
T.eq(#list.items, 1, "the potion shows in MEDICINE")
T.eq(list.items[1].value, "POTION", "the potion row carries its id")
T.eq(list.items[1].right, "x2", "the potion row carries its count")

ex.switchPocket(list, -1) -- MEDICINE -> ITEMS
ex.switchPocket(list, -1) -- ITEMS -> KEY ITEMS (wrap)
T.eq(list.__pocketIndex, #ex.POCKETS, "LEFT from ITEMS wraps to KEY ITEMS")

-- ------------------------------------------------ TAB sort regression

-- pressing TAB used to crash: openSortPrompt was declared after decorate(),
-- so the bag's update closure resolved it as a nil global.  Drive the real
-- flow: TAB press -> prompt pushed -> option selected -> bag reorders.
stub.save.inventory = { POTION = 2, BICYCLE = 1 }
stub.save.bagOrder = { "POTION", "BICYCLE" }
local sortBag = Screens.get(stub, "BagMenu").new(stub)
stack:push(sortBag)
local Input = require("src.core.Input")
Input.keypressed(Input, "tab") -- swallowed by the wrapper -> session.wantSort
sortBag:update(1 / 60)         -- the bag's update opens the prompt
T.check(stack:top() ~= sortBag, "TAB pushes the SORT BY NAME / COUNT prompt")
local prompt = stack:top()
T.check(prompt.items and prompt.items[1] and prompt.items[2],
  "prompt offers both sort modes")
prompt.items[1].onSelect() -- SORT BY NAME
T.eq(table.concat(stub.save.bagOrder, ","), "BICYCLE,POTION",
  "name sort runs through the prompt without crashing")
Input.keypressed(Input, "tab")
sortBag:update(1 / 60)
stack:top().items[2].onSelect() -- SORT BY COUNT
T.eq(table.concat(stub.save.bagOrder, ","), "POTION,BICYCLE",
  "count sort runs through the prompt without crashing")

-- ------------------------------------------------ battle-aware pockets

-- a battle bag opens on BATTLE ITEMS and its L/R cycling skips TMs / HMs
-- (index 4) and KEY ITEMS (index 6), wrapping through the usable pockets
stub.save = {
  inventory = { X_ATTACK = 2, POTION = 3, POKE_BALL = 4, TM_01 = 1, BICYCLE = 1 },
  bagOrder = { "X_ATTACK", "POTION", "POKE_BALL", "TM_01", "BICYCLE" },
  money = 0,
}
local battleBag = Screens.get(stub, "BagMenu").new(stub, { battle = {} })
T.check(battleBag.__battle ~= nil, "battle bag flags itself")
T.eq(battleBag.title, "BATTLE ITEMS", "battle bag opens on BATTLE ITEMS")
T.eq(#battleBag.items, 1, "battle bag shows only the X_ATTACK")
T.eq(battleBag.items[1].value, "X_ATTACK", "X_ATTACK is the sole row")

ex.switchPocket(battleBag, 1) -- battle -> key (skipped) -> wraps to items
T.eq(battleBag.title, "ITEMS", "RIGHT from BATTLE ITEMS lands on ITEMS, skipping KEY")
ex.switchPocket(battleBag, 1)
T.eq(battleBag.title, "MEDICINE", "RIGHT from ITEMS lands on MEDICINE")
ex.switchPocket(battleBag, 1)
T.eq(battleBag.title, "POKé BALLS", "RIGHT from MEDICINE lands on POKé BALLS")
ex.switchPocket(battleBag, 1)
T.eq(battleBag.title, "BATTLE ITEMS", "RIGHT from POKé BALLS wraps back to BATTLE ITEMS")
ex.switchPocket(battleBag, -1) -- battle -> tms (skipped) -> balls
T.eq(battleBag.title, "POKé BALLS", "LEFT from BATTLE ITEMS lands on POKé BALLS, skipping TMs")

-- empty BATTLE ITEMS falls back to the first non-empty usable pocket
stub.save = { inventory = { POTION = 3, POKE_BALL = 4 },
              bagOrder = { "POTION", "POKE_BALL" }, money = 0 }
local fallbackBag = Screens.get(stub, "BagMenu").new(stub, { battle = {} })
T.eq(fallbackBag.title, "POKé BALLS",
  "empty BATTLE ITEMS falls back to the first non-empty usable pocket")

-- overworld bags are unaffected: all six pockets still cycle
stub.save = { inventory = { POTION = 2 }, bagOrder = { "POTION" }, money = 0 }
local owBag = Screens.get(stub, "BagMenu").new(stub)
T.check(not owBag.__battle, "overworld bag is not battle-flagged")
T.eq(owBag.title, "ITEMS", "overworld bag still opens on ITEMS")
ex.switchPocket(owBag, 1)
T.eq(owBag.title, "MEDICINE", "overworld bag still cycles to MEDICINE")

-- ------------------------------------------------ sort feature

-- seed item names so the name sort has something to compare
Data.items.APPLE = { id = "APPLE", name = "Apple" }
Data.items.BANANA = { id = "BANANA", name = "Banana" }
Data.items.CHERRY = { id = "CHERRY", name = "Cherry" }

local s2 = {
  inventory = { BANANA = 2, CHERRY = 9, APPLE = 5 },
  bagOrder = { "BANANA", "CHERRY", "APPLE" },
}

T.eq(table.concat(ex.computeOrder(s2, Data, "name"), ","),
  "APPLE,BANANA,CHERRY", "name sort is alphabetical")
T.eq(table.concat(ex.computeOrder(s2, Data, "count"), ","),
  "CHERRY,APPLE,BANANA", "count sort puts the biggest stack first")
s2.inventory.CHERRY = 2
T.eq(table.concat(ex.computeOrder(s2, Data, "count"), ","),
  "APPLE,BANANA,CHERRY", "count tie falls back to id order")

T.eq(table.concat(s2.bagOrder, ","), "BANANA,CHERRY,APPLE",
  "computeOrder leaves the save untouched")
s2.inventory.CHERRY = 9 -- restore the biggest stack
ex.applySort(s2, Data, "count")
T.eq(table.concat(s2.bagOrder, ","), "CHERRY,APPLE,BANANA",
  "applySort rewrites the live bagOrder")
ex.applySort(s2, Data, "name")
T.eq(table.concat(s2.bagOrder, ","), "APPLE,BANANA,CHERRY",
  "applySort name pass reorders again")

-- ------------------------------------------------ PC SELECT-swap

-- pcOrder mirrors Bag.order for the PC storage: built sorted on first
-- touch, persisted into save.pcOrder, pruned of stale ids, appended with
-- new deposits
local pcSave = { pcItems = { POKE_BALL = 5, POTION = 3, REPEL = 2 } }
T.eq(table.concat(ex.pcOrder(pcSave), ","), "POKE_BALL,POTION,REPEL",
  "pcOrder builds the acquisition order (sorted on first touch)")
T.check(pcSave.pcOrder ~= nil, "pcOrder persists into save.pcOrder")

ex.swapOrder(pcSave.pcOrder, "POTION", "REPEL")
T.eq(table.concat(pcSave.pcOrder, ","), "POKE_BALL,REPEL,POTION",
  "swapOrder swaps two ids in save.pcOrder")
ex.swapOrder(pcSave.pcOrder, "POTION", "MISSING")
T.eq(table.concat(pcSave.pcOrder, ","), "POKE_BALL,REPEL,POTION",
  "swapOrder with a missing id is a no-op")

local pcRows = {
  { value = "POTION", label = "Potion" },
  { value = "REPEL", label = "Repel" },
  { value = "POKE_BALL", label = "Poké Ball" },
}
ex.reorderItems(pcRows, pcSave.pcOrder)
T.eq(pcRows[1].value, "POKE_BALL", "reorderItems ranks by the order list")
T.eq(pcRows[2].value, "REPEL", "reorderItems follows the swapped order")
T.eq(pcRows[3].value, "POTION", "reorderItems follows the swapped order")

pcSave.pcItems.SUPER_POTION = 1
pcSave.pcItems.REPEL = nil
T.eq(table.concat(ex.pcOrder(pcSave), ","),
  "POKE_BALL,POTION,SUPER_POTION",
  "pcOrder prunes a tossed stack and appends a new deposit")

-- the game.ready listener already wrapped ListMenu.new, so a PC list built
-- through it gets the SELECT-swap; the withdraw list opens in pcOrder (not
-- alphabetical) and SELECT swaps write save.pcOrder
local stubPc = {
  save = { pcItems = { POKE_BALL = 5, POTION = 3, REPEL = 2 }, bagOrder = {} },
  data = Data,
  input = { wasPressed = function() return false end,
            isDown = function() return false end },
}
local ListMenu = require("src.ui.ListMenu")
local withdraw = ListMenu.new(stubPc, "WITHDRAW ITEM", {
  { value = "POTION", label = "Potion" },
  { value = "REPEL", label = "Repel" },
  { value = "POKE_BALL", label = "Poké Ball" },
})
T.check(withdraw.onSelectKey ~= nil, "withdraw list got the SELECT-swap")
T.eq(withdraw.items[1].value, "POKE_BALL", "withdraw list opens in pcOrder")
withdraw.onSelectKey(withdraw.items[1], withdraw) -- mark the first row
withdraw.index = 3
withdraw.onSelectKey(withdraw.items[3], withdraw) -- swap with the cursor row
T.eq(withdraw.items[1].value, "REPEL", "SELECT marks then swaps the PC row")
T.eq(withdraw.items[3].value, "POKE_BALL", "the marked row moves to the cursor")
T.eq(table.concat(stubPc.save.pcOrder, ","), "REPEL,POTION,POKE_BALL",
  "the PC storage order is rewritten in the save")

-- the deposit list follows the bag (save.bagOrder), like the original
local stubDep = {
  save = { inventory = { POTION = 3, REPEL = 2, POKE_BALL = 5 },
           bagOrder = { "REPEL", "POTION", "POKE_BALL" }, pcItems = {} },
  data = Data,
  input = { wasPressed = function() return false end,
            isDown = function() return false end },
}
local deposit = ListMenu.new(stubDep, "DEPOSIT ITEM", {
  { value = "POTION", label = "Potion" },
  { value = "REPEL", label = "Repel" },
  { value = "POKE_BALL", label = "Poké Ball" },
})
T.check(deposit.onSelectKey ~= nil, "deposit list got the SELECT-swap")
T.eq(deposit.items[1].value, "REPEL", "deposit list follows bagOrder")
deposit.onSelectKey(deposit.items[1], deposit) -- mark REPEL
deposit.index = 3
deposit.onSelectKey(deposit.items[3], deposit) -- swap with POKE_BALL
T.eq(table.concat(stubDep.save.bagOrder, ","), "POKE_BALL,POTION,REPEL",
  "deposit swap writes save.bagOrder (the bag)")
T.eq(deposit.items[1].value, "POKE_BALL", "deposit rows reordered after the swap")

-- A also completes a pending swap instead of starting the action
local onChooseCalled = false
local chooseProbe = ListMenu.new(stubPc, "TOSS ITEM", {
  { value = "POTION", label = "Potion" },
  { value = "REPEL", label = "Repel" },
  { value = "POKE_BALL", label = "Poké Ball" },
}, { onChoose = function() onChooseCalled = true end })
chooseProbe.swapIndex = 1 -- a SELECT press marked the first row
chooseProbe.index = 3
chooseProbe.onChoose(chooseProbe.items[3], chooseProbe)
T.check(not onChooseCalled, "A with a pending swap completes the swap, not the action")
T.eq(chooseProbe.swapIndex, nil, "the pending swap clears after A")

-- ------------------------------------------------ full TM/HM names + ticker

-- machine items label as "TM14 BLIZZARD" in both lists
Data.items.TM_02 = { id = "TM_02", name = "TM02",
  machine = { kind = "TM", number = 2, move = "FIX_SCRATCH" } }
T.eq(ex.labelForItem(Data, "FIX_TM"), "FIX TM01 FIX CUT",
  "a machine item's label shows the full TM name")
T.eq(ex.labelForItem(Data, "TM_02"), "TM02 FIX SCRATCH",
  "a plain-name TM carries its move name")
T.eq(ex.labelForItem(Data, "FIX_POTION"), "FIX POTION",
  "a non-machine item keeps its plain name")
T.eq(ex.labelForItem(Data, "NO_SUCH_ITEM"), "NO_SUCH_ITEM",
  "an unknown item id labels as itself")

-- the machine prefix is returned so it can stay pinned while the move
-- name ticks
local tmLabel, tmPrefixW, tmPrefix, tmMove = ex.labelForItem(Data, "TM_02")
T.eq(tmLabel, "TM02 FIX SCRATCH", "labelForItem returns the full label first")
T.eq(tmPrefix, "TM02 ", "the pinned prefix is the machine name plus space")
T.eq(tmPrefixW, #"TM02 " * 8, "prefixW is the prefix's pixel width")
T.eq(tmMove, "FIX SCRATCH", "the scrollable part is the move name only")
T.eq(select(3, ex.labelForItem(Data, "FIX_POTION")), nil,
  "a non-machine item has no pinned prefix")

-- a bag pocket row carries the full TM label
stub.save = { inventory = { FIX_TM = 1, POTION = 2 },
              bagOrder = { "FIX_TM", "POTION" }, money = 0 }
local tmBag = Screens.get(stub, "BagMenu").new(stub)
ex.switchPocket(tmBag, 1) -- items -> medicine
ex.switchPocket(tmBag, 1) -- medicine -> balls
ex.switchPocket(tmBag, 1) -- balls -> tms
T.eq(tmBag.title, "TMs / HMs", "the TM lands in the TMs / HMs pocket")
T.eq(tmBag.items[1].label, "FIX TM01 FIX CUT",
  "the bag row shows the full TM name")

-- a PC list row is rewritten to the full TM name on open
local stubTm = {
  save = { pcItems = { FIX_TM = 1 }, bagOrder = {}, inventory = {} },
  data = Data,
  input = { wasPressed = function() return false end,
            isDown = function() return false end },
}
local withdrawTm = ListMenu.new(stubTm, "WITHDRAW ITEM", {
  { value = "FIX_TM", label = "FIX TM01" },
})
T.eq(withdrawTm.items[1].label, "FIX TM01 FIX CUT",
  "the PC row shows the full TM name")

-- ticker geometry: labels that fit stay static, wide ones scroll
T.eq(ex.tickerFor("FIX POTION", "x1"), nil,
  "a short label fits the row window")
local long = ex.tickerFor("TM15 HYPER BEAM", "x99")
T.neq(long, nil, "a wide label overflows into a ticker")
T.eq(long.x, 16, "ticker starts at the label's x")
T.eq(long.w, 128 - 24, "ticker clips before the count (152-16-8-24)")
T.eq(long.overflow, 120 - (128 - 24),
  "overflow is the pixels past the window")
T.eq(ex.tickerFor("TM14 BLIZZARD", "x99"), nil,
  "a 13-glyph TM fits the x99 window exactly")
local tight = ex.tickerFor("TM14 BLIZZARD", "x999")
T.neq(tight, nil, "a wider count shrinks the window, so it ticks")
T.eq(tight.overflow, 104 - (128 - 32), "the x999 count costs 8px of window")

-- a machine row scrolls only the move name: the ticker anchors after the
-- pinned "TM15 " prefix and clips to the space that remains
local m = ex.tickerFor("TM15 HYPER BEAM", "x99", #"TM15 " * 8)
T.neq(m, nil, "a machine row still ticks when its move overflows")
T.eq(m.x, 16 + #"TM15 " * 8, "the scroll starts after the pinned TM prefix")
T.eq(m.w, (128 - 24) - #"TM15 " * 8, "the scroll window is the space after the prefix")
T.eq(m.overflow, 120 - (128 - 24),
  "the overflow is the full label's overflow (suffix overflow is the same)")
T.eq(ex.tickerFor("TM14 BLIZZARD", "x99", #"TM14 " * 8), nil,
  "a machine row whose move fits its window stays static")

-- the PC row carries the pinned prefix so the ticker can draw it statically
T.eq(withdrawTm.items[1].prefix, "FIX TM01 ",
  "the PC row carries the machine prefix for the pinned draw")
T.eq(withdrawTm.items[1].prefixW, #"FIX TM01 " * 8,
  "the PC row carries the prefix width")
T.eq(withdrawTm.items[1].move, "FIX CUT",
  "the PC row carries the move name so only it scrolls")

-- the bag row carries the same split
T.eq(tmBag.items[1].move, "FIX CUT",
  "the bag row carries the move name too")

-- pacing: hold at the head, scroll out, hold, scroll back
local to = ex.tickerOffset
T.eq(to(0, 40), 0, "ticker starts at the label head")
T.eq(to(1.5, 40), 0, "ticker holds at the head before scrolling")
T.check(to(2.5, 40) < 0, "ticker scrolls out past the hold")
T.eq(to(0, -5), 0, "a fitting label never moves")

run.release()
T.finish("useful_bag")
