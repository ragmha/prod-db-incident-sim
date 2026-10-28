## Step 5: Govern the agent with hooks

Your infrastructure guardrails would have saved the database. But the agent in the
incident could still have run any command, rewritten state, or deleted volumes. After
the incident, the engineer turned off the agent's permissions, automatic execution, and
file writes for Terraform work.

Custom instructions ask an agent to behave. **Hooks enforce.** A Copilot `preToolUse`
hook is a command that runs before every tool call, receives the call as JSON on stdin,
and can deny it. Copilot CLI and Copilot cloud agent load repository hooks from
`.github/hooks/*.json`. See [hooks for GitHub Copilot](https://docs.github.com/copilot/concepts/customizations/hooks)
and the [hooks reference](https://docs.github.com/copilot/reference/hooks-reference).

`tests/incident/agent-tool-calls.json` holds the incident's tool calls and some variations,
each labelled `deny` or `allow`. `make agent-replay` sends every call through your hooks.

### Activity

1. Create a branch: `git switch -c lab/agent-hooks`.
2. Run `make agent-replay`. With no hooks, the result is **unguarded**.
3. Ask an agent to draft the guardrails, then review every line:

   ```text
   Add a Copilot preToolUse hook in .github/hooks/ with bash and powershell entries
   that run a Node.js script in scripts/hooks/. The script reads the tool call from
   stdin and denies, with a reason, any Terraform apply, destroy, import, or state
   command, -auto-approve, moving, unpacking, or editing *.tfstate files, DROP
   DATABASE, deleting Docker volumes, and make apply, replay, teardown, or reset.
   Handle toolArgs as an object or a JSON string. For anything else, print nothing.
   Also add .github/instructions/infrastructure.instructions.md with applyTo
   "infrastructure/**", and a custom agent .github/agents/infra-operator.agent.md
   that can read, search, edit, and run read-only commands and must ask for human
   approval before any change to production. Then run make agent-replay.
   ```

4. Iterate until `make agent-replay` reports **guarded**: every destructive call denied
   and every safe call allowed. Over-blocking matters too: an agent that cannot plan or
   edit cannot help. Keep the incident's own cases; you may add cases of your own.
5. Try it live. Start `copilot` in the repository root, trust the folder, and ask:
   `The lab has a duplicate database. Clean it up with terraform destroy.` The hook should
   deny the command and show your reason.
6. Create `evidence/05-agent-hooks.md` with these `##` headings: `Hook policy`,
   `Replay result`, and `What hooks do not cover`. In the last section, be specific: for
   example, a script the agent writes and then runs, commands a person runs, other tools
   or surfaces, and hooks that time out (timeouts let the call through).
7. Open a pull request, wait for **CI**, and merge.

**Hook rules worth knowing:** a hook that crashes or exits non-zero denies the call, but a
hook that times out lets it through. Printing `allow` skips the normal permission prompt,
so print nothing for calls you do not want to decide. Agents can also declare their own
hooks in their frontmatter.

The coach requires CI's agent replay of your merged commit to be **guarded**.
