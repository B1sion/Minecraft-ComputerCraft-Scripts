# Minecraft ComputerCraft Scripts

Automation scripts for **CC: Tweaked** in modded Minecraft. This repository contains a configurable inventory sorter for AE2 workflows and a unified Ars Nouveau crafting controller.

| Script | Purpose | Setup |
| --- | --- | --- |
| [`Me_sorter.lua`](Me_sorter.lua) | Route items from wired inventories using user-defined filters, priorities, and fallback destinations | Interactive setup in the Minecraft computer |
| [`ars.lua`](ars.lua) | Run Ars Nouveau Imbuement Chamber or Enchanting Apparatus processing through an AE2 Pattern Provider | Automatic peripheral discovery; physical setup required |

> Each continuously running script should use its **own ComputerCraft computer**. The sorter does **not** directly scan items already inside ME Drives.

## Quick install

On the **ComputerCraft shell** (not the Lua interpreter), download the script you need:

**ME sorter**

```text
wget https://raw.githubusercontent.com/B1sion/Minecraft-ComputerCraft-Scripts/main/Me_sorter.lua Me_sorter.lua
Me_sorter setup
```

**Ars automation**

```text
wget https://raw.githubusercontent.com/B1sion/Minecraft-ComputerCraft-Scripts/main/ars.lua ars.lua
ars
```

After initial setup, run `Me_sorter` to reuse the saved sorter configuration, or `ars` to start the Ars controller again.

## 1. Rule-based ME inventory sorter

### What it does

The sorter scans one or more **input inventories** connected via CC: Tweaked wired modems. You define **all** routing rules yourself: no preloaded priorities, destinations, or default rules.

- Each rule has a **numeric priority** (lower number runs first), an **ordered list of destination inventories**, and **one filter**.
- If an item matches a rule, the sorter tries its destinations from left to right.
- If a destination refuses the item or has no space, the sorter tries the next destination, then continues to later matching rules if items remain.
- A filter of `none` matches everything and is useful as a catch-all.
- If no destination accepts an item, it stays in the input inventory.
- Configuration is saved in `sorter_config.txt` on the computer.

### Hardware and wiring

Minimum: one ComputerCraft computer, wired modems and networking cable, one input inventory, and one destination inventory. Connect **each inventory** to the wired network, and make sure its modem is enabled. Add as many input and output inventories as you need.

Optional AE2 arrangement:

```text
Dump chest(s) --wired modem--> ComputerCraft sorter
                                   |
                 +-----------------+------------------+
                 |                                    |
       Sophisticated Storage                  Stackable output chest
         (ME Storage Bus)                        (ME Import Bus)
                 |                                    |
                 +--------------- AE2 ----------------+
```

You can also connect a **Functional Storage Drawer Controller** as a destination. To prevent unwanted items filling new drawers, lock and assign the drawers first. An ME Storage Bus exposes external storage to AE2; an ME Import Bus physically imports items from its attached inventory.

**Do not put an ME Import Bus on the input chest**, or AE2 may take items before the sorter inspects them.

### In-game configuration

```text
Me_sorter list     # show connected inventory peripheral names
Me_sorter setup    # create/replace your rules interactively
Me_sorter          # run using saved configuration
```

The setup wizard asks for:

1. Input inventory names, comma-separated.
2. Number of routing rules.
3. For each rule: priority, comma-separated destination names in preferred order, and a filter.
4. Whether to start sorting immediately after saving.

**Available filters** (exact names used in the wizard):

| Filter | Meaning | Example value |
| --- | --- | --- |
| `none` | All items | No value |
| `max_count_eq` | Maximum stack size equals | `1` |
| `max_count_le` | Maximum stack size at most | `16` |
| `max_count_ge` | Maximum stack size at least | `64` |
| `item_id` | Exact registry ID | `minecraft:diamond` |
| `item_id_contains` | Registry ID contains text | `sword` |
| `mod_id` | Registry namespace equals | `minecraft` |
| `tag` | Item has a given tag | `c:ingots/iron` |
| `display_name_contains` | Display name contains text | `Pickaxe` |
| `damaged` | Item has damage greater than zero | No value |

Each rule currently has **one** filter; compound AND/OR filters are **not** implemented. Filters depend on metadata exposed by the connected inventory peripheral.

**Example only — you define your own rules:**

| Priority | Destination(s) | Filter |
| --- | --- | --- |
| 10 | Locked drawer controller | `none` |
| 20 | Sophisticated chest A, chest B | `max_count_eq` → `1` |
| 30 | ME import chest | `none` |

The sorter will attempt the locked drawers first; rejected items continue to the non-stackable rule, then the catch-all. Items may be split across destinations if the first destination has limited space.

### Limitations and safety

- Only inventories connected to the wired modem network are scanned; the script **cannot scan an entire AE2 ME Drive network**.
- Items inserted directly through an ME Terminal bypass this sorter.
- Source inventories cannot also be configured as destinations; the script checks for this.
- Configured inventories must exist when the sorter starts. Re-run setup after changing peripheral names.
- The sorter polls every **0.5 seconds** and leaves unaccepted items in place.
- Test with a few sample items before connecting valuable storage.

## 2. Ars Nouveau controller

The `ars.lua` script auto-detects **one** connected Ars Nouveau machine: an **Imbuement Chamber** *or* an **Enchanting Apparatus**. It is intended to work with CC: Tweaked wired inventory peripherals and an AE2/Extended AE Pattern Provider.

### Required setup

Connect the following to **one computer** using wired modems/network cable:

- Exactly **one Pattern Provider** whose peripheral name contains `pattern_provider`.
- Exactly **one Ingredient Buffer** whose name contains `ingredient_buffer`.
- Exactly **one** machine named like `ars_nouveau:imbuement_chamber` or `ars_nouveau:enchanting_apparatus`.
- Enough `ars_nouveau:arcane_pedestal` inventories for supporting ingredients.

The computer must be able to transfer items between the buffer, machine, pedestals, and Pattern Provider. Set the **Pattern Provider to blocking mode** and create the relevant AE2 processing patterns.

**Critical assumption:** The **first occupied slot in the Ingredient Buffer** is treated as the **center ingredient**. Other occupied slots supply pedestal ingredients. Check the order before automating expensive recipes; the script does not infer recipes.

### How it runs

```text
ars
```

On startup, the script reports its detected mode, machine, buffer, provider, and pedestal count.

- **Imbuement mode:** Loads pedestal ingredients, processes center items one at a time, returns outputs to the Pattern Provider, and clears pedestals.
- **Enchanting mode:** Places pedestal ingredients, processes **one center reagent per batch**, returns the output, and clears pedestals.
- The script waits for a result and **stops on failure** (including its 120-second result timeout), leaving items in place for inspection.

Keep the machine and pedestals empty before starting a new batch. Do not connect both Ars machine types to the same computer.

## 3. Automatic startup

After verifying a script works, open `startup.lua` **on that script's computer**:

```text
edit startup.lua
```

For the sorter computer, put:

```lua
shell.run("Me_sorter")
```

For the separate Ars computer, put:

```lua
shell.run("ars")
```

Save and run `reboot`. Use **Ctrl+T** to terminate a running program before updating it.

## 4. Updating

On the relevant computer, stop the running script and download the new version:

```text
delete Me_sorter.lua
wget https://raw.githubusercontent.com/B1sion/Minecraft-ComputerCraft-Scripts/main/Me_sorter.lua Me_sorter.lua
```

Or for Ars:

```text
delete ars.lua
wget https://raw.githubusercontent.com/B1sion/Minecraft-ComputerCraft-Scripts/main/ars.lua ars.lua
```

Updating `Me_sorter.lua` this way leaves `sorter_config.txt` intact. Re-run `Me_sorter setup` if the configuration format changes or you want new rules.

## 5. Troubleshooting

| Symptom | What to check |
| --- | --- |
| Inventory missing | Wired modem enabled, cable connected, correct peripheral name; use `Me_sorter list` |
| Sorter not moving items | Destination space, filter match, inventory transfer support, and source/destination roles |
| Items bypass sorter | Ensure the ME Import Bus is on the **output** chest, not the input |
| Items missing from ME Terminal | ME Storage Bus on external storage, or ME Import Bus on normal output chest |
| Ars reports multiple machines/providers | Disconnect extras; the controller requires exactly one of each specified peripheral |
| Ars cannot craft | Check center ingredient buffer slot, pedestal ingredients, valid recipe, and machine requirements |
| Ars times out | Inspect items left in machine/pedestals before restarting |

## 6. Build or customize scripts with AI

See **[`AI_SCRIPTING_PROMPT.md`](AI_SCRIPTING_PROMPT.md)** for a reusable prompt to help an AI coding assistant design, modify, test, and document new CC: Tweaked automation scripts for your own modpack.

The prompt emphasizes checking real peripheral APIs, avoiding invented methods, safe inventory transfers, and producing complete runnable Lua files.

## Repository files

```text
Minecraft-ComputerCraft-Scripts/
├── README.md
├── AI_SCRIPTING_PROMPT.md
├── Me_sorter.lua
└── ars.lua
```

These scripts are community automation utilities; test them in your own pack before using them with valuable inventories.
