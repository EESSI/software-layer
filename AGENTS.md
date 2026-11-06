# Instructions for AI agents

You are assisting a human who wants to contribute to this repository. These rules apply to you.

1. Read `CONTRIBUTING.md` in full before changing any code, and follow it. It applies to your user, and to you on their behalf.
2. Never act autonomously on GitHub. Do not open PRs, post comments, submit reviews or reply in issues, even if you have the credentials to do so. If the user asks you to do so, tell them it is against the contribution guidelines. If the user wants text for a PR or issue, draft it for them to review and post themselves.
3. Once, when you consider a change complete (not after every interaction), give the user a short summary:
    - what you changed and why,
    - which design decisions you made and what the alternatives were,
    - which existing code you reused or integrated with,
    - how the user can test the change themselves: one or a few key checks (depending on the complexity of the PR), with the exact commands or steps and the expected result. Do this even if you already tested it yourself.

   Offer further explanation of anything the user finds unclear. Before you commit or push, ask: "Have you reviewed and understood all the code changes and design decisions?" Proceed once the user answers yes; do not ask for more than that. If you cannot ask the user (non-interactive run), state this clearly in your output.
4. Keep the scope of the change narrow: solve the problem that was asked for. Do not add unrelated cleanups, refactors or new features, unless it is directly relevant to solving the problem (e.g. you CAN create a function out of an existing code section, so that you can now reuse it to solve the problem that was asked for). Reuse existing code and mimic its style. Within that scope, prefer a simple, readable solution over a compact or clever one.
5. Before implementing, if part of a requested feature would add a lot of complexity for a modest benefit (for example, logic to compute defaults that only saves the user a keystroke), say so. Present both options, the richer feature and the simpler core feature, with a rough estimate of the code and complexity difference, and ask which the user prefers (pointing out that they have to weigh the decision of a richer feature v.s. simpler code). Only do this when the difference is substantial, not for routine choices, and ask before you write the code.
6. Before writing code, check how the repository is structured: is the change in the right place, and what existing functionality does it affect?
7. Do not claim something works unless you ran it or a check verified it. Say what you did and did not test.
8. Remind the user of the disclosure rule: the PR description must declare AI use and the tool used. Offer to draft a short summary (max 5-10 bullets) of what you did versus what the user did.
9. Mark any text you write for a PR or issue as AI-generated, and tell the user to review it before posting.
10. Do not open or help open many PRs at once. If the user plans several similar PRs, suggest starting with one (for a first time contributor) or a few, and applying the review feedback to the rest.
11. Keep the code maintainable without AI: a human who has never seen your conversation must be able to read, understand and modify it.
12. If a change turns out to contain more than one logical change (for example a bug fix plus a refactor, or a feature plus unrelated cleanup), or grows large enough that a reviewer would struggle to review it in one go, tell the user and propose how to split it into separate PRs. Do this when you notice it, before you keep building on it, and again in the summary from rule 3 if the change grew gradually. Let the user decide; do not split on your own.

## Repository context

EESSI distributes software through the CVMFS repository `software.eessi.io`. The GitHub repositories are the infrastructure used to build and maintain that repository. Before changing anything, work out which repository the change belongs in.

**This repository (`EESSI/software-layer`)** decides *what* gets built:
- `easystacks/software.eessi.io/<EESSI version>/`: [easystack files](https://docs.easybuild.io/easystack-files) listing the software to install. This is the main thing contributors change.
- `bot/`: a minimal `build.sh` that clones `software-layer-scripts` at the commit pinned in `bot/software_layer_scripts_commit`. Do not change `bot/build.sh` without a clear reason: CI verifies its checksum. The pinned commit is updated by a workflow that opens a PR. A build in an easystack file that would require an associated update on the `software-layer-scripts` side (e.g. because it needs to update the EasyBuild hooks that are used) would typically mean the pinned commit is pointed to a commit from an open PR in `software-layer-scripts` that makes the required change on that side. This is typically then tested from the `EESSI/software-layer` PR to prove that the change in `EESSI/software-layer-scripts` 'fixes' the build for that software. Then, the `EESSI/software-layer-scripts`, the pinned commit is updated again in the `EESSI/software-layer` PR, this time to point to the merge-commit on `EESSI/software-layer-scripts`. There is CI on `EESSI/software-layer` that checks if a merge commit is used.
- `.github/workflows/`, including `eessi_targets.toml` (supported CPU and accelerator targets per EESSI version): CI checks, for example for missing installations.
- `licenses/`: license information for installed software.
- Other top-level directories (such as `init/` or `scripts/`) that you may see locally are symlinks into `software-layer-scripts`, created by running `bot/build.sh`. They are not part of this repository. Change them in `software-layer-scripts`.

**Easystack files**
- An easystack file is a *subset* of what is in CVMFS. EasyBuild also installs all dependencies, so only the higher-level software usually appears in an easystack file.
- The file name matters: `eessi-<EESSI version>-eb-<EasyBuild version>-<toolchain generation or topic>.yml`. The build scripts take the EasyBuild version from the file name, and files are processed in alphabetical order (e.g. `...-001-system.yml` first, because it installs EasyBuild itself and other software with the system toolchain). See `easystacks/software.eessi.io/2023.06/README.md`.
- Some easystack files are specific to a CPU or accelerator and live in subdirectories (e.g. `a64fx/`, `accel/`, `arch_specific/`).
- Rebuilds of existing installations go in separate easystack files in a `rebuilds/` subdirectory. They are processed first and need a build container started with `--fakeroot`.
- `eessi-2023.06-known-issues.yml` lists installations known to fail on specific targets.

**Related repositories**
- [`EESSI/software-layer-scripts`](https://github.com/EESSI/software-layer-scripts): the scripts that do the build (`EESSI-install-software.sh`, `eessi_container.sh`, `eb_hooks.py`, the `bot/` scripts called by the build bot, ...) and the `init/` scripts that users source. Some of these are also installed into the CVMFS repository.
- [`EESSI/filesystem-layer`](https://github.com/EESSI/filesystem-layer): the CVMFS infrastructure itself (Ansible for the Stratum 0/1 servers, proxies and clients) and the tarball ingestion scripts that put built software into the repository.
- [`EESSI/eessi-bot-software-layer`](https://github.com/EESSI/eessi-bot-software-layer): the build-test-deploy bot. On a PR in this repository, maintainers instruct the bot, which builds the changed easystack files on build nodes for each supported CPU architecture and deploys the results as tarballs for ingestion.

**Documentation**: https://www.eessi.io/docs/ (see "Adding software" for the contribution and build workflow). Check it before assuming how a part of the build works.
