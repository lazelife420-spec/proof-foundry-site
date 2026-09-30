import assert from "node:assert/strict";
import fs from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CLI = path.join(ROOT, "scripts", "pf-product.mjs");
const BASE_COMMIT = "d52eedb6fcbf5ead060318e8fee0e60406dc19a2";
const FIXTURE = path.join(ROOT, "scripts", "fixtures", "product-module-v2");
const TEMP = await fsp.mkdtemp(path.join(os.tmpdir(), "pf-product-p3-p5-tests-"));
const OUT = path.join(TEMP, "candidates");
const KEEP_TEMP = process.env.PF_PRODUCT_P3_P5_KEEP_TEMP === "1";
const QUALIFICATION_ONLY = process.env.PF_PRODUCT_P3_P5_QUALIFICATION_ONLY === "1";
const assertTemp = (p) => {
  const resolved = path.resolve(p), base = path.resolve(os.tmpdir()) + path.sep;
  assert.ok(resolved.startsWith(base) && path.basename(resolved).startsWith("pf-product-p3-p5-tests-"), "test cleanup remains inside its generated temp root");
};
assertTemp(TEMP);

function sha(bytes) { return crypto.createHash("sha256").update(bytes).digest("hex"); }
function json(file, value) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(value, null, 2) + "\n", "utf8"); }
function readJson(file) { return JSON.parse(fs.readFileSync(file, "utf8")); }
function run(args) { return spawnSync(process.execPath, [CLI, ...args], { cwd: ROOT, encoding: "utf8", timeout: 600000, maxBuffer: 32 * 1024 * 1024, windowsHide: true }); }
function report(args) {
  const r = run(args);
  let parsed;
  try { parsed = JSON.parse(r.stdout); } catch { throw new Error("CLI did not return structured JSON for " + args[0] + ": " + (r.stderr || r.stdout || "no output")); }
  return { ...r, report: parsed };
}
function check(ok, name) { assert.ok(ok, name); passed++; }
function clone(value) { return JSON.parse(JSON.stringify(value)); }
function allStrings(value, out = []) {
  if (typeof value === "string") out.push(value);
  else if (Array.isArray(value)) for (const v of value) allStrings(v, out);
  else if (value && typeof value === "object") for (const v of Object.values(value)) allStrings(v, out);
  return out;
}
async function copySourceMediaCapsule(dir, productId, module, content) {
  const values = allStrings(module).concat(content ? [content] : []);
  const media = new Set();
  const prefix = "/assets/" + productId + "/";
  for (const value of values) {
    for (const match of value.matchAll(/\/assets\/[a-z0-9-]+\/([A-Za-z0-9._/-]+)/g)) {
      const whole = match[0];
      if (!whole.startsWith(prefix)) continue;
      const rel = whole.slice(prefix.length).replace(/[.;,)]+$/, "");
      if (rel && !rel.includes("..") && !rel.includes("?")) media.add(rel);
    }
  }
  const mediaRoot = path.join(dir, "product", "media");
  for (const rel of media) {
    const source = path.join(ROOT, "assets", productId, ...rel.split("/"));
    if (!fs.existsSync(source)) throw new Error("Missing source media needed to assemble product test Capsule.");
    const target = path.join(mediaRoot, ...rel.split("/"));
    fs.mkdirSync(path.dirname(target), { recursive: true });
    fs.copyFileSync(source, target);
  }
}
function baseCapsule(productId, type, version, lifecycle) {
  return {
    schemaVersion: 1, productId, submissionType: type, requestedLifecycle: lifecycle,
    sourceRepository: "https://github.com/proof-foundry/pf-capsule-fixture",
    sourceCommit: BASE_COMMIT, releaseVersion: version, platforms: ["Windows"],
    modulePath: "product/module.json",
    releaseManifestPath: "release/release.json", checksumPath: "release/SHA256SUMS.txt",
    provenancePath: "provenance/source.json", artifactRefs: [],
    qualificationProfiles: ["PRODUCT_MODULE_V2", "H13_REGISTRY", "LOCAL_ARTIFACT_HASH", "CLAIM_EVIDENCE_LINKS"]
  };
}
async function makeNewProduct(name, extra = {}) {
  const dir = path.join(TEMP, name), id = extra.id || "pf-p3-fixture";
  const template = JSON.parse(fs.readFileSync(path.join(FIXTURE, "module.json"), "utf8"));
  const module = JSON.parse(JSON.stringify(template).replaceAll("fixture-product", id));
  module.id = id; module.route = "/" + id + "/"; module.lifecycle = "preview"; module.visibility = "hidden";
  module.homepage.visibility = "visible";
  module.commerce = { status: "FREE", label: "Free download" };
  const logo = fs.readFileSync(path.join(FIXTURE, "logo.svg"));
  const media = fs.readFileSync(path.join(FIXTURE, "media", "hero.png"));
  const artifactBytes = Buffer.from("synthetic candidate archive 1.0.0\n");
  const evidenceBytes = Buffer.from("synthetic local build record\n");
  const artifactPath = "release/artifacts/fixture-1.0.0.zip";
  const evidencePath = "release/evidence/build.txt";
  const capsule = { ...baseCapsule(id, "NEW_PRODUCT", "1.0.0", "preview"), artifactRefs: [{ path: artifactPath, platform: "Windows", sha256: sha(artifactBytes) }], ...extra.capsule };
  const release = {
    schemaVersion: 1, productId: id, version: capsule.releaseVersion, platforms: ["Windows"],
    artifacts: capsule.artifactRefs,
    evidence: [{ id: "build-output", kind: "build", path: evidencePath, sha256: sha(evidenceBytes) }],
    claims: [{ id: "archive-created", summary: "The submitted archive was produced.", evidenceIds: ["build-output"] }]
  };
  const provenance = { schemaVersion: 1, sourceRepository: capsule.sourceRepository, sourceCommit: capsule.sourceCommit, build: { builder: "fixture", buildId: "p3-p5" } };
  fs.mkdirSync(path.join(dir, "product", "media"), { recursive: true });
  fs.mkdirSync(path.dirname(path.join(dir, artifactPath)), { recursive: true });
  fs.mkdirSync(path.dirname(path.join(dir, evidencePath)), { recursive: true });
  fs.mkdirSync(path.join(dir, "provenance"), { recursive: true });
  fs.writeFileSync(path.join(dir, "product", "module.json"), JSON.stringify(module, null, 2) + "\n");
  fs.writeFileSync(path.join(dir, "product", "logo.svg"), logo);
  fs.writeFileSync(path.join(dir, "product", "media", "hero.png"), media);
  fs.writeFileSync(path.join(dir, artifactPath), artifactBytes);
  fs.writeFileSync(path.join(dir, evidencePath), evidenceBytes);
  json(path.join(dir, "capsule.json"), capsule);
  json(path.join(dir, "release", "release.json"), release);
  json(path.join(dir, "provenance", "source.json"), provenance);
  fs.writeFileSync(path.join(dir, "release", "SHA256SUMS.txt"), sha(artifactBytes) + "  " + artifactPath + "\n");
  return { dir, id, artifactPath };
}
async function makeExistingProduct(name, type, options = {}) {
  const dir = path.join(TEMP, name), id = "cache-vault";
  const modulePath = path.join(ROOT, "products", id, "module.json");
  const module = readJson(modulePath);
  const content = fs.readFileSync(path.join(ROOT, "products", id, "content.html"), "utf8");
  if (options.presentationChange) module.card.tagline = "Find the clip. Keep moving.";
  const capsuleModule = clone(module);
  delete capsuleModule.homepage.mediaDisclosure;
  const version = type === "NEW_VERSION" ? "0.2.5" : "0.2.4";
  const capsule = baseCapsule(id, type, version, module.lifecycle);
  capsule.contentPath = "product/content.html";
  if (type === "NEW_VERSION") {
    const artifactBytes = Buffer.from("synthetic cache vault candidate 0.2.5\n");
    const artifactPath = "release/artifacts/cache-vault-0.2.5-windows.zip";
    const evidenceBytes = Buffer.from("synthetic candidate build receipt\n");
    const evidencePath = "release/evidence/build.txt";
    capsule.artifactRefs = [{ path: artifactPath, platform: "Windows", sha256: sha(artifactBytes) }];
    fs.mkdirSync(path.dirname(path.join(dir, artifactPath)), { recursive: true });
    fs.writeFileSync(path.join(dir, artifactPath), artifactBytes);
    fs.mkdirSync(path.dirname(path.join(dir, evidencePath)), { recursive: true });
    fs.writeFileSync(path.join(dir, evidencePath), evidenceBytes);
    capsule._testArtifact = { artifactPath, artifactBytes, evidencePath, evidenceBytes };
  }
  const artifactInfo = capsule._testArtifact;
  delete capsule._testArtifact;
  const release = {
    schemaVersion: 1, productId: id, version, platforms: ["Windows"], artifacts: capsule.artifactRefs,
    evidence: artifactInfo ? [{ id: "build-output", kind: "build", path: artifactInfo.evidencePath, sha256: sha(artifactInfo.evidenceBytes) }] : [],
    claims: artifactInfo ? [{ id: "archive-created", summary: "The archive bytes were produced.", evidenceIds: ["build-output"] }] : []
  };
  const provenance = { schemaVersion: 1, sourceRepository: capsule.sourceRepository, sourceCommit: capsule.sourceCommit, build: { builder: "fixture", buildId: "existing-product" } };
  fs.mkdirSync(path.join(dir, "product"), { recursive: true });
  fs.mkdirSync(path.join(dir, "release"), { recursive: true });
  fs.mkdirSync(path.join(dir, "provenance"), { recursive: true });
  fs.writeFileSync(path.join(dir, "product", "module.json"), JSON.stringify(capsuleModule, null, 2) + "\n", "utf8");
  fs.copyFileSync(path.join(ROOT, "products", id, "logo.svg"), path.join(dir, "product", "logo.svg"));
  fs.writeFileSync(path.join(dir, "product", "content.html"), content);
  await copySourceMediaCapsule(dir, id, module, content);
  json(path.join(dir, "capsule.json"), capsule);
  json(path.join(dir, "release", "release.json"), release);
  json(path.join(dir, "provenance", "source.json"), provenance);
  fs.writeFileSync(path.join(dir, "release", "SHA256SUMS.txt"), artifactInfo ? sha(artifactInfo.artifactBytes) + "  " + artifactInfo.artifactPath + "\n" : "", "utf8");
  return { dir, id };
}
async function treeDigest(root) {
  const rows = [];
  async function walk(dir, prefix = "") {
    for (const ent of (await fsp.readdir(dir, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name, "en"))) {
      const rel = prefix ? prefix + "/" + ent.name : ent.name, full = path.join(dir, ent.name);
      if (ent.isDirectory()) await walk(full, rel);
      else rows.push({ rel, size: (await fsp.stat(full)).size, hash: sha(await fsp.readFile(full)) });
    }
  }
  await walk(root);
  return sha(Buffer.from(rows.map((r) => r.rel + "\0" + r.size + "\0" + r.hash + "\n").join(""), "utf8"));
}
async function copyCandidate(source, name) {
  const target = path.join(TEMP, name);
  await fsp.cp(source, target, { recursive: true });
  return target;
}

let passed = 0;
try {
  if (QUALIFICATION_ONLY) {
    const capsule = await makeNewProduct("qualification-only");
    const materialized = report(["materialize", capsule.dir, "--output-dir", OUT]);
    check(materialized.status === 0 && materialized.report.publicationState === "VALID_UNVERIFIED", "P3 candidate materializes on final source");
    const candidate = materialized.report.candidatePath;
    const preview = report(["preview", candidate]);
    check(preview.status === 0 && preview.report.status === "PASS", "P4 preview passes on final source");
    const qualification = report(["qualify", candidate]);
    check(qualification.status === 0 && qualification.report.status === "PASS" && qualification.report.publicationState === "QUALIFIED_UNPUBLISHED", "P5 qualifies on final source without publication");
    check(qualification.report.dimensions.LIVE_PUBLICATION_VALID === "NOT_RUN" && Object.values(qualification.report.dimensions).filter((v) => v !== "NOT_RUN").every((v) => v === "PASS"), "all final-source dimensions pass with live publication NOT_RUN");
    check(qualification.report.regressionSuites.length === 11 && qualification.report.regressionSuites.every((x) => x.status === "PASS"), "all final-source regression authorities pass");
    console.log("PF PRODUCT P3-P5 FINAL QUALIFICATION: " + passed + " passed, 0 failed");
  } else {
  const newProduct = await makeNewProduct("new-product");
  const newInspect = run(["inspect", newProduct.dir]);
  check(newInspect.status === 0 && newInspect.stdout.includes("SUBMISSION_TYPE: NEW_PRODUCT"), "NEW_PRODUCT Capsule is inspected before validation");
  const newValid = report(["validate", newProduct.dir]);
  check(newValid.status === 0 && newValid.report.status === "VALID_UNVERIFIED", "NEW_PRODUCT Capsule validates: " + JSON.stringify(newValid.report));
  const newMat = report(["materialize", newProduct.dir, "--output-dir", OUT]);
  const newCandidate = newMat.report.candidatePath;
  check(newMat.status === 0 && newMat.report.publicationState === "VALID_UNVERIFIED", "NEW_PRODUCT materializes without publication authority");
  const newPaths = newMat.report.changedPaths.map((x) => x.path);
  check(newPaths.includes("site-manifest.json") && newPaths.includes("products/" + newProduct.id + "/module.json") && newPaths.includes("products/" + newProduct.id + "/media/hero.png"), "NEW_PRODUCT contains module, media, and hidden manifest candidate");
  const repeat = report(["materialize", newProduct.dir, "--output-dir", OUT]);
  check(repeat.status === 0 && repeat.report.reused && repeat.report.candidateId === newMat.report.candidateId, "same Capsule reuses identical candidate identity");
  const second = report(["materialize", newProduct.dir, "--output-dir", path.join(TEMP, "candidates-second")]);
  const stateA = fs.readFileSync(path.join(newCandidate, "candidate-state.json"));
  const stateB = fs.readFileSync(path.join(second.report.candidatePath, "candidate-state.json"));
  const pathsA = fs.readFileSync(path.join(newCandidate, "candidate-changed-paths.json"));
  const pathsB = fs.readFileSync(path.join(second.report.candidatePath, "candidate-changed-paths.json"));
  check(second.status === 0 && newMat.report.candidateId === second.report.candidateId && stateA.equals(stateB) && pathsA.equals(pathsB), "separate materializations of identical inputs are deterministic");

  const newPreview = report(["preview", newCandidate]);
  check(newPreview.status === 0 && newPreview.report.status === "PASS", "NEW_PRODUCT local preview passes");
  const newPage = fs.readFileSync(path.join(newCandidate, "preview-site", "__preview", newProduct.id, "index.html"), "utf8");
  const publicTruth = readJson(path.join(newCandidate, "preview-site", "truth", "index.json"));
  const sitemap = fs.readFileSync(path.join(newCandidate, "preview-site", "sitemap.xml"), "utf8");
  check(["PREVIEW", "UNVERIFIED", "NOT PUBLIC", "PUBLIC_DOWNLOAD = NOT_PUBLISHED"].every((x) => newPage.includes(x)), "preview labels status and unpublished candidate downloads");
  check(!(publicTruth.products || []).some((p) => p.id === newProduct.id) && !sitemap.includes("/__preview/") && !fs.existsSync(path.join(newCandidate, "preview-site", newProduct.id, "index.html")), "preview candidate does not enter normal public Truth, sitemap, or route");

  const badPath = await copyCandidate(newCandidate, "bad-undeclared-path");
  fs.writeFileSync(path.join(badPath, "unexpected.txt"), "undeclared", "utf8");
  check(report(["qualify", badPath]).report.status === "INVALID", "candidate changes to an undeclared path are rejected");
  const badArtifact = await copyCandidate(newCandidate, "bad-artifact-bytes");
  const artifactFile = path.join(badArtifact, "candidate-artifacts", newProduct.artifactPath);
  fs.writeFileSync(artifactFile, "tampered archive bytes", "utf8");
  check(report(["qualify", badArtifact]).report.status === "INVALID", "materialized artifact bytes cannot diverge from declared hash");
  const selfVerified = await copyCandidate(newCandidate, "bad-self-verified");
  const selfModulePath = path.join(selfVerified, "submitted-capsule", "product", "module.json");
  const selfModule = readJson(selfModulePath); selfModule.verification = { status: "VERIFIED" }; json(selfModulePath, selfModule);
  check(report(["qualify", selfVerified]).report.status === "INVALID", "candidate cannot self-assert VERIFIED");
  const selfPublished = await copyCandidate(newCandidate, "bad-self-public-release");
  const forgedStatePath = path.join(selfPublished, "candidate-state.json");
  const forgedState = readJson(forgedStatePath); forgedState.publicationState = "PUBLIC_RELEASE"; json(forgedStatePath, forgedState);
  check(report(["qualify", selfPublished]).report.status === "INVALID", "candidate cannot self-assert PUBLIC_RELEASE");
  const leakedPreview = await copyCandidate(newCandidate, "bad-preview-public-route");
  fs.mkdirSync(path.join(leakedPreview, "preview-site", newProduct.id), { recursive: true });
  fs.writeFileSync(path.join(leakedPreview, "preview-site", newProduct.id, "index.html"), "candidate public route collision", "utf8");
  const forgedPreviewReceiptPath = path.join(leakedPreview, "preview-receipt.json");
  const forgedPreviewReceipt = readJson(forgedPreviewReceiptPath);
  forgedPreviewReceipt.sitePayloadSha256 = await treeDigest(path.join(leakedPreview, "preview-site"));
  json(forgedPreviewReceiptPath, forgedPreviewReceipt);
  check(report(["preview", leakedPreview]).report.status === "FAIL", "preview route collision is rejected after output/receipt tampering");

  const version = await makeExistingProduct("new-version", "NEW_VERSION");
  const versionInspect = run(["inspect", version.dir]);
  check(versionInspect.status === 0 && versionInspect.stdout.includes("SUBMISSION_TYPE: NEW_VERSION"), "NEW_VERSION Capsule is inspected before validation");
  const versionValidation = report(["validate", version.dir]);
  check(versionValidation.status === 0 && versionValidation.report.status === "VALID_UNVERIFIED", "NEW_VERSION Capsule validates against current product state: " + JSON.stringify(versionValidation.report));
  const versionMat = report(["materialize", version.dir, "--output-dir", OUT]);
  check(versionMat.status === 0 && versionMat.report.changedPaths?.length === 1 && versionMat.report.changedPaths[0].path === "site-manifest.json", "NEW_VERSION defaults to manifest-only candidate change: " + JSON.stringify(versionMat.report));
  const otherProduct = await copyCandidate(versionMat.report.candidatePath, "bad-version-other-product");
  const otherModule = path.join(otherProduct, "proposed-source", "products", "ghostlayer", "module.json");
  fs.mkdirSync(path.dirname(otherModule), { recursive: true }); fs.writeFileSync(otherModule, "{}\n", "utf8");
  check(report(["qualify", otherProduct]).report.status === "INVALID", "NEW_VERSION cannot change another product or homepage module");
  check(report(["preview", versionMat.report.candidatePath]).report.status === "PASS", "NEW_VERSION local preview passes");
  const versionQualification = report(["qualify", versionMat.report.candidatePath]);
  check(versionQualification.status === 0 && versionQualification.report.publicationState === "QUALIFIED_UNPUBLISHED", "NEW_VERSION qualifies against the current website without publishing");
  const versionFreeze = report(["freeze", versionMat.report.candidatePath]);
  check(versionFreeze.status === 0 && versionFreeze.report.approvalState === "FROZEN_FOR_OWNER_REVIEW", "NEW_VERSION freezes only for owner review");

  const presentation = await makeExistingProduct("presentation-update", "PRESENTATION_UPDATE", { presentationChange: true });
  const presentationInspect = run(["inspect", presentation.dir]);
  check(presentationInspect.status === 0 && presentationInspect.stdout.includes("SUBMISSION_TYPE: PRESENTATION_UPDATE"), "PRESENTATION_UPDATE Capsule is inspected before validation");
  const presentationValidation = report(["validate", presentation.dir]);
  check(presentationValidation.status === 0 && presentationValidation.report.status === "VALID_UNVERIFIED", "PRESENTATION_UPDATE Capsule validates");
  const presentationMat = report(["materialize", presentation.dir, "--output-dir", OUT]);
  check(presentationMat.status === 0 && presentationMat.report.changedPaths.length === 1 && presentationMat.report.changedPaths[0].path === "products/cache-vault/module.json", "PRESENTATION_UPDATE changes only product presentation source");
  check(report(["preview", presentationMat.report.candidatePath]).report.status === "PASS", "PRESENTATION_UPDATE local preview passes");
  const presentationQualification = report(["qualify", presentationMat.report.candidatePath]);
  check(presentationQualification.status === 0 && presentationQualification.report.publicationState === "QUALIFIED_UNPUBLISHED", "PRESENTATION_UPDATE qualifies without changing release truth");
  const presentationFreeze = report(["freeze", presentationMat.report.candidatePath]);
  check(presentationFreeze.status === 0 && presentationFreeze.report.approvalState === "FROZEN_FOR_OWNER_REVIEW", "PRESENTATION_UPDATE freezes only for owner review");

  const badUpdateVersion = await makeExistingProduct("presentation-version-mutation", "PRESENTATION_UPDATE");
  const badUpdateCapsule = readJson(path.join(badUpdateVersion.dir, "capsule.json")); badUpdateCapsule.releaseVersion = "0.2.5"; json(path.join(badUpdateVersion.dir, "capsule.json"), badUpdateCapsule);
  const badUpdateRelease = readJson(path.join(badUpdateVersion.dir, "release", "release.json")); badUpdateRelease.version = "0.2.5"; json(path.join(badUpdateVersion.dir, "release", "release.json"), badUpdateRelease);
  check(report(["validate", badUpdateVersion.dir]).report.status === "INVALID", "PRESENTATION_UPDATE release-version mutation is rejected");
  const badUpdateHash = await makeExistingProduct("presentation-artifact-mutation", "PRESENTATION_UPDATE");
  const badUpdateHashCapsule = readJson(path.join(badUpdateHash.dir, "capsule.json"));
  badUpdateHashCapsule.artifactRefs = [{ path: "release/artifacts/fake.zip", platform: "Windows", sha256: "a".repeat(64) }];
  json(path.join(badUpdateHash.dir, "capsule.json"), badUpdateHashCapsule);
  check(report(["validate", badUpdateHash.dir]).report.status === "INVALID", "PRESENTATION_UPDATE artifact-hash mutation is rejected");

  const badId = await makeNewProduct("bad-module-id");
  const badIdModule = readJson(path.join(badId.dir, "product", "module.json")); badIdModule.id = "other-id"; json(path.join(badId.dir, "product", "module.json"), badIdModule);
  check(report(["validate", badId.dir]).report.status === "INVALID", "manifest/module identity disagreement is rejected");
  const badRoute = await makeNewProduct("bad-route");
  const badRouteModule = readJson(path.join(badRoute.dir, "product", "module.json")); badRouteModule.route = "/about/"; json(path.join(badRoute.dir, "product", "module.json"), badRouteModule);
  check(report(["validate", badRoute.dir]).report.status === "INVALID", "route disagreement and public-route collision are rejected");
  const badLifecycle = await makeNewProduct("bad-visibility");
  const badLifecycleModule = readJson(path.join(badLifecycle.dir, "product", "module.json")); badLifecycleModule.lifecycle = "public-eligible"; json(path.join(badLifecycle.dir, "product", "module.json"), badLifecycleModule);
  check(report(["validate", badLifecycle.dir]).report.status === "INVALID", "visibility/lifecycle disagreement is rejected");
  const futureUrl = await makeNewProduct("future-public-url");
  const futureModule = readJson(path.join(futureUrl.dir, "product", "module.json")); futureModule.hero.primaryAction.href = "https://downloads.theprooffoundry.com/future/v1.0.0/file.zip"; json(path.join(futureUrl.dir, "product", "module.json"), futureModule);
  check(report(["validate", futureUrl.dir]).report.status === "INVALID", "future public download URL cannot be treated as live");
  const selfVerifiedInput = await makeNewProduct("self-verified-input");
  const verifiedModule = readJson(path.join(selfVerifiedInput.dir, "product", "module.json")); verifiedModule.verification = { status: "VERIFIED" }; json(path.join(selfVerifiedInput.dir, "product", "module.json"), verifiedModule);
  check(report(["validate", selfVerifiedInput.dir]).report.status === "INVALID", "Capsule module cannot grant itself VERIFIED authority");
  const arbitraryTestCommand = await makeNewProduct("arbitrary-test-command");
  const arbitraryCapsule = readJson(path.join(arbitraryTestCommand.dir, "capsule.json")); arbitraryCapsule.testCommand = "anything the submitter wants"; json(path.join(arbitraryTestCommand.dir, "capsule.json"), arbitraryCapsule);
  check(report(["validate", arbitraryTestCommand.dir]).report.status === "INVALID", "arbitrary testCommand is rejected by the Capsule schema");
  const badBytes = await makeNewProduct("artifact-hash-mismatch"); fs.writeFileSync(path.join(badBytes.dir, badBytes.artifactPath), "different artifact bytes", "utf8");
  check(report(["validate", badBytes.dir]).report.status === "INVALID", "artifact bytes differing from declared SHA-256 are rejected");

  const validCandidate = await report(["qualify", newCandidate]);
  check(validCandidate.status === 0 && validCandidate.report.status === "PASS" && validCandidate.report.publicationState === "QUALIFIED_UNPUBLISHED", "valid candidate qualifies without publication: " + JSON.stringify(validCandidate.report));
  check(validCandidate.report.dimensions.LIVE_PUBLICATION_VALID === "NOT_RUN" && Object.values(validCandidate.report.dimensions).filter((v) => v !== "NOT_RUN").every((v) => v === "PASS"), "independent non-publication qualification dimensions pass");
  check(validCandidate.report.regressionSuites.length === 11 && validCandidate.report.regressionSuites.every((x) => x.status === "PASS"), "all eleven registered regression authorities pass during P5 qualification");
  const newProductFreeze = report(["freeze", newCandidate]);
  check(newProductFreeze.status === 0 && newProductFreeze.report.approvalState === "FROZEN_FOR_OWNER_REVIEW", "NEW_PRODUCT freezes only for owner review");
  console.log("PF PRODUCT P3-P5 QUALIFICATION TESTS: " + passed + " passed, 0 failed");
  }
} catch (error) {
  console.error("PF PRODUCT P3-P5 QUALIFICATION TESTS: " + passed + " passed, 1 failed");
  console.error(error?.stack || String(error));
  process.exitCode = 1;
} finally {
  assertTemp(TEMP);
  if (KEEP_TEMP) console.log("PF_TEST_TEMP_ROOT=" + TEMP);
  else await fsp.rm(TEMP, { recursive: true, force: true });
}
