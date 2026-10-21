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
