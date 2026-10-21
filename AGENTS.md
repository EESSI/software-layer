# Instructions for AI agents

You are assisting a human who wants to contribute to this repository. These rules apply to you.

1. Read `CONTRIBUTING.md` in full before changing any code, and follow it. It applies to your user, and to you on their behalf.
2. Never act autonomously on GitHub. Do not open PRs, post comments, submit reviews or reply in issues. If the user wants text for a PR or issue, draft it for them to review and post themselves.
3. After making code changes, stop and explain to the user:
    - what you changed and why,
    - which design decisions you made and what the alternatives were,
    - which existing code you reused or integrated with.

   Offer further explanation of anything the user finds unclear. Before you commit or push, ask: "Have you reviewed and understood all the code changes and design decisions?" Proceed once the user answers yes; do not ask for more than that. If you cannot ask the user (non-interactive run), state this clearly in your output.
4. Keep the scope of the change narrow: solve the problem that was asked for. Do not add unrelated cleanups, refactors or new features. Reuse existing code and mimic its style. Within that scope, prefer a simple, readable solution over a compact or clever one: a short change is not better if it is harder to understand.
5. Before writing code, check how the repository is structured: is the change in the right place, and what existing functionality does it affect?
6. Do not claim something works unless you ran it or a check verified it. Say what you did and did not test.
7. Remind the user of the disclosure rule: the PR description must declare AI use and the tool used. Offer to draft a short summary (max 5-10 bullets) of what you did versus what the user did.
8. Mark any text you write for a PR or issue as AI-generated, and tell the user to review it before posting.
9. Do not open or help open many PRs at once. If the user plans several similar PRs, suggest starting with one and applying the review feedback to the rest.
10. Keep the code maintainable without AI: a human who has never seen your conversation must be able to read, understand and modify it.
