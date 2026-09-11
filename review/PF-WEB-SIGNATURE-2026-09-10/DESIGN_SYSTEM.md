# Signature Homepage Design System

## Composition

- Shared content boundary: the existing storefront shell, capped by the signature homepage at approximately `1320px`.
- Opening composition: `0.82fr / 1.18fr` copy-to-stage on wide desktop; stacked copy → action → stage on phone.
- Stage: fixed outer geometry with the real screenshot fitted inside. Product switching changes the inner image and context, not the action target or surrounding page structure.
- Foundry identity: approved `brand/proof-foundry-logo-horizontal.svg` in the hero; the compact mark remains in navigation and utility surfaces.
- Featured hierarchy: Reality Gate keeps a full-width editorial module; regular products remain generated from the canonical manifest.

## Signature tokens

The homepage-specific tokens live in `signature.css`:

| Token | Value | Use |
|---|---|---|
| `--pf-ink` | `#0d1115` | Deep page field |
| `--pf-panel` | `#151b20` | Shared dark surface |
| `--pf-panel-raised` | `#1b2429` | Raised stage surface |
| `--pf-warm` | `#f2eee4` | Primary warm text |
| `--pf-muted` | `#aab2b3` | Supporting text |
| `--pf-dim` | `#758083` | Quiet metadata |
| `--pf-brass` | `#d6a84f` | Foundry index/accent |
| `--pf-brass-light` | `#efc978` | Primary action and active state |
| `--pf-line` | `#313a3d` | Structural rule |
| `--pf-teal` | `#85c8bb` | Public availability cue |

Existing shared tokens and product-specific art direction remain in `studio.css` and `experience.css`.

## Components

- `home-brand-lockup`: approved studio identity plus the independent-studio kicker.
- `product-theater`: real product stage, contextual copy, product index, stateful selector, and film link.
- `home-reassurance`: compact ownership/release-record reassurance, not a badge wall.
- `studio-featured`: featured Reality Gate editorial module.
- Generated `product-card`: canonical product identity, media, availability, public version, candidate detail, route, and comparison control.
- `studio-proof-standard`: evidence explanation kept secondary to software discovery.
- `studio-identity` and `founders-signpost`: lower-page accountability and commercial preview signposts.

## Product accents

The shared frame stays charcoal/warm neutral. Product accents remain concentrated in the actual product media and existing product-card classes:

- Reality Gate: teal control-room treatment.
- Cache Vault: archive green.
- Lights Out: night blue.
- Cleanroom: daylight green/neutral.
- GhostLayer: layered violet/green.
- ForgeCast: atmospheric blue.
- ProofShot: slate/coral capture framing.

## Motion and reduced motion

- Existing stage and control transitions remain short and state-based.
- No autoplay, cursor-following spotlight, continuous hero rotation, or background video was added.
- The existing `prefers-reduced-motion` and local motion toggle remain authoritative.
- The stage loader now waits on a real image load event and keeps the existing screen on failure.

## Responsive behavior

- At phone widths, the hero changes composition instead of shrinking the desktop grid.
- The selector wraps into a two-column control grid so all products remain reachable without hidden horizontal scrolling.
- The real product stage follows the action and keeps a reserved, readable media area.
- Catalog filters wrap; regular cards remain one column; lower editorial bands stack.
