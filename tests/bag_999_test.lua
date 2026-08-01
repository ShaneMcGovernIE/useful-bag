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

run.release()
T.finish("bag_999")
