-- 999 Bag Slots, plus a bag-sort shortcut:
--   TAB (keyboard) or R3 / right stick click (controller) opens a prompt
--   in the bag: SORT BY NAME or SORT BY COUNT (biggest stacks first).
--
-- The capacity half is a single constants patch: the engine reads the
-- limit from Data.constants.bagSize (src/core/Data.lua seeds 20;
-- Bag.capacity in src/inventory/Bag.lua consults it).
--
-- The sort half rides the engine's internal seams while a public hook is
-- added (same approach as the nuzlocke mod): at game.ready we wrap
-- src.ui.BagMenu.new so every bag list carries a TAB/R3 handler, and we
-- wrap src.core.Input so TAB (normally SELECT / swap-item) and R3
-- (unbound) reach that handler instead.  Shift keys still do the
-- vanilla SELECT item-swap.

local SORT_MODE_LABELS = { "SORT BY NAME", "SORT BY COUNT" }

-- Pure: the sorted id list for `mode` ("name" | "count").  The name sort
-- compares item names with an id tiebreak (stable); the count sort puts
-- the biggest stacks first, id tiebreak.  Returns a fresh list -- the
-- save's bagOrder is left untouched.
local function computeOrder(save, data, mode)
  local Bag = require("src.inventory.Bag")
  local order = {}
  for _, id in ipairs(Bag.order(save)) do table.insert(order, id) end
  local inv = save.inventory
  if mode == "count" then
    table.sort(order, function(a, b)
      local ca, cb = inv[a] or 0, inv[b] or 0
      if ca == cb then return a < b end
      return ca > cb
    end)
  else -- "name"
    table.sort(order, function(a, b)
      local da, db = data.items[a], data.items[b]
      local na, nb = (da and da.name) or a, (db and db.name) or b
      if na == nb then return a < b end
      return na < nb
    end)
  end
  return order
end

-- Applies a sort to the live save: Bag.order returns save.bagOrder
-- itself, so sorting it in place is the whole write.
local function applySort(save, data, mode)
  local Bag = require("src.inventory.Bag")
  local order = Bag.order(save)
  if mode == "count" then
    local inv = save.inventory
    table.sort(order, function(a, b)
      local ca, cb = inv[a] or 0, inv[b] or 0
      if ca == cb then return a < b end
      return ca > cb
    end)
  else
    table.sort(order, function(a, b)
      local da, db = data.items[a], data.items[b]
      local na, nb = (da and da.name) or a, (db and db.name) or b
      if na == nb then return a < b end
      return na < nb
    end)
  end
end

return function(mod)
  mod.content.constants:patch("bagSize", 999)

  mod.events:on("game.ready", function(ev)
    local game = ev.game
    local Input = require("src.core.Input")
    local BagMenu = require("src.ui.BagMenu")
    local Menu = require("src.ui.Menu")

    -- hot reload re-runs entry chunks: wrap each module once
    if BagMenu.__bag999Sort then return end
    BagMenu.__bag999Sort = true
    Input.__bag999Sort = true

    -- the bag list currently on the stack (nil when none is open)
    local active = nil
    -- the sort prompt itself is on the stack
    local sortOpen = false
    -- a TAB/R3 edge waiting for the bag's next update
    local wantSort = false

    -- Rebuild the list rows from the (possibly reordered) bag order.
    local function rebuild(list)
      local Bag = require("src.inventory.Bag")
      local items = {}
      for _, id in ipairs(Bag.order(list.game.save)) do
        local def = list.game.data.items[id]
        table.insert(items, {
          value = id,
          label = def and def.name or id,
          right = "x" .. list.game.save.inventory[id],
        })
      end
      list.items = items
      list.index = math.min(list.index, math.max(1, #items))
    end

    local function openSortPrompt(list)
      sortOpen = true
      list.game.stack:push(Menu.new(list.game, {
        { label = SORT_MODE_LABELS[1], onSelect = function()
            sortOpen = false
            applySort(list.game.save, list.game.data, "name")
            require("src.core.Sound").play(list.game.data, "Swap")
            rebuild(list)
          end },
        { label = SORT_MODE_LABELS[2], onSelect = function()
            sortOpen = false
            applySort(list.game.save, list.game.data, "count")
            require("src.core.Sound").play(list.game.data, "Swap")
            rebuild(list)
          end },
      }, { tx = 10, ty = 10, onCancel = function() sortOpen = false end }))
    end

    local vanillaNew = BagMenu.new
    BagMenu.new = function(game_, opts)
      local list = vanillaNew(game_, opts)
      local vanillaUpdate = list.update
      list.update = function(self, dt)
        -- only the visible top bag responds; a stale edge from a press
        -- while some other screen was on top is dropped
        if wantSort and active == self and not sortOpen
           and self.game.stack:top() == self then
          wantSort = false
          list.swapIndex = nil -- a pending SELECT-swap would go stale
          openSortPrompt(self)
        end
        return vanillaUpdate(self, dt)
      end
      local vanillaClose = list.close
      list.close = function(self, ...)
        if active == self then active = nil end
        return vanillaClose(self, ...)
      end
      active = list
      wantSort = false -- presses before the bag opened do not carry over
      return list
    end

    local vanillaKey = Input.keypressed
    Input.keypressed = function(self, key)
      -- TAB is bound to SELECT; while the bag is open it means "sort"
      -- instead, and the press is swallowed so it cannot also swap
      if key == "tab" and active and not sortOpen then
        wantSort = true
        return
      end
      return vanillaKey(self, key)
    end

    local vanillaPad = Input.gamepadpressed
    Input.gamepadpressed = function(self, joystick, button)
      if button == "rightstick" and active and not sortOpen then
        wantSort = true
        return
      end
      return vanillaPad(self, joystick, button)
    end
  end)

  mod.exports = {
    computeOrder = computeOrder,
    applySort = applySort,
  }
end
