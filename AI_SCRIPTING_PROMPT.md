# AI Prompt: Build or Modify a CC: Tweaked Automation Script

Copy the prompt below into your AI coding assistant. Fill in the bracketed sections and attach your existing Lua script if modifying one. A reusable prompt is preferable to a packaged skill here because it works with any AI assistant and does not depend on a specific tool or installation.

---

## Copy-and-paste prompt

```text
You are an expert Minecraft CC: Tweaked / ComputerCraft Lua engineer. Help me design, implement, and debug a reliable in-game automation script.

ENVIRONMENT
- Minecraft version: [VERSION]
- Modpack and version: [MODPACK + VERSION]
- ComputerCraft implementation: [CC: Tweaked version if known]
- Relevant mods: [AE2, Extended AE, Sophisticated Storage, Functional Storage, Ars Nouveau, etc.]
- Existing repository or script: [LINK OR ATTACHED FILE, IF ANY]

GOAL
[Describe what the script should automate, including inputs, outputs, priorities, filters, and desired behavior.]

HARDWARE / PERIPHERALS
- Connected peripheral names (output of peripheral.getNames()): [PASTE]
- Available methods (output of peripheral.getMethods("name") for each important peripheral): [PASTE IF KNOWN]
- Physical layout / item flow: [DESCRIBE]
- How items/fluids/energy enter and leave: [DESCRIBE]

REQUIREMENTS
1. Do not invent peripheral names, methods, or integration capabilities. Verify CC: Tweaked APIs against documentation and my existing code. For mod-specific peripherals, request a method listing or other evidence if needed.
2. Use ordinary CC: Tweaked Lua compatible with the stated Minecraft/mod versions. Do not assume desktop Lua libraries, internet access, or an ME Bridge unless confirmed available.
3. Make configuration interactive in the Minecraft computer where useful. Do not hardcode my inventory names or assume default routing rules unless I explicitly request them.
4. If implementing routing rules, let me choose priority, ordered destinations, and filters. Explain whether rejected or partially moved items fall through to later rules. Support an in-game edit menu that can append inputs, append outputs to the end of a rule, add rules at the lowest priority, remove entries, and change priorities/filters without resetting saved configuration. Preserve existing config files and provide save/cancel behavior.
5. Prevent item loss and unintended routing: validate peripherals, avoid input/output loops, handle full destinations, check actual transfer counts, and leave unhandled items safely in the source inventory.
6. Handle unexpected conditions explicitly: disconnected peripherals, missing metadata, empty inputs, failed transfers, and interrupted processing. Do not silently discard errors.
7. Preserve my existing working behavior when modifying a script. Describe every intentional behavior change.
8. Provide the COMPLETE runnable .lua file, not a partial patch or pseudocode. Include installation, first-run setup, restart, and update commands.
9. Include a practical test plan: normal item, non-stackable item, full destination, rejected destination, disconnected peripheral, restart with saved configuration, and any mod-specific cases.
10. State any assumptions or unverified details clearly. If information is missing that blocks a correct implementation, ask only the necessary questions before coding.

OUTPUT
- Brief architecture and wiring instructions.
- Complete Lua script with comments.
- Exact ComputerCraft shell commands to install and run it.
- Configuration walkthrough and example (clearly labeled as optional).
- Tests and troubleshooting guidance.
- README updates when behavior changes.

For GitHub installation, use a raw-content URL matching the actual repository path and filename. Do not claim the code was tested in Minecraft unless it was.

Start by checking my stated hardware and the existing code, then implement the simplest reliable solution.
```

## Gathering peripheral information in-game

Run `lua` at the ComputerCraft shell, then use:

```lua
peripheral.getNames()
```

To inspect a specific peripheral:

```lua
peripheral.getMethods("minecraft:chest_0")
```

Replace `minecraft:chest_0` with the actual peripheral name. Paste the results into the prompt. Exit the interpreter with `exit()`.

If you want to inspect the contents and metadata of an inventory, use a temporary Lua snippet such as:

```lua
local inv = peripheral.wrap("minecraft:chest_0")
print(textutils.serialize(inv.list()))
print(textutils.serialize(inv.getItemDetail(1)))
```

Only use a valid occupied slot for `getItemDetail`. Some peripherals expose different metadata or methods; verify what your modpack actually provides.

## Example requests

- "Build a sorter that sends items to a locked Functional Storage controller first, then routes `maxCount == 1` to Sophisticated Storage, then sends everything else to an AE2 Import Bus chest. Let me define the rule priorities in-game."
- "Modify my Ars controller to add better error recovery, but keep its existing Imbuement Chamber and Enchanting Apparatus behavior and ingredient-order assumptions."
- "Create a configurable fluid router that uses only peripheral methods I can demonstrate with `peripheral.getMethods()`."

## Review checklist before using AI-generated code

- Are all peripheral names and methods real in this modpack?
- Does the script run on CC: Tweaked Lua, rather than desktop Lua?
- Does it keep items safe when a destination is full or disconnected?
- Are input and output inventories prevented from forming loops?
- Does it save configuration and restart correctly?
- Does the README describe the actual code rather than hypothetical features?
- Has it been tested on a small sample before connecting valuable inventories?
