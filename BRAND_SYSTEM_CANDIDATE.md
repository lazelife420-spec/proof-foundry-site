# PF unified maker’s-seal candidate

Local visual candidate based on qualified repair `137182a4527967547a66a2582060411c2aaa1343`, whose parent is deployed website source `54ef94acab654306664b091a185f10ca779225cb`.

The rectangular steel plate and circular impression form one primary mark. The shipped PF contours remain unchanged. The header uses the same contours, proportions, receipt fold and gold record crossbar, with interrupted impression arcs and a clipped plate edge instead of miniature inscriptions. The lower round mark is a quiet secondary watermark of that construction. It carries no verification or approval claim.

## Assets and deterministic construction

`node scripts/build-pf-brand.cjs` generates the five SVG derivatives from one set of PF paths and one shared placement. An optional output-directory argument allows two independent generations to be compared without touching the source assets.

- `brand/PF_MAKER_SEAL.svg`: embossed impression inserted into the existing hero plate. Its steel is the surrounding CSS plate; it has no separate circular background or badge.
- `brand/PF_MAKER_PLATE.svg`: standalone vector rendition of the same steel plate and impression, for the large inspection sheet.
- `brand/PF_HEADER_MARK.svg`: small-size mark for dark headers and footers; no microtext or texture.
- `brand/PF_HEADER_MARK_DARK.svg`: corresponding derivative for light backgrounds.
- `brand/PF_RECEIPT_WATERMARK.svg`: secondary flat impression, used at reduced opacity in the existing philosophy section.

The generator preserves the exact three path strings in shipped `PF_MARK_G_MASTER.svg`. None of the pre-existing brand files is overwritten. The PF has one shared transform: `translate(31.52 35.84) scale(.72)`.

## Every discoverable element

| Element | Location and exact content | Meaning | Intended viewing scale |
|---|---|---|---|
| Pressed circle | Concentric recessed circles around the PF, highlighted on their lower edges | A maker’s impression pressed into the plate; joins the former plaque and stamp | Hero and large plate |
| Folded receipt | P counter; a document outline with a folded upper-right corner; two short record lines only in the large impression | A release leaves a record. No checkmark, certification or security assertion | The fold survives structurally in the micro mark; lines are close-inspection detail |
| Record crossbar | Existing bridge at `M139 103.5H185`; restrained gold inlay | The connecting line between source and record; preserves the recognizable existing gold bridge | All variants |
| Binary maker inscription | Left inner rim: `01010000 01000110` | Public ASCII bytes `0x50 0x46`, which spell **PF**. They are not a credential, digest or encoded secret | Approximately 600 px and larger; easiest at close-up |
| Code inscription | Right inner rim: `record(source, artifact)` | Symbolic relationship between source, artifact and record; not an executable API or product claim | Approximately 600 px and larger |
| Upper microtext | `SOURCE / ARTIFACT / RECORD` | The three objects the Foundry’s recordkeeping connects | Large impression; not present in header |
| Lower microtext | `BUILD IT · PROVE IT · SHIP IT` | Existing brand motto, engraved into the impression | Large impression; not present in header |
| Three notches | Twelve o’clock, left/centre/right | Source, artifact and record in reading order | Large impression and secondary watermark |
| Four registration marks | Twelve, three, six and nine o’clock; small restrained gold strokes | Shared cardinal alignment of the impression and frame | All variants, simplified for micro mark |
| Clipped plate corners | Small-size outline and standalone plate | Material/frame construction, rather than an unrelated badge silhouette | Micro mark and standalone master |
| Four fasteners | Same existing four corner positions; slots face inward along opposite diagonals | Registers the physical frame; purposeful assembly detail | Website plate and standalone master |

## Scope and review

Homepage copy, section order, dimensions, product records and page interactions are preserved. Shared header/footer changes replace their logo image references and remove the legacy photographic crop/filter from those image elements, preserving their box sizes. The two H9 guards retain their assertion populations and now require all three actual unified assets while rejecting the former competing mark on the homepage. No release reducer, authority model, machine schema, intake policy or product asset changes are included.

The review package contains desktop/mobile before-and-after renders, 24/32/40 px samples on light and dark backgrounds, and magnified hidden-element callouts. Machine and visual checks are candidate evidence, not visual approval. This candidate is not merged to master, pushed or deployed. Production signing stays HOLD and installation authority stays NONE.
