-- Standalone: luajit mods/bag_999/tests/bag_999_test.lua
-- Loads the mod through the real headless loader and asserts its stated
-- effect: the bag capacity constant lands at 999 and Bag.add accepts a
-- 21st distinct item.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local run = T.sdk.loadMod("mods/bag_999", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")

T.eq(Data.constants.bagSize, 999, "bagSize patched to 999")

local Bag = require("src.inventory.Bag")
T.eq(Bag.capacity(Data), 999, "Bag.capacity reads the patched constant")

local save = { inventory = {}, bagOrder = {} }
for i = 1, 20 do
  Bag.add(save, "POTION" .. i, 1, Data)
end
T.check(Bag.add(save, "VANILLA_ITEM", 1, Data), "a 21st item is accepted")
T.eq(Bag.slots(save), 21, "bag holds 21 distinct items")

-- ------------------------------------------------ sort feature

local ex = run.loader.exports.bag_999
T.neq(ex, nil, "sort exports reachable")

-- seed item names so the name sort has something to compare
Data.items.APPLE = { id = "APPLE", name = "Apple" }
Data.items.BANANA = { id = "BANANA", name = "Banana" }
Data.items.CHERRY = { id = "CHERRY", name = "Cherry" }

local s = {
  inventory = { BANANA = 2, CHERRY = 9, APPLE = 5 },
  bagOrder = { "BANANA", "CHERRY", "APPLE" },
}

T.eq(table.concat(ex.computeOrder(s, Data, "name"), ","),
  "APPLE,BANANA,CHERRY", "name sort is alphabetical")
T.eq(table.concat(ex.computeOrder(s, Data, "count"), ","),
  "CHERRY,APPLE,BANANA", "count sort puts the biggest stack first")
s.inventory.CHERRY = 2
T.eq(table.concat(ex.computeOrder(s, Data, "count"), ","),
  "APPLE,BANANA,CHERRY", "count tie falls back to id order")

T.eq(table.concat(s.bagOrder, ","), "BANANA,CHERRY,APPLE",
  "computeOrder leaves the save untouched")
s.inventory.CHERRY = 9 -- restore the biggest stack
ex.applySort(s, Data, "count")
T.eq(table.concat(s.bagOrder, ","), "CHERRY,APPLE,BANANA",
  "applySort rewrites the live bagOrder")
ex.applySort(s, Data, "name")
T.eq(table.concat(s.bagOrder, ","), "APPLE,BANANA,CHERRY",
  "applySort name pass reorders again")

run.release()
T.finish("bag_999")
