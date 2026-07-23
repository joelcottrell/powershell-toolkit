# Development Workflow

How scripts get from "developed with Claude" to "published in this repository", and how to
work across more than one machine without fighting sync.

---

## The one rule that makes everything else simple

**GitHub is the single source of truth, and git is the sync layer.**

You do not build a separate sync between machines. Each machine (or cloud environment)
clones the repo; `git pull` before you work, `git push` after. That is the entire sync story.

> **Never put this repo inside OneDrive, Dropbox, or any file-sync folder.** They corrupt
> `.git` internals and this reorg touched nearly every path in the tree. Clone to a plain
> local folder such as `C:\Repos\powershell-toolkit`. Sync through git, which is what git is
> for.

Because the Claude workflow itself lives in the repo ([`CLAUDE.md`](../CLAUDE.md) and the
[`publish-to-toolkit`](../.claude/skills/publish-to-toolkit/SKILL.md) skill), cloning the
repo anywhere brings the conventions and the publish process with it. There is no per-machine
Claude configuration to replicate.

---

## The publish loop

1. Develop a script with Claude.
2. When it is finished, Claude offers to publish it here (see `CLAUDE.md`).
3. On yes, Claude runs the `publish-to-toolkit` skill: correct domain, `Verb-Noun` name, the
   mandatory ASCII header, a README and CHANGELOG from `_Template/`, the parent category
   README updated, verification, and a pull request on a feature branch.
4. Review the PR and merge. It is now on GitHub; every other machine gets it on the next pull.

You can also trigger it yourself at any time with `/publish-to-toolkit`.

---

## Working across two (or more) machines

### Recommended: Claude Code on the web (claude.ai/code)

Best fit when you want it to "just work everywhere" with no per-machine setup.

- **One-time:** open [claude.ai/code](https://claude.ai/code) and connect it to this
  repository. It clones into a cloud environment.
- **Every session, from any machine:** open a browser, and you are working against the same
  cloud repo. Git handles the code; your conversations are tied to your account, so switching
  machines mid-task means opening the browser on the other one and carrying on.
- **Nothing to install or sync per machine.**

This is Claude Code in the cloud, not the regular chat interface - the difference is that it
can run `git` and `gh` and therefore actually publish.

### Alternative: Claude Desktop (or CLI) on each machine

Viable, with more setup and no cross-machine conversation continuity.

- **Each machine, once:**
  - Install the Claude Desktop app (or the CLI).
  - `git clone https://github.com/joelcottrell/powershell-toolkit.git` into a non-OneDrive
    folder.
  - Authenticate the GitHub CLI (`gh auth login`).
  - On Windows, put the GitHub CLI on PATH so `gh` resolves without a full path:
    `setx PATH "%PATH%;C:\Program Files\GitHub CLI"` then restart the shell.
- **The Claude behaviour replicates automatically** through git - `CLAUDE.md` and the skill
  arrive with the clone, so both machines behave identically with no extra configuration.
- **Your discipline:** `git pull` before you start, `git push` before you walk away.

---

## Handing off mid-script

Git syncs committed code, not an uncommitted buffer. To resume an in-progress script on
another machine, commit it to a work-in-progress branch and push before you leave:

```
git checkout -b wip/<thing>
git add -A && git commit -m "wip"
git push -u origin wip/<thing>
```

Then on the other machine:

```
git fetch && git checkout wip/<thing>
```

Finish it, fold it into the normal publish loop, and delete the WIP branch. (claude.ai/code
softens this: its cloud working copy persists between browser sessions.)

---

## Where things live

| Item | Location | Syncs via |
| --- | --- | --- |
| Scripts and docs | this repo | git |
| Publish workflow and conventions | [`CLAUDE.md`](../CLAUDE.md), [`.claude/skills/`](../.claude/skills/publish-to-toolkit/SKILL.md), [`docs/`](./) | git (travels with the repo) |
| Personal Claude permissions | `.claude/settings.local.json` | not synced - gitignored, per machine |

---

[Back to repository root](../README.md)
