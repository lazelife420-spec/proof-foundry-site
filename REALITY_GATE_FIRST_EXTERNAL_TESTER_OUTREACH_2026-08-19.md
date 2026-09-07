# Reality Gate — First External Tester Outreach Pack

**Status:** Externally pilot-ready; no external pilot user yet.  
**Immediate goal:** Find one developer willing to try the current pilot cold.

> **Do not send section 1 as a first contact.** It asks for 30–45 minutes, which
> is too large an ask for someone who has not agreed yet. Use the short
> first-contact messages in `REALITY_GATE_MESSAGING_STARTER_2026-08-19.md`
> (10–15 minute ask), and send the detail below only after someone says yes.
> Sections 2–8 remain the canonical observation, feedback, and triage record.

## 1. Copy-paste recruitment message

Hi — I’m looking for one developer to try a small Windows pilot called Reality Gate.

Reality Gate is a local-first continuity layer for the Git workflow you already use. It works alongside GitHub, GitLab, Forgejo, or ordinary Git. It does not replace your Git host, migrate your repository, or require a cloud account.

I’m not asking for a testimonial. I want to see whether the product makes sense without me explaining it.

The test should take about 30–45 minutes:

1. Download and install it without my help.
2. Add one of your own Git repositories, or use the included disposable demo repository.
3. Look at the dependency, Continuity, and Proof views.
4. Quit and reopen the app.
5. Tell me what was confusing, broken, misleading, or unexpectedly useful.

Please do not send source code, passwords, tokens, private keys, or credential-bearing remote URLs. Screenshots and logs are optional, and should be redacted first.

Pilot download:

<https://pub-0273ac689b544b959a93bbe5d953d71e.r2.dev/reality-gate/Reality-Gate-1.1.0-Developer-Pilot.zip>

ZIP SHA-256:

```text
58CC27D22BDEE8157EE4598E116E17FF42D0EFC95630C97BEE4B2BC6BE6CE756
```

Checksum file:

<https://pub-0273ac689b544b959a93bbe5d953d71e.r2.dev/reality-gate/Reality-Gate-1.1.0-Developer-Pilot.zip.sha256.txt>

If you are willing, please reply with:

> I can try the Reality Gate pilot.

I’ll send the same short test checklist and answer only setup questions. I will not guide the product flow unless you are blocked.

## 2. What the tester is being asked to do

### Before launch

- Download the ZIP.
- Optionally verify the ZIP SHA-256.
- Extract the entire ZIP.
- Note any SmartScreen or installation-confidence problem.

### First-use flow

- Install without founder assistance.
- Launch Reality Gate.
- Explain in your own words what you think it does.
- Add one real Git repository, if comfortable.
- Otherwise use the included disposable demo repository.
- Inspect:
  - provider/dependency information;
  - Continuity;
  - Proof;
  - recovery information, if discoverable.

### Return-use signal

- Quit the app.
- Reopen it without assistance.
- Decide whether you would leave it installed.
- Say whether you would open it again without being asked.

The strongest signal is voluntary return use, not politeness or a positive first reaction.

## 3. Feedback request

Please answer briefly:

1. What did you think Reality Gate was before installing it?
2. Did installation work without help?
3. What happened when SmartScreen or Windows asked for confidence?
4. Could you add a repository?
5. Did you understand the provider/dependency information?
6. Did Continuity make sense?
7. Did Proof make sense?
8. What was the most confusing part?
9. Did anything fail, crash, or look misleading?
10. Did you leave it installed?
11. Did you reopen it without being asked?
12. What would make it useful enough to keep using?
13. Which setup did you use: GitHub, GitLab, Forgejo, self-hosted, or other?

## 4. What I am asking from the tester

- Try it cold before receiving explanations.
- Use a real repository only if comfortable.
- Report confusion and failure plainly.
- Separate “I dislike this” from “I could not complete the task.”
- Do not spend time writing polished feedback.
- Do not share secrets or private repository content.

## 5. What I am not asking for

- No public review.
- No endorsement.
- No source-code upload.
- No telemetry enrollment.
- No account creation.
- No provider credentials.
- No destructive repository actions.
- No commitment to continue using the product.

## 6. Tester observation record

| Field | Result |
|---|---|
| Tester identifier | |
| Acquisition source | |
| Date/time | |
| Installation completed without help | YES / NO |
| SmartScreen or trust friction | |
| First launch completed | YES / NO |
| Initial explanation in tester’s words | |
| Repository added | YES / NO / demo only |
| Time to first repository | |
| Dependency comprehension | CLEAR / PARTIAL / UNCLEAR |
| Continuity comprehension | CLEAR / PARTIAL / UNCLEAR |
| Proof comprehension | CLEAR / PARTIAL / UNCLEAR |
| Errors/crashes | |
| Misleading terminology | |
| Unexpected network/privacy concern | |
| Core workflow completed | YES / NO |
| Left installed | YES / NO |
| Reopened without prompting | YES / NO |
| Real continuity problem identified | |
| Exact quotes | |
| Reproducible evidence supplied | |

## 7. Triage rule

Do not change Reality Gate because of a single preference alone.

Classify findings:

- **P0:** destructive behavior, data loss, credential/security exposure;
- **P1:** blocks install, launch, repository registration, or core workflow;
- **P2:** repeated comprehension or usefulness failure;
- **P3:** polish or edge case;
- **IDEA:** speculative request without evidence.

The first tester’s job is to expose reality, not to authorize a redesign.

## 8. Current pilot receipt

- Product: Reality Gate Developer Pilot v1.1.0
- Platform: Windows 10/11 x64
- Source checkpoint: `7a3e47136341951dcb8365db8c40da8553edd6c5`
- Installer SHA-256: `0B13FD5DA6FA2855B02CC1363068CBE8B684B58B7208291A542968162627387B`
- Current ZIP SHA-256: `58CC27D22BDEE8157EE4598E116E17FF42D0EFC95630C97BEE4B2BC6BE6CE756`
- Public page: <https://theprooffoundry.com/reality-gate/>

## 9. Next action

Send the copy-paste message to one developer who did not build Reality Gate. Do not pre-explain the workflow. Observe where they stop, hesitate, ask questions, or return voluntarily.
