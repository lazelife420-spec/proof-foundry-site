# Reality Gate — Messaging Starter (Recruit, Don't Launch)

**Week of 2026-08-19.** Goal: recruit 3 testers privately. No public launch posts.
The ask everywhere is the same: *"Can you cold-test this for 10–15 minutes and tell me where it fails?"*

Pilot page: <https://theprooffoundry.com/reality-gate/>
Pilot download: <https://pub-0273ac689b544b959a93bbe5d953d71e.r2.dev/reality-gate/Reality-Gate-1.1.0-Developer-Pilot.zip>
ZIP SHA-256: `58CC27D22BDEE8157EE4598E116E17FF42D0EFC95630C97BEE4B2BC6BE6CE756`

> Keep every first message under ~90 words. The long 30–45 min checklist belongs only AFTER someone says yes.

---

## 1. Direct DM (Discord / Slack / LinkedIn) — first contact

> Hey [Name], I’m looking for a few developers to cold-test Reality Gate, a Windows app that adds local continuity and proof around the Git workflow you already use. It works alongside GitHub, GitLab, or Forgejo — it doesn’t replace them or need a cloud account.
>
> Would you spend 10–15 minutes trying it on one real repo and tell me where the explanation or workflow fails? No testimonial needed, and no source code, secrets, or telemetry shared.
>
> Pilot page: https://theprooffoundry.com/reality-gate/

## 2. Discord / Slack dev community — channel post

> Recruiting 3–5 developers for a small Reality Gate pilot. It’s a Windows app for seeing provider dependencies and preserving local continuity/proof around an existing Git repository.
>
> I want blunt usability feedback, not promotion. The test takes ~10–15 minutes. If interested, reply here or DM me: https://theprooffoundry.com/reality-gate/

## 3. LinkedIn DM — first contact (slightly more formal)

> Hi [Name], I’m recruiting a handful of developers to cold-test a Windows tool I built called Reality Gate — a local-first continuity layer for existing Git workflows (GitHub/GitLab/Forgejo). No cloud account, no replacement of your host.
>
> Would you be open to a 10–15 minute cold test on one of your own repos? I’m looking for where the onboarding or explanation fails, not a positive review. Pilot page: https://theprooffoundry.com/reality-gate/

## 4. When they say yes — send the short checklist

> Thanks. Quick specs first: it needs **Windows 10 or 11, 64-bit**, and the download is **~113 MB** (so grab it on a decent connection).
>
> Please use one real, non-sensitive Git repository if you can, or the included disposable demo repo. I’m mainly watching whether you can:
>
> 1. Install it without my help (note any SmartScreen/trust friction).
> 2. Launch it and explain in your own words what you think it does.
> 3. Add a repository.
> 4. Look at the Dependency, Continuity, and Proof views.
> 5. Quit and reopen it without help.
>
> Please don’t send source code, secrets, or private logs. Screenshots are optional and should be redacted. Just tell me where you got stuck, what you expected, or what didn’t make sense.

## 5. Follow-up once (after 3–4 days, only if no reply)

> Quick follow-up in case this got buried — I’m still looking for one or two developers to try Reality Gate for 10–15 minutes. The most useful feedback is simply: “I got stuck here,” “I expected this,” or “I don’t understand why I need this.” Pilot page: https://theprooffoundry.com/reality-gate/

> Stop after one follow-up. Do not chase.

---

## 6. Recruit tracker

Keep this to 5 starters. Aim for people who: use Git regularly, work on Windows, rely on GitHub/GitLab/Forgejo, give blunt feedback, and are NOT close friends who will only be encouraging.

| # | Name / handle | Channel | Why a fit | Date sent | Status | Replied | Tested | Feedback summary | Next step |
|---|---|---|---|---|---|---|---|---|---|
| 1 |  |  |  |  |  |  |  |  |  |
| 2 |  |  |  |  |  |  |  |  |  |
| 3 |  |  |  |  |  |  |  |  |  |
| 4 |  |  |  |  |  |  |  |  |  |
| 5 |  |  |  |  |  |  |  |  |  |

**Status values:** Not sent / Sent / Replied / Declined / Testing / Done / Ghosted
**Stop recruiting at 3 testers.** Do not broaden to public surfaces until 3 have actually tested.

---

## 7. GitHub Discussions — “Pilot feedback” template (paste into your repo)

> Enable Discussions on the Reality Gate repo, then create a Discussion category called **Pilot feedback** and add this as an issue/Discussion template.

**Title:** Pilot feedback — Reality Gate Developer Pilot v1.1.0

**Body:**

```markdown
Thanks for testing Reality Gate. You don’t need to write polished feedback — short and blunt is ideal.

Please answer only what’s easy:

1. What did you think Reality Gate was *before* installing it?
2. Did installation work without help? Any SmartScreen / trust friction?
3. Could you add a repository? (real repo, or the included demo repo)
4. Did the Dependency / Continuity / Proof views make sense?
5. What was the most confusing part?
6. Did anything fail, crash, or look misleading?
7. Did you leave it installed? Did you reopen it without being asked?
8. Which setup did you use: GitHub, GitLab, Forgejo, self-hosted, or other?

**Please do not paste source code, secrets, tokens, or private logs.** Screenshots are optional — redact first.

Pilot page: https://theprooffoundry.com/reality-gate/
```

---

## 8. This week’s rule

Do not launch. Recruit.
Send message #1 to five people today. Send message #4 only to those who reply yes.
Log every contact in the tracker. Stop at 3 testers, then review feedback before any broader posting.
