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
  World/CritterCove          builds the starting island
src/client/            StarterPlayerScripts.Client
  init.client.lua      entry point, UI scaling
  ClientData           read-only copy of your data
  UI                   shared UI helpers
  Controllers/         HUD, notifications, discovery reveal, collection book
```

## Stage status

- [x] **Stage 1: Foundation.** Critter Cove island, spawn plaza, meadow, six discovery bushes, HUD, saving, discovery with reveal, collection book.
- [ ] Stage 2: Creature models, idle animations, inventory, equipping, following.
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
