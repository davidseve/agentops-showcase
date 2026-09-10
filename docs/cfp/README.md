# Call for Papers (CfP) kit

Reusable content for conference and internal talk proposals about the AgentOps showcase. Start from a saved submission, swap event-specific fields, and pull snippets from shared blocks.

## Workflow

1. **Pick a base** — [`submissions/enterprise-agentops-rhoai.md`](submissions/enterprise-agentops-rhoai.md) is the canonical AgentOps + RHOAI proposal.
2. **Copy the template** — [`template.md`](template.md) for a new event or angle (hands-on lab, shorter lightning, Spanish abstract, etc.).
3. **Reuse blocks** — [`reusable-blocks.md`](reusable-blocks.md) holds key message, stack bullets, demo scenarios, links, and TDP mappings without duplicating full proposals.
4. **Align with live assets** — keep abstract/comments in sync with [`demo-script.md`](../demo-script.md), [`demo/README.md`](../demo/README.md), and repo [`README.md`](../../README.md).

When a proposal is accepted or rejected, add a one-line status note at the top of the submission file (`Status: submitted | accepted | rejected | delivered`).

## Directory

```
docs/cfp/
├── README.md                 # This guide
├── template.md               # Blank CfP form (Red Hat TLDR-style fields)
├── reusable-blocks.md        # Copy-paste snippets
└── submissions/
    └── enterprise-agentops-rhoai.md   # Base proposal (saved 2026-03)
```

## Related source material

| Asset | Use in CfP |
|-------|------------|
| [README.md](../../README.md) | Elevator pitch, architecture GIF, platform stack table |
| [stack-decisions.md](../stack-decisions.md) | TDP / product alignment narrative |
| [AGENT-SANDBOX-AND-OPENSHELL.md](../AGENT-SANDBOX-AND-OPENSHELL.md) | Sandbox, Landlock, OpenShell deep dive |
| [demo-script.md](../demo-script.md) | Timed live demo flow (~9–10 min core; scale to 50 min with Q&A) |
| [demo-narrative-v1.md](../demo-narrative-v1.md) | Spanish presenter narrative |
| [demo/v5/live.html](../demo/v5/live.html) | Presenter companion URL for comments field |
| [ADR index](../adr/README.md) | Technical credibility (MLflow tracing, guardrails, pinning) |

## Format cheat sheet (Red Hat TLDR)

| Slot | Session | Break | Typical use |
|------|---------|-------|-------------|
| 10 min | 9 min | 1 min | Lightning (often ×3 in a block) |
| 30 min | 25 min | 5 min | Short demo or talk |
| 60 min | 50 min | 10 min | Full demo + discussion (**default for this project**) |
| 120 min | 110 min | 10 min | Hands-on lab |
| 240 min | 240 min | embedded | Workshop / hackathon |

Virtual delivery: standard Google Meet or similar (noted in TLDR CfP forms).

## Speakers (default)

| Name | Email |
|------|-------|
| David Severia | dseveria@redhat.com |
| Carlos Cornejo | ccornejo@redhat.com |

Update per event if the panel changes.
