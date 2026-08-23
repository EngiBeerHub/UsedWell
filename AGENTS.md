# AGENTS.md

## Project

- Native iPhone application named `UsedWell`.
- Use SwiftUI and SwiftData.
- Support iOS 18 or later.
- iPad, macOS, and watchOS apps are outside the MVP scope.
- Data is stored locally on the device.
- Accounts, cloud sync, external APIs, and AI features are outside the MVP scope.

## Product source of truth

- Read `docs/product.md` before making product or UX decisions.
- Treat `docs/product.md` as the source of truth for the current product concept, MVP scope, and product rules.
- Do not introduce behavior that conflicts with `docs/product.md` without raising the product decision first.
- If an implementation change makes `docs/product.md` inaccurate, update it to represent the new current state.

## Development workflow

- Treat the current Chat/Codex handoff, `docs/product.md`, and the existing codebase as the inputs for the implementation task.
- Product WHAT / WHY and scope decisions belong to the PM-side Chat; implementation HOW should be decided autonomously when it does not change agreed product behavior.
- Do not stop for approval of implementation-only decisions.
- Escalate only when implementation requires a new product or UX decision, changes MVP scope, or conflicts with `docs/product.md`.
- For substantive implementation work, complete the change through implementation, validation, commit, push, and GitHub PR creation when repository access allows it.
- Use the GitHub PR as the primary implementation handoff.
- PR descriptions should include:
  - Summary
  - Validation
  - Notes
- Do not create separate Markdown files for implementation summaries or handoff notes.
- Small, low-risk changes may be completed without a PR when explicitly appropriate.

## Implementation principles

- Prefer Apple-standard SwiftUI components, navigation, controls, and interaction patterns.
- Keep the implementation appropriate for a small MVP.
- Prefer simple, readable code over speculative abstractions.
- Do not introduce architectural layers, protocols, wrappers, or dependencies without a concrete benefit.
- Avoid third-party dependencies unless there is a clear need.
- Keep product rules and calculations testable.

## Code quality

- Use `swift-format` to keep Swift code consistently formatted.
- Use SwiftLint for lightweight static analysis.
- Both tools are available as command-line tools in the development environment.
- Prefer the existing/default configuration and keep custom rules minimal unless there is a concrete reason to add them.
- Do not suppress lint violations merely to make checks pass unless the rule is genuinely inappropriate for the code.
- Before considering implementation complete, ensure formatting and lint checks pass.

## Validation

- Build the application after meaningful implementation changes.
- Add automated tests where they provide clear value, especially for calculation and state-transition rules.
- Before considering implementation complete, verify:
  - `swift-format` passes;
  - SwiftLint passes;
  - the application builds successfully;
  - relevant automated tests pass;
  - the key product flows work as intended.

Key product flows include:

- add an item;
- view its replacement progress and costs;
- edit an item;
- mark an item as replacement completed;
- view completed items in history;
- delete active or historical records where allowed.

## UI validation

- Do not consider UI changes validated by build and tests alone.
- For UI changes, run the app and verify the affected screens and interactions when the available environment allows it.
- Validate the states relevant to the change, including navigation, sheets, scrolling, input, and empty or error states where applicable.
- Check for obvious layout, readability, and interaction issues.
- Choose an appropriate validation method for the change, such as Simulator interaction, UI tests, or other available tools.
- When a UI change has meaningful visual or interaction impact, include useful UI evidence in the PR.
- UI evidence may include screenshots of relevant states, multiple screenshots when state differences matter, or a screen recording when motion or interaction is important.
- Record the environment and validation method briefly in the PR `Validation` section.

## Documentation

- Do not create additional Markdown files merely for planning, implementation summaries, or AI handoff.
- Prefer updating an existing source of truth when long-lived documentation needs to change.
- Create a new long-lived document only when the information cannot be represented appropriately in the existing documentation.

## Product escalation

Do not guess when implementation requires a new product decision.

Raise the issue when:

- the agreed MVP scope would need to change;
- a new UX or product rule is required;
- `docs/product.md` is ambiguous or internally conflicting;
- implementation would materially change the meaning of an existing product rule.

Implementation details that do not change product behavior should be decided autonomously.