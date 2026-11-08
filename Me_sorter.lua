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
local function saveConfig(cfg)
  local tmp = CONFIG .. '.tmp'
  local h = assert(fs.open(tmp, 'w'))
  h.write(textutils.serialize(cfg))
  h.close()
  if fs.exists(CONFIG) then fs.delete(CONFIG) end
  fs.move(tmp, CONFIG)
end
local function loadConfig()
  if not fs.exists(CONFIG) then return nil end
  local h = assert(fs.open(CONFIG, 'r'))
  local cfg = textutils.unserialize(h.readAll())
  h.close()
  if type(cfg) ~= 'table' or cfg.version ~= 2 then return nil end
  return cfg
end
local function validate(cfg, checkOnline)
  assert(type(cfg.inputs) == 'table' and #cfg.inputs > 0, 'At least one input required')
  assert(type(cfg.rules) == 'table' and #cfg.rules > 0, 'At least one rule required')
  local inputs = {}
  for _, name in ipairs(cfg.inputs) do
    assert(type(name) == 'string' and name ~= '', 'Invalid input name')
    assert(not inputs[name], 'Duplicate input: ' .. name)
    if checkOnline then assert(peripheral.hasType(name, 'inventory'), 'Missing input: ' .. name) end
    inputs[name] = true
  end
  for i, rule in ipairs(cfg.rules) do
    assert(type(rule.priority) == 'number', 'Invalid priority in rule ' .. i)
    assert(type(rule.destinations) == 'table' and #rule.destinations > 0, 'Missing destinations in rule ' .. i)
    assert(type(rule.filter) == 'table' and type(rule.filter.type) == 'string', 'Invalid filter in rule ' .. i)
    local seen = {}
    for _, name in ipairs(rule.destinations) do
      assert(type(name) == 'string' and name ~= '', 'Invalid destination name')
      assert(not inputs[name], 'Destination is also an input: ' .. name)
      assert(not seen[name], 'Duplicate destination in rule ' .. i .. ': ' .. name)
      if checkOnline then assert(peripheral.hasType(name, 'inventory'), 'Missing destination: ' .. name) end
      seen[name] = true
    end
  end
end
local function orderedRules(cfg)
  local ordered = {}
  for _, rule in ipairs(cfg.rules) do ordered[#ordered+1] = rule end
  table.sort(ordered, function(a,b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return (a.order or 0) < (b.order or 0)
  end)
  return ordered
end
local function nextPriority(cfg)
  local max = 0
  for _, rule in ipairs(cfg.rules) do max = math.max(max, rule.priority) end
  return max + 1
end
local function addRule(cfg)
  print('\nNew rule (appended at lowest priority)')
  local rule = {
    priority = nextPriority(cfg),
    order = #cfg.rules + 1,
    destinations = askNames('DESTINATIONS (tried left to right)'),
    filter = askFilter()
  }
  cfg.rules[#cfg.rules+1] = rule
end
local function setup()
  term.clear()
  term.setCursorPos(1,1)
  print('=== ME SORTER FIRST SETUP ===')
  showInventories()
  local cfg = {version=2, inputs=askNames('\nINPUT inventories'), rules={}}
  local count = askNumber('Number of rules', 1, 1)
  for i=1,count do addRule(cfg) end
  validate(cfg, true)
  saveConfig(cfg)
  print('Saved ' .. CONFIG)
  return cfg
end
local function showConfig(cfg)
  print('\n=== CURRENT CONFIG ===')
  print('Inputs (scan order):')
  for i,n in ipairs(cfg.inputs) do print(('  %d) %s'):format(i,n)) end
  print('Rules (priority order):')
  for i,r in ipairs(orderedRules(cfg)) do
    print(('  %d) priority=%d filter=%s %s'):format(i,r.priority,r.filter.type,tostring(r.filter.value or '')))
    for j,n in ipairs(r.destinations) do print(('     %d. %s'):format(j,n)) end
  end
end
local function chooseRule(cfg)
  local ordered = orderedRules(cfg)
  for i,r in ipairs(ordered) do
    print(('%d) priority %d / %s'):format(i,r.priority,r.filter.type))
  end
  local n = askNumber('Rule number', 1, 1)
  if n > #ordered then print('Invalid rule number') return nil end
  return ordered[n]
end
local function removeAt(list, label)
  if #list == 0 then print('Nothing to remove') return false end
  for i,n in ipairs(list) do print(('%d) %s'):format(i,n)) end
  local i = askNumber('Remove ' .. label .. ' number', 1, 1)
  if i > #list then print('Invalid number') return false end
  table.remove(list, i)
  return true
end
local function appendNames(list)
  local names = askNames('New inventories (comma-separated; appended in order)')
  local seen = {}
  for _,n in ipairs(list) do seen[n] = true end
  for _,n in ipairs(names) do
    if not seen[n] then list[#list+1] = n; seen[n] = true
    else print('Already present: ' .. n) end
  end
end
local function editMenu(cfg)
  while true do
    print('\n=== SORTER CONFIG MENU ===')
    print('1 View configuration')
    print('2 Add input(s) to END')
    print('3 Remove input')
    print('4 Add output(s) to END of a rule')
    print('5 Remove output from a rule')
    print('6 Add new rule at END (lowest priority)')
    print('7 Change rule priority')
    print('8 Change rule filter')
    print('9 Remove rule')
    print('10 Save and exit')
    print('11 Exit WITHOUT saving')
    local choice = askNumber('Choice', 1, 1)
    if choice == 1 then showConfig(cfg)
    elseif choice == 2 then appendNames(cfg.inputs)
    elseif choice == 3 then
      if #cfg.inputs <= 1 then print('Cannot remove last input')
      else removeAt(cfg.inputs, 'input') end
    elseif choice == 4 then
      local r = chooseRule(cfg)
      if r then appendNames(r.destinations) end
    elseif choice == 5 then
      local r = chooseRule(cfg)
      if r then
        if #r.destinations <= 1 then print('Cannot remove last destination')
        else removeAt(r.destinations, 'destination') end
      end
    elseif choice == 6 then addRule(cfg)
    elseif choice == 7 then
      local r = chooseRule(cfg)
      if r then r.priority = askNumber('New priority (lower = first)',r.priority,0) end
    elseif choice == 8 then
      local r = chooseRule(cfg)
      if r then r.filter = askFilter() end
    elseif choice == 9 then
      if #cfg.rules <= 1 then print('Cannot remove last rule')
      else
        local r = chooseRule(cfg)
        if r then
          for i,v in ipairs(cfg.rules) do
            if v == r then table.remove(cfg.rules,i); break end
          end
        end
      end
    elseif choice == 10 then
      local ok, err = pcall(validate,cfg,true)
      if ok then saveConfig(cfg); print('Saved. Run Me_sorter to start.'); return
      else print('Cannot save: ' .. tostring(err)) end
    elseif choice == 11 then print('Changes discarded.'); return
    else print('Unknown choice') end
  end
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
  for _, rule in ipairs(orderedRules(cfg)) do
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
  validate(cfg, true)
  term.clear()
  term.setCursorPos(1, 1)
  print('=== ME SORTER ===')
  print('Rules: ' .. #cfg.rules .. ' | Inputs: ' .. #cfg.inputs)
  print('Ctrl+T to stop; run Me_sorter config to edit.')
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
  if prompt('Start sorting now? (y/n)', 'y'):lower() == 'y' then run(cfg) end
elseif args[1] == 'config' then
  local cfg = loadConfig()
  if not cfg then
    print('No saved configuration; starting first-time setup.')
    setup()
  else
    -- Work on a copy: cancel never alters the saved configuration.
    editMenu(textutils.unserialize(textutils.serialize(cfg)))
  end
else
  local cfg = loadConfig()
  if not cfg then
    print('No compatible saved configuration; starting setup.')
    cfg = setup()
  end
  run(cfg)
end
