-- CC:Tweaked rule-based inventory sorter
-- Configure entirely in-game: Me_sorter setup
-- Rules evaluated by ascending numeric priority; rejected items fall through.
local CONFIG = "sorter_config.txt"
local args = {...}

local function trim(s) return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
local function parseNames(s)
  local out, seen = {}, {}
  for part in s:gmatch('[^,]+') do
    local name = trim(part)
    if name ~= '' and not seen[name] then
      out[#out+1] = name
      seen[name] = true
    end
  end
  return out
end
local function prompt(message, default)
  write(message .. (default and (' [' .. default .. ']') or '') .. ': ')
  local value = trim(read())
  if value == '' and default then return default end
  return value
end
local function askNumber(message, default, minimum)
  while true do
    local n = tonumber(prompt(message, tostring(default)))
    if n and n == math.floor(n) and (not minimum or n >= minimum) then return n end
    print('Enter an integer >= ' .. tostring(minimum or 0))
  end
end
local function askNames(message)
  while true do
    print(message)
    local names = parseNames(prompt('Comma-separated peripheral names'))
    if #names > 0 then return names end
    print('At least one name is required.')
  end
end
local filterOptions = {
  'none', 'max_count_eq', 'max_count_le', 'max_count_ge',
  'item_id', 'item_id_contains', 'mod_id', 'tag',
  'display_name_contains', 'damaged'
}
local function showInventories()
  print('\nConnected inventories:')
  local count = 0
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name, 'inventory') then
      print('  ' .. name)
      count = count + 1
    end
  end
  if count == 0 then print('  (none detected)') end
end
local function askFilter()
  print('\nFilter choices:')
  for i, f in ipairs(filterOptions) do print(('  %d. %s'):format(i, f)) end
  local n
  repeat n = askNumber('Filter number', 1, 1) until n <= #filterOptions
  local kind = filterOptions[n]
  if kind == 'none' then return {type = kind} end
  if kind == 'damaged' then return {type = kind} end
  local value = ''
  while value == '' do value = prompt('Filter value') end
  if kind:find('max_count_', 1, true) then
    local num = tonumber(value)
    if not num or num < 1 or num ~= math.floor(num) then
      print('Invalid max count; using 1.')
      num = 1
    end
    value = num
  end
  return {type = kind, value = value}
end
local function setup()
  term.clear()
  term.setCursorPos(1, 1)
  print('=== ME SORTER SETUP ===')
  showInventories()
  local cfg = {version = 2, inputs = askNames('\nINPUT inventories (scanned for items)'), rules = {}}
  local count = askNumber('\nNumber of routing rules', 1, 1)
  for i = 1, count do
    print(('\n=== Rule %d of %d ==='):format(i, count))
    local priority = askNumber('Priority (lower runs first)', i, 0)
    local destinations = askNames('DESTINATIONS (tried left to right)')
    local filter = askFilter()
    cfg.rules[#cfg.rules+1] = {
      priority = priority, destinations = destinations, filter = filter, order = i
    }
  end
  local handle = assert(fs.open(CONFIG, 'w'))
  handle.write(textutils.serialize(cfg))
  handle.close()
  print('\nSaved ' .. CONFIG)
  return cfg
end
local function loadConfig()
  if not fs.exists(CONFIG) then return nil end
  local handle = assert(fs.open(CONFIG, 'r'))
  local contents = handle.readAll()
  handle.close()
  local cfg = textutils.unserialize(contents)
  if type(cfg) ~= 'table' or cfg.version ~= 2 then return nil end
  return cfg
end
local function validate(cfg)
  assert(type(cfg.inputs) == 'table' and #cfg.inputs > 0, 'No inputs')
  assert(type(cfg.rules) == 'table' and #cfg.rules > 0, 'No rules')
  local inputs = {}
  for _, name in ipairs(cfg.inputs) do
    assert(peripheral.hasType(name, 'inventory'), 'Missing input: ' .. name)
    assert(not inputs[name], 'Duplicate input: ' .. name)
    inputs[name] = true
  end
  for i, rule in ipairs(cfg.rules) do
    assert(type(rule.priority) == 'number', 'Invalid priority in rule ' .. i)
    assert(type(rule.destinations) == 'table' and #rule.destinations > 0, 'Missing destinations in rule ' .. i)
    assert(type(rule.filter) == 'table' and type(rule.filter.type) == 'string', 'Invalid filter in rule ' .. i)
    local seen = {}
    for _, name in ipairs(rule.destinations) do
      assert(not inputs[name], 'Destination is also an input: ' .. name)
      assert(not seen[name], 'Duplicate destination in rule ' .. i .. ': ' .. name)
      assert(peripheral.hasType(name, 'inventory'), 'Missing destination: ' .. name)
      seen[name] = true
    end
  end
  table.sort(cfg.rules, function(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return (a.order or 0) < (b.order or 0)
  end)
end
local function matches(filter, item)
  local kind, value = filter.type, filter.value
  if kind == 'none' then return true end
  if kind == 'max_count_eq' then return item.maxCount == value end
  if kind == 'max_count_le' then return item.maxCount and item.maxCount <= value end
  if kind == 'max_count_ge' then return item.maxCount and item.maxCount >= value end
  if kind == 'item_id' then return item.name == value end
  if kind == 'item_id_contains' then return item.name:lower():find(tostring(value):lower(), 1, true) ~= nil end
  if kind == 'mod_id' then return item.name:match('^([^:]+):') == value end
  if kind == 'tag' then return type(item.tags) == 'table' and item.tags[value] == true end
  if kind == 'display_name_contains' then
    return type(item.displayName) == 'string' and
      item.displayName:lower():find(tostring(value):lower(), 1, true) ~= nil
  end
  if kind == 'damaged' then
    return type(item.damage) == 'number' and item.damage > 0
  end
  return false
end
local function transferSlot(sourceName, source, slot, cfg)
  local item = source.getItemDetail(slot)
  if not item then return 0 end
  local total = 0
  for _, rule in ipairs(cfg.rules) do
    if matches(rule.filter, item) then
      for _, destination in ipairs(rule.destinations) do
        local remaining = source.getItemDetail(slot)
        if not remaining then return total end
        -- pushItems returns the number moved; zero means try next destination/rule.
        local ok, moved = pcall(source.pushItems, destination, slot)
        if ok then
          total = total + (moved or 0)
        else
          print(('Transfer failed %s -> %s: %s'):format(sourceName, destination, tostring(moved)))
        end
      end
    end
  end
  return total
end
local function run(cfg)
  validate(cfg)
  term.clear()
  term.setCursorPos(1, 1)
  print('=== ME SORTER ===')
  print('Rules: ' .. #cfg.rules .. ' | Inputs: ' .. #cfg.inputs)
  print('Ctrl+T to stop; run Me_sorter setup to edit.')
  print('')
  local total = 0
  while true do
    local cycle = 0
    for _, name in ipairs(cfg.inputs) do
      local source = peripheral.wrap(name)
      if source and peripheral.hasType(name, 'inventory') then
        local ok, items = pcall(source.list)
        if ok and type(items) == 'table' then
          for slot in pairs(items) do
            local success, moved = pcall(transferSlot, name, source, slot, cfg)
            if success then cycle = cycle + moved
            else print('Slot error ' .. name .. ':' .. slot .. ' ' .. tostring(moved)) end
          end
        end
      end
    end
    total = total + cycle
    term.setCursorPos(1, 5)
    term.clearLine()
    print('Moved this scan: ' .. cycle)
    term.clearLine()
    print('Moved since start: ' .. total)
    sleep(0.5)
  end
end

if args[1] == 'list' then
  showInventories()
elseif args[1] == 'setup' then
  local cfg = setup()
  local answer = prompt('Start sorting now? (y/n)', 'y')
  if answer:lower() == 'y' then run(cfg) end
else
  local cfg = loadConfig()
  if not cfg then
    print('No compatible saved configuration; starting setup.')
    cfg = setup()
  end
  run(cfg)
end
