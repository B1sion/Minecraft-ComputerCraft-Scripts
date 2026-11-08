
-- Configurable Inventory Sorter
-- CC: Tweaked
-- Routes max-stack-1 items separately from stackables.
-- Supports multiple input and output inventories.
-- Saves configuration between restarts.

local CONFIG_FILE = "sorter_config.txt"

local function splitNames(line)
    local result = {}

    for name in line:gmatch("[^,]+") do
        name = name:match("^%s*(.-)%s*$")
        if name ~= "" then
            table.insert(result, name)
        end
    end

    return result
end

local function askList(prompt)
    print("")
    print(prompt)
    print("Enter names separated by commas:")
    local line = read()
    return splitNames(line)
end

local function saveConfig(config)
    local file = fs.open(CONFIG_FILE, "w")
    file.write(textutils.serialize(config))
    file.close()
end

local function loadConfig()
    if not fs.exists(CONFIG_FILE) then
        return nil
    end

    local file = fs.open(CONFIG_FILE, "r")
    local config = textutils.unserialize(file.readAll())
    file.close()

    return config
end

local function showInventories()
    print("")
    print("Available inventories:")
    print("----------------------")

    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.hasType(name, "inventory") then
            print(name)
        end
    end
end

local function setup()
    term.clear()
    term.setCursorPos(1, 1)

    print("=== INVENTORY SORTER SETUP ===")

    showInventories()

    local config = {}

    config.inputs = askList(
        "1. INPUT inventories"
    )

    config.normal = askList(
        "2. NORMAL item destinations (priority order)"
    )

    config.nonstack = askList(
        "3. MAX STACK 1 destinations (priority order)"
    )

    saveConfig(config)

    print("")
    print("Configuration saved!")
    sleep(1)

    return config
end

local function validate(config)
    local roles = {}

    local groups = {
        {name = "input", list = config.inputs},
        {name = "normal", list = config.normal},
        {name = "nonstack", list = config.nonstack}
    }

    for _, group in ipairs(groups) do
        assert(
            type(group.list) == "table"
            and #group.list > 0,
            "Missing inventory list: " .. group.name
        )

        for _, name in ipairs(group.list) do
            assert(
                peripheral.hasType(name, "inventory"),
                "Inventory unavailable: " .. name
            )

            assert(
                not roles[name],
                "Inventory assigned twice: " .. name
            )

            roles[name] = group.name
        end
    end
end

local function moveToDestinations(source, slot, destinations)
    local totalMoved = 0

    for _, destination in ipairs(destinations) do
        local detail = source.getItemDetail(slot)

        if not detail then
            break
        end

        local moved = source.pushItems(
            destination,
            slot
        )

        totalMoved = totalMoved + moved

        -- If destination is full, try next one.
        -- Remaining items stay in the source slot.
    end

    return totalMoved
end

local function sortInventory(name, config)
    local source = peripheral.wrap(name)

    if not source then
        return 0
    end

    local movedTotal = 0

    for slot in pairs(source.list()) do
        local item = source.getItemDetail(slot)

        if item then
            local destinations

            if item.maxCount == 1 then
                destinations = config.nonstack
            elseif type(item.maxCount) == "number" then
                destinations = config.normal
            else
                -- Unknown stack size: do not misroute.
                destinations = nil
            end

            if destinations then
                movedTotal = movedTotal
                    + moveToDestinations(
                        source,
                        slot,
                        destinations
                    )
            else
                print("Unknown maxCount: " .. item.name)
            end
        end
    end

    return movedTotal
end

-- MAIN PROGRAM

local args = {...}
local config

if args[1] == "setup" then
    config = setup()
else
    config = loadConfig()

    if not config then
        config = setup()
    end
end

validate(config)

term.clear()
term.setCursorPos(1, 1)

print("=== INVENTORY SORTER ===")
print("Status: RUNNING")
print("Inputs: " .. #config.inputs)
print("Normal outputs: " .. #config.normal)
print("Nonstack outputs: " .. #config.nonstack)
print("------------------------")

local totalMoved = 0

while true do
    local movedThisCycle = 0

    for _, name in ipairs(config.inputs) do
        if peripheral.hasType(name, "inventory") then
            movedThisCycle = movedThisCycle
                + sortInventory(name, config)
        end
    end

    totalMoved = totalMoved + movedThisCycle

    term.setCursorPos(1, 8)
    term.clearLine()
    print("Last cycle: " .. movedThisCycle)

    term.clearLine()
    print("Total moved: " .. totalMoved)

    sleep(0.5)
end
