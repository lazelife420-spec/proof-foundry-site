import assert from "node:assert/strict";
import fs from "node:fs";
import fsp from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CLI = path.join(ROOT, "scripts/pf-product.mjs");
const FIXTURE = path.join(ROOT, "scripts/fixtures/product-module-v2");
const TEMP = await fsp.mkdtemp(path.join(os.tmpdir(), "pf-product-tests-"));
assert.ok(path.resolve(TEMP).startsWith(path.resolve(os.tmpdir()) + path.sep));

function sha(data) { return crypto.createHash("sha256").update(data).digest("hex"); }
function saveJson(file, value) { fs.mkdirSync(path.dirname(file), { recursive: true }); fs.writeFileSync(file, JSON.stringify(value, null, 2) + "\n", "utf8"); }
function copyCapsule(from, name) { const dest = path.join(TEMP, name); fs.cpSync(from, dest, { recursive: true }); return dest; }
function run(args) { return spawnSync(process.execPath, [CLI, ...args], { cwd: ROOT, encoding: "utf8", timeout: 240000, maxBuffer: 8 * 1024 * 1024 }); }

async function makeCapsule(name, opts = {}) {
  const dir = path.join(TEMP, name);
  const id = opts.id || "pf-capsule-fixture";
  const type = opts.type || "NEW_PRODUCT";
  const version = opts.version || (type === "PRESENTATION_UPDATE" ? "0.2.4" : "1.0.0");
  const lifecycle = opts.lifecycle || (type === "PRESENTATION_UPDATE" ? "public-eligible" : "preview");
  const module = JSON.parse(fs.readFileSync(path.join(FIXTURE, "module.json"), "utf8"));
  const moduleText = JSON.stringify(module).replaceAll("fixture-product", id);
  const productModule = JSON.parse(moduleText);
  productModule.id = id;
  productModule.route = "/" + id + "/";
  productModule.lifecycle = lifecycle;
  productModule.visibility = lifecycle === "public-eligible" ? "visible" : "hidden";
  productModule.homepage.visibility = "visible";
  productModule.commerce = { status: "FREE", label: "Free download" };
  const logo = fs.readFileSync(path.join(FIXTURE, "logo.svg"));
  const media = fs.readFileSync(path.join(FIXTURE, "media", "hero.png"));
  const artifactBytes = Buffer.from("synthetic capsule artifact " + version + "\n");
  const evidenceBytes = Buffer.from("synthetic build evidence\n");
  const artifactPath = "release/artifacts/fixture-" + version + ".zip";
  const evidencePath = "release/evidence/build.txt";
  const artifactSha = sha(artifactBytes), evidenceSha = sha(evidenceBytes);
  const artifacts = type === "PRESENTATION_UPDATE" ? [] : [{ path: artifactPath, platform: "Windows", sha256: artifactSha }];
  fs.mkdirSync(path.join(dir, "product/media"), { recursive: true });
  fs.mkdirSync(path.join(dir, "release/artifacts"), { recursive: true });
  fs.mkdirSync(path.join(dir, "release/evidence"), { recursive: true });
  fs.mkdirSync(path.join(dir, "provenance"), { recursive: true });
  fs.writeFileSync(path.join(dir, "product/module.json"), JSON.stringify(productModule, null, 2) + "\n");
  fs.writeFileSync(path.join(dir, "product/logo.svg"), logo);
  fs.writeFileSync(path.join(dir, "product/media/hero.png"), media);
  if (artifacts.length) fs.writeFileSync(path.join(dir, artifactPath), artifactBytes);
  if (type !== "PRESENTATION_UPDATE") fs.writeFileSync(path.join(dir, evidencePath), evidenceBytes);
  const capsule = {
    schemaVersion: 1,
    productId: id,
    submissionType: type,
    requestedLifecycle: lifecycle,
    sourceRepository: "https://github.com/proof-foundry/pf-capsule-fixture",
    sourceCommit: "d52eedb6fcbf5ead060318e8fee0e60406dc19a2",
    releaseVersion: version,
    platforms: ["Windows"],
    modulePath: "product/module.json",
    releaseManifestPath: "release/release.json",
    checksumPath: "release/SHA256SUMS.txt",
    provenancePath: "provenance/source.json",
    artifactRefs: artifacts
  };
  const release = {
    schemaVersion: 1,
    productId: id,
    version,
    platforms: ["Windows"],
    artifacts,
    evidence: type === "PRESENTATION_UPDATE" ? [] : [{ id: "build-output", kind: "build", path: evidencePath, sha256: evidenceSha }],
    claims: type === "PRESENTATION_UPDATE" ? [] : [{ id: "archive-created", summary: "The submitted archive was produced.", evidenceIds: ["build-output"] }]
  };
  const provenance = {
    schemaVersion: 1,
    sourceRepository: capsule.sourceRepository,
    sourceCommit: capsule.sourceCommit,
    build: { builder: "fixture-builder", buildId: "fixture-1" }
  };
  saveJson(path.join(dir, "capsule.json"), capsule);
  saveJson(path.join(dir, "release/release.json"), release);
  saveJson(path.join(dir, "provenance/source.json"), provenance);
  fs.writeFileSync(path.join(dir, "release/SHA256SUMS.txt"), artifacts.map((a) => a.sha256 + "  " + a.path).join("\n") + (artifacts.length ? "\n" : ""), "utf8");
  return { dir, capsule, release, module: productModule, artifactPath };
}

function validate(dir) {
  const result = run(["validate", dir]);
  let report;
  try { report = JSON.parse(result.stdout); } catch { throw new Error("CLI did not return JSON: " + result.stderr + result.stdout); }
  return { result, report, text: result.stdout };
}

let assertions = 0;
function check(condition, message) { assert.ok(condition, message); assertions++; }

try {
  const operatorGuide = fs.readFileSync(path.join(ROOT, "PRODUCT_PUBLISHING.md"), "utf8");
  const workflow = ["inspect <capsule-directory>", "validate <capsule-directory>", "materialize <capsule-directory>", "preview <candidate-directory>", "qualify <candidate-directory>", "freeze <candidate-directory>"];
  const workflowPositions = workflow.map((step) => operatorGuide.indexOf(step));
  check(workflowPositions.every((position) => position >= 0) && workflowPositions.every((position, index) => index === 0 || position > workflowPositions[index - 1]), "operator guide documents the ordered inspect-to-freeze lifecycle");
  const lifecycleStates = ["INVALID", "VALID_UNVERIFIED", "QUALIFIED_UNPUBLISHED", "FROZEN_FOR_OWNER_REVIEW", "OWNER_APPROVED", "ARTIFACTS_PUBLISHED_VERIFIED", "SITE_PAYLOAD_QUALIFIED_UNDEPLOYED", "DEPLOYED_UNVERIFIED", "PUBLISHED_VERIFIED"];
  check(lifecycleStates.every((state) => operatorGuide.includes("`" + state + "`")), "operator guide names all publication lifecycle states");
  check(["NEW_PRODUCT", "NEW_VERSION", "PRESENTATION_UPDATE"].every((type) => operatorGuide.includes("`" + type + "`")), "operator guide distinguishes all supported submission types");
  check(/Freeze does not approve or publish/i.test(operatorGuide) && /owner-signed Ed25519 decision/i.test(operatorGuide) && /live mutation is disabled/i.test(operatorGuide), "operator guide preserves explicit owner approval and fixture-only live boundary");

  const valid = await makeCapsule("valid");
  const pass1 = validate(valid.dir), pass2 = validate(valid.dir);
  check(pass1.result.status === 0 && pass1.report.status === "VALID_UNVERIFIED", "valid package returns VALID_UNVERIFIED");
  check(pass1.report.moduleValidation.status === "PASS" && pass1.report.h13RegistryCompatibility.status === "PASS", "valid module passes the existing H13 registry/render path");
  check(pass1.report.artifactInventory[0].status === "PASS" && pass1.report.artifactSha256[0].sha256 === sha(fs.readFileSync(path.join(valid.dir, valid.artifactPath))), "artifact bytes and SHA-256 are inventoried");
  check(pass1.report.manifestCompatibility.status === "PASS" && pass1.report.publicationCollisions.length === 0, "new product has no current registry/manifest collision");
  check(pass1.text === pass2.text, "validation report is byte-deterministic");
  const inspect = run(["inspect", valid.dir]);
  check(inspect.status === 0 && inspect.stdout.includes("PF PRODUCT CAPSULE INVENTORY") && inspect.stdout.includes("CAPSULE_SHA256: "), "inspect prints a readable hashed inventory");
  check(!inspect.stdout.includes("proof-foundry/pf-capsule-fixture") && inspect.stdout.includes("SOURCE_REPOSITORY_PATH: [WITHHELD]"), "inspect withholds repository path components");

  const missing = copyCapsule(valid.dir, "missing-artifact");
  fs.rmSync(path.join(missing, valid.artifactPath));
  check(validate(missing).report.status === "INVALID", "missing artifact is rejected");

  const mismatch = copyCapsule(valid.dir, "hash-mismatch");
  fs.writeFileSync(path.join(mismatch, valid.artifactPath), "different bytes");
  check(validate(mismatch).report.validationErrors.some((x) => x.includes("SHA-256 mismatch")), "artifact hash mismatch is rejected");

  const unsafe = copyCapsule(valid.dir, "unsafe-path");
  const unsafeDoc = JSON.parse(fs.readFileSync(path.join(unsafe, "capsule.json"), "utf8"));
  unsafeDoc.artifactRefs[0].path = "release/artifacts/../../outside.zip";
  saveJson(path.join(unsafe, "capsule.json"), unsafeDoc);
  check(validate(unsafe).report.status === "INVALID", "path traversal is rejected");

  const duplicate = await makeCapsule("duplicate-id", { id: "cache-vault" });
  check(validate(duplicate.dir).report.publicationCollisions.some((x) => x.includes("already exists")), "duplicate product ID is rejected");

  const collision = copyCapsule(valid.dir, "route-collision");
  const collisionModule = JSON.parse(fs.readFileSync(path.join(collision, "product/module.json"), "utf8"));
  collisionModule.route = "/about/";
  saveJson(path.join(collision, "product/module.json"), collisionModule);
  check(validate(collision).report.publicationCollisions.length > 0, "reserved route collision is rejected");

  const semver = copyCapsule(valid.dir, "bad-semver");
  const semverDoc = JSON.parse(fs.readFileSync(path.join(semver, "capsule.json"), "utf8"));
  const semverRelease = JSON.parse(fs.readFileSync(path.join(semver, "release/release.json"), "utf8"));
  semverDoc.releaseVersion = "v1.2";
  semverRelease.version = "v1.2";
  saveJson(path.join(semver, "capsule.json"), semverDoc);
  saveJson(path.join(semver, "release/release.json"), semverRelease);
  check(validate(semver).report.schemaValidation.capsule === "FAIL", "bad semantic version is rejected");

  const missingMedia = copyCapsule(valid.dir, "missing-media");
  fs.rmSync(path.join(missingMedia, "product/media/hero.png"));
  check(validate(missingMedia).report.missingFields.some((x) => x.includes("hero.png")), "missing product media is rejected");

  const lifecycle = copyCapsule(valid.dir, "bad-lifecycle");
  const lifecycleDoc = JSON.parse(fs.readFileSync(path.join(lifecycle, "capsule.json"), "utf8"));
  lifecycleDoc.requestedLifecycle = "VERIFIED";
  saveJson(path.join(lifecycle, "capsule.json"), lifecycleDoc);
  check(validate(lifecycle).report.schemaValidation.capsule === "FAIL", "invalid lifecycle is rejected");

  const selfVerified = copyCapsule(valid.dir, "self-verified");
  const verifiedRelease = JSON.parse(fs.readFileSync(path.join(selfVerified, "release/release.json"), "utf8"));
  verifiedRelease.verification = { status: "VERIFIED" };
  saveJson(path.join(selfVerified, "release/release.json"), verifiedRelease);
  check(validate(selfVerified).report.validationErrors.some((x) => x.includes("not an input authority")), "self-asserted VERIFIED is rejected");

  const secret = copyCapsule(valid.dir, "secret-leak");
  const fake = "ghp_" + "A".repeat(32);
  fs.writeFileSync(path.join(secret, ".env"), "ACCESS_TOKEN=" + fake, "utf8");
  const secretReport = validate(secret);
  check(secretReport.report.status === "INVALID" && secretReport.report.securityPrivacyFindings.length > 0, "secret-like token and credential filename are rejected");
  check(!secretReport.text.includes(fake), "detected secret value is not echoed");

  const privatePath = copyCapsule(valid.dir, "private-path");
  fs.writeFileSync(path.join(privatePath, "notes.txt"), "Local build source: C:\\Users\\PrivateOwner\\Projects\\secret\\src\n", "utf8");
  check(validate(privatePath).report.securityPrivacyFindings.some((x) => x.includes("private-path")), "private/local source path is rejected");

  const unsafeUrl = copyCapsule(valid.dir, "unsafe-url");
  const urlModule = JSON.parse(fs.readFileSync(path.join(unsafeUrl, "product/module.json"), "utf8"));
  urlModule.hero.primaryAction.href = "javascript:alert(1)";
  saveJson(path.join(unsafeUrl, "product/module.json"), urlModule);
  check(validate(unsafeUrl).report.status === "INVALID", "active URL is rejected");

  const undeclared = copyCapsule(valid.dir, "undeclared-file");
  fs.writeFileSync(path.join(undeclared, "notes.txt"), "extra", "utf8");
  check(validate(undeclared).report.validationErrors.some((x) => x.includes("Undeclared capsule file")), "undeclared package file is rejected");

  const duplicateJson = copyCapsule(valid.dir, "duplicate-json-key");
  fs.writeFileSync(path.join(duplicateJson, "capsule.json"), '{"schemaVersion":1,"productId":"safe","productId":"different"}', "utf8");
  check(validate(duplicateJson).report.validationErrors.some((x) => x.includes("duplicate JSON property")), "duplicate JSON keys are rejected");

  const badSource = copyCapsule(valid.dir, "private-source-url");
  const badSourceDoc = JSON.parse(fs.readFileSync(path.join(badSource, "capsule.json"), "utf8"));
  badSourceDoc.sourceRepository = "https://127.0.0.1/private/repo";
  saveJson(path.join(badSource, "capsule.json"), badSourceDoc);
  check(validate(badSource).report.validationErrors.some((x) => x.includes("public host")), "private/local repository URL is rejected");

  const presentation = await makeCapsule("presentation-update", { id: "cache-vault", type: "PRESENTATION_UPDATE" });
  const presentationResult = validate(presentation.dir);
  check(presentationResult.result.status === 0 && presentationResult.report.status === "VALID_UNVERIFIED", "presentation update without new artifacts is accepted as unverified");
  check(presentationResult.report.artifactInventory.length === 0, "presentation update does not invent artifact refs");

  const profiles = copyCapsule(valid.dir, "bounded-qualification-profiles");
  const profilesDoc = JSON.parse(fs.readFileSync(path.join(profiles, "capsule.json"), "utf8"));
  profilesDoc.qualificationProfiles = ["H13_REGISTRY", "LOCAL_ARTIFACT_HASH"];
  saveJson(path.join(profiles, "capsule.json"), profilesDoc);
  check(validate(profiles).report.status === "VALID_UNVERIFIED", "only named built-in qualification profiles are accepted");

  const arbitraryCommand = copyCapsule(valid.dir, "arbitrary-test-command");
  const arbitraryDoc = JSON.parse(fs.readFileSync(path.join(arbitraryCommand, "capsule.json"), "utf8"));
  arbitraryDoc.testCommand = "anything the submitter wants";
  saveJson(path.join(arbitraryCommand, "capsule.json"), arbitraryDoc);
  check(validate(arbitraryCommand).report.status === "INVALID", "arbitrary submitted test commands are rejected");

  console.log("PF PRODUCT CAPSULE QUALIFICATION: " + assertions + " passed, 0 failed");
} finally {
  const resolved = path.resolve(TEMP), base = path.resolve(os.tmpdir()) + path.sep;
  if (resolved.startsWith(base) && path.basename(resolved).startsWith("pf-product-tests-")) fs.rmSync(resolved, { recursive: true, force: true });
}
