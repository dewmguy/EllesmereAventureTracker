# WoW Forever API restrictions

This file records protected-action and data-access limitations observed while
developing Adventure Tracker. Check it before adding a feature that casts a
spell, uses an item, changes protected UI, or reads combat-sensitive state.

## Protected actions

| Intended behavior | Unsafe or unavailable approach | Supported addon pattern |
| --- | --- | --- |
| Use an inventory item | Calling `C_Item.UseItemByName` or `UseItemByName` directly from an addon click handler. WoW Forever reports that the action is available only to Blizzard UI. | Preconfigure a `SecureActionButtonTemplate` outside combat with `type = "item"` and `item = "item:<ID>"`; require a real player click. |
| Cast a spell | Calling a protected cast function from ordinary Lua. | Preconfigure a secure action button with `type = "spell"`, the spell attribute and an allowed unit. |
| Change a secure action | Setting secure attributes, moving the secure overlay or changing its state driver during combat lockdown. | Hide it through a state driver in combat and defer all attribute or position changes until combat ends. |
| Activate a protected action automatically | Programmatically clicking a secure button or triggering it from a timer/event. | Require the player's hardware click. The addon may recommend and prepare the action, but cannot execute it automatically. |
| Buy back a recently sold merchant item | Treating a remembered buyback index as stable, or trying to buy after the merchant closes. | Re-read the live buyback list during the player's click, match the item again, and call `BuybackItem` only while the merchant is open. This action does not require a secure item-use button. |

Wrapping a protected call in `pcall` does not make it permitted and does not
prevent Blizzard's blocked-action dialog. Protection is enforced by the UI
security system outside normal Lua error handling.

## Combat-sensitive reads

- Aura, unit and specialization values may become secret or otherwise
  unreadable in combat. Do not interpret an unreadable result as a missing
  buff. Preserve the last trustworthy state and refresh it when readable.
- Avoid rebuilding or repositioning secure overlays during combat. Queue a
  refresh for `PLAYER_REGEN_ENABLED`.
- Treat values returned by live APIs as potentially secret before comparing,
  formatting or using them as table keys.

## Adventure Tracker decisions

- The Well Fed recommendation uses secure item buttons over both its status icon
  and recommendation row. The exact item is selected and configured only while
  out of combat.
- Role-critical self-buffs use the same secure-button pattern for spells.
- Direct item-use and spell-cast calls are not allowed in recommendation
  `onClick` handlers.
- Future quest-material warnings may call `BuybackItem` from their normal
  player click, but never from the merchant event that detected the sale.
- Secure action overlays are hidden in combat and resynchronized afterward.

## Implementation checklist

Before shipping an interactive recommendation:

1. Determine whether the action is protected or Blizzard-only on Forever.
2. Prefer a normal read-only click handler only for opening panels or changing
   addon-owned state.
3. For permitted item/spell actions, create and configure a secure button while
   out of combat and require a hardware click.
4. Clear stale secure attributes when the recommendation changes.
5. Hide the secure action in combat and defer updates until combat ends.
6. Test the action in game both before and after entering combat; static Lua
   parsing cannot validate protected-action behavior.
