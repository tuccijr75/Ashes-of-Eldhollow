# Quests (Data + Runtime Rules)

## Inventory
- Quest database: `data/quests.json` (Array of 100 quests).
- Quest dialogs: `data/dialogs/quest_###.json` (100 files).

## Canon (current build)
- Quests form a single **Authority Web** (Reality Contracts / Authority Ladder).
- Domains: `INK`, `BLOOD`, `SILENCE`, `DEBT`, `WITNESS` plus `META` nodes (Keystone/Censure/Finale).
- Boss unlock rule is systemic: **3 of 5 seals** + **Keystone Trial** + resolve **Censure**.

## Quest JSON schema (observed)
Each quest entry includes:
- `quest_id` (int)
- `name` (string)
- `region` (string)
- `objectives` (string array)
- `triggers` (array; currently often empty)
- `enemy_groups` (string array)
- `rewards` (string array, e.g. `money:277`, `item:Blade of Ash`)
- `dependencies` (int array)
- `location` (string id)
- `tags` (string array, e.g. `main`)
- `authority_domain` (string; one of `INK|BLOOD|SILENCE|DEBT|WITNESS|META`)
- `availability_conditions` (optional; condition DSL array)
- `completion_conditions` (optional; condition DSL array)
- `outcomes` (optional; list of small effect dicts applied to `WorldFlags`)
- `is_terminal` (optional bool)
- `_meta` (Dictionary) with authoring/support fields (estimated minutes, unique mechanic, narrative premise, etc.)

## Runtime quest state (Authority Web)
- `QuestSys` is a stable facade API; the underlying runtime is graph-backed via `QuestDirector + QuestGraph`.
- State lives in the quest director save blob (active/completed nodes) and is persisted by `SaveSys`.
- Status rules:
  - `completed` if node completed
  - `active` if node active
  - `available` if `availability_conditions` pass and quest not active/completed
  - otherwise `locked`
- Completion rule (important): quest completion requires `Q_READY_### = true`.
  - That flag represents “all requirements satisfied” (combat cleared / item delivered / proof obtained / etc.).
  - Current authoring path sets it via dialog on completion routes (so content remains console/dialog-driven).
- Side-effect flags (WorldFlags):
  - `Q_START_###`, `Q_ACTIVE_###`, `Q_READY_###`, `Q_DONE_###`.
  - Authority Ladder globals: `CLAUSE_SET`, `SEAL_*`, `KEYSTONE_TRIAL_DONE`, `CENSURE_MODE`, `BOSS_UNLOCKED`, `ENDING_ID`.

## Dialogue integration (current)
Dialog is data-driven and supports:
- Conditions on choices (flags + comparisons)
- Effects that set/clear flags, start/complete quests, set chapter, set RNG seed

Authority Web additions:
- `set_clause`, `grant_seal`, `set_censure_mode`, `compute_boss_unlock`.

The debug console can open a quest dialog with:
- `dlg <quest_id>`

## Quest authoring checklist
- Add/update quest in `data/quests.json`.
- Ensure `quest_id` is unique and within 1..100.
- Ensure dependencies refer to valid quest IDs.
- Ensure `authority_domain` is valid.
- Ensure dialog file exists: `data/dialogs/quest_###.json`.
- Ensure dialog has `start`, `nodes`, and at least one `complete_quest` effect for that quest.

## Validation
- Automated: `src/tests/QuestTests.gd` checks count, ID range, dependency validity/acyclic, and dialog schema.
- Data script: `scripts/validate-data.mjs` validates JSON files.
