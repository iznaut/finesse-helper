# Finesse Helper

`finesse.sh` can be run directly via Terminal or automated via Mac Shortcuts.

## Initial Config

Unzip this repo's contents to `~/finesse-helper/`.

Run `~/finesse-helper/finesse.sh` via Terminal. You will be prompted for the following:

- Finesse server URL w/ port (e.g. http://finesse.xyz:8080)
- Finesse username
- Finesse extension (phone number)
- Finesse password (this will be encrypted and stored locally)

## Script Usage

Run `finesse.sh` again to get your current state.

Run `finesse.sh [STATE]` to update your state. Valid states are `READY`, `NOT_READY` (Break), and `LOGOUT`.

## Shortcut Usage

Add the [Finesse Helper](https://www.icloud.com/shortcuts/d78afd1eda174489899b1e24699bb578) Shortcut. This is simply a wrapper for the Bash script that will similarly output your current state or update to a new state (if passed as input). A notification will appear if the state changed (or display an error if something went wrong).

## Automation via Shortcuts

Status changes can be automated based on system state via [Shortery](https://apps.apple.com/us/app/shortery/id1594183810).

Add the [Shortery - Update Finesse State](https://www.icloud.com/shortcuts/bbd28d916b45422f8ae6366bbe160692) Shortcut. This depends on the Finesse Helper Shortcut being installed and will change state based on four different input strings that come from Shortery triggers:

- `locked` (Screen Lock) will change state from `READY` to `NOT_READY` (Break)
- `unlocked` (Screen Unlocked) will change state from `NOT_READY` to `READY`
- `started` (Calendar Events) will change state to `READY`
- `ended` (Calendar Events) will change state to `LOGOUT`

### Anybar Status Icon (Optional)

If Anybar is installed, the [Set Anybar Color From Finesse State](https://www.icloud.com/shortcuts/ec0d0626ebef428b935ebc03b9c6120d) Shortcut can also be added to automatically the statusbar icon's color to match the last known state change:

- `green` for `READY`
- `red` for `NOT_READY`
- `white` for `LOGOUT`
- `exclaimation` for `ERROR` (sent if Finesse Helper failed to set state)

## Troubleshooting

Run `finesse.sh --reconfig` to be reprompted with the initial configuration questions (except for password).

To change your password, delete the contents of `~/.encpass` and run `finesse.sh` again.