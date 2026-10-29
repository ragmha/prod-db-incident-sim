# A review workflow that reads context without taking over

Step 6 adds a bounded agentic review of the learner's guardrails. It follows the pattern
of [skills/agentic-workflows-that-read-the-room](https://github.com/skills/agentic-workflows-that-read-the-room):
a narrow agent interprets repository context and offers feedback. It does not replace
deterministic CI or a human decision.

The source is `.github/workflows/guardrail-review.md`. The template ships only that
source: in Step 6 you compile it into `.github/workflows/guardrail-review.lock.yml`, which
GitHub runs, and commit both. The compiler also updates `.github/aw/actions-lock.json`;
commit it if it changes.

## Author and compile

The pinned authoring version is **gh-aw v0.86.2**:

```bash
gh extension install github/gh-aw --pin v0.86.2
gh aw --version
npm run compile:review
```

The Codespace installs it when it is missing. A successful compilation validates the
configuration; it does not call a model or prove that the review is good. The npm command
pins the `github/gh-aw-actions` runtime to the v0.86.2 release commit and refuses any other
compiler version.

CI downloads the official `linux-amd64` v0.86.2 binary, checks its SHA-256, and compiles
the source on every run. Once you commit a lock, CI also compares it with the fresh
compilation. Differences in executable YAML, permissions, source hashes, or pinned
dependencies fail; comment formatting that differs between platforms does not.

## Running the review live is optional

For a personal repository, follow the
[v0.86.2 authentication documentation](https://github.com/github/gh-aw/blob/v0.86.2/docs/src/content/docs/reference/auth.mdx)
to create a fine-grained token with the **Copilot Requests** permission, and store it as the
Actions secret `COPILOT_GITHUB_TOKEN`. Never commit the token or paste it into a report.
Check that your Copilot plan and policies allow the usage.

Then dispatch **Guardrail review** from Actions on the default branch. Nothing triggers it
automatically. It reads only this repository through read-only tools and can open at most
one issue through a safe output. Checkout, shell, and edit tools are disabled, and it runs
for at most ten turns and fifteen minutes. It cannot write code, merge, approve, or release.

If you don't run it live, label your report **manual review; no live agent run**.
Compilation and your own analysis complete the checkpoint.

## Security boundaries

- GitHub tools are read-only; only the safe-output job can create the single issue.
- Repository content is treated as data, never as instructions.
- The workflow uses no lab, cloud, or deployment credentials.
- Prompt text is not a security boundary: the frontmatter permissions and safe outputs are.

Source: [GitHub Agentic Workflows](https://github.github.com/gh-aw/).
