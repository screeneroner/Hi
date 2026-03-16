# Quick summary
Summarize the text in 3 bullets.

Constraints:
- No more than 12 words per bullet.
- Keep the original meaning.
- If dates/numbers exist, preserve them.

# Writing
## Rewrite
### Friendly
Rewrite the text in a friendly tone.

Rules:
- Keep it clear and short.
- Avoid jargon.
- Preserve any proper names and code terms.

### Formal
Rewrite the text in a formal tone suitable for a report.

## Insert disclaimer
Add this disclaimer at the end (keep it on separate lines):

- This is informational and may be incomplete.
- Verify against your source of truth.

## Translate
### EN → RU
Translate to Russian.

Keep formatting:
- Preserve lists and indentation.
- Keep code blocks unchanged.

### RU → EN
Translate to English.

# Engineering
## Bug report
### Short
Summarize:
- Repro steps
- Expected vs actual
- Environment (OS/app version)
- Any logs or errors

### Detailed
Write a full bug report with:
- Repro steps
- Expected vs actual
- Suspected root cause(s)
- Debugging plan (what to check next)
- Proposed fix (if clear)

## Code review
### Quick
Review the code and list issues in bullets.

### Deep
Review for correctness, security, and edge cases.
Provide:
- High risk issues
- Medium risk issues
- Low risk issues
- Suggested refactors

# Rules (how menus are built)
Any number of heading levels is allowed.
A heading becomes a submenu only if the next non-empty line is a heading with exactly one more #.
Otherwise it becomes a clickable item and its text (multi-line supported) is inserted until the next heading.

Preview:
- Hover a clickable prompt item to see a tooltip preview (after a short delay).
