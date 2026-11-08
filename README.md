# Minecraft ComputerCraft Scripts

A collection of automation scripts for **CC: Tweaked**, designed for modded Minecraft environments using Applied Energistics 2 (AE2), Extended AE, Ars Nouveau, and external storage systems.

## Available Scripts

| Script | Description |
|---|---|
| `Me_sorter.lua` | Automatically sorts stackable and non-stackable items into configurable inventories. |
| `ars.lua` | Automates Ars Nouveau Imbuement Chambers and Enchanting Apparatus through AE2 autocrafting. |

Both scripts operate independently and can run continuously on separate ComputerCraft computers.

---

# 1. ME Inventory Sorter

**File:** `Me_sorter.lua`

A configurable inventory sorter that separates items according to their maximum stack size.

### Features

- Automatically identifies items with a maximum stack size of 1.
- Routes stackable and non-stackable items to separate inventories.
- Supports multiple input and output inventories.
- Uses configurable destination priority.
- Automatically tries alternative destinations when one cannot accept an item.
- Saves configuration between restarts.
- Continuously scans inventories every 0.5 seconds.
- Leaves items in the input inventory if no destination can accept them.

## Installation

On a ComputerCraft computer, run:

```lua
wget https://raw.githubusercontent.com/B1sion/Minecraft-ComputerCraft-Scripts/main/Me_sorter.lua Me_sorter.lua
```

Start the script:

```lua
Me_sorter
```

On the first launch, the configuration wizard starts automatically.

## Physical Setup

Connect the computer and all inventories using Wired Modems and Networking Cables.

Recommended AE2 integration:

```text
                      INPUT CHEST
                           |
                           v
                    CC:Tweaked Computer
                           |
                     Item Inspection
                      /          \
                     /            \
             Max Stack = 1     Max Stack > 1
                   |                |
                   v                v
             Sophisticated      Normal Output
             Storage Chests         Chest
                   |                |
                   v                v
              ME Storage Bus    ME Import Bus
                    \              /
                     \            /
                       ME Network
```

The input chest should not have an ME Import Bus, because that would allow AE2 to remove items before the sorter processes them.

## Configuration

The program displays available inventory peripheral names and requests three comma-separated lists.

**1. Input inventories**

```text
minecraft:chest_0,minecraft:chest_1
```

These inventories contain unsorted items.

**2. Normal item destinations**

```text
minecraft:chest_2,minecraft:chest_3
```

Items with a maximum stack size greater than 1 are sent here.

**3. Non-stackable item destinations**

```text
sophisticatedstorage:chest_0,sophisticatedstorage:chest_1
```

Items with a maximum stack size of exactly 1 are sent here.

### Destination Priority

Inventories are attempted in the order entered.

For example:

```text
chest_0,chest_1,chest_2
```

The sorter attempts `chest_0` first, then `chest_1`, then `chest_2`.

If none accepts the item, it remains in the input inventory.

### Finding Peripheral Names

Open the ComputerCraft Lua interpreter:

```lua
lua
```

Then enter:

```lua
peripheral.getNames()
```

Use the names displayed when configuring the sorter.

Exit the interpreter with:

```lua
exit()
```

## Running and Reconfiguring

Start with saved settings:

```lua
Me_sorter
```

Reconfigure:

```lua
Me_sorter setup
```

Configuration is stored locally in:

```text
sorter_config.txt
```

The sorter cannot directly inspect items already inside ME Drives. Items must pass through its configured input inventories.

---

# 2. Ars Nouveau Automation Controller

**File:** `ars.lua`

A unified automation controller for Ars Nouveau machines using CC: Tweaked and Extended AE.

Supports:

- **Imbuement Chamber**
- **Enchanting Apparatus**

The script automatically identifies the connected machine and selects the correct automation logic.

It is designed to work with AE2 Pattern Providers and processing patterns.

## Installation

On a separate ComputerCraft computer, run:

```lua
wget https://raw.githubusercontent.com/B1sion/Minecraft-ComputerCraft-Scripts/main/ars.lua ars.lua
```

Start the controller:

```lua
ars
```

No configuration file is required. The script automatically discovers connected peripherals.

## Required Components

| Component | Purpose |
|---|---|
| ComputerCraft Computer | Executes the automation |
| Wired Modems | Connects machine inventories |
| Networking Cables | Connects peripherals to the computer |
| Extended AE Pattern Provider | Supplies crafting ingredients |
| Ingredient Buffer | Holds ingredients before processing |
| Imbuement Chamber or Enchanting Apparatus | Performs crafting |
| Arcane Pedestals | Holds supporting ingredients |

Each computer must connect to exactly:

- 1 Pattern Provider
- 1 Ingredient Buffer
- 1 Ars Nouveau machine
- Any pedestals needed for its recipes

**Important:** Do not connect both an Imbuement Chamber and an Enchanting Apparatus to the same computer. Use separate computers for each machine.

The script identifies the machine by its peripheral name.

## Physical Setup

```text
                   AE2 ME NETWORK
                         |
                         v
                 Pattern Provider
                         |
                         v
                  Ingredient Buffer
                         |
                         v
                  CC:Tweaked Computer
                         |
             +-----------+-----------+
             |                       |
             v                       v
       Ars Machine             Arcane Pedestals
             |                       |
             +-----------+-----------+
                         |
                         v
                  Pattern Provider
                         |
                         v
                    ME Network
```

The diagram represents item flow. The computer uses wired peripherals to move ingredients and outputs; it does not require physical item pipes between every component.

## AE2 Pattern Provider Setup

Configure the Pattern Provider to use **Blocking Mode**.

This is important because the controller expects to process one stable batch at a time.

Create AE2 processing patterns for the desired recipes.

The script assumes that the **first occupied slot in the Ingredient Buffer is the center ingredient**.

This is a critical requirement of the current implementation. Incorrect ingredient ordering can cause the wrong item to be inserted into the center machine.

## Imbuement Chamber Mode

When the computer detects an Imbuement Chamber, it automatically uses imbuement mode.

Processing sequence:

1. Waits for ingredients to appear in the Ingredient Buffer.
2. Waits for the buffer contents to stabilize.
3. Treats the first occupied buffer slot as the center ingredient.
4. Places remaining ingredients onto Arcane Pedestals.
5. Inserts center ingredients one at a time.
6. Waits for each crafting operation to finish.
7. Returns completed outputs to the Pattern Provider.
8. Clears pedestal ingredients after the batch.

This allows batches containing multiple center ingredients while reusing supporting pedestal ingredients.

### Starting Imbuement Automation

Run:

```lua
ars
```

Expected startup information:

```text
Unified Ars Controller | imbuement
Machine: ars_nouveau:imbuement_chamber_...
Buffer: ...
Provider: ...
Pedestals: ...
Setup OK
```

The controller then waits for AE2 crafting requests.

## Enchanting Apparatus Mode

When the computer detects an Enchanting Apparatus, it automatically switches to enchanting mode.

Processing sequence:

1. Waits for ingredients in the buffer.
2. Treats the first occupied slot as the center reagent.
3. Distributes supporting ingredients across pedestals.
4. Inserts the center reagent into the Enchanting Apparatus.
5. Waits for the resulting item.
6. Returns the output to the Pattern Provider.
7. Clears remaining pedestal items.

The current script processes **one center reagent per enchanting batch**.

It requires enough connected pedestals for all supporting ingredients.

### Starting Enchanting Automation

Run:

```lua
ars
```

Expected startup information:

```text
Unified Ars Controller | enchanting
Machine: ars_nouveau:enchanting_apparatus_...
Buffer: ...
Provider: ...
Pedestals: ...
Setup OK
```

The controller automatically waits for AE2 crafting requests.

## Important Ars Automation Rules

- Use one computer per Ars machine.
- Enable Pattern Provider Blocking Mode.
- Keep the machine and pedestals empty before starting a batch.
- Ensure all required inventories are accessible through wired modems.
- The first occupied Ingredient Buffer slot must contain the center ingredient.
- The controller uses a 120-second timeout when waiting for a crafting result.
- If processing fails, the controller stops and leaves items in place for recovery.

The script does not require a manually configured recipe database. It uses the ingredients supplied by the Pattern Provider.

---

# 3. Automatic Startup

Both scripts can start automatically whenever their respective ComputerCraft computers reboot.

**Use a separate computer for each continuously running script.**

## ME Sorter Computer

Open the startup file:

```lua
edit startup.lua
```

Add:

```lua
shell.run("Me_sorter")
```

Save the file.

## Ars Automation Computer

Open the startup file:

```lua
edit startup.lua
```

Add:

```lua
shell.run("ars")
```

Save the file.

## Reboot

On each computer, run:

```lua
reboot
```

The corresponding script should start automatically.

For the ME Sorter, complete its configuration before enabling automatic startup.

For Ars automation, verify that the correct peripherals are connected and the machine inventories are empty before enabling automatic startup.

---

# 4. Updating Scripts

To update the ME Sorter:

```lua
delete Me_sorter.lua
wget https://raw.githubusercontent.com/B1sion/Minecraft-ComputerCraft-Scripts/main/Me_sorter.lua Me_sorter.lua
```

To update Ars automation:

```lua
delete ars.lua
wget https://raw.githubusercontent.com/B1sion/Minecraft-ComputerCraft-Scripts/main/ars.lua ars.lua
```

Restart the corresponding computer after updating.

The ME Sorter's saved configuration file is not deleted by these commands.

**Note:** If automatic startup is enabled, stop the running program with `Ctrl+T` before updating it.

---

# 5. Troubleshooting

## ME Sorter

**Inventory unavailable**

Ensure that the inventory is connected through an active wired modem and that its configured peripheral name is correct.

**Items are not moving**

Check that the destination has available space and that the source inventory supports ComputerCraft inventory transfers.

**Items are being sorted incorrectly**

Run:

```lua
Me_sorter setup
```

Verify the normal and non-stackable destination lists.

**Items do not appear in AE2**

Check that the Sophisticated Storage inventory has an ME Storage Bus connected to the ME network, or that the normal output chest has a working ME Import Bus.

## Ars Controller

**Expected exactly one Pattern Provider**

The computer detected zero or multiple Pattern Providers. Ensure that only one matching provider is connected.

**Expected exactly one Ingredient Buffer**

The computer requires exactly one connected peripheral whose name contains `ingredient_buffer`.

**Connect exactly one Ars machine per computer**

Both machine types may be connected, or no compatible machine was detected. Disconnect unnecessary Ars machines.

**Machine/pedestals not empty**

Clear the machine and its pedestals before restarting automation.

**Not enough pedestals**

Connect enough Arcane Pedestals to hold the recipe's supporting ingredients.

**Timed out waiting for result**

Possible causes include:

- Incorrect ingredient order
- Invalid recipe
- Missing source or other crafting requirements
- Missing pedestal ingredients
- Insufficient processing time

Inspect the machine and inventories before restarting.

---

# 6. Repository Structure

```text
Minecraft-ComputerCraft-Scripts/
├── Me_sorter.lua
├── ars.lua
└── README.md
```

## Credits

Developed for Minecraft automation using CC: Tweaked and compatible modded storage and crafting systems.

**Repository:** https://github.com/B1sion/Minecraft-ComputerCraft-Scripts

**Scripts:** `Me_sorter.lua` and `ars.lua`
