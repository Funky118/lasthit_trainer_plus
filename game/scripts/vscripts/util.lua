function DebugPrint(...)
	if USE_DEBUG then
		print(...)
	end
end

function PrintTable(t, indent, done)
  --print ( string.format ('PrintTable type %s', type(keys)) )
  if type(t) ~= "table" then return end

  done = done or {}
  done[t] = true
  indent = indent or 0

  local l = {}
  for k, v in pairs(t) do
    table.insert(l, k)
  end

  table.sort(l)
  for k, v in ipairs(l) do
    -- Ignore FDesc
    if v ~= 'FDesc' then
      local value = t[v]

      if type(value) == "table" and not done[value] then
        done [value] = true
        print(string.rep ("\t", indent)..tostring(v)..":")
        PrintTable (value, indent + 2, done)
      elseif type(value) == "userdata" and not done[value] then
        done [value] = true
        print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
        PrintTable ((getmetatable(value) and getmetatable(value).__index) or getmetatable(value), indent + 2, done)
      else
        if t.FDesc and t.FDesc[v] then
          print(string.rep ("\t", indent)..tostring(t.FDesc[v]))
        else
          print(string.rep ("\t", indent)..tostring(v)..": "..tostring(value))
        end
      end
    end
  end
end

-- Requires an element (key) and a table, returns true if element is in the table.
function TableContains(t, element)
    if t == nil then return false end
    for k, v in pairs(t) do
        if k == element then
            return true
        end
    end
    return false
end

-- Return length of the table even if the table is nil or empty
-- # operator will not calculate table length properly if the table contains nil elements
function TableLength(t)
    if t == nil or t == {} then
        return 0
    end
    local length = 0
    for k, v in pairs(t) do
        length = length + 1
    end
    return length
end

function GetRandomTableElement(t)
    -- iterate over whole table to get all keys
    local keyset = {}
    for k in pairs(t) do
        table.insert(keyset, k)
    end
    -- keyset table doesn't have nil elements
    return t[keyset[RandomInt(1, #keyset)]]
end

-- Colors
COLOR_NONE = '\x06'
COLOR_GRAY = '\x06'
COLOR_GREY = '\x06'
COLOR_GREEN = '\x0C'
COLOR_DPURPLE = '\x0D'
COLOR_SPINK = '\x0E'
COLOR_DYELLOW = '\x10'
COLOR_PINK = '\x11'
COLOR_RED = '\x12'
COLOR_LGREEN = '\x15'
COLOR_BLUE = '\x16'
COLOR_DGREEN = '\x18'
COLOR_SBLUE = '\x19'
COLOR_PURPLE = '\x1A'
COLOR_ORANGE = '\x1B'
COLOR_LRED = '\x1C'
COLOR_GOLD = '\x1D'

function DebugAllCalls()
    if not GameRules.DebugCalls then
        print("Starting DebugCalls")
        GameRules.DebugCalls = true

        debug.sethook(function(...)
            local info = debug.getinfo(2)
            local src = tostring(info.short_src)
            local name = tostring(info.name)
            if name ~= "__index" then
                print("Call: ".. src .. " -- " .. name .. " -- " .. info.currentline)
            end
        end, "c")
    else
        print("Stopped DebugCalls")
        GameRules.DebugCalls = false
        debug.sethook(nil, "c")
    end
end

-- Author: Noya
-- This function hides all dota item cosmetics (hats/wearables) from the hero/unit and store them into a handle variable
-- Works only for wearables added with code
function HideWearables(unit)
  unit.hiddenWearables = {} -- Keep every wearable handle in a table to show them later
  local model = unit:FirstMoveChild()
  while model ~= nil do
    if model:GetClassname() == "dota_item_wearable" then
      model:AddEffects(EF_NODRAW) -- Set model hidden
      table.insert(unit.hiddenWearables, model)
    end
    model = model:NextMovePeer()
  end
end

-- Author: Noya
-- This function un-hides (shows) wearables that were hidden with HideWearables() function.
function ShowWearables(unit)
	for k, v in pairs(unit.hiddenWearables) do
		v:RemoveEffects(EF_NODRAW)
	end
end

-- Author: Noya
-- This function changes (swaps) dota item cosmetic models (hats/wearables)
-- Works only for wearables added with code
function SwapWearable(unit, target_model, new_model)
    local wearable = unit:FirstMoveChild()
    while wearable ~= nil do
        if wearable:GetClassname() == "dota_item_wearable" then
            if wearable:GetModelName() == target_model then
                wearable:SetModel(new_model)
                return
            end
        end
        wearable = wearable:NextMovePeer()
    end
end

-- This function checks if a given unit is Roshan, returns boolean value;
function CDOTA_BaseNPC:IsRoshanCustom()
	return string.find(self:GetUnitName(), "npc_dota_roshan")
end

-- This function checks if this entity is a fountain or not; returns boolean value;
function CBaseEntity:IsFountain()
	if self:GetName() == "ent_dota_fountain_bad" or self:GetName() == "ent_dota_fountain_good" then
		return true
	end

	return false
end

-- This function checks if a given unit is Lone Druid's Spirit Bear, returns boolean value;
function CDOTA_BaseNPC:IsSpiritBearCustom()
	return string.find(self:GetUnitName(), "npc_dota_lone_druid_bear")
end

function IsMonkeyKingCloneCustom(entity)
	if entity.HasModifier == nil then
		return false
	end

	local monkey_king_soldier_modifiers = {
		"modifier_monkey_king_fur_army_soldier_hidden",
		"modifier_monkey_king_fur_army_soldier",
		"modifier_monkey_king_fur_army_thinker",
		"modifier_monkey_king_fur_army_soldier_inactive",
		"modifier_monkey_king_fur_army_soldier_in_position",
	}

	for _, v in pairs(monkey_king_soldier_modifiers) do
		if entity:HasModifier(v) then
			return true
		end
	end

	return false
end

-- Author: Noya
-- This function is showing custom Error Messages using notifications library
function SendErrorMessage(pID, string)
  if Notifications then
    Notifications:ClearBottom(pID)
    Notifications:Bottom(pID, {text=string, style={color='#E62020'}, duration=2})
  end
  EmitSoundOnClient("General.Cancel", PlayerResource:GetPlayer(pID))
end

function VectorDistanceSq(v1, v2)
  return (v1.x - v2.x) * (v1.x - v2.x) + (v1.y - v2.y) * (v1.y - v2.y) + (v1.z - v2.z) * (v1.z - v2.z)
end

function VectorDistance(v1, v2)
  return math.sqrt(VectorDistanceSq(v1, v2))
end

-- Author: not Noya
-- This function does what it literally says, draw 2D graph in console
-- Inputs: data - 1D vector, graph_height - how many console lines will be used (data quantization)
function DrawGraph(data, graph_height)
  local max = data[1]
  local min = data[1]
  for k,v in pairs(data) do
    if v < min then
      min = v
    end
    if v > max then
      max = v
    end
  end

  local vert_lines = {}
  local last_line = ""

  for k,value in pairs(data) do
    -- Rescale datapoint based on graph_height so that all of data fits into the graph
    local offset = math.floor(graph_height * (value-min)/(max-min))
    local line = ""
    -- Render the Y axis values at each frame (column vectors)...
    for i = graph_height, 0, -1 do
      if i == offset then
        line = line.."@" --Datapoint marker
      else
        line = line.."." --Empty space marker
      end
    end
    table.insert(vert_lines, line)
    -- X axis delimiter
    last_line = last_line.."-"
  end

  for i = 1, graph_height+1 do
    -- Y axis delimiter with number values (which aren't very accurate)
    local yaxis = math.floor(max * (graph_height-i-0)/(graph_height-0))
    local horizontal_line = yaxis.."|"
    -- ...now render rows from the column vectors
    for k, col in pairs(vert_lines)do
      local tmp = string.sub(col, i, i)
      horizontal_line = horizontal_line..tmp
    end
    print(horizontal_line)
  end
  
  print(last_line)
end
