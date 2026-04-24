# Editing an existing jig command

The conventions above still apply. You are **modifying** an existing function — not creating a new one.

## You will receive

1. The current source of the function (from its `.bash` file).
2. A description of the requested change.

## What to return

Respond with **exactly one** fenced ```bash code block containing the **complete updated function** — opening `name() {` through closing `}`.

- Keep the function name exactly the same unless explicitly asked to rename.
- Include the entire function body, not just the edited portion.
- Do **not** include any file-scope lines outside the function (no `_complete_*`, no `_require_module`). Those are not part of the edit and will be left untouched.
- No prose, no explanation, no tool use.
