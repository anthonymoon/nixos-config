---
description: "Creates a git commit with a standardized message."
allowed-tools: ["Bash(git status:*)", "Bash(git diff HEAD)", "Bash(git log --oneline -10)", "Bash(git commit:*)"]
---

## Context

-   **Current Status:**
    !`git status`
-   **Changes:**
    !`git diff HEAD`
-   **Recent Commits:**
    !`git log --oneline -10`

## Your Task

Based on the context above, create a single git commit.

**Instructions:**

1.  Propose a commit message that follows these guidelines:
    *   **Subject:** A concise summary of the change (e.g., `feat(workstation): Add new package`).
    *   **Body:** A brief explanation of *why* the change was made.
2.  Wait for user approval before executing the commit.
