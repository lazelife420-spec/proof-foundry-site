import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";
import { assertCandidateBaseBinding, verifyPublisherSourceBaseForRepository } from "./pf-product-p3-p5.mjs";
import { assertApprovedSiteBase } from "./pf-product-p7-p9.mjs";

const temp = fs.mkdtempSync(path.join(os.tmpdir(), "pf-product-source-base-"));
const repoRoot = path.join(temp, "site");
const publisherSourcePaths = new Set(["scripts/publisher.mjs"]);
let passed = 0;

function git(...args) {
  const result = spawnSync("git", ["-c", "core.autocrlf=false", "-c", "commit.gpgsign=false", ...args], {
    cwd: repoRoot, encoding: "utf8", timeout: 15000, windowsHide: true
  });
  assert.equal(result.status, 0, `git ${args[0]} failed: ${result.stderr || result.error || "unknown error"}`);
  return result.stdout.trim();
}
function write(rel, value) {
  const dest = path.join(repoRoot, ...rel.split("/"));
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, value, "utf8");
}
function sha(value) { return crypto.createHash("sha256").update(value).digest("hex"); }
function commit(message, ...paths) {
  git("add", "--", ...paths);
  git("-c", "user.name=Source Base Test", "-c", "user.email=source-base@example.invalid", "commit", "-qm", message);
  return git("rev-parse", "HEAD");
}
function check(condition, message) { assert.ok(condition, message); passed++; }
function packageBase(base) {
  return {
    approval: { baseSiteCommit: base.commit, baseSiteTree: base.tree },
    sourceBinding: { baseSiteCommit: base.commit, baseSiteTree: base.tree, baseManifestSha256: base.manifestSha256 },
    state: { baseCommit: base.commit, baseTree: base.tree, baseManifestSha256: base.manifestSha256 }
  };
}
function assertPackageBase(pkg, base) {
  assertApprovedSiteBase(pkg.approval, pkg.sourceBinding, pkg.state, base);
}

try {
  fs.mkdirSync(repoRoot);
  git("init", "-q", "-b", "main");
  const rootManifest = '{"version":0}\n';
  write("site-manifest.json", rootManifest);
  write("index.html", "baseline\n");
  const frozenSiteCommit = commit("frozen site", "site-manifest.json", "index.html");
  const frozenSiteTree = git("show", "-s", "--format=%T", frozenSiteCommit);
  const options = { repoRoot, frozenSiteCommit, frozenSiteTree,
    frozenManifestSha256: sha(rootManifest), publisherSourcePaths };

  write("scripts/publisher.mjs", "export const version = 1;\n");
  const integrationCommit = commit("publisher integration", "scripts/publisher.mjs");
  let base = verifyPublisherSourceBaseForRepository(options);
  check(base.commit === frozenSiteCommit && base.tree === frozenSiteTree &&
    base.publisherCommit === integrationCommit, "publisher-only integration retains the frozen site base");
  const frozenCandidateState = { baseCommit: base.commit, baseTree: base.tree, baseManifestSha256: base.manifestSha256 };
  assert.doesNotThrow(() => assertCandidateBaseBinding(frozenCandidateState, base));
  passed++;
  const frozenPackageBase = packageBase(base);
  assert.doesNotThrow(() => assertPackageBase(frozenPackageBase, base));
  passed++;

  const correctedManifest = '{"version":1}\n';
  write("site-manifest.json", correctedManifest);
  write("products/reality-gate/content.html", "corrected truth\n");
  const correctionCommit = commit("site correction", "site-manifest.json", "products/reality-gate/content.html");
  base = verifyPublisherSourceBaseForRepository(options);
  check(base.commit === correctionCommit && base.tree === git("show", "-s", "--format=%T", correctionCommit) &&
    base.manifestSha256 === sha(correctedManifest), "committed site correction binds its exact commit, tree, and manifest bytes");
  assert.throws(() => assertCandidateBaseBinding(frozenCandidateState, base), /Candidate site base advanced/i);
  passed++;
  const correctionCandidateState = { baseCommit: base.commit, baseTree: base.tree, baseManifestSha256: base.manifestSha256 };
  assert.throws(() => assertPackageBase(frozenPackageBase, base), (error) => error.code === "APPROVAL_STALE");
  passed++;
  const correctionPackageBase = packageBase(base);
  assert.doesNotThrow(() => assertPackageBase(correctionPackageBase, base));
  passed++;

  write("products/reality-gate/content.html", "later committed truth\n");
  const contentCommit = commit("content-only site correction", "products/reality-gate/content.html");
  base = verifyPublisherSourceBaseForRepository(options);
  check(base.commit === contentCommit && base.manifestSha256 === sha(correctedManifest),
    "content-only site correction advances the base even without a manifest change");
  assert.throws(() => assertCandidateBaseBinding(correctionCandidateState, base), /Candidate site base advanced/i);
  passed++;
  assert.throws(() => assertPackageBase(correctionPackageBase, base), (error) => error.code === "APPROVAL_STALE");
  passed++;
  const contentPackageBase = packageBase(base);
  assert.doesNotThrow(() => assertPackageBase(contentPackageBase, base));
  passed++;

  write("scripts/publisher.mjs", "export const version = 2;\n");
  const laterPublisherCommit = commit("publisher update", "scripts/publisher.mjs");
  base = verifyPublisherSourceBaseForRepository(options);
  check(base.commit === contentCommit && base.publisherCommit === laterPublisherCommit,
    "later publisher-only commit retains the corrected site base");
  assert.doesNotThrow(() => assertPackageBase(contentPackageBase, base));
  passed++;

  write("scripts/publisher.mjs", "export const version = 3;\n");
  check(verifyPublisherSourceBaseForRepository(options).commit === contentCommit,
    "publisher implementation may be edited before the clean owner-review freeze");
  git("restore", "--", "scripts/publisher.mjs");

  write("site-manifest.json", '{"version":2}\n');
  assert.throws(() => verifyPublisherSourceBaseForRepository(options), /manifest differs/i);
  passed++;
  git("restore", "--", "site-manifest.json");

  write("products/reality-gate/content.html", "uncommitted truth\n");
  assert.throws(() => verifyPublisherSourceBaseForRepository(options), /Non-publisher source differs/i);
  passed++;
  git("restore", "--", "products/reality-gate/content.html");

  write("untracked-site.txt", "uncommitted site file\n");
  assert.throws(() => verifyPublisherSourceBaseForRepository(options), /Non-publisher source differs/i);
  passed++;
  fs.unlinkSync(path.join(repoRoot, "untracked-site.txt"));

  assert.throws(() => verifyPublisherSourceBaseForRepository({ ...options, frozenSiteTree: "0".repeat(40) }), /receipt does not match/i);
  passed++;
  assert.throws(() => verifyPublisherSourceBaseForRepository({ ...options, frozenManifestSha256: "0".repeat(64) }), /receipt does not match/i);
  passed++;

  git("checkout", "-qb", "merge-feature");
  write("feature.txt", "feature branch\n");
  commit("feature branch change", "feature.txt");
  git("checkout", "-q", "main");
  git("-c", "user.name=Source Base Test", "-c", "user.email=source-base@example.invalid", "merge", "-q", "--no-ff", "merge-feature");
  assert.throws(() => verifyPublisherSourceBaseForRepository(options), /unsupported merge/i);
  passed++;

  git("checkout", "-q", "--detach", integrationCommit);
  assert.throws(() => verifyPublisherSourceBaseForRepository({ ...options,
    frozenSiteCommit: correctionCommit,
    frozenSiteTree: git("show", "-s", "--format=%T", correctionCommit),
    frozenManifestSha256: sha(correctedManifest)
  }), /first-parent lineage/i);
  passed++;

  console.log(`PF PRODUCT SOURCE BASE: ${passed} passed, 0 failed`);
} finally {
  const resolved = path.resolve(temp), tempRoot = path.resolve(os.tmpdir()) + path.sep;
  if (!resolved.startsWith(tempRoot) || !path.basename(resolved).startsWith("pf-product-source-base-")) {
    throw new Error("Source-base test cleanup escaped its own temporary directory.");
  }
  fs.rmSync(resolved, { recursive: true, force: true });
}
