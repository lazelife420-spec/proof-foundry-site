import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {
  MemoryPagesFixtureTransport, assertApprovedCandidatePath, assertCanonicalPromotionScope,
  assertNoDuplicateDeployment, assertProductionBase, buildPagesDeployCommand, classifyCanonicalDelta,
  classifyPagesUpload, createSitePayloadManifest, isCurrentVerifiedPayload, sha256, verifySitePayload
} from "./pf-product-p7-p9.mjs";

const TEMP = await fs.mkdtemp(path.join(os.tmpdir(), "pf-product-p8-tests-"));
let passed = 0;
function check(value, description) { assert.ok(value, description); passed++; }

try {
  const productId = "fixture-product";
  const beforeRecord = { id: productId, productStatus: "PUBLIC_RELEASE", state: "available", route: "/fixture-product/",
    release: { publicVersion: "1.2.2", candidateVersion: "1.2.3", releaseStatus: "PUBLIC_RELEASE" }, artifacts: [{ sha256: "a".repeat(64), downloadUrl: "https://downloads.theprooffoundry.com/fixture-product/v1.2.2/a.zip" }], verification: { status: "VERIFIED" } };
  const afterRecord = { ...structuredClone(beforeRecord), release: { publicVersion: "1.2.3", candidateVersion: null, releaseStatus: "PUBLIC_RELEASE" }, artifacts: [{ sha256: "b".repeat(64), downloadUrl: "https://downloads.theprooffoundry.com/fixture-product/v1.2.3/b.zip" }] };
  const beforeModule = { route: "/fixture-product/", commerce: { status: "FREE", label: "Free download" }, homepage: { visibility: "visible" } };
  const afterModule = structuredClone(beforeModule);
  const beforeManifest = { siteName: "fixture", products: [beforeRecord, { id: "other-product", route: "/other-product/", release: { publicVersion: "4.0.0" } }] };
  const afterManifest = { siteName: "fixture", products: [afterRecord, structuredClone(beforeManifest.products[1])] };
  const approved = {
    proposedPaths: [{ path: "site-manifest.json" }],
    productPresentationChange: { changed: "NO" }, publicReleaseTruthChange: { changed: "YES" }, artifactChange: { changed: "YES" },
    commerceDelta: { changed: "NO" }, routeDelta: { changed: "NO" }, homepageChange: { changed: "NO" }, truthFileChange: { changed: "YES" }
  };
  check(assertCanonicalPromotionScope(beforeManifest, afterManifest, productId, "NEW_VERSION", beforeModule, afterModule), "canonical promotion accepts only the target product release transition");
  const delta = classifyCanonicalDelta({ manifest: beforeManifest, record: beforeRecord, module: beforeModule }, { manifest: afterManifest, record: afterRecord, module: afterModule }, approved, 1);
  check(delta.matches && delta.actual.PUBLIC_RELEASE_TRUTH_CHANGE && delta.actual.ARTIFACT_CHANGE, "semantic delta classifications match the frozen approval labels");
  const unrelated = structuredClone(afterManifest);
  unrelated.products[1].release.publicVersion = "4.0.1";
  assert.throws(() => assertCanonicalPromotionScope(beforeManifest, unrelated, productId, "NEW_VERSION", beforeModule, afterModule), /another product record/);
  check(true, "other-product manifest mutation is rejected");
  assert.throws(() => assertApprovedCandidatePath("products/other-product/module.json", productId), /outside its product/);
  check(true, "NEW_VERSION cannot add or alter unrelated product files");
  assert.throws(() => assertCanonicalPromotionScope(beforeManifest, afterManifest, productId, "PRESENTATION_UPDATE", beforeModule, afterModule), /release truth or verification/);
  check(true, "PRESENTATION_UPDATE cannot alter release version, artifact, URL, receipt, or verification projection");
  const commerceChanged = structuredClone(afterModule); commerceChanged.commerce.label = "Paid";
  assert.throws(() => assertCanonicalPromotionScope(beforeManifest, afterManifest, productId, "NEW_VERSION", beforeModule, commerceChanged), /commerce, route, or homepage/);
  check(true, "NEW_VERSION cannot silently change commerce, route, or homepage module state");

  const publicDir = path.join(TEMP, "public");
  await fs.mkdir(path.join(publicDir, "fixture-product"), { recursive: true });
  await fs.writeFile(path.join(publicDir, "index.html"), "<h1>fixture payload</h1>\n");
  await fs.writeFile(path.join(publicDir, "fixture-product", "index.html"), "<p>fixture route</p>\n");
  const sourceIdentity = { commit: "1".repeat(40), tree: "2".repeat(40), candidateId: "pfc-fixture", candidateDigest: "3".repeat(64) };
  const first = await createSitePayloadManifest(publicDir, sourceIdentity, "4".repeat(64));
  const second = await createSitePayloadManifest(publicDir, sourceIdentity, "4".repeat(64));
  check(JSON.stringify(first) === JSON.stringify(second), "payload manifest is deterministic for exact public bytes and source identity");
  check((await verifySitePayload(publicDir, first)).ok, "qualified manifest matches the exact directory bytes for deployment");
  await fs.appendFile(path.join(publicDir, "index.html"), "changed after qualification");
  check(!(await verifySitePayload(publicDir, first)).ok, "rebuild or edit after qualification is detected before upload");

  const command = buildPagesDeployCommand("C:\\fixture\\qualified\\public", { commitHash: "5".repeat(40), commitMessage: "candidate fixture" });
  check(command.includes("wrangler pages deploy") && command.includes("--project-name proof-foundry-site --branch main") && command.includes("--commit-hash"), "Pages Direct Upload command pins the exact production project and branch");
  assert.throws(() => buildPagesDeployCommand("public", { projectName: "wrong-project" }), /project must be proof-foundry-site/);
  check(true, "wrong Pages project is rejected");
  assert.throws(() => buildPagesDeployCommand("public", { branch: "preview" }), /branch must be main/);
  check(true, "wrong production branch is rejected");
  const expectedBase = { baseSiteCommit: "6".repeat(40), baseSiteTree: "7".repeat(40) };
  assertProductionBase(expectedBase, { source: { commit: expectedBase.baseSiteCommit, tree: expectedBase.baseSiteTree } });
  assert.throws(() => assertProductionBase(expectedBase, { source: { commit: "8".repeat(40), tree: expectedBase.baseSiteTree } }), (error) => error.code === "DEPLOY_DENIED_STALE_BASE");
  check(true, "stale production baseline blocks deploy before transport");
  check(classifyPagesUpload(true, false) === "DEPLOYED_UNVERIFIED", "successful upload followed by failed verification is DEPLOYED_UNVERIFIED");
  check(classifyPagesUpload(false, false) === "DEPLOY_FAILED", "failed upload remains distinct from post-upload verification failure");
  assert.throws(() => assertNoDuplicateDeployment({ state: "DEPLOYED_UNVERIFIED", payloadSha256: "9".repeat(64) }, "9".repeat(64)), /diagnose or plan rollback/);
  check(true, "DEPLOYED_UNVERIFIED receipt blocks a second upload");
  assert.throws(() => assertNoDuplicateDeployment({ state: "DEPLOYED_FIXTURE_VERIFIED", payloadSha256: "a".repeat(64) }, "a".repeat(64)), /second deployment is blocked/);
  check(true, "already deployed exact payload cannot create a duplicate deployment");
  const current = { verified: true, payloadSha256: first.payloadSha256, source: sourceIdentity, deploymentId: "existing-deployment", deploymentUrl: "https://existing.pages.dev/" };
  check(isCurrentVerifiedPayload(current, first, { candidateSourceCommit: sourceIdentity.commit, candidateSourceTree: sourceIdentity.tree }), "exact already-verified production payload becomes an idempotent no-op");
  check(!isCurrentVerifiedPayload({ ...current, verified: false }, first, { candidateSourceCommit: sourceIdentity.commit, candidateSourceTree: sourceIdentity.tree }), "unverified current payload is never treated as an idempotent deployment");
  const transport = new MemoryPagesFixtureTransport({ failVerification: true });
  const manifest = await createSitePayloadManifest(publicDir, sourceIdentity, "4".repeat(64));
  const upload = await transport.deploy(publicDir, manifest, command);
  check(upload.uploaded && !(await transport.verify(upload, manifest)), "fixture Pages transport records upload success independently from verification");
  console.log("PF PRODUCT P8 TESTS: " + passed + " passed, 0 failed");
} catch (error) {
  console.error("PF PRODUCT P8 TESTS: " + passed + " passed, 1 failed");
  console.error(error?.stack || String(error));
  process.exitCode = 1;
} finally {
  await fs.rm(TEMP, { recursive: true, force: true });
}
