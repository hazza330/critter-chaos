# Critter Chaos

A creature-collecting Roblox game, built in stages. Code is synced into Roblox Studio with [Rojo](https://rojo.space).

## Setup (Windows)

1. Install tools: `aftman install` (needs [Aftman](https://github.com/LPGhatguy/aftman)).
2. Install the Studio plugin once, with Studio closed: `rojo plugin install`.
3. Open Roblox Studio and create a new **Baseplate** place.
4. In this folder, run `rojo serve`.
5. In Studio: **Plugins** tab, **Rojo**, **Connect**.
6. Press **Play**.

To make saving work in Studio: publish the place (File, Publish to Roblox), then Game Settings, Security, turn on **Enable Studio Access to API Services**. Without this the game still runs but warns that progress won't save.

## Project layout

```
src/shared/            ReplicatedStorage.Shared   (read by server and client)
  Config/Rarities      rarity colours and reward values
  Config/Creatures     every creature's data
  Config/Islands       per-island rarity weights and unlock level
  Config/Economy       cooldowns, level curve, capacities
  Remotes              creates/fetches all RemoteEvents
src/server/            ServerScriptService.Server
  init.server.lua      entry point
  Services/DataService       saving, session locking, autosave
  Services/ProgressService   coins, XP, levels, leaderstats
  Services/DiscoveryService  discovery spots and creature rolls
  Services/TreasureService   hidden daily treasure chests
  World/Builder              shared map-building helpers and props
  World/CritterCove          builds the starting island
  World/CoveDetails          detail pass: plaza, beach, woods, cliffs, chests
src/client/            StarterPlayerScripts.Client
  init.client.lua      entry point, UI scaling
  ClientData           read-only copy of your data
  UI                   shared UI helpers
  Controllers/         HUD, notifications, discovery reveal, collection book
```

## Stage status

- [x] **Stage 1: Foundation.** Critter Cove island, spawn plaza, meadow, six discovery bushes, HUD, saving, discovery with reveal, collection book.
- [x] **Stage 2: Creature system.** 3D models for all 10 Cove creatures, rarity glow and sparkles, inventory (search, sort, island filter, favourites, equip/unequip, Equip Best, comparison), equip limit of 3, smooth following with walk/hop/float/fly styles, model thumbnails, 3D discovery reveal. Basic creature income brought forward from Stage 3.
- [x] **Map pass.** Waterfall with a hidden cave, cliff stairs to a lookout, palm-lined beach, dock and boat, islets, plaza fountain and lanterns, mushrooms, pond stepping stones, clouds, tropical water, day/night cycle.
- [ ] Stage 3: Creature income, shop, upgrades.
- [ ] Stage 4: Quests, achievements, habitats.
- [ ] Stage 5: Other five islands.
- [ ] Stage 6: Trading, leaderboards, events, friends.
- [ ] Stage 7: Persistence and security testing.
- [ ] Stage 8: Polish, audio, effects, optimisation.

## Stage 1 test checklist

Run these in Studio and tick them off:

- [ ] Spawn on the yellow pad in the plaza, CRITTER CHAOS sign visible.
- [ ] HUD shows level 1, XP bar, 0 coins, 0 gems.
- [ ] Walk east along the path to Creature Meadow.
- [ ] Sparkling bushes show a "Search" prompt; holding it plays the reveal.
- [ ] Coins and XP go up after a discovery; player list shows Level, Species, Coins.
- [ ] Searching the same bush again within 8s shows a "needs Xs to settle" message.
- [ ] Collection button opens the book; discovered species are coloured, others show ???.
- [ ] Rarity tabs filter the book; clicking a card shows details; X closes it.
- [ ] (Published, API access on) Leave and rejoin: coins, level and collection are kept.
- [ ] Test > Clients and Servers, 2 players: each has their own data.
- [ ] Device emulator (phone): HUD fits, buttons can be tapped.

## Stage 2 test checklist

- [ ] Inventory button opens the inventory; cards show 3D thumbnails.
- [ ] Select a creature, press Equip: it appears next to you and follows smoothly.
- [ ] Equipping a 4th creature shows "You can only equip 3 creatures".
- [ ] Equip Best picks the highest-income creatures; Unequip All clears them.
- [ ] Hoppers bounce, Bubbles/Glowfin float, Flutterbug/Griffin fly with flapping wings.
- [ ] Pets follow up hills and over the cliff stairs without sinking into the ground.
- [ ] Every 10s a "+N" floats up from your coins while creatures are equipped.
- [ ] Search box, Sort, Island and Favourites buttons all change the grid.
- [ ] Collection book shows coloured models for found species and black silhouettes for the rest.
- [ ] Two-player test: each player sees the other's pets.
- [ ] Rejoin (published place): equipped creatures and favourites are kept.

## Map test checklist

- [ ] Spawn faces the fountain and CRITTER CHAOS sign.
- [ ] Path north under the sign leads to the waterfall lagoon.
- [ ] Walk through the waterfall into the cave; the crystal spot can be searched.
- [ ] Wooden stairs at the east end of the cliffs reach Griffin's Lookout.
- [ ] Path south reaches the dock and boat.
- [ ] Lanterns light up at night (a full day takes 15 minutes).
- [ ] Plaza: Griffin statue on the fountain, bunting, benches, market stalls.
- [ ] Beach: huts, umbrellas, lifeguard tower (climbable ladder), campfire, sandcastle.
- [ ] Boats and buoys bob; the windmill on the meadow hill turns.
- [ ] Seagulls circle overhead; butterflies in the meadow and plaza.
- [ ] Whispering Woods (west): pines, ferns, glowing mushrooms, ruined arch.
- [ ] Fireflies appear over the pond and woods at night.
- [ ] Treasure chests (arch, west cliff top, south-west islet) give coins and gems once every 20 hours.
