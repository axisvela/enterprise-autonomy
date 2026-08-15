# Facility Inspection Reference Stack

## Purpose

This public reference stack illustrates how AxisRobo products can contribute to a governed facility-inspection outcome. It is a product-composition overview, not a deployment blueprint or implementation specification.

## Example Composition

| Outcome Need | Example Product Role |
| --- | --- |
| Operator goal, oversight, and review | Symbivela |
| Operational context and facility state | Ontovela |
| Planning and replanning | Orchadyn |
| Capability discovery and control | Moduregis |
| Identity, authorization, and approval | Aegivela |
| Robot-fleet task execution | Kinetovela |
| External systems and notifications | Limenora |
| Process continuity and recovery | Rheovela |
| Simulation before live operation | Peiravela |
| Testing and release assurance | Tekmovela |

## Design Steps

1. Define the inspection boundary, expected evidence, service window, and operator accountable for review.
2. Establish the operational context to be considered, such as the facility zone, known restrictions, and available inspection resources.
3. Select the product roles needed for collaboration, planning, authorization, execution, context, integration, and recovery.
4. Identify the human decision points: initial approval, exception handling, and final result acceptance.
5. Start with a limited zone and a repeatable inspection objective before expanding coverage.

## Operating Steps

1. Prepare each selected product using its own public setup documentation and verify that the responsible operator can access the required workspaces.
2. Review the facility context, define the inspection objective, and select the limited zone for the trial.
3. Review the proposed work and approve or revise it according to the organization's operating practice.
4. Start the accepted inspection work and monitor the resulting status through the designated operator workspace.
5. Pause or escalate when an exception, safety concern, or unexpected result requires human review.
6. Review the completed evidence, record the outcome, and use the result to improve the next inspection cycle.

## Scope Boundary

Actual deployment topology, integrations, policies, data handling, and product configuration are organization-specific. Follow the [public example design guide](../docs/example-design-guide.md) and product documentation; do not treat this overview as a deployment instruction.
