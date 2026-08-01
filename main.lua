-- Vanilla Red caps the bag at 20 distinct item ids (BAG_ITEM_CAPACITY).
-- The engine reads that limit from Data.constants.bagSize (src/core/Data.lua
-- seeds it to 20; Bag.capacity in src/inventory/Bag.lua consults it), so a
-- single constants patch is the whole mod.
return function(mod)
  mod.content.constants:patch("bagSize", 999)
  mod.log:info("bag capacity raised to 999 slots")
end
