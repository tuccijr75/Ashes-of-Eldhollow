import fs from "node:fs";
import path from "node:path";

const root = process.cwd();

function pad3(n) {
  return String(n).padStart(3, "0");
}

function writeJson(relPath, data) {
  const full = path.join(root, relPath);
  fs.mkdirSync(path.dirname(full), { recursive: true });
  fs.writeFileSync(full, JSON.stringify(data, null, 2) + "\n", "utf8");
}

function choice(text, next, effects = [], conditions = []) {
  const c = { text, next };
  if (effects.length) c.effects = effects;
  if (conditions.length) c.conditions = conditions;
  return c;
}

function node(speaker, text, choices = null, end = false) {
  const n = { speaker, text };
  if (end) n.end = true;
  if (choices) n.choices = choices;
  return n;
}

const DOMAINS = [
  {
    key: "INK",
    clause: "ink",
    title: "Ink",
    virtue: "clarity",
    wound: "rewriting",
    verb: "name",
    icon: "quill",
    palette: ["ledger", "ash-ink", "vellum", "margins"],
    speakers: ["Scribe", "Archivist", "Ink-Warden"],
  },
  {
    key: "BLOOD",
    clause: "blood",
    title: "Blood",
    virtue: "courage",
    wound: "violence",
    verb: "take",
    icon: "blade",
    palette: ["scar", "salt", "iron", "pulse"],
    speakers: ["Warden", "Butcher-Saint", "Oathbreaker"],
  },
  {
    key: "SILENCE",
    clause: "silence",
    title: "Silence",
    virtue: "mercy",
    wound: "withholding",
    verb: "withhold",
    icon: "bell",
    palette: ["hush", "fog", "threshold", "unspoken"],
    speakers: ["Bell-Keeper", "Confessor", "Mute Knight"],
  },
  {
    key: "DEBT",
    clause: "debt",
    title: "Debt",
    virtue: "duty",
    wound: "possession",
    verb: "owe",
    icon: "chain",
    palette: ["coin", "link", "interest", "receipt"],
    speakers: ["Factor", "Usurer", "Chain-Priest"],
  },
  {
    key: "WITNESS",
    clause: "witness",
    title: "Witness",
    virtue: "truth",
    wound: "exposure",
    verb: "witness",
    icon: "eye",
    palette: ["lantern", "glass", "testimony", "footprints"],
    speakers: ["Lantern-Bearer", "Jurist", "Gravespeaker"],
  },
];

const REGIONS = [
  { id: "eldhollow", name: "Eldhollow" },
  { id: "fenmire", name: "Fenmire" },
  { id: "blightlands", name: "Blightlands" },
  { id: "hollow_city", name: "Hollow City" },
  { id: "vale_of_bones", name: "Vale of Bones" },
  { id: "gallows_shoal", name: "Gallows Shoal" },
];

function regionFor(qid) {
  return REGIONS[qid % REGIONS.length];
}

function seededPick(arr, seed) {
  return arr[seed % arr.length];
}

function makePremise(qid, domain, region, beat) {
  const p = domain.palette;
  const a = seededPick(p, qid + 1);
  const b = seededPick(p, qid + 3);
  const c = seededPick(p, qid + 5);
  return (
    `In ${region.name}, an Authority clerk has filed the world under the wrong heading. ` +
    `The error is not paper-deep: it changes who is permitted to grieve, who is permitted to eat, ` +
    `and who is permitted to be remembered.\n\n` +
    `The Domain of ${domain.title} calls it a ${a}. The people call it ${b}. ` +
    `You call it ${c}.\n\n` +
    `${beat}`
  );
}

function makeQuestName(qid, domain, i) {
  const nouns = {
    INK: ["Margin", "Ledger", "Pale Signature", "Redaction", "Archive", "Counterfeit Name"],
    BLOOD: ["Oath", "Blade", "Scar", "Salt-River", "Banner", "Hound"],
    SILENCE: ["Bell", "Hush", "Confession", "Door", "Breath", "Unsaid"],
    DEBT: ["Chain", "Receipt", "Interest", "Bond", "Tithe", "Weight"],
    WITNESS: ["Lantern", "Testimony", "Mirror", "Footprint", "Ash-Eye", "Verdict"],
  };
  const verbs = ["Gather", "Undo", "Carry", "Refuse", "Return", "Name", "Bury", "Bind", "Release", "Cross"]; 
  const noun = seededPick(nouns[domain.key], qid + i);
  const verb = seededPick(verbs, qid * 7 + i);
  return `${verb} the ${noun}`;
}

function makeDialog(qid, quest, domain) {
  const speaker = seededPick(domain.speakers, qid);
  const r = regionFor(qid);

  const intro =
    `We pretend the Ladder is a tool.\n` +
    `But tools don’t get hungry.\n\n` +
    `This is a contract you can feel in your teeth: in ${r.name}, the Authority has written a rule ` +
    `that decides who gets to be real today.\n\n` +
    `Tell me how you will answer it. Not what you want — what you will pay.`;

  const hinge =
    `There are five ways the world keeps score, and none of them are kind.\n\n` +
    `Ink asks you to ${domain.verb} it.\n` +
    `Blood asks you to take it.\n` +
    `Silence asks you to withhold it.\n` +
    `Debt asks you to owe it.\n` +
    `Witness asks you to witness it.\n\n` +
    `Choose, and don’t flatter yourself: even refusal is a clause.`;

  const vow =
    `Good. Then say it plainly.\n\n` +
    `If you step forward, the Ladder remembers your weight.\n` +
    `If you step back, it remembers the shape of your absence.`;

  const endText =
    `The contract closes with a sound like a book shutting in an empty room.\n\n` +
    `You can walk away, but you cannot walk back into who you were.`;

  const startEffects = [{ start_quest: qid }];
  const completeEffects = [
    { set_flag: `Q_READY_${pad3(qid)}`, value: true },
    { complete_quest: qid },
  ];

  const clauseChoices = DOMAINS.map((d) =>
    choice(
      `Bind yourself to the Clause of ${d.title} (become ${d.verb}-shaped).`,
      "vow",
      [{ set_clause: d.clause }],
      [{ flag: "CLAUSE_SET", op: "==", value: "" }]
    )
  );

  const proceedChoices = [
    choice("Speak the first line of the contract (begin).", "hinge", startEffects),
    choice("Say nothing. Watch how silence signs itself.", "hinge", startEffects),
  ];

  const answerChoices = [
    choice(
      `Answer in ${domain.title}: choose ${domain.virtue} even if it stains you.`,
      "vow",
      [{ inc_flag: `DOMAIN_${domain.key}_SCORE`, delta: 1 }]
    ),
    choice(
      `Answer against ${domain.title}: choose restraint and carry the ${domain.wound} anyway.`,
      "vow",
      [{ inc_flag: "CENSURE", delta: 1 }]
    ),
  ];

  // A third choice that only appears after a clause is chosen.
  answerChoices.push(
    choice(
      "Invoke your Clause. Let the Authority hear the shape of your vow.",
      "vow",
      [{ inc_flag: "CENSURE", delta: -1 }],
      [{ flag: "CLAUSE_SET", op: "!=", value: "" }]
    )
  );

  const vowChoices = [
    choice("Close the contract (complete this step).", "end", completeEffects),
    choice("Leave it open a moment longer. Breathe. Then close it.", "end", completeEffects),
  ];

  // Special handling: Censure hearing (quest 98)
  if (qid === 98) {
    return {
      quest_id: qid,
      start: "start",
      nodes: {
        start: node(
          "Censor",
          `The Authority calls this a hearing.\nYou should call it what it is: a knife that asks politely.\n\n` +
            `You have carried your signatures here. Now choose what to do with them.`,
          [
            choice(
              "Reduce Censure: accept the ritual, pay the fine, and live smaller.",
              "vow",
              startEffects.concat([{ set_censure_mode: "reduced" }])
            ),
            choice(
              "Defy Censure: refuse the ritual, keep your name, and live hunted.",
              "vow",
              startEffects.concat([{ set_censure_mode: "defied" }])
            ),
          ]
        ),
        vow: node(
          "Censor",
          `So be it.\n\n` +
            `The Ladder does not forgive. It only recalculates.`,
          [choice("Finalize the record.", "end", completeEffects.concat([{ compute_boss_unlock: true }]))]
        ),
        end: node("Narrator", endText, null, true),
      },
    };
  }

  // Special handling: Keystone trial (quest 97)
  if (qid === 97) {
    return {
      quest_id: qid,
      start: "start",
      nodes: {
        start: node(
          "Keystone",
          `Three seals are not a key.\nThey are proof you can survive the price.\n\n` +
            `The Keystone Trial does not test strength. It tests what you keep when strength is gone.`,
          [
            choice("Enter the Trial.", "vow", startEffects),
            choice("Enter anyway. The hesitation is part of it.", "vow", startEffects),
          ]
        ),
        vow: node(
          "Keystone",
          `You do not win.\nYou are measured.\n\n` +
            `And the measure approves enough of you to let you pass.`,
          [choice("Take the Keystone.", "end", completeEffects.concat([{ compute_boss_unlock: true }]))]
        ),
        end: node("Narrator", endText, null, true),
      },
    };
  }

  // Special handling: Final arena (quest 100)
  if (qid === 100) {
    return {
      quest_id: qid,
      start: "start",
      nodes: {
        start: node(
          "Herald",
          `The Ladder has run out of ordinary steps.\n\n` +
            `What remains is the rung that breaks, and the hand that decides whether to hold.`,
          [
            choice(
              "Take the crown of procedure (ENDING: INK).",
              "end",
              startEffects.concat([{ set_flag: "ENDING_ID", value: "INK" }]).concat(completeEffects)
            ),
            choice(
              "Take the crown of force (ENDING: BLOOD).",
              "end",
              startEffects.concat([{ set_flag: "ENDING_ID", value: "BLOOD" }]).concat(completeEffects)
            ),
            choice(
              "Take the crown of mercy (ENDING: SILENCE).",
              "end",
              startEffects.concat([{ set_flag: "ENDING_ID", value: "SILENCE" }]).concat(completeEffects)
            ),
            choice(
              "Take the crown of obligation (ENDING: DEBT).",
              "end",
              startEffects.concat([{ set_flag: "ENDING_ID", value: "DEBT" }]).concat(completeEffects)
            ),
            choice(
              "Take the crown of truth (ENDING: WITNESS).",
              "end",
              startEffects.concat([{ set_flag: "ENDING_ID", value: "WITNESS" }]).concat(completeEffects)
            ),
          ]
        ),
        end: node("Narrator", endText + `\n\nEnding: {ENDING_ID}.`, null, true),
      },
    };
  }

  return {
    quest_id: qid,
    start: "start",
    nodes: {
      start: node(speaker, intro, proceedChoices.concat(clauseChoices)),
      hinge: node(speaker, hinge, answerChoices),
      vow: node(speaker, vow, vowChoices),
      end: node("Narrator", endText, null, true),
    },
  };
}

function makeQuest(qid, opts) {
  const region = regionFor(qid);
  const domain = opts.domain;
  const name = opts.name;

  const base = {
    quest_id: qid,
    name,
    region: region.name,
    objectives: [
      "Explore",
      "Investigate",
      "Dialogue challenge (Authority Ladder clauses)",
      "Conflict (combat or social)",
      "A decision with a cost",
      "World-state update",
    ],
    triggers: [],
    enemy_groups: [],
    rewards: ["xp:200", "money:200"],
    dependencies: opts.dependencies || [],
    location: region.id,
    tags: opts.tags || ["main"],
    authority_domain: opts.authority_domain || "",
    availability_conditions: opts.availability_conditions || undefined,
    completion_conditions: opts.completion_conditions || undefined,
    outcomes: opts.outcomes || [],
    is_terminal: !!opts.is_terminal,
    _meta: {
      type: opts.metaType || "Main",
      estimated_minutes: opts.minutes || 20,
      unique_mechanic: opts.mechanic || "Authority clause choice",
      narrative_premise: makePremise(qid, domain, region, opts.beat || "The contract wants a signature. The world wants a person."),
      player_motivation: opts.motivation || "Shape Authority, gain leverage, and keep your humanity.",
      branching_outcomes: opts.branching || [
        "Choose a clause (one-time)",
        "Trade Censure for leverage",
        "Advance a Domain score and unlock seals",
      ],
      failure_states: opts.failure || "Fail-forward: setbacks increase Censure and shift later dialog tone; progress remains possible.",
      source_markdown: "",
    },
  };

  // Remove undefined optional fields so JSON stays clean.
  if (base.availability_conditions === undefined) delete base.availability_conditions;
  if (base.completion_conditions === undefined) delete base.completion_conditions;

  return base;
}

function main() {
  // Safety guard: this generator creates the original 100-quest Authority Web dataset
  // and writes numeric quest ids. Live game data now uses canonical string quest_id
  // values and may contain >100 quests. Refuse to overwrite unless explicitly forced.
  try {
    const questsPath = path.join(root, "data", "quests.json");
    if (fs.existsSync(questsPath)) {
      const existing = JSON.parse(fs.readFileSync(questsPath, "utf8"));
      const first = Array.isArray(existing) ? existing[0] : null;
      const existingQuestId = first && typeof first === "object" ? first.quest_id : null;
      const looksLikeCanonicalString = typeof existingQuestId === "string" && existingQuestId.includes(".");
      const looksExpanded = Array.isArray(existing) && existing.length !== 100;
      if ((looksLikeCanonicalString || looksExpanded) && process.env.FORCE_GENERATE_AUTHORITY_WEB !== "1") {
        console.error(
          "Refusing to overwrite data/quests.json (current schema detected). " +
            "If you really intend to regenerate the legacy 100-quest Authority Web dataset, set FORCE_GENERATE_AUTHORITY_WEB=1."
        );
        process.exit(2);
      }
    }
  } catch {
    // If file missing or invalid, proceed (generator will write fresh output).
  }

  const quests = [];

  // Q001: Prologue
  quests.push(
    makeQuest(1, {
      domain: DOMAINS[0],
      name: "The Ladder Wakes",
      authority_domain: "META",
      dependencies: [],
      mechanic: "First contract: choose to enter the Authority web",
      beat:
        "A bell rings without sound. A ledger turns a page by itself. Someone you have never met has filed your name under ‘solvent’.\n\nYou decide whether to accept that lie or make it expensive.",
    })
  );

  // Q002-Q006: Invitations (one per domain; clause can be set here)
  for (let i = 0; i < DOMAINS.length; i++) {
    const d = DOMAINS[i];
    const qid = 2 + i;
    quests.push(
      makeQuest(qid, {
        domain: d,
        name: `Invitation: ${d.title}`,
        authority_domain: d.key,
        dependencies: [1],
        mechanic: "Choose (or refuse) a clause; establish Domain tone",
        beat:
          `A messenger offers you a contract written in ${d.title.toLowerCase()}.\n` +
          `It promises ${d.virtue}. It hides ${d.wound}.\n\n` +
          `If you sign, you become easier to categorize — and harder to erase.`,
        outcomes: [{ inc_flag: `DOMAIN_${d.key}_SCORE`, delta: 1 }],
      })
    );
  }

  // Domain arcs: 18 each = 90 quests, IDs 7..96
  let qid = 7;
  const sealQuestIdByDomain = new Map();
  for (const d of DOMAINS) {
    const arcStart = qid;
    for (let j = 0; j < 18; j++) {
      const thisId = qid++;
      const deps = [];
      if (j === 0) deps.push(2 + DOMAINS.findIndex((x) => x.key === d.key));
      else deps.push(thisId - 1);

      const isSeal = j === 17;
      if (isSeal) sealQuestIdByDomain.set(d.key, thisId);

      quests.push(
        makeQuest(thisId, {
          domain: d,
          name: makeQuestName(thisId, d, j),
          authority_domain: d.key,
          dependencies: deps,
          minutes: 25,
          mechanic: isSeal ? "Seal ritual (Domain finale)" : "Authority clause pressure",
          beat: isSeal
            ? `A seal is not a reward. It is a verdict in your favor, stamped onto your skin.\n\n` +
              `You can take it — and become legible to the Ladder forever.`
            : `A small rule in ${d.title} has become a large harm.\n\n` +
              `The Authority will call it procedure. The hungry will call it weather. You must call it something you can live with.`,
          outcomes: isSeal
            ? [
                { grant_seal: d.key },
                { inc_flag: `DOMAIN_${d.key}_SCORE`, delta: 2 },
                { compute_boss_unlock: true },
              ]
            : [{ inc_flag: `DOMAIN_${d.key}_SCORE`, delta: 1 }],
        })
      );
    }
    // eslint-disable-next-line no-unused-vars
    const arcEnd = qid - 1;
  }

  // Q097 Keystone Trial: requires 3/5 seals
  quests.push(
    makeQuest(97, {
      domain: DOMAINS[0],
      name: "Keystone Trial",
      authority_domain: "META",
      dependencies: [1],
      availability_conditions: [
        {
          all: [
            {
              count_true: ["SEAL_INK", "SEAL_BLOOD", "SEAL_SILENCE", "SEAL_DEBT", "SEAL_WITNESS"],
              op: ">=",
              value: 3,
            },
          ],
        },
      ],
      mechanic: "Keystone Trial gate (3 seals)",
      outcomes: [{ set_flag: "KEYSTONE_TRIAL_DONE", value: true }, { compute_boss_unlock: true }]
    })
  );

  // Q098 Censure Hearing
  quests.push(
    makeQuest(98, {
      domain: DOMAINS[2],
      name: "Censure Hearing",
      authority_domain: "META",
      dependencies: [97],
      availability_conditions: [{ flag: "KEYSTONE_TRIAL_DONE", op: "==", value: true }],
      mechanic: "Choose Reduced vs Defied Censure",
      outcomes: [{ compute_boss_unlock: true }],
    })
  );

  // Q099 The Ladder’s Price
  quests.push(
    makeQuest(99, {
      domain: DOMAINS[3],
      name: "The Ladder’s Price",
      authority_domain: "META",
      dependencies: [98],
      availability_conditions: [{ flag: "CENSURE_MODE", op: "!=", value: "unresolved" }],
      mechanic: "Finalize your Authority stance",
      outcomes: [{ compute_boss_unlock: true }],
    })
  );

  // Q100 Final
  quests.push(
    makeQuest(100, {
      domain: DOMAINS[4],
      name: "Final: The Rung That Breaks",
      authority_domain: "META",
      dependencies: [99],
      availability_conditions: [{ flag: "BOSS_UNLOCKED", op: "==", value: true }],
      mechanic: "Final confrontation / ending selection",
      is_terminal: true,
      outcomes: [{ compute_boss_unlock: true }],
    })
  );

  if (quests.length !== 100) {
    throw new Error(`Internal error: expected 100 quests, got ${quests.length}`);
  }

  // Write quests.json
  writeJson("data/quests.json", quests);

  // Write dialogs
  for (const q of quests) {
    const qid2 = q.quest_id;
    const domain = DOMAINS.find((d) => d.key === String(q.authority_domain || "").toUpperCase()) || DOMAINS[0];
    const dialog = makeDialog(qid2, q, domain);

    writeJson(`data/dialogs/quest_${pad3(qid2)}.json`, dialog);
  }

  console.log("OK generated authority web", {
    quests: quests.length,
    dialogs: quests.length,
  });
}

main();
