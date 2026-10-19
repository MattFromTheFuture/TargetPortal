# Target Portal

Lets you target any portal, instead of having to connect two portals via a tag.

If you enter a portal, a map opens and displays the position of all portals. Click one of the portal icons, to teleport to this portal.

You can still tag the portals and the tags will be displayed with the portal icon on the map.

You can toggle between different portal modes:
- Public: Everyone can target this portal
- Private: Only you can target this portal
- Group: Only group members can target this portal
- Admin: Only admins can target this portal
- Guild: Only guild members can target this portal

The group option requires the [Groups](https://valheim.thunderstore.io/package/Smoothbrain/Groups) mod to be installed.

The guild option requires the [Guilds](https://valheim.thunderstore.io/package/Smoothbrain/Guilds) mod to be installed.

The admin option requires you to be an admin.

The owner of a portal changes everytime the portal mode is toggled.

Valheim fetches portals every 5 seconds, so it might take a few seconds for new portals to show up on the map.

Works with custom portals added by other mods.

For multiplayer games, this is required on the server as well.

There is a hotkey to toggle portal icon display on the normal map. Default is P.

You can right-click portals, to add them to a favorite list on the left side of the map.

---

## Unofficial build: gamepad / controller support

**Not an official Smoothbrain release.** This is upstream `master` plus pull
request #82, which adds controller support to the portal picker.

The version is deliberately left at **1.2.7** so this stays version-compatible
with players and servers running the official 1.2.7. It is code-equivalent to
official 1.2.7 everywhere except the gamepad additions below.

### What the gamepad support does

- Selects the portal under the map crosshair with a gamepad button. On a pad the
  crosshair is fixed at screen centre and the map pans underneath it, so the
  selection reads the pad directly instead of the mouse pointer.
- Toggles, and cycles through, favorite portals with a gamepad. Cycling moves the
  map so the favorite lands under the crosshair, and highlights it in the list.
- Shows controller glyph hints on the map's hint bar for teleport and favorite
  while a portal is being picked, plus a hint above the favorites list for the
  cycle button. Glyphs follow the connected controller type and any rebinding.
- Uses Valheim's own interact-alt modifier for the portal mode toggle on a pad,
  so the hover text shows the correct controller glyph.
- While a portal is being picked, the vanilla map's own gamepad bindings
  (create pin / delete pin / toggle public position) are suppressed so they
  cannot fire at the same time as the portal buttons.
- Fixes a vanilla-side audio bug the bulk icon filtering could trigger, where
  enough rumble/select sfx objects at once exhausted Unity's virtual voices and
  silenced all later sound, music included.

### New config options (`1 - General`)

| Option | Default |
| --- | --- |
| Gamepad teleport button | `A` |
| Gamepad favorite button | `Y` |
| Gamepad cycle favorites button | `DPadLeft` |

Set any of them to `Disabled` to turn that binding off. `B` is intentionally not
offered, because the map uses it to close, which doubles as cancelling.

### Groups / Guilds compatibility

Both optional integrations are intact and verified against this build:

- The bundled `Groups` API stubs are byte-identical to official 1.2.7, and
  `PlayerReference.fromPlayerInfo` - the one method TargetPortal calls directly
  for group membership - is identical to the installed Groups 1.2.12. Groups
  needs nothing extra.
- The bundled `Guilds` API was rebuilt from current Guilds source, because the
  copy committed to the TargetPortal repo was stale: its `forOwnPlayer` still
  used the old `UserInfo.GetLocalUser()` path instead of the Splatform one that
  Guilds now uses to derive the local player id. Official 1.2.7 ships the new
  one, and this build's is byte-identical to it, so guild-mode portals resolve
  your guild correctly.

### Installing

Remove or disable the official `Smoothbrain-TargetPortal` first. Both DLLs declare
the same BepInEx GUID (`org.bepinex.plugins.targetportal`), so with both present
only one loads and BepInEx logs a conflict.

As with the official mod, for multiplayer this is needed on the server too.

Source: https://github.com/blaxxun-boop/TargetPortal/pull/82
