# RPGGO Rules (Canonical)

RPGGO is a stateful narrative rules engine. Godot remains the authoritative simulation.

## Non-Negotiable Constraints

- No RPGGO calls in `_process` / `_physics_process`
- No per-frame networking
- Offline play must never break
- API keys are never hardcoded or logged

## Governance (Project Roles)

- **Head Developer (assistant):** makes implementation decisions end-to-end and drives the project toward Steam/commercial readiness using the existing project data and constraints.
- **Project Overseer (you):** reviews changes and uses the editor prompts/buttons to keep/apply changes.

## Canonical Narrative Event IDs

All narrative event identifiers are defined locally and treated as immutable contracts.

- Registry: `res://data/rpggo_events.gd` (`class_name RPGGOEvents`)
- All gameplay code must reference `RPGGOEvents.*` constants only
- Event IDs must be stable, human-readable, and must not embed runtime data

### Required naming schema

- `quest.<region>.<quest_name>.<state>`
- `choice.<location>.<decision>`
- `boss.<name>.<state>`
- `faction.<name>.<action>`
- `world.<region>.<change>`
- `ending.<ending_id>`

## Offline Event Sync

When online and configured:
- Send curated events to RPGGO `/world/event`
- Update cached `world_state` / `player_state` from responses

When offline/unconfigured:
- Apply deterministic local meaning immediately (via local flags)
- Queue events in order
- Flush later when online (best-effort, time-bounded, non-blocking)

## Integration Hooks (Allowed)

- Quest completion
- Major choice resolution
- Boss defeat
- Ritual completion
- Zone/region transitions

## Security

Credentials must come from environment variables:
- `RPGGO_BASE_URL`
- `RPGGO_GAME_ID`
- `RPGGO_API_KEY`

Never commit credentials to the repo.
