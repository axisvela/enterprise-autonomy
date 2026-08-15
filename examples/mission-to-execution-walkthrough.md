# Mission-to-Execution — Worked Walkthrough

A concrete run of the [mission-to-execution](mission-to-execution.md) example. All values are illustrative and organization-specific; the walkthrough shows the input/output shape at each step so an adapter can reproduce the pattern.

**Scenario.** `ops-lead` inspects `zone-alpha` and returns a reviewable result.

## Step 1 — Open the request

**Input:**
```json
{
  "mission": "mission-alpha-001",
  "zone": "zone-alpha",
  "purpose": "verify rack alignment after retrofitting",
  "window": {"from": "2026-08-20T09:00:00Z", "to": "2026-08-20T18:00:00Z"},
  "required_evidence": ["zone-images", "sensor-log", "exception-report"],
  "restrictions": ["no-entry-after-17:00"],
  "accountable_operator": "ops-lead"
}
```

**Products:** Symbivela, Ontovela.

**Output artifact:**
```json
{"mission_id": "mission-alpha-001", "status": "open",
 "subject_ref": "zone://zone-alpha", "owner": "ops-lead"}
```

## Step 2 — Validate context

**Input:** zone availability check.

**Products:** Ontovela, Limenora.

**Output artifact:**
```json
{"assertion_id": "assertion-zone-alpha-available", "subject_id": "zone-alpha",
 "property": "availability", "value": "available", "source": "facility-system",
 "evidence_ref": "evidence://facility/zone-alpha"}
```

## Step 3 — Review work

**Input:** proposed plan for review.

**Products:** Orchadyn, Moduregis, Aegivela, Symbivela.

**Output artifact:**
```json
{"plan_id": "plan-mission-alpha-001", "status": "approved",
 "approval_ref": "approval://mission-alpha-001", "approved_by": "ops-lead"}
```

## Step 4 — Supervise

**Input:** start command + live status.

**Products:** Kinetovela, Ontovela, Symbivela.

**Output artifacts:** mission status events (`started`, `in-progress`, `paused`); any exception raises a pause request.

## Step 5 — Review outcome

**Input:** collected evidence.

**Products:** Ontovela, Tekmovela, Symbivela.

**Output artifact:**
```json
{"mission_id": "mission-alpha-001", "evidence_complete": true,
 "findings": ["rack-07-bolt-torque-out-of-spec"], "status": "reviewed"}
```

## Step 6 — Close or repeat

**Input:** acceptance or escalation.

**Products:** Rheovela, Symbivela.

**Output artifact:**
```json
{"mission_id": "mission-alpha-001", "status": "closed",
 "follow_up": "work-order-ff-0001", "evidence": "evidence://mission-alpha-001"}
```

## Value Demonstrated

- **Division of authority:** no single product decides; each contributes one governed link.
- **Human gates:** plan approval (step 3) and outcome acceptance (step 6) are human decisions.
- **Recoverability:** the durable close keeps partial or failed work visible.
