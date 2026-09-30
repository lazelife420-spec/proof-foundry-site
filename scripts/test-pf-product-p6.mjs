import assert from "node:assert/strict";
import fs from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { approvalBindingMatches, computeCandidatePayloadSha256, deterministicApprovalDigest } from "./pf-product-p3-p5.mjs";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CLI = path.join(ROOT, "scripts", "pf-product.mjs");
const FIXTURE = path.join(ROOT, "scripts", "fixtures", "product-module-v2");
const TEMP = await fsp.mkdtemp(path.join(os.tmpdir(), "pf-product-p6-tests-"));
const OUTPUT = path.join(TEMP, "candidates");
let passed = 0;
const sha = (bytes) => crypto.createHash("sha256").update(bytes).digest("hex");
const json = (file, value) => { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(value, null, 2) + "\n", "utf8"); };
const readJson = (file) => JSON.parse(fs.readFileSync(file, "utf8"));
const allStrings = (value, out = []) => {
  if (typeof value === "string") out.push(value);
  else if (Array.isArray(value)) for (const x of value) allStrings(x, out);
  else if (value && typeof value === "object") for (const x of Object.values(value)) allStrings(x, out);
  return out;
};
function check(condition, description) { assert.ok(condition, description); passed++; }
function run(args) {
  return spawnSync(process.execPath, [CLI, ...args], { cwd: ROOT, encoding: "utf8", timeout: 900000, maxBuffer: 64 * 1024 * 1024, windowsHide: true });
}
function report(args) {
  const result = run(args);
  let value;
  try { value = JSON.parse(result.stdout || ""); } catch { throw new Error("Expected structured CLI output for " + args[0]); }
  return { ...result, report: value };
}
async function makeNewProduct() {
  const dir = path.join(TEMP, "new-product");
  const id = "pf-p6-approval-fixture";
  const template = JSON.parse(fs.readFileSync(path.join(FIXTURE, "module.json"), "utf8"));
  const module = JSON.parse(JSON.stringify(template).replaceAll("fixture-product", id));
  module.id = id; module.route = "/" + id + "/"; module.lifecycle = "preview"; module.visibility = "hidden";
  module.homepage.visibility = "visible";
  module.commerce = { status: "FREE", label: "Free download" };
  const logo = fs.readFileSync(path.join(FIXTURE, "logo.svg"));
  const media = fs.readFileSync(path.join(FIXTURE, "media", "hero.png"));
  const artifactBytes = Buffer.from("synthetic p6 candidate archive\n");
  const evidenceBytes = Buffer.from("synthetic p6 build receipt\n");
  const artifactPath = "release/artifacts/fixture-1.0.0.zip";
  const evidencePath = "release/evidence/build.txt";
  const capsule = {
    schemaVersion: 1, productId: id, submissionType: "NEW_PRODUCT", requestedLifecycle: "preview",
    sourceRepository: "https://github.com/proof-foundry/pf-p6-fixture", sourceCommit: "d52eedb6fcbf5ead060318e8fee0e60406dc19a2",
    releaseVersion: "1.0.0", platforms: ["Windows"], modulePath: "product/module.json",
    releaseManifestPath: "release/release.json", checksumPath: "release/SHA256SUMS.txt",
    provenancePath: "provenance/source.json", artifactRefs: [{ path: artifactPath, platform: "Windows", sha256: sha(artifactBytes) }],
    qualificationProfiles: ["PRODUCT_MODULE_V2", "H13_REGISTRY", "LOCAL_ARTIFACT_HASH", "CLAIM_EVIDENCE_LINKS"]
  };
  const release = {
    schemaVersion: 1, productId: id, version: "1.0.0", platforms: ["Windows"], artifacts: capsule.artifactRefs,
    evidence: [{ id: "build-output", kind: "build", path: evidencePath, sha256: sha(evidenceBytes) }],
    claims: [{ id: "archive-created", summary: "The submitted archive was produced.", evidenceIds: ["build-output"] }]
  };
  const provenance = { schemaVersion: 1, sourceRepository: capsule.sourceRepository, sourceCommit: capsule.sourceCommit, build: { builder: "fixture", buildId: "p6" } };
  fs.mkdirSync(path.join(dir, "product", "media"), { recursive: true });
  for (const p of [path.dirname(path.join(dir, artifactPath)), path.dirname(path.join(dir, evidencePath)), path.join(dir, "provenance")]) fs.mkdirSync(p, { recursive: true });
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

try {
  const capsule = await makeNewProduct();
  const materialized = report(["materialize", capsule.dir, "--output-dir", OUTPUT]);
  check(materialized.status === 0 && materialized.report.publicationState === "VALID_UNVERIFIED", "P6 candidate materializes offline");
  const candidate = materialized.report.candidatePath;
  const candidateId = materialized.report.candidateId;
  const preview = report(["preview", candidate]);
  check(preview.status === 0 && preview.report.status === "PASS", "P6 candidate preview passes locally");
  const qualified = report(["qualify", candidate]);
  check(qualified.status === 0 && qualified.report.publicationState === "QUALIFIED_UNPUBLISHED" && qualified.report.livePublication === "NOT_RUN", "only a fully qualified unpublished candidate reaches freeze");
  check(qualified.report.dimensions.CANONICAL_OUTPUT_VALID === "PASS", "qualification regenerates canonical ignored public output before public-surface authorities");

  const frozen = report(["freeze", candidate]);
  check(frozen.status === 0 && frozen.report.approvalState === "FROZEN_FOR_OWNER_REVIEW", "qualified candidate freezes for owner review");
  const packageDir = path.join(candidate, "owner-review-package");
  const expectedFiles = ["candidate-approval.json", "candidate-changed-paths.json", "candidate-artifacts.json", "candidate-qualification.json", "candidate-preview.json", "candidate-source-binding.json", "candidate-approval-summary.txt"];
  check(expectedFiles.every((x) => fs.existsSync(path.join(packageDir, x))), "freeze emits all review package components");
  const approval = readJson(path.join(packageDir, "candidate-approval.json"));
  const head = spawnSync("git", ["show", "-s", "--format=%H", "HEAD"], { cwd: ROOT, encoding: "utf8" }).stdout.trim();
  const tree = spawnSync("git", ["show", "-s", "--format=%T", "HEAD"], { cwd: ROOT, encoding: "utf8" }).stdout.trim();
  check(approval.publisherCommit === head && approval.publisherTree === tree, "approval binds the committed publisher implementation");
  const candidateState = readJson(path.join(candidate, "candidate-state.json"));
  const approvedBaseTree = spawnSync("git", ["show", "-s", "--format=%T", approval.baseSiteCommit], { cwd: ROOT, encoding: "utf8" });
  check(approval.baseSiteCommit === candidateState.baseCommit && approval.baseSiteTree === candidateState.baseTree &&
    approvedBaseTree.status === 0 && approval.baseSiteTree === approvedBaseTree.stdout.trim(),
    "approval binds the candidate's exact committed site base and tree");
  check(approval.approvalState === "FROZEN_FOR_OWNER_REVIEW" && approval.livePublication === "NOT_RUN" && !Object.hasOwn(approval, "approved") && !Object.hasOwn(approval, "published"), "freeze cannot imply approval or publication");
  check([approval.productPresentationChange, approval.publicReleaseTruthChange, approval.artifactChange, approval.commerceDelta, approval.routeDelta, approval.homepageChange, approval.truthFileChange, approval.releaseTruthDelta].every((x) => ["YES", "NO"].includes(x.changed)), "all seven public-impact deltas and release-truth binding are explicit YES/NO");
  const summary = fs.readFileSync(path.join(packageDir, "candidate-approval-summary.txt"), "utf8");
  check(summary.includes("PRODUCT_PRESENTATION_CHANGE = YES") && summary.includes("LIVE_PUBLICATION_VALID = NOT_RUN"), "human summary exposes impact and live-publication state");
  const timestamp = approval.createdAt;
  const repeated = report(["freeze", candidate]);
  check(repeated.status === 0 && repeated.report.reused && repeated.report.approvalPackageDigest === approval.approvalPackageDigest, "repeat freeze reuses the same immutable package");
  check(readJson(path.join(packageDir, "candidate-approval.json")).createdAt === timestamp, "re-freeze preserves package event timestamp");

  const artifactFile = path.join(candidate, "candidate-artifacts", ...capsule.artifactPath.split("/"));
  const originalArtifact = await fsp.readFile(artifactFile);
  await fsp.writeFile(artifactFile, Buffer.concat([originalArtifact, Buffer.from("changed") ]));
  check(report(["freeze", candidate]).status !== 0, "stale approval cannot freeze after candidate artifact bytes change");
  await fsp.writeFile(artifactFile, originalArtifact);
  const submittedModulePath = path.join(candidate, "submitted-capsule", "product", "module.json");
  const originalModule = await fsp.readFile(submittedModulePath);
  await fsp.writeFile(submittedModulePath, Buffer.concat([originalModule, Buffer.from(" ") ]));
  check(report(["freeze", candidate]).status !== 0, "stale approval cannot freeze after candidate source bytes change");
  await fsp.writeFile(submittedModulePath, originalModule);
  check(readJson(path.join(packageDir, "candidate-approval.json")).approvalPackageDigest === approval.approvalPackageDigest, "rejected stale freezes do not rewrite the existing approval package");

  const missingApproval = report(["freeze", capsule.dir]);
  check(missingApproval.status !== 0 && missingApproval.report.approvalState === "INVALID", "qualification failure cannot freeze for owner review");

  const fakePlan = {
    candidateId: candidateId, candidateDigest: "a".repeat(64), validationReport: { capsuleSha256: "b".repeat(64) },
    candidateStateSha256: "c".repeat(64), stateSourceSha256: "d".repeat(64),
    changes: [{ path: "products/example/module.json", operation: "MODIFY", preImageSha256: "e".repeat(64), postImageSha256: "f".repeat(64) }],
    artifactInventory: [{ packagePath: "release/artifacts/example.zip", sizeBytes: 3, computedSha256: "1".repeat(64) }],
    evidenceInventory: [{ packagePath: "release/evidence/build.txt", sizeBytes: 4, sha256: "2".repeat(64) }],
    foreignUntrackedFiles: ["foreign-owner-note.txt"]
  };
  const fakePlan2 = structuredClone(fakePlan); fakePlan2.foreignUntrackedFiles = ["different-foreign-file.bin"];
  check(computeCandidatePayloadSha256(fakePlan) === computeCandidatePayloadSha256(fakePlan2), "foreign untracked files do not enter the approval payload digest");
  const artifactChanged = structuredClone(fakePlan); artifactChanged.artifactInventory[0].computedSha256 = "3".repeat(64);
  check(computeCandidatePayloadSha256(fakePlan) !== computeCandidatePayloadSha256(artifactChanged), "candidate payload digest changes with artifact bytes");
  const candidateChanged = structuredClone(fakePlan); candidateChanged.candidateDigest = "4".repeat(64);
  check(computeCandidatePayloadSha256(fakePlan) !== computeCandidatePayloadSha256(candidateChanged), "candidate payload digest changes with candidate bytes or base binding");

  const approvalWithNewTime = { ...approval, createdAt: "2099-01-01T00:00:00.000Z" };
  check(deterministicApprovalDigest(approval) === deterministicApprovalDigest(approvalWithNewTime), "event timestamp does not alter deterministic approval identity");
  const approvalWithNewBase = { ...approval, baseSiteCommit: "9".repeat(40) };
  check(deterministicApprovalDigest(approval) !== deterministicApprovalDigest(approvalWithNewBase), "approval package identity changes when the base commit changes");
  check(approvalBindingMatches(approval, approval), "future approval binding matches the exact candidate");
  check(!approvalBindingMatches(approval, { ...approval, productId: "other-product" }), "product A approval cannot authorize product B");
  check(!approvalBindingMatches(approval, { ...approval, candidateDigest: "8".repeat(64) }), "stale approval cannot match a modified candidate digest");

  const publicResidue = spawnSync("git", ["ls-tree", "-r", "--name-only", "HEAD", "--", "public"], { cwd: ROOT, encoding: "utf8" });
  check(publicResidue.status === 0 && publicResidue.stdout.trim() === "", "generated public residue is excluded from the publisher source commit");
  check(candidateId === approval.candidateId && approval.capsuleSha256 === readJson(path.join(candidate, "candidate-state.json")).createdFromCapsuleSha256, "approval binds candidate and capsule identity");
  console.log("PF PRODUCT P6 APPROVAL TESTS: " + passed + " passed, 0 failed");
} catch (error) {
  console.error("PF PRODUCT P6 APPROVAL TESTS: " + passed + " passed, 1 failed");
  console.error(error?.stack || String(error));
  process.exitCode = 1;
} finally {
  const resolved = path.resolve(TEMP), base = path.resolve(os.tmpdir()) + path.sep;
  assert.ok(resolved.startsWith(base) && path.basename(resolved).startsWith("pf-product-p6-tests-"), "P6 test cleanup stays under its own temporary root");
  await fsp.rm(TEMP, { recursive: true, force: true });
}
