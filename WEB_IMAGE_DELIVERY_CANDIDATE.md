# Lossless preview image delivery candidate

Local successor to the fully qualified site design at `214c3d09598a7b14a07108bc3b65bd25ab4234f3`.

The homepage and catalog keep each module's original PNG media reference, alt text, link, dimensions and lazy-loading behavior. A typed picture source offers an existing sibling WebP; absence of a derivative leaves the original PNG. Paths are restricted to local assets and traversal segments are refused. The picture wrapper adds no layout box.

Three new delivery derivatives cover Cache Vault quick paste, ProofShot proof cards and the Lights Out preview. All three retain the exact dimensions and decoded RGBA pixels of their source PNGs. Two independent encodings produced identical bytes. Combined image payload is 337,252 bytes versus 569,896 bytes, a reduction of 232,644 bytes (40.82%). No resizing, crop, generative edits or visual substitutions were performed. Original PNGs remain untouched.

Generation uses the existing bundled sharp runtime with `{lossless:true, effort:6}`. A qualified regeneration should decode and compare pixels and repeat the byte comparison before accepting new derivatives. New original media requires its derivative to be regenerated and requalified; sibling naming alone is not evidence of pixel identity.

The shared release model, all seven product modules, authority compiler, machine truth semantics, accepted PF geometry, typography and navigation remain unchanged. Installation authority remains NONE and production signing remains HOLD. This is a local visual/performance candidate; no push, master movement or deployment is authorized by this work.

Exact committed qualification, hashes, provenance, browser captures and network measurements are preserved in `C:/Users/KickA/Projects/Context/ProofFoundry/review/pf-web-image-delivery-20261005`. Prior qualification is retained separately and is not reused as evidence for the successor commit.
