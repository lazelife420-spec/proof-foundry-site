import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const BASE_PROJECT = "proof-foundry-site";
const BASE_BRANCH = "main";
const R2_BUCKET = "proof-foundry-downloads";
const DOWNLOAD_ORIGIN = "https://downloads.theprooffoundry.com";
const SITE_ORIGIN = "https://theprooffoundry.com";
const LIVE_MUTATION_ENABLED = false;
const ACTIONS = new Set(["PUBLISH_ARTIFACTS", "PROMOTE_CANONICAL_STATE", "DEPLOY_SITE", "VERIFY_LIVE"]);
const HEX64 = /^[0-9a-f]{64}$/;
const HEX40 = /^[0-9a-f]{40}$/;
const SEMVER = /^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/;

export class PublicationError extends Error {
  constructor(code, message = code, details = {}) { super(message); this.name = "PublicationError"; this.code = code; this.details = details; }
}

function sorted(value) {
  if (Array.isArray(value)) return value.map(sorted);
  if (value && typeof value === "object") {
    const out = {};
    for (const key of Object.keys(value).sort((a, b) => a.localeCompare(b, "en"))) out[key] = sorted(value[key]);
    return out;
  }
  return value;
}
export function canonical(value) { return JSON.stringify(sorted(value)); }
export function sha256(bytes) { return crypto.createHash("sha256").update(bytes).digest("hex"); }
const pretty = (value) => JSON.stringify(sorted(value), null, 2) + "\n";
const exists = (file) => { try { fs.accessSync(file); return true; } catch { return false; } };
function assertHex(value, length, label) { if (typeof value !== "string" || !(length === 40 ? HEX40 : HEX64).test(value)) throw new PublicationError("INVALID_BINDING", label + " is malformed."); }
function safeRel(value) {
  return typeof value === "string" && !!value && !value.includes("\\") && !value.startsWith("/") &&
    !/^[A-Za-z]:/.test(value) && !/[:?#]/.test(value) && value.split("/").every((p) => p && p !== "." && p !== ".." && /^[A-Za-z0-9._-]+$/.test(p));
}
function resolveInside(root, rel) {
  if (!safeRel(rel)) throw new PublicationError("UNSAFE_PATH", "An input path is unsafe.");
  const base = path.resolve(root), result = path.resolve(base, ...rel.split("/"));
  if (!result.startsWith(base + path.sep)) throw new PublicationError("UNSAFE_PATH", "An input path escapes its package.");
  return result;
}
function isWithin(parent, child) {
  const rel = path.relative(path.resolve(parent), path.resolve(child));
  return rel === "" || (rel !== ".." && !rel.startsWith(".." + path.sep) && !path.isAbsolute(rel));
}
function assertDirectoryNoLink(dir) {
  const st = fs.lstatSync(dir);
  if (!st.isDirectory() || st.isSymbolicLink()) throw new PublicationError("INVALID_DIRECTORY", "Expected a real directory.");
}
function readJson(file) {
  try { return JSON.parse(fs.readFileSync(file, "utf8")); }
  catch { throw new PublicationError("INVALID_JSON", "A required publication record is missing or invalid."); }
}
async function writeJson(file, value) {
  await fsp.mkdir(path.dirname(file), { recursive: true });
  const tmp = file + ".tmp-" + crypto.randomBytes(6).toString("hex");
  await fsp.writeFile(tmp, pretty(value), "utf8");
  await fsp.rename(tmp, file);
}
async function walkFiles(root) {
  const files = [];
  async function walk(dir, prefix) {
    const entries = await fsp.readdir(dir, { withFileTypes: true });
    entries.sort((a, b) => a.name.localeCompare(b.name, "en"));
    for (const entry of entries) {
      const rel = prefix ? prefix + "/" + entry.name : entry.name;
      const full = path.join(dir, entry.name), st = await fsp.lstat(full);
      if (st.isSymbolicLink()) throw new PublicationError("UNSAFE_FILESYSTEM_ENTRY", "Publication input contains a link.");
      if (st.isDirectory()) await walk(full, rel);
      else if (st.isFile()) files.push({ path: rel, full, sizeBytes: st.size });
      else throw new PublicationError("UNSAFE_FILESYSTEM_ENTRY", "Publication input contains an unsupported filesystem entry.");
    }
  }
  await walk(root, "");
  return files;
}
async function inventoryDigest(root) {
  const files = await walkFiles(root), lines = [];
  for (const file of files) {
    const bytes = await fsp.readFile(file.full);
    lines.push(file.path + "\0" + bytes.length + "\0" + sha256(bytes) + "\n");
  }
  return { files, sha256: sha256(Buffer.from(lines.join(""), "utf8")) };
}
function runGit(args, cwd = ROOT, env = process.env, required = true) {
  const result = spawnSync("git", args, { cwd, env, encoding: "utf8", windowsHide: true, timeout: 120000, maxBuffer: 16 * 1024 * 1024 });
  if (result.error || (required && result.status !== 0)) throw new PublicationError("SOURCE_BINDING_FAILED", "A Git source-binding check failed.");
  return { status: result.status ?? 2, stdout: (result.stdout || "").trim(), stderr: result.stderr || "" };
}
function protectedMasterRoot() {
  const common = runGit(["rev-parse", "--git-common-dir"]).stdout;
  return path.dirname(path.resolve(ROOT, common));
}
function readGitBlob(commit, rel) {
  if (!safeRel(rel)) throw new PublicationError("UNSAFE_PATH", "Canonical source path is unsafe.");
  const result = spawnSync("git", ["show", "--no-textconv", commit + ":" + rel], { cwd: ROOT, windowsHide: true, timeout: 30000, maxBuffer: 64 * 1024 * 1024 });
  if (result.error) throw new PublicationError("SOURCE_BINDING_FAILED", "Could not read the approved base image.");
  if (result.status !== 0) return null;
  return Buffer.from(result.stdout);
}
function currentPublisherIdentity() {
  const commit = runGit(["rev-parse", "HEAD"]).stdout;
  const tree = runGit(["show", "-s", "--format=%T", "HEAD"]).stdout;
  const status = runGit(["status", "--porcelain", "--untracked-files=all"]).stdout;
  if (status) throw new PublicationError("DIRTY_PUBLISHER_SOURCE", "Publication requires the exact committed publisher source.");
  return { commit, tree };
}
function verifyPublisherAncestry(expected) {
  assertHex(expected.publisherCommit, 40, "Publisher commit");
  assertHex(expected.publisherTree, 40, "Publisher tree");
  const tree = runGit(["show", "-s", "--format=%T", expected.publisherCommit]).stdout;
  if (tree !== expected.publisherTree) throw new PublicationError("APPROVAL_STALE", "Approval publisher tree does not match its commit.");
  const ancestor = runGit(["merge-base", "--is-ancestor", expected.publisherCommit, "HEAD"], ROOT, process.env, false);
  if (ancestor.status !== 0) throw new PublicationError("APPROVAL_STALE", "Approval publisher commit is not an ancestor of the running publisher.");
  const current = currentPublisherIdentity();
  return { ...current, approvalPublisherCommit: expected.publisherCommit, approvalPublisherTree: expected.publisherTree };
}
export function deterministicApprovalDigest(approval) {
  const { createdAt, approvalPackageDigest, ...stable } = approval;
  return sha256(Buffer.from(canonical(stable), "utf8"));
}
function approvalSigningPayload(record) {
  const { signature, ...payload } = record;
  return Buffer.from(canonical(payload), "utf8");
}
function approvalIdPayload(record) {
  const { approvalId, signature, ...payload } = record;
  return sha256(Buffer.from(canonical(payload), "utf8"));
}
export function ownerKeyId(publicKey) {
  const key = publicKey && publicKey.type === "public" ? publicKey : crypto.createPublicKey(publicKey);
  return sha256(key.export({ type: "spki", format: "der" })).slice(0, 24);
}
export function verifyOwnerApproval(expected, record, publicKey, action) {
  const fail = (code) => { throw new PublicationError(code, code); };
  if (!expected || !record || record.approvalVersion !== 1 || record.decision !== "OWNER_APPROVED") fail("OWNER_APPROVAL_REQUIRED");
  const required = ["approvalVersion", "decision", "approvalId", "approvalPackageDigest", "candidateId", "candidateDigest", "capsuleSha256", "publisherCommit", "publisherTree", "baseSiteCommit", "baseSiteTree", "productId", "submissionType", "artifactSha256", "approvedActions", "approvedAt", "signatureAlgorithm", "signerKeyId", "signature"];
  const allowed = new Set(required);
  if (required.some((field) => !Object.hasOwn(record, field)) || Object.keys(record).some((field) => !allowed.has(field))) fail("INVALID_OWNER_APPROVAL");
  const fields = ["approvalPackageDigest", "candidateId", "candidateDigest", "capsuleSha256", "publisherCommit", "publisherTree", "baseSiteCommit", "baseSiteTree", "productId", "submissionType"];
  if (fields.some((field) => expected[field] !== record[field])) fail("APPROVAL_STALE");
  if (canonical(expected.artifactSha256 || []) !== canonical(record.artifactSha256 || [])) fail("APPROVAL_STALE");
  if (!HEX64.test(record.approvalPackageDigest || "") || !HEX64.test(record.candidateDigest || "") || !HEX64.test(record.capsuleSha256 || "")) fail("APPROVAL_STALE");
  if (!HEX40.test(record.publisherCommit || "") || !HEX40.test(record.publisherTree || "") || !HEX40.test(record.baseSiteCommit || "") || !HEX40.test(record.baseSiteTree || "")) fail("APPROVAL_STALE");
  if (!Array.isArray(record.artifactSha256) || record.artifactSha256.some((x) => !HEX64.test(x)) || new Set(record.artifactSha256).size !== record.artifactSha256.length) fail("INVALID_OWNER_APPROVAL");
  if (!Array.isArray(record.approvedActions) || new Set(record.approvedActions).size !== record.approvedActions.length || record.approvedActions.some((x) => !ACTIONS.has(x))) fail("INVALID_APPROVED_ACTIONS");
  if (!record.approvedActions.includes(action)) fail("APPROVED_ACTION_REQUIRED");
  if (typeof record.approvedAt !== "string" || !Number.isFinite(Date.parse(record.approvedAt))) fail("INVALID_OWNER_APPROVAL");
  let key, verified = false;
  try {
    if (Buffer.isBuffer(publicKey) && (!publicKey.toString("utf8").startsWith("-----BEGIN PUBLIC KEY-----") || publicKey.toString("utf8").includes("PRIVATE KEY"))) fail("INVALID_OWNER_PUBLIC_KEY");
    key = crypto.createPublicKey(publicKey);
    if (key.asymmetricKeyType !== "ed25519" || record.signatureAlgorithm !== "Ed25519" || record.signerKeyId !== ownerKeyId(key)) fail("INVALID_OWNER_APPROVAL_SIGNATURE");
    if (record.approvalId !== approvalIdPayload(record)) fail("INVALID_OWNER_APPROVAL_SIGNATURE");
    verified = crypto.verify(null, approvalSigningPayload(record), key, Buffer.from(record.signature || "", "base64"));
  } catch (error) {
    if (error instanceof PublicationError) throw error;
    fail("INVALID_OWNER_APPROVAL_SIGNATURE");
  }
  if (!verified) fail("INVALID_OWNER_APPROVAL_SIGNATURE");
  return { approvalId: record.approvalId, approvedAt: record.approvedAt, approvedActions: [...record.approvedActions], signerKeyId: record.signerKeyId };
}

function capsulePackageDigest(candidateRoot) {
  const capsuleRoot = path.join(candidateRoot, "submitted-capsule");
  assertDirectoryNoLink(capsuleRoot);
  const rows = [];
  function walk(dir, prefix) {
    const entries = fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name, "en"));
    for (const entry of entries) {
      const rel = prefix ? prefix + "/" + entry.name : entry.name, full = path.join(dir, entry.name), st = fs.lstatSync(full);
      if (st.isSymbolicLink()) throw new PublicationError("CANDIDATE_INVALID", "The submitted Capsule contains a link.");
      if (st.isDirectory()) walk(full, rel);
      else if (st.isFile()) { const bytes = fs.readFileSync(full); rows.push(rel + "\0" + bytes.length + "\0" + sha256(bytes) + "\n"); }
      else throw new PublicationError("CANDIDATE_INVALID", "The submitted Capsule contains an unsupported entry.");
    }
  }
  walk(capsuleRoot, "");
  return sha256(Buffer.from(rows.join(""), "utf8"));
}
function candidateDigestFromState(state, stateSourceBytes) {
  const payload = {
    candidateSchemaVersion: 1, baseCommit: state.baseCommit, baseTree: state.baseTree,
    baseManifestSha256: state.baseManifestSha256, capsuleSha256: state.createdFromCapsuleSha256,
    submissionType: state.submissionType, productId: state.productId, releaseVersion: state.releaseVersion,
    proposedPaths: state.proposedPaths, candidateStateSourceSha256: state.candidateStateSourceSha256,
    artifacts: state.artifacts, evidence: state.evidence, claims: state.claims,
    qualificationProfiles: state.qualificationProfiles || []
  };
  if (sha256(stateSourceBytes) !== state.candidateStateSourceSha256) throw new PublicationError("CANDIDATE_INVALID", "Candidate state source bytes changed.");
  return sha256(Buffer.from(canonical(payload), "utf8"));
}
function same(a, b) { return canonical(a) === canonical(b); }

export async function loadFrozenPackage(packageDirArg, { approvalRecordPath, approvalPublicKeyPath, action } = {}) {
  const packageDir = path.resolve(packageDirArg);
  assertDirectoryNoLink(packageDir);
  const candidateRoot = path.dirname(packageDir);
  assertDirectoryNoLink(candidateRoot);
  const master = protectedMasterRoot();
  if (isWithin(ROOT, candidateRoot) || isWithin(candidateRoot, ROOT) || isWithin(master, candidateRoot) || isWithin(candidateRoot, master)) {
    throw new PublicationError("CANDIDATE_INVALID", "Frozen candidate packages must remain outside all source checkouts.");
  }
  const approvalPath = path.join(packageDir, "candidate-approval.json");
  const approval = readJson(approvalPath);
  if (approval.approvalState !== "FROZEN_FOR_OWNER_REVIEW" || approval.livePublication !== "NOT_RUN") throw new PublicationError("CANDIDATE_NOT_FROZEN", "Only a frozen unpublished package can enter publication.");
  if (approval.approvalPackageDigest !== deterministicApprovalDigest(approval)) throw new PublicationError("APPROVAL_STALE", "Frozen approval package digest is invalid.");
  if (!approvalRecordPath || !approvalPublicKeyPath) throw new PublicationError("OWNER_APPROVAL_REQUIRED", "A signed owner approval record and public key are required.");
  const ownerRecord = readJson(path.resolve(approvalRecordPath));
  const publicKey = fs.readFileSync(path.resolve(approvalPublicKeyPath));
  const ownerApproval = verifyOwnerApproval(approval, ownerRecord, publicKey, action);
  verifyPublisherAncestry(approval);

  const packageFiles = [
    "candidate-approval.json", "candidate-changed-paths.json", "candidate-artifacts.json",
    "candidate-qualification.json", "candidate-preview.json", "candidate-source-binding.json",
    "candidate-approval-summary.txt"
  ];
  const actualFiles = (await walkFiles(packageDir)).map((x) => x.path).sort();
  if (!same(actualFiles, [...packageFiles].sort())) throw new PublicationError("CANDIDATE_INVALID", "Frozen owner-review package inventory differs from P6.");

  const statePath = path.join(candidateRoot, "candidate-state.json");
  const stateBytes = fs.readFileSync(statePath), state = JSON.parse(stateBytes.toString("utf8"));
  const stateSourceBytes = fs.readFileSync(path.join(candidateRoot, "candidate-state-source.json"));
  const candidateArtifacts = readJson(path.join(packageDir, "candidate-artifacts.json"));
  const changedPaths = readJson(path.join(packageDir, "candidate-changed-paths.json"));
  const sourceBinding = readJson(path.join(packageDir, "candidate-source-binding.json"));
  const preview = readJson(path.join(packageDir, "candidate-preview.json"));
  const qualification = readJson(path.join(packageDir, "candidate-qualification.json"));
  const dimensions = qualification.qualificationDimensions || {};
  const qualificationResults = qualification.qualificationResults || [];
  if (qualification.livePublication !== "NOT_RUN" || preview.livePublication !== "NOT_RUN" ||
      !Object.keys(dimensions).length || Object.entries(dimensions).some(([key, value]) => key === "LIVE_PUBLICATION_VALID" ? value !== "NOT_RUN" : value !== "PASS") ||
      !qualificationResults.length || qualificationResults.some((x) => x.status !== "PASS") ||
      !same(approval.qualificationDimensions, dimensions) || !same(approval.qualificationResults, qualificationResults)) {
    throw new PublicationError("CANDIDATE_NOT_QUALIFIED", "Frozen package does not bind a complete unpublished qualification result.");
  }
  const identityPairs = [
    [state.candidateId, approval.candidateId], [state.candidateDigest, approval.candidateDigest],
    [state.productId, approval.productId], [state.submissionType, approval.submissionType],
    [state.createdFromCapsuleSha256, approval.capsuleSha256], [sha256(stateBytes), approval.candidateStateSha256],
    [sourceBinding.publisherCommit, approval.publisherCommit], [sourceBinding.publisherTree, approval.publisherTree],
    [sourceBinding.baseSiteCommit, approval.baseSiteCommit], [sourceBinding.baseSiteTree, approval.baseSiteTree],
    [sourceBinding.candidateDigest, approval.candidateDigest], [sourceBinding.capsuleSha256, approval.capsuleSha256],
    [candidateArtifacts.candidateId, approval.candidateId], [candidateArtifacts.productId, approval.productId],
    [preview.candidateDigest, approval.candidateDigest], [qualification.candidateDigest, approval.candidateDigest]
  ];
  if (identityPairs.some(([a, b]) => a !== b) || !same(state.proposedPaths, approval.proposedPaths) || !same(changedPaths, approval.proposedPaths)) {
    throw new PublicationError("APPROVAL_STALE", "Frozen candidate files no longer match the signed approval.");
  }
  assertHex(sourceBinding.baseManifestSha256, 64, "Base manifest SHA-256");
  if (capsulePackageDigest(candidateRoot) !== approval.capsuleSha256) throw new PublicationError("APPROVAL_STALE", "Submitted Capsule bytes no longer match the frozen approval.");
  if (candidateDigestFromState(state, stateSourceBytes) !== approval.candidateDigest) throw new PublicationError("APPROVAL_STALE", "Candidate state digest no longer matches the signed approval.");
  if (!same(candidateArtifacts.artifactInventory, approval.artifactInventory) || !same(candidateArtifacts.artifactSha256, approval.artifactSha256) ||
      !same(candidateArtifacts.artifactInventory, state.artifacts) || !same(candidateArtifacts.evidenceInventory, state.evidence)) {
    throw new PublicationError("APPROVAL_STALE", "Frozen artifact inventory differs from the signed candidate.");
  }
  for (const artifact of approval.artifactInventory || []) {
    const rel = "candidate-artifacts/" + artifact.packagePath, file = resolveInside(candidateRoot, rel), bytes = fs.readFileSync(file);
    if (bytes.length !== artifact.sizeBytes || sha256(bytes) !== artifact.computedSha256) throw new PublicationError("APPROVAL_STALE", "Candidate artifact bytes changed after freeze.");
  }
  for (const change of approval.proposedPaths || []) {
    const file = resolveInside(candidateRoot, "proposed-source/" + change.path);
    if (!fs.existsSync(file) || sha256(fs.readFileSync(file)) !== change.postImageSha256) throw new PublicationError("APPROVAL_STALE", "Proposed source bytes changed after freeze.");
  }
  const capsule = readJson(path.join(candidateRoot, "submitted-capsule", "capsule.json"));
  const release = readJson(resolveInside(path.join(candidateRoot, "submitted-capsule"), capsule.releaseManifestPath));
  if (capsule.productId !== approval.productId || capsule.submissionType !== approval.submissionType || capsule.releaseVersion !== state.releaseVersion || release.productId !== approval.productId || release.version !== state.releaseVersion) {
    throw new PublicationError("APPROVAL_STALE", "Capsule release identity differs from the signed candidate.");
  }
  return { packageDir, candidateRoot, approval, ownerRecord, ownerApproval, ownerPublicKey: publicKey, state, capsule, release, candidateArtifacts, sourceBinding };
}

function mimeType(file) {
  const ext = path.extname(file).toLowerCase();
  return ({ ".zip": "application/zip", ".msi": "application/x-msi", ".exe": "application/vnd.microsoft.portable-executable", ".apk": "application/vnd.android.package-archive", ".dmg": "application/x-apple-diskimage", ".tar": "application/x-tar", ".gz": "application/gzip", ".json": "application/json", ".txt": "text/plain; charset=utf-8", ".pdf": "application/pdf" })[ext] || "application/octet-stream";
}
function encodeKey(key) { return key.split("/").map(encodeURIComponent).join("/"); }
function objectUrl(key) { return DOWNLOAD_ORIGIN + "/" + encodeKey(key); }

export function buildR2PutCommand(object, { remote = true, bucket = R2_BUCKET } = {}) {
  if (remote !== true) throw new PublicationError("R2_REMOTE_REQUIRED", "R2 publication plans must explicitly target remote storage.");
  if (bucket !== R2_BUCKET) throw new PublicationError("R2_BUCKET_MISMATCH", "R2 publication bucket is fixed by the publisher contract.");
  const keyParts = String(object.objectKey || "").split("/");
  if (keyParts.length !== 3 || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(keyParts[0]) || !/^v\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?(?:\+[A-Za-z0-9.-]+)?$/.test(keyParts[1]) || !safeRel(keyParts[2])) {
    throw new PublicationError("R2_OBJECT_PATH_MISMATCH", "R2 object key must be a versioned product release object.");
  }
  const escape = (value) => "'" + String(value).replaceAll("'", "''") + "'";
  return "wrangler r2 object put " + escape(R2_BUCKET + "/" + object.objectKey) +
    " --file " + escape(object.sourcePath) + " --remote --content-type " + escape(object.contentType) +
    " --content-disposition " + escape(object.contentDisposition) + " --cache-control " + escape(object.cachePolicy);
}
export function makeArtifactDryRun(approvalId, plan) {
  return { state: "DRY_RUN_ONLY", approvalId, plan, mutationPerformed: false };
}
export async function buildR2Plan(context) {
  const { approval, candidateRoot, state, capsule, release } = context;
  const productId = approval.productId, version = state.releaseVersion;
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(productId) || !SEMVER.test(version)) throw new PublicationError("INVALID_RELEASE_PATH", "Product slug or release version is unsafe.");
  const prefix = productId + "/v" + version + "/", rows = [];
  for (const artifact of approval.artifactInventory || []) {
    const filename = path.posix.basename(artifact.packagePath);
    if (!safeRel(filename) || filename.includes("/")) throw new PublicationError("INVALID_RELEASE_PATH", "Artifact filename is unsafe.");
    const sourcePath = resolveInside(candidateRoot, "candidate-artifacts/" + artifact.packagePath);
    const bytes = await fsp.readFile(sourcePath), digest = sha256(bytes);
    if (bytes.length !== artifact.sizeBytes || digest !== artifact.computedSha256 || !approval.artifactSha256.includes(digest)) throw new PublicationError("ARTIFACT_HASH_MISMATCH", "Candidate artifact bytes do not match approval.");
    const objectKey = prefix + filename;
    rows.push({ role: "artifact", packagePath: artifact.packagePath, sourcePath, objectKey, byteLength: bytes.length, sha256: digest,
      contentType: mimeType(filename), contentDisposition: 'attachment; filename="' + filename + '"', cachePolicy: "public, max-age=31536000, immutable", publicUrl: objectUrl(objectKey), platform: artifact.platform || null });
  }
  if (rows.length) {
    const checksumRel = capsule.checksumPath;
    const checksumSource = resolveInside(path.join(candidateRoot, "submitted-capsule"), checksumRel);
    const checksumBytes = await fsp.readFile(checksumSource);
    const checksumText = checksumBytes.toString("utf8");
    for (const item of rows) if (!checksumText.includes(item.sha256)) throw new PublicationError("CHECKSUM_FILE_MISMATCH", "Approved checksum file does not contain every artifact digest.");
    rows.push({ role: "checksums", packagePath: checksumRel, sourcePath: checksumSource, objectKey: prefix + "SHA256SUMS.txt", byteLength: checksumBytes.length,
      sha256: sha256(checksumBytes), contentType: "text/plain; charset=utf-8", contentDisposition: "inline", cachePolicy: "public, max-age=31536000, immutable", publicUrl: objectUrl(prefix + "SHA256SUMS.txt") });
    const releaseSource = resolveInside(path.join(candidateRoot, "submitted-capsule"), capsule.releaseManifestPath);
    const releaseBytes = await fsp.readFile(releaseSource);
    if (release.version !== version || release.productId !== productId) throw new PublicationError("RELEASE_RECORD_MISMATCH", "Release record does not match approved candidate.");
    rows.push({ role: "release-record", packagePath: capsule.releaseManifestPath, sourcePath: releaseSource, objectKey: prefix + "release.json", byteLength: releaseBytes.length,
      sha256: sha256(releaseBytes), contentType: "application/json", contentDisposition: "inline", cachePolicy: "public, max-age=31536000, immutable", publicUrl: objectUrl(prefix + "release.json") });
  } else if (approval.submissionType !== "PRESENTATION_UPDATE") {
    throw new PublicationError("ARTIFACT_INVENTORY_EMPTY", "A release candidate must contain at least one approved artifact.");
  }
  const objectKeys = rows.map((x) => x.objectKey);
  if (new Set(objectKeys).size !== objectKeys.length) throw new PublicationError("DUPLICATE_OBJECT_KEY", "R2 plan contains duplicate object keys.");
  return { schemaVersion: 1, bucket: R2_BUCKET, immutableVersionedObjects: true, productId, version, objectCount: rows.length, objects: rows,
    remoteRequired: true, planSha256: sha256(Buffer.from(canonical(rows.map(({ sourcePath, ...rest }) => rest)), "utf8")),
    commands: rows.map((item) => buildR2PutCommand(item, { remote: true })) };
}

export class MemoryR2FixtureTransport {
  constructor({ failPutAt = null, publicOverrides = {} } = {}) { this.objects = new Map(); this.putCount = 0; this.failPutAt = failPutAt; this.publicOverrides = publicOverrides; this.deletedKeys = []; }
  async head(object) { return this.objects.get(object.objectKey) || null; }
  async put(object, bytes, { remote } = {}) {
    if (remote !== true) throw new PublicationError("R2_REMOTE_REQUIRED");
    this.putCount++;
    if (this.failPutAt === this.putCount) throw new PublicationError("R2_WRITE_FAILED", "Fixture transport injected a write failure.");
    const current = this.objects.get(object.objectKey);
    if (current) {
      if (sha256(current.bytes) !== sha256(bytes) || !same(current.headers, { "content-type": object.contentType, "content-disposition": object.contentDisposition, "cache-control": object.cachePolicy })) {
        throw new PublicationError("IMMUTABLE_OBJECT_CONFLICT", "A versioned R2 object already exists with different bytes or metadata.");
      }
      return { status: "ALREADY_PRESENT_VERIFIED" };
    }
    this.objects.set(object.objectKey, { bytes: Buffer.from(bytes), headers: { "content-type": object.contentType, "content-disposition": object.contentDisposition, "cache-control": object.cachePolicy } });
    return { status: "WRITTEN" };
  }
  async fetchPublic(object) {
    const override = this.publicOverrides[object.objectKey];
    if (override) return { status: override.status ?? 200, bytes: Buffer.from(override.bytes ?? ""), headers: override.headers ?? {} };
    const item = this.objects.get(object.objectKey);
    return item ? { status: 200, bytes: Buffer.from(item.bytes), headers: { ...item.headers, "content-length": String(item.bytes.length) } } : { status: 404, bytes: Buffer.alloc(0), headers: {} };
  }
}

export async function publishArtifactPlan(context, plan, transport, { remote = true, outputDir } = {}) {
  if (!transport || typeof transport.put !== "function" || typeof transport.fetchPublic !== "function") throw new PublicationError("FIXTURE_TRANSPORT_REQUIRED", "This tranche only enables a local fixture transport.");
  if (remote !== true) throw new PublicationError("R2_REMOTE_REQUIRED", "Artifact writes require an explicit remote flag in the plan.");
  const ledger = [], startedAt = new Date().toISOString();
  for (const object of plan.objects) {
    const row = { objectKey: object.objectKey, role: object.role, publicUrl: object.publicUrl, declaredSha256: object.sha256, byteLength: object.byteLength, state: "PLANNED" };
    try {
      const bytes = await fsp.readFile(object.sourcePath);
      if (bytes.length !== object.byteLength || sha256(bytes) !== object.sha256) throw new PublicationError("ARTIFACT_HASH_MISMATCH");
      const prior = await transport.head?.(object);
      if (prior && (sha256(prior.bytes) !== object.sha256 || !same(prior.headers, { "content-type": object.contentType, "content-disposition": object.contentDisposition, "cache-control": object.cachePolicy }))) {
        throw new PublicationError("IMMUTABLE_OBJECT_CONFLICT", "A versioned R2 object already exists with different bytes or metadata.");
      }
      const write = prior ? { status: "ALREADY_PRESENT_VERIFIED" } : await transport.put(object, bytes, { remote: true });
      const response = await transport.fetchPublic(object);
      const actualSha = sha256(response.bytes);
      row.httpStatus = response.status; row.responseLength = response.bytes.length; row.responseSha256 = actualSha;
      row.headers = response.headers || {}; row.writeDisposition = write.status;
      if (response.status !== 200 || response.bytes.length !== object.byteLength || actualSha !== object.sha256) {
        row.state = "PUBLIC_BYTE_VERIFICATION_FAILED"; ledger.push(row);
        throw new PublicationError("ARTIFACT_VERIFICATION_FAILED", "Public bytes do not match the approved artifact.");
      }
      row.state = write.status === "ALREADY_PRESENT_VERIFIED" || write.status === "ALREADY_PRESENT" ? "ALREADY_PRESENT_VERIFIED" : "WRITTEN_VERIFIED";
      row.digestMatch = true; ledger.push(row);
    } catch (error) {
      if (row.state === "PLANNED") { row.state = "WRITE_FAILED"; row.failureCode = error?.code || "R2_WRITE_FAILED"; ledger.push(row); }
      const state = ledger.some((x) => ["WRITTEN_VERIFIED", "ALREADY_PRESENT_VERIFIED"].includes(x.state)) ? "PARTIAL_PUBLICATION_HOLD" : error?.code === "ARTIFACT_VERIFICATION_FAILED" ? "ARTIFACT_VERIFICATION_FAILED" : "ARTIFACT_PUBLICATION_FAILED";
      const receipt = {
        receiptSchemaVersion: 1, receiptId: sha256(Buffer.from(context.approval.approvalPackageDigest + "\0" + plan.planSha256 + "\0" + startedAt)).slice(0, 32),
        state, candidateId: context.approval.candidateId, approvalPackageDigest: context.approval.approvalPackageDigest,
        approvalId: context.ownerApproval.approvalId, productId: context.approval.productId, version: context.state.releaseVersion,
        ownerApprovalRecord: context.ownerRecord,
        r2PlanSha256: plan.planSha256, objectLedger: ledger, startedAt, completedAt: new Date().toISOString(),
        recoveryPlan: "Inspect every immutable versioned object and public digest; resume only identical missing objects. Do not delete successful objects automatically."
      };
      if (outputDir) await writePublicationFiles(outputDir, plan, ledger, receipt);
      return { status: state, plan, ledger, receipt };
    }
  }
  const receipt = {
    receiptSchemaVersion: 1, receiptId: sha256(Buffer.from(context.approval.approvalPackageDigest + "\0" + plan.planSha256)).slice(0, 32),
    state: "ARTIFACTS_PUBLISHED_VERIFIED", candidateId: context.approval.candidateId, approvalPackageDigest: context.approval.approvalPackageDigest,
    approvalId: context.ownerApproval.approvalId, ownerApprovalRecord: context.ownerRecord, productId: context.approval.productId, version: context.state.releaseVersion,
    r2Bucket: plan.bucket, r2PlanSha256: plan.planSha256, objectCount: plan.objectCount, objectLedger: ledger,
    publicArtifacts: ledger.filter((x) => x.role === "artifact").map((x) => ({ objectKey: x.objectKey, publicUrl: x.publicUrl, sha256: x.responseSha256, byteLength: x.responseLength })),
    startedAt, completedAt: new Date().toISOString(), published: plan.objectCount > 0
  };
  if (outputDir) await writePublicationFiles(outputDir, plan, ledger, receipt);
  return { status: receipt.state, plan, ledger, receipt };
}
async function writePublicationFiles(outputDir, plan, ledger, receipt) {
  await fsp.mkdir(outputDir, { recursive: true });
  await writeJson(path.join(outputDir, "artifact-publication.json"), { schemaVersion: 1, bucket: plan.bucket, objectCount: plan.objectCount, planSha256: plan.planSha256, objects: plan.objects, commands: plan.commands });
  await writeJson(path.join(outputDir, "artifact-publication-receipt.json"), receipt);
  await writeJson(path.join(outputDir, "public-object-ledger.json"), { schemaVersion: 1, state: receipt.state, objects: ledger, recoveryPlan: receipt.recoveryPlan || null });
}
export async function verifyArtifactReceipt(receipt, context, plan, fetchPublic) {
  if (!receipt || receipt.state !== "ARTIFACTS_PUBLISHED_VERIFIED" || receipt.candidateId !== context.approval.candidateId ||
      receipt.approvalPackageDigest !== context.approval.approvalPackageDigest || receipt.productId !== context.approval.productId ||
      receipt.version !== context.state.releaseVersion || receipt.r2Bucket !== plan.bucket || receipt.r2PlanSha256 !== plan.planSha256 ||
      receipt.objectCount !== plan.objectCount || !Array.isArray(receipt.objectLedger) || receipt.objectLedger.length !== plan.objectCount ||
      receipt.published !== (plan.objectCount > 0) || typeof receipt.approvalId !== "string" || !HEX64.test(receipt.approvalId) ||
      typeof fetchPublic !== "function" || !context.ownerPublicKey || !receipt.ownerApprovalRecord) return false;
  try {
    const p7Approval = verifyOwnerApproval(context.approval, receipt.ownerApprovalRecord, context.ownerPublicKey, "PUBLISH_ARTIFACTS");
    if (p7Approval.approvalId !== receipt.approvalId) return false;
  } catch { return false; }
  for (let i = 0; i < plan.objects.length; i++) {
    const object = plan.objects[i], row = receipt.objectLedger[i];
    if (!row || !["WRITTEN_VERIFIED", "ALREADY_PRESENT_VERIFIED"].includes(row.state) || row.digestMatch !== true ||
        row.objectKey !== object.objectKey || row.role !== object.role || row.publicUrl !== object.publicUrl ||
        row.declaredSha256 !== object.sha256 || row.byteLength !== object.byteLength ||
        row.responseSha256 !== object.sha256 || row.responseLength !== object.byteLength || row.httpStatus !== 200) return false;
    let response;
    try { response = await fetchPublic(object); } catch { return false; }
    if (!response || response.status !== 200 || !Buffer.isBuffer(response.bytes) && !(response.bytes instanceof Uint8Array) ||
        response.bytes.length !== object.byteLength || sha256(response.bytes) !== object.sha256) return false;
  }
  return true;
}

function projection(record, module) {
  return {
    productStatus: record?.productStatus ?? null, state: record?.state ?? null, visible: record?.visible ?? null,
    route: record?.route ?? module?.route ?? null,
    release: record?.release ?? null,
    artifacts: record?.artifacts ?? [], downloadUrl: record?.downloadUrl ?? null, sha256Url: record?.sha256Url ?? null,
    sha256: record?.sha256 ?? null, verification: record?.verification ?? null,
    commerce: module?.commerce ?? null, homepage: module?.homepage ?? null
  };
}
export function classifyCanonicalDelta(before, after, approved, artifactCount = 0) {
  const changed = (a, b) => canonical(a ?? null) !== canonical(b ?? null);
  const result = {
    PRODUCT_PRESENTATION_CHANGE: approved.proposedPaths.some((x) => x.path !== "site-manifest.json"),
    PUBLIC_RELEASE_TRUTH_CHANGE: changed(before.record?.release, after.record?.release) || changed(before.record?.productStatus, after.record?.productStatus) || changed(before.record?.artifacts, after.record?.artifacts),
    ARTIFACT_CHANGE: artifactCount > 0,
    COMMERCE_CHANGE: changed(before.module?.commerce, after.module?.commerce),
    ROUTE_CHANGE: (before.module?.route ?? before.record?.route ?? null) !== (after.module?.route ?? after.record?.route ?? null),
    HOMEPAGE_CHANGE: !!before.module && changed(before.module.homepage, after.module?.homepage),
    TRUTH_FILE_CHANGE: changed(before.manifest, after.manifest)
  };
  const declared = {
    PRODUCT_PRESENTATION_CHANGE: approved.productPresentationChange?.changed === "YES",
    PUBLIC_RELEASE_TRUTH_CHANGE: approved.publicReleaseTruthChange?.changed === "YES",
    ARTIFACT_CHANGE: approved.artifactChange?.changed === "YES",
    COMMERCE_CHANGE: approved.commerceDelta?.changed === "YES",
    ROUTE_CHANGE: approved.routeDelta?.changed === "YES",
    HOMEPAGE_CHANGE: approved.homepageChange?.changed === "YES",
    TRUTH_FILE_CHANGE: approved.truthFileChange?.changed === "YES"
  };
  return { schemaVersion: 1, approved: declared, actual: result, matches: Object.keys(result).every((key) => result[key] === declared[key]), categories: Object.fromEntries(Object.keys(result).map((key) => [key, { approved: declared[key] ? "YES" : "NO", actual: result[key] ? "YES" : "NO" }])) };
}
export function assertApprovedCandidatePath(rel, productId) {
  if (!(rel === "site-manifest.json" || rel.startsWith("products/" + productId + "/") || rel.startsWith("assets/" + productId + "/"))) {
    throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Candidate contains a path outside its product and canonical manifest scope.");
  }
  return true;
}
export function assertCanonicalPromotionScope(beforeManifest, afterManifest, productId, submissionType, beforeModule = null, afterModule = null) {
  const beforeOthers = (beforeManifest.products || []).filter((x) => x.id !== productId).sort((a, b) => a.id.localeCompare(b.id, "en"));
  const afterOthers = (afterManifest.products || []).filter((x) => x.id !== productId).sort((a, b) => a.id.localeCompare(b.id, "en"));
  if (!same(beforeOthers, afterOthers)) throw new PublicationError("UNRELATED_PRODUCT_MUTATION", "Canonical promotion changed another product record.");
  const beforeTop = { ...beforeManifest }; delete beforeTop.products;
  const afterTop = { ...afterManifest }; delete afterTop.products;
  if (!same(beforeTop, afterTop)) throw new PublicationError("UNRELATED_PRODUCT_MUTATION", "Canonical promotion changed a site-manifest field outside the approved product record.");
  if (submissionType === "PRESENTATION_UPDATE" && (!same(beforeModule?.commerce ?? null, afterModule?.commerce ?? null) ||
      !same(beforeModule?.route ?? null, afterModule?.route ?? null) || !same(beforeModule?.homepage ?? null, afterModule?.homepage ?? null))) {
    throw new PublicationError("CANONICAL_PROMOTION_FAILED", "A presentation update changed commerce, route, or homepage semantics.");
  }
  if (submissionType === "PRESENTATION_UPDATE") {
    const beforeProduct = (beforeManifest.products || []).find((x) => x.id === productId) || null;
    const afterProduct = (afterManifest.products || []).find((x) => x.id === productId) || null;
    const releaseTruth = (x) => x ? { productStatus: x.productStatus, state: x.state, release: x.release, artifacts: x.artifacts, downloadUrl: x.downloadUrl,
      sha256Url: x.sha256Url, sha256: x.sha256, verification: x.verification, visible: x.visible, route: x.route } : null;
    if (!same(releaseTruth(beforeProduct), releaseTruth(afterProduct))) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "A presentation update changed public release truth or verification.");
  }
  if (submissionType === "NEW_VERSION" && (!same(beforeModule?.commerce ?? null, afterModule?.commerce ?? null) ||
      (beforeModule?.route ?? null) !== (afterModule?.route ?? null) || !same(beforeModule?.homepage ?? null, afterModule?.homepage ?? null))) {
    throw new PublicationError("CANONICAL_PROMOTION_FAILED", "A version promotion changed commerce, route, or homepage semantics.");
  }
  return true;
}

function releaseTransform(manifest, module, submittedModule, context, receipt, plan) {
  const id = context.approval.productId, row = (manifest.products || []).find((x) => x.id === id);
  if (!row) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Promoted manifest has no approved product record.");
  const type = context.approval.submissionType, version = context.state.releaseVersion;
  if (type === "PRESENTATION_UPDATE") return { manifest, module };
  if (!plan.objects.length) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "A release promotion requires verified public artifacts.");
  if (type === "NEW_VERSION" && row.release?.candidateVersion !== version) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Candidate version does not match the frozen manifest proposal.");
  if (type === "NEW_PRODUCT") {
    if (context.state.requestedLifecycle !== "public-eligible" || submittedModule.lifecycle !== "public-eligible" || submittedModule.visibility !== "visible") {
      throw new PublicationError("CANONICAL_PROMOTION_FAILED", "A new public product must have requestedLifecycle public-eligible and a visible submitted module.");
    }
    module.lifecycle = "public-eligible";
    module.visibility = "visible";
    module.commerce = structuredClone(submittedModule.commerce);
  }
  const artifactObjects = plan.objects.filter((x) => x.role === "artifact");
  const checksumObject = plan.objects.find((x) => x.role === "checksums");
  const releaseObject = plan.objects.find((x) => x.role === "release-record");
  row.state = "available";
  row.productStatus = "PUBLIC_RELEASE";
  row.visible = true;
  row.cta = "Download";
  row.presentation = { ...(row.presentation || {}), downloadUnavailable: false };
  delete row.presentation.downloadNotice;
  row.release = { ...(row.release || {}), publicVersion: version, candidateVersion: null, releaseStatus: "PUBLIC_RELEASE", publishedAt: context.ownerApproval.approvedAt.slice(0, 10) };
  row.artifacts = artifactObjects.map((item) => ({ filename: path.posix.basename(item.objectKey), sizeBytes: item.byteLength, sha256: item.sha256, downloadUrl: item.publicUrl,
    sha256Url: checksumObject?.publicUrl ?? null, platform: item.platform, signingStatus: "UNSIGNED" }));
  row.downloadUrl = artifactObjects[0]?.publicUrl ?? null;
  row.sha256Url = checksumObject?.publicUrl ?? null;
  row.sha256 = artifactObjects[0]?.sha256 ?? null;
  row.downloadLabel = module.commerce?.label || (module.commerce?.status === "FREE" ? "Free download" : "Download");
  row.verification = { status: "PENDING", verifiedAt: null, verificationType: ["ARTIFACT_HASH_PUBLISHED", "ARTIFACT_HASH_VERIFIED"], receiptId: receipt.receiptId, receiptUrl: releaseObject?.publicUrl ?? null };
  return { manifest, module };
}

function gitCloneCandidate(baseCommit, target, candidateChanges, commitMetadata) {
  const clone = spawnSync("git", ["clone", "--shared", "--no-checkout", "--quiet", ROOT, target], { cwd: path.dirname(target), encoding: "utf8", windowsHide: true, timeout: 120000 });
  if (clone.error || clone.status !== 0) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Could not create the isolated canonical candidate workspace.");
  const checkout = runGit(["checkout", "--detach", baseCommit], target);
  void checkout;
  for (const change of candidateChanges) {
    const source = path.join(target, ...change.path.split("/"));
    const bytes = change.promotedBytes || fs.readFileSync(change.sourcePath);
    fs.mkdirSync(path.dirname(source), { recursive: true });
    fs.writeFileSync(source, bytes);
  }
  if (!candidateChanges.length) return { commit: baseCommit, tree: runGit(["show", "-s", "--format=%T", baseCommit], target).stdout, committedAt: runGit(["show", "-s", "--format=%cI", baseCommit], target).stdout };
  const add = runGit(["add", "--", ...candidateChanges.map((x) => x.path)], target, process.env, false);
  if (add.status !== 0) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Could not stage approved canonical candidate paths.");
  const status = runGit(["status", "--porcelain", "--untracked-files=all"], target).stdout;
  const approvedPaths = new Set(candidateChanges.map((x) => x.path));
  if (status.split(/\r?\n/).filter(Boolean).some((line) => !approvedPaths.has(line.slice(3).replaceAll("\\", "/")))) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Isolated promotion changed an unapproved canonical path.");
  const env = { ...process.env, GIT_AUTHOR_NAME: "Proof Foundry Publisher Fixture", GIT_AUTHOR_EMAIL: "publisher@example.invalid", GIT_COMMITTER_NAME: "Proof Foundry Publisher Fixture", GIT_COMMITTER_EMAIL: "publisher@example.invalid", GIT_AUTHOR_DATE: commitMetadata, GIT_COMMITTER_DATE: commitMetadata };
  const commit = spawnSync("git", ["-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "candidate publication " + candidateChanges[0].candidateId], { cwd: target, env, encoding: "utf8", windowsHide: true, timeout: 120000 });
  if (commit.error || commit.status !== 0) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Could not bind promoted source to an isolated commit.");
  return { commit: runGit(["rev-parse", "HEAD"], target).stdout, tree: runGit(["rev-parse", "HEAD^{tree}"], target).stdout, committedAt: runGit(["show", "-s", "--format=%cI", "HEAD"], target).stdout };
}

export async function createSitePayloadManifest(publicDir, sourceIdentity, manifestSha256) {
  const files = await walkFiles(publicDir), entries = [];
  for (const file of files) {
    const bytes = await fsp.readFile(file.full);
    entries.push({ path: file.path, byteLength: bytes.length, sha256: sha256(bytes) });
  }
  const payloadSha256 = sha256(Buffer.from(entries.map((x) => x.path + "\0" + x.byteLength + "\0" + x.sha256 + "\n").join(""), "utf8"));
  return { schemaVersion: 1, payloadFileCount: entries.length, payloadSha256, sourceIdentity, manifestSha256, files: entries };
}
export async function verifySitePayload(publicDir, payloadManifest) {
  if (!payloadManifest || payloadManifest.schemaVersion !== 1 || !Array.isArray(payloadManifest.files)) return { ok: false, code: "SITE_QUALIFICATION_FAILED" };
  const actual = await createSitePayloadManifest(publicDir, payloadManifest.sourceIdentity, payloadManifest.manifestSha256);
  return { ok: actual.payloadFileCount === payloadManifest.payloadFileCount && actual.payloadSha256 === payloadManifest.payloadSha256 && same(actual.files, payloadManifest.files), actual };
}

export function buildPagesDeployCommand(directory, { projectName = BASE_PROJECT, branch = BASE_BRANCH, commitHash, commitMessage } = {}) {
  if (projectName !== BASE_PROJECT) throw new PublicationError("WRONG_PAGES_PROJECT", "Pages project must be proof-foundry-site.");
  if (branch !== BASE_BRANCH) throw new PublicationError("WRONG_PAGES_BRANCH", "Pages production branch must be main.");
  const quote = (x) => "'" + String(x).replaceAll("'", "''") + "'";
  let command = "wrangler pages deploy " + quote(directory) + " --project-name " + BASE_PROJECT + " --branch main";
  if (commitHash) { if (!HEX40.test(commitHash)) throw new PublicationError("INVALID_COMMIT_BINDING"); command += " --commit-hash " + commitHash; }
  if (commitMessage) command += " --commit-message " + quote(commitMessage);
  return command;
}

export class MemoryPagesFixtureTransport {
  constructor({ failVerification = false } = {}) { this.deployments = new Map(); this.calls = 0; this.failVerification = failVerification; }
  async deploy(publicDir, manifest, command) {
    this.calls++;
    const deploymentId = "fixture-" + manifest.payloadSha256.slice(0, 16);
    const entries = new Map();
    for (const item of manifest.files) entries.set(item.path, await fsp.readFile(path.join(publicDir, ...item.path.split("/"))));
    this.deployments.set(deploymentId, { entries, command, payloadSha256: manifest.payloadSha256 });
    return { deploymentId, deploymentUrl: "https://" + deploymentId + ".proof-foundry-site.pages.dev/", uploaded: true };
  }
  async verify(deployment, manifest) {
    const stored = this.deployments.get(deployment.deploymentId);
    if (this.failVerification || !stored || stored.payloadSha256 !== manifest.payloadSha256) return false;
    for (const item of manifest.files) {
      const bytes = stored.entries.get(item.path);
      if (!bytes || bytes.length !== item.byteLength || sha256(bytes) !== item.sha256) return false;
    }
    return true;
  }
}
export function classifyPagesUpload(uploaded, verified) {
  if (!uploaded) return "DEPLOY_FAILED";
  return verified ? "DEPLOYED_FIXTURE_VERIFIED" : "DEPLOYED_UNVERIFIED";
}
export function assertNoDuplicateDeployment(prior, payloadSha256) {
  if (!prior) return true;
  if (prior.payloadSha256 === payloadSha256 && prior.state === "DEPLOYED_UNVERIFIED") throw new PublicationError("DEPLOYED_UNVERIFIED", "An upload already exists with failed verification; diagnose or plan rollback without redeploying.");
  throw new PublicationError("DUPLICATE_DEPLOY_BLOCKED", "An upload receipt already exists for this candidate; a second deployment is blocked.");
}

class FilePagesFixtureTransport extends MemoryPagesFixtureTransport {
  constructor(root, options = {}) { super(options); this.root = root; }
  async deploy(publicDir, manifest, command) {
    const deployment = await super.deploy(publicDir, manifest, command);
    const target = path.join(this.root, "site");
    await fsp.rm(target, { recursive: true, force: true });
    await fsp.mkdir(target, { recursive: true });
    for (const [rel, bytes] of this.deployments.get(deployment.deploymentId).entries) {
      const file = resolveInside(target, rel);
      await fsp.mkdir(path.dirname(file), { recursive: true });
      await fsp.writeFile(file, bytes);
    }
    return deployment;
  }
}

function parseSitemap(xml) {
  const urls = [...String(xml).matchAll(/<loc>([^<]+)<\/loc>/g)].map((x) => x[1]);
  return urls.map((url) => { const u = new URL(url); return u.pathname.endsWith("/") ? u.pathname : path.posix.extname(u.pathname) ? u.pathname : u.pathname + "/"; });
}
export function assertProductionBase(expected, observed) {
  if (!observed || observed.source?.commit !== expected.baseSiteCommit || observed.source?.tree !== expected.baseSiteTree) {
    throw new PublicationError("DEPLOY_DENIED_STALE_BASE", "Current production source binding differs from the approved predecessor.");
  }
}
export function isCurrentVerifiedPayload(observed, payloadManifest, promotion) {
  return !!observed && observed.verified === true && observed.payloadSha256 === payloadManifest.payloadSha256 &&
    observed.source?.commit === promotion.candidateSourceCommit && observed.source?.tree === promotion.candidateSourceTree &&
    typeof observed.deploymentId === "string" && typeof observed.deploymentUrl === "string";
}
function urlToPayloadPath(route) { return route === "/" ? "index.html" : route.replace(/^\//, "").replace(/\/$/, "") + "/index.html"; }
function responseJson(response, label) {
  if (response.status !== 200) throw new PublicationError("LIVE_TRUTH_MISMATCH", label + " returned a non-200 response.");
  try { return JSON.parse(response.bytes.toString("utf8")); } catch { throw new PublicationError("LIVE_TRUTH_MISMATCH", label + " did not return JSON."); }
}
function truthProductProjection(doc) {
  return { id: doc.id, route: doc.route, productStatus: doc.productStatus, release: doc.release, download: doc.download,
    artifacts: doc.artifacts, verification: doc.verification, commerce: doc.commerce ?? null };
}
function semanticFromManifest(product, module) {
  return { id: product.id, route: product.route, productStatus: product.productStatus, state: product.state, release: product.release,
    downloadUrl: product.downloadUrl ?? null, sha256Url: product.sha256Url ?? null, sha256: product.sha256 ?? null,
    artifacts: product.artifacts || [], verification: product.verification || null, commerce: module?.commerce ?? null };
}

export async function verifyLivePublication(record, fetchPublic) {
  if (typeof fetchPublic !== "function") throw new PublicationError("FIXTURE_ORIGIN_REQUIRED", "A read-only public origin adapter is required.");
  const result = { state: "VERIFYING", checks: {}, unrelatedProductStateChange: "NONE", unrelatedCommerceChange: "NONE", unrelatedRouteChange: "NONE", unrelatedHomepageChange: "NONE", errors: [] };
  const fetchOne = async (url) => {
    const response = await fetchPublic(url);
    result.checks[url] = { status: response.status, contentLength: response.bytes.length, sha256: sha256(response.bytes), headers: response.headers || {} };
    return response;
  };
  try {
    const routes = [...new Set(record.expectedRoutes || [])].sort();
    if (!routes.length) throw new PublicationError("LIVE_ROUTE_REGRESSION", "Publication record has no registered route inventory.");
    const required = ["/", "/software/", record.productRoute, "/proof/", "/truth/", "/truth/index.json", record.truthProductRoute, "/truth-files/", record.truthFileRoute, "/sitemap.xml", "/robots.txt"];
    for (const route of new Set([...required, ...routes])) {
      const response = await fetchOne(SITE_ORIGIN + route);
      if (response.status !== 200) throw new PublicationError("LIVE_ROUTE_REGRESSION", "A required public route did not return HTTP 200.", { route });
    }
    const truthResponse = await fetchOne(SITE_ORIGIN + "/truth/index.json"), truth = responseJson(truthResponse, "truth/index.json");
    if (truth.source?.commit !== record.expectedSourceCommit || truth.source?.tree !== record.expectedSourceTree || truth.productCount !== record.expectedProductCount) {
      result.state = "LIVE_TRUTH_MISMATCH";
      throw new PublicationError("LIVE_TRUTH_MISMATCH", "Truth source identity or product count differs.");
    }
    result.checks.sourceBinding = { status: "PASS", commit: truth.source.commit, tree: truth.source.tree, productCount: truth.productCount };
    const productResponse = await fetchOne(SITE_ORIGIN + record.truthProductRoute), productDoc = responseJson(productResponse, "product Truth File");
    const semantic = truthProductProjection(productDoc);
    if (productDoc.id !== record.expectedProduct.id || canonical(semantic) !== canonical(record.expectedProduct.truthProjection)) {
      result.state = "LIVE_TRUTH_MISMATCH";
      throw new PublicationError("LIVE_TRUTH_MISMATCH", "Live product Truth File differs from the approved canonical projection.");
    }
    const sitemapResponse = await fetchOne(SITE_ORIGIN + "/sitemap.xml"), sitemapRoutes = parseSitemap(sitemapResponse.bytes.toString("utf8")).sort();
    if (!same(sitemapRoutes, routes)) { result.state = "UNRELATED_REGRESSION"; result.unrelatedRouteChange = "CHANGED"; throw new PublicationError("LIVE_ROUTE_REGRESSION", "Live sitemap routes differ from the qualified payload."); }
    const pageRoutes = [record.productRoute, "/software/", record.truthFileRoute];
    let softwareText = "";
    for (const route of pageRoutes) {
      const page = (await fetchOne(SITE_ORIGIN + route)).bytes.toString("utf8");
      if (route === "/software/") softwareText = page;
      if (record.expectedProduct.publicVersion && !page.includes(record.expectedProduct.publicVersion)) throw new PublicationError("LIVE_TRUTH_MISMATCH", "Product-facing surface has a different version.", { route });
      for (const url of record.expectedProduct.artifactUrls || []) if (route !== record.truthFileRoute && !page.includes(url)) throw new PublicationError("LIVE_TRUTH_MISMATCH", "Product-facing surface omits an approved artifact URL.", { route });
    }
    if (record.expectedProduct.commerceLabel && !softwareText.includes(record.expectedProduct.commerceLabel)) throw new PublicationError("LIVE_TRUTH_MISMATCH", "Software catalog acquisition label differs from the promoted product module.");
    if (!record.expectedProduct.releaseRecordUrl) throw new PublicationError("LIVE_TRUTH_MISMATCH", "No public release record URL is bound to the publication.");
    const releaseResponse = await fetchOne(record.expectedProduct.releaseRecordUrl);
    const releaseJson = responseJson(releaseResponse, "public release record");
    if (releaseJson.productId !== record.approval.productId || releaseJson.version !== record.expectedProduct.publicVersion ||
        (record.expectedProduct.artifacts || []).some((artifact) => !(releaseJson.artifacts || []).some((item) => item.sha256 === artifact.sha256))) {
      throw new PublicationError("LIVE_TRUTH_MISMATCH", "Public release record differs from approved release identity or artifact hashes.");
    }
    const artifactDigests = [];
    for (const artifact of record.expectedProduct.artifacts) {
      const response = await fetchOne(artifact.downloadUrl), digest = sha256(response.bytes);
      if (response.status !== 200 || response.bytes.length !== artifact.sizeBytes || digest !== artifact.sha256) { result.state = "LIVE_ARTIFACT_MISMATCH"; throw new PublicationError("LIVE_ARTIFACT_MISMATCH", "Live public artifact bytes differ from approval."); }
      artifactDigests.push({ url: artifact.downloadUrl, status: response.status, byteLength: response.bytes.length, sha256: digest, matchesApproved: true });
    }
    result.checks.liveArtifacts = artifactDigests;
    for (const previous of record.predecessorProducts || []) {
      if (previous.id === record.approval.productId) continue;
      const response = await fetchOne(SITE_ORIGIN + "/truth/products/" + encodeURIComponent(previous.id) + ".json");
      const current = responseJson(response, "unrelated product Truth File");
      if (canonical(truthProductProjection(current)) !== canonical(previous.truthProjection)) {
        result.state = "UNRELATED_REGRESSION"; result.unrelatedProductStateChange = "CHANGED";
        if (canonical(current.download) !== canonical(previous.truthProjection.download)) result.unrelatedCommerceChange = "CHANGED";
        throw new PublicationError("UNRELATED_REGRESSION", "An unrelated product semantic projection changed.");
      }
      if (previous.commerceLabel && !softwareText.includes(previous.commerceLabel)) {
        result.state = "UNRELATED_REGRESSION"; result.unrelatedCommerceChange = "CHANGED";
        throw new PublicationError("UNRELATED_REGRESSION", "An unrelated product acquisition label changed.");
      }
    }
    const home = (await fetchOne(SITE_ORIGIN + "/")).bytes;
    if (record.expectedHomepageSha256 && sha256(home) !== record.expectedHomepageSha256) {
      result.state = "UNRELATED_REGRESSION"; result.unrelatedHomepageChange = "CHANGED"; throw new PublicationError("UNRELATED_REGRESSION", "Homepage bytes differ from the approved payload.");
    }
    result.state = "PUBLISHED_VERIFIED";
    result.checks.crossSurfaceConsistency = "PASS";
    result.checks.routes = { status: "PASS", count: routes.length };
    return result;
  } catch (error) {
    if (result.state === "VERIFYING") result.state = error?.code || "LIVE_TRUTH_MISMATCH";
    result.errors.push({ code: error?.code || "LIVE_VERIFICATION_FAILED", message: error?.message || "Live verification failed." });
    return result;
  }
}
export function validatePublicationRecordChain(record, publicKey) {
  const approval = record?.approval, artifactReceipt = record?.artifactPublicationReceipt, promotion = record?.promotion;
  const payloadManifest = record?.payloadManifest, deployment = record?.deployment;
  const approvals = record?.stageApprovals || {};
  if (!approval || !artifactReceipt || !promotion || !payloadManifest || !deployment || !publicKey || !approvals.publish || !approvals.promote || !approvals.deploy) throw new PublicationError("PUBLICATION_RECORD_INVALID", "Publication record chain is incomplete.");
  let publishApproval, promoteApproval, deployApproval;
  try {
    publishApproval = verifyOwnerApproval(approval, approvals.publish, publicKey, "PUBLISH_ARTIFACTS");
    promoteApproval = verifyOwnerApproval(approval, approvals.promote, publicKey, "PROMOTE_CANONICAL_STATE");
    deployApproval = verifyOwnerApproval(approval, approvals.deploy, publicKey, "DEPLOY_SITE");
    if (approvals.verifyLive) verifyOwnerApproval(approval, approvals.verifyLive, publicKey, "VERIFY_LIVE");
  } catch { throw new PublicationError("PUBLICATION_RECORD_INVALID", "One or more stage approvals are invalid or not action-scoped."); }
  if (artifactReceipt.state !== "ARTIFACTS_PUBLISHED_VERIFIED" || artifactReceipt.approvalPackageDigest !== approval.approvalPackageDigest ||
      artifactReceipt.candidateId !== approval.candidateId || artifactReceipt.productId !== approval.productId || artifactReceipt.approvalId !== publishApproval.approvalId ||
      artifactReceipt.ownerApprovalRecord?.approvalId !== publishApproval.approvalId ||
      !Array.isArray(artifactReceipt.objectLedger) || artifactReceipt.objectLedger.some((x) => !["WRITTEN_VERIFIED", "ALREADY_PRESENT_VERIFIED"].includes(x.state) || x.digestMatch !== true)) {
    throw new PublicationError("PUBLICATION_RECORD_INVALID", "Artifact receipt is not fully verified or bound to this candidate.");
  }
  if (promotion.candidateId !== approval.candidateId || promotion.candidateDigest !== approval.candidateDigest || promotion.approvalPackageDigest !== approval.approvalPackageDigest ||
      promotion.approvalId !== promoteApproval.approvalId || promotion.ownerApprovalRecord?.approvalId !== promoteApproval.approvalId ||
      promotion.artifactReceiptId !== artifactReceipt.receiptId || promotion.state !== "SITE_PAYLOAD_QUALIFIED_UNDEPLOYED" ||
      promotion.payloadSha256 !== payloadManifest.payloadSha256 || promotion.candidateSourceCommit !== payloadManifest.sourceIdentity?.commit || promotion.candidateSourceTree !== payloadManifest.sourceIdentity?.tree ||
      promotion.siteManifestSha256 !== payloadManifest.manifestSha256 || !record.expectedRoutes?.length) {
    throw new PublicationError("PUBLICATION_RECORD_INVALID", "Canonical promotion or qualified payload differs from its approved binding.");
  }
  if (record.approvalId !== deployApproval.approvalId) throw new PublicationError("PUBLICATION_RECORD_INVALID", "Deploy approval identity differs from the publication record.");
  if (deployment.payloadSha256 !== payloadManifest.payloadSha256 || deployment.project !== BASE_PROJECT || deployment.branch !== BASE_BRANCH ||
      !["DEPLOYED_FIXTURE_VERIFIED", "DEPLOYED_UNVERIFIED", "ALREADY_CURRENT_VERIFIED"].includes(deployment.state)) {
    throw new PublicationError("PUBLICATION_RECORD_INVALID", "Pages deployment does not bind the exact qualified payload and production target.");
  }
  if (approval.artifactSha256.length && !same([...approval.artifactSha256].sort(), (record.expectedProduct.artifacts || []).map((x) => x.sha256).sort())) {
    throw new PublicationError("PUBLICATION_RECORD_INVALID", "Expected public artifact list differs from signed artifact hashes.");
  }
  return true;
}

function rollbackPlan(context, promotion, deployment) {
  return {
    artifactRollback: { action: "NO_AUTOMATIC_DELETE", policy: "Keep immutable versioned R2 objects as evidence; mark them superseded only by a later owner-approved canonical change." },
    canonicalSourceRollback: { targetCommit: context.approval.baseSiteCommit, targetTree: context.approval.baseSiteTree, action: "Plan a reviewed source revert in an isolated checkout; do not mutate production source." },
    websiteDeploymentRollback: { predecessorCommit: context.approval.baseSiteCommit, predecessorTree: context.approval.baseSiteTree, deploymentId: deployment?.deploymentId ?? null, action: "Plan one owner-reviewed Direct Upload of the exact predecessor payload; do not redeploy or invoke rollback automatically." },
    candidateSourceCommit: promotion?.candidateSourceCommit ?? null
  };
}

function parseArgs(args) {
  const positional = [], flags = {};
  for (let i = 0; i < args.length; i++) {
    const value = args[i];
    if (!value.startsWith("--")) { positional.push(value); continue; }
    const key = value.slice(2);
    if (["dry-run", "fixture", "live", "remote", "fail-verification", "live-read-only"].includes(key)) flags[key] = true;
    else { if (!args[i + 1] || args[i + 1].startsWith("--")) throw new PublicationError("INVALID_ARGUMENT", "A command option is missing its value."); flags[key] = args[++i]; }
  }
  return { positional, flags };
}
function requireNoLive(flags) {
  if (flags.live || !LIVE_MUTATION_ENABLED) throw new PublicationError("LIVE_MUTATION_DISABLED", "Real R2 and Pages mutations are disabled in this tranche.");
}
function requireFixtureMode(flags) {
  if (flags["dry-run"] && flags.fixture) throw new PublicationError("INVALID_ARGUMENT", "Choose one of --dry-run or --fixture.");
  if (!flags["dry-run"] && !flags.fixture) throw new PublicationError("LIVE_MUTATION_DISABLED", "Specify --dry-run or --fixture; no live transport is available.");
}
function keyAndApprovalFlags(flags) {
  return { approvalRecordPath: flags["owner-approval"], approvalPublicKeyPath: flags["owner-public-key"] };
}
function currentProductionFixture(flags) {
  if (!flags["production-truth"]) throw new PublicationError("PRODUCTION_BASE_REQUIRED", "Supply a read-only production truth snapshot for the dry-run/fixture base check.");
  const doc = readJson(path.resolve(flags["production-truth"]));
  return doc;
}
function fixtureRoot(flags) {
  if (!flags["fixture-dir"]) throw new PublicationError("FIXTURE_DIRECTORY_REQUIRED", "Fixture transport requires --fixture-dir.");
  const dir = path.resolve(flags["fixture-dir"]);
  const master = protectedMasterRoot();
  if (isWithin(ROOT, dir) || isWithin(dir, ROOT) || isWithin(master, dir) || isWithin(dir, master)) throw new PublicationError("UNSAFE_FIXTURE_DIRECTORY", "Fixture transport output must stay outside all source checkouts.");
  return dir;
}
async function readDirectoryPublic(dir, url) {
  const parsed = new URL(url);
  const segments = decodeURIComponent(parsed.pathname).split("/").filter(Boolean);
  if (segments.some((x) => x === "." || x === ".." || x.includes("\\") || x.includes(":"))) throw new PublicationError("UNSAFE_PUBLIC_PATH", "Fixture origin path is unsafe.");
  let file;
  if (parsed.hostname === "theprooffoundry.com") file = path.join(dir, "site", ...segments);
  else if (parsed.hostname === "downloads.theprooffoundry.com") file = path.join(dir, R2_BUCKET, ...segments);
  else throw new PublicationError("UNAPPROVED_PUBLIC_ORIGIN", "Live verification accepts only Proof Foundry public origins.");
  if (parsed.pathname.endsWith("/") || fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, "index.html");
  try { return { status: 200, bytes: await fsp.readFile(file), headers: {} }; }
  catch { return { status: 404, bytes: Buffer.alloc(0), headers: {} }; }
}

async function publishCommand(packageDir, args) {
  const { positional, flags } = parseArgs(args);
  if (flags.live) requireNoLive(flags);
  requireFixtureMode(flags);
  const context = await loadFrozenPackage(packageDir, { ...keyAndApprovalFlags(flags), action: "PUBLISH_ARTIFACTS" });
  const plan = await buildR2Plan(context);
  const dir = path.join(context.candidateRoot, "p7-artifacts");
  if (flags["dry-run"]) {
    const report = makeArtifactDryRun(context.ownerApproval.approvalId, plan);
    await writeJson(path.join(dir, "dry-run-artifact-publication.json"), report);
    return { command: "publish-artifacts", ...report, remoteRequired: true };
  }
  const transportRoot = fixtureRoot(flags), transport = new FileR2FixtureTransport(transportRoot);
  const published = await publishArtifactPlan(context, plan, transport, { remote: true, outputDir: dir });
  return { command: "publish-artifacts", state: published.status, receiptPath: path.join(dir, "artifact-publication-receipt.json"), ledgerPath: path.join(dir, "public-object-ledger.json"), objectCount: plan.objectCount, publicHashesVerified: published.status === "ARTIFACTS_PUBLISHED_VERIFIED", automaticDeleteOnFailure: false };
}

class FileR2FixtureTransport extends MemoryR2FixtureTransport {
  constructor(root) { super(); this.root = root; fs.mkdirSync(root, { recursive: true }); }
  async head(object) {
    const file = resolveInside(this.root, R2_BUCKET + "/" + object.objectKey);
    if (!fs.existsSync(file)) return null;
    const bytes = await fsp.readFile(file); return { bytes, headers: readJson(file + ".headers.json") };
  }
  async put(object, bytes, options) {
    const existing = await this.head(object);
    if (existing) {
      if (sha256(existing.bytes) !== sha256(bytes) || !same(existing.headers, { "content-type": object.contentType, "content-disposition": object.contentDisposition, "cache-control": object.cachePolicy })) throw new PublicationError("IMMUTABLE_OBJECT_CONFLICT");
      return { status: "ALREADY_PRESENT_VERIFIED" };
    }
    const result = await super.put(object, bytes, options);
    const file = resolveInside(this.root, R2_BUCKET + "/" + object.objectKey);
    await fsp.mkdir(path.dirname(file), { recursive: true });
    await fsp.writeFile(file, bytes);
    await writeJson(file + ".headers.json", { "content-type": object.contentType, "content-disposition": object.contentDisposition, "cache-control": object.cachePolicy });
    return result;
  }
  async fetchPublic(object) {
    const file = resolveInside(this.root, R2_BUCKET + "/" + object.objectKey);
    try { const bytes = await fsp.readFile(file), headers = readJson(file + ".headers.json"); return { status: 200, bytes, headers: { ...headers, "content-length": String(bytes.length) } }; }
    catch { return { status: 404, bytes: Buffer.alloc(0), headers: {} }; }
  }
}

async function promoteCommand(packageDir, receiptArg, args) {
  const { positional, flags } = parseArgs(args);
  if (flags.live) requireNoLive(flags);
  if (!flags.fixture) throw new PublicationError("ISOLATED_CANDIDATE_REQUIRED", "Canonical promotion in this tranche requires --fixture and an isolated output directory.");
  const context = await loadFrozenPackage(packageDir, { ...keyAndApprovalFlags(flags), action: "PROMOTE_CANONICAL_STATE" });
  const plan = await buildR2Plan(context);
  const artifactReceipt = readJson(path.resolve(receiptArg));
  const fixture = fixtureRoot(flags), r2Fixture = new FileR2FixtureTransport(fixture);
  if (!await verifyArtifactReceipt(artifactReceipt, context, plan, (object) => r2Fixture.fetchPublic(object))) throw new PublicationError("ARTIFACT_VERIFICATION_FAILED", "A fully verified signed artifact receipt and matching public fixture bytes are required before promotion.");
  const sourceChanges = [];
  for (const change of context.approval.proposedPaths) {
    assertApprovedCandidatePath(change.path, context.approval.productId);
    const sourcePath = resolveInside(context.candidateRoot, "proposed-source/" + change.path);
    const baseBytes = readGitBlob(context.approval.baseSiteCommit, change.path);
    if (change.preImageSha256 === null ? baseBytes !== null : !baseBytes || sha256(baseBytes) !== change.preImageSha256) {
      throw new PublicationError("APPROVAL_STALE", "A proposed source path no longer matches the approved base image.");
    }
    if (sha256(await fsp.readFile(sourcePath)) !== change.postImageSha256) throw new PublicationError("APPROVAL_STALE", "A proposed source post-image differs from its frozen hash.");
    sourceChanges.push({ ...change, sourcePath, candidateId: context.approval.candidateId });
  }
  const stage = path.resolve(flags["output-dir"] || path.join(context.candidateRoot, "p8-promotion"));
  const master = protectedMasterRoot();
  if (isWithin(ROOT, stage) || isWithin(stage, ROOT) || isWithin(master, stage) || isWithin(stage, master)) throw new PublicationError("UNSAFE_PROMOTION_DIRECTORY", "Promotion output must stay outside all source checkouts.");
  if (!(isWithin(context.candidateRoot, stage) || isWithin(stage, context.candidateRoot))) throw new PublicationError("UNSAFE_PROMOTION_DIRECTORY", "Promotion output must remain attached to its isolated candidate.");
  if (exists(stage) && !exists(path.join(stage, "promotion-receipt.json"))) throw new PublicationError("PROMOTION_OUTPUT_CONFLICT", "Promotion output exists without a complete receipt; preserve it for owner inspection.");
  if (exists(path.join(stage, "promotion-receipt.json"))) {
    const old = readJson(path.join(stage, "promotion-receipt.json"));
    if (old.approvalPackageDigest === context.approval.approvalPackageDigest && old.artifactReceiptId === artifactReceipt.receiptId) throw new PublicationError("PROMOTION_ALREADY_COMPLETED", "This candidate promotion already exists; do not create another source candidate.");
    throw new PublicationError("PROMOTION_OUTPUT_CONFLICT", "Promotion output already belongs to another candidate.");
  }
  await fsp.mkdir(stage, { recursive: true });
  const cloneDir = path.join(stage, "source-checkout");
  const baseManifestBytes = readGitBlob(context.approval.baseSiteCommit, "site-manifest.json");
  if (!baseManifestBytes || sha256(baseManifestBytes) !== context.sourceBinding.baseManifestSha256) throw new PublicationError("APPROVAL_STALE", "Approved base manifest bytes differ from their source binding.");
  const baseManifest = JSON.parse(baseManifestBytes.toString("utf8"));
  const manifestPath = path.join(context.candidateRoot, "proposed-source", "site-manifest.json");
  const afterManifest = sourceChanges.some((x) => x.path === "site-manifest.json") ? readJson(manifestPath) : structuredClone(baseManifest);
  const candidateModulePath = path.join(context.candidateRoot, "proposed-source", "products", context.approval.productId, "module.json");
  const baseModuleBytes = readGitBlob(context.approval.baseSiteCommit, "products/" + context.approval.productId + "/module.json");
  const baseModule = baseModuleBytes ? JSON.parse(baseModuleBytes.toString("utf8")) : null;
  let afterModule = exists(candidateModulePath) ? readJson(candidateModulePath) : baseModule;
  const submittedModule = readJson(path.join(context.candidateRoot, "submitted-capsule", "product", "module.json"));
  const finalState = releaseTransform(afterManifest, afterModule, submittedModule, context, artifactReceipt, plan);
  afterModule = finalState.module;
  const finalManifestPath = path.join(context.candidateRoot, "proposed-source", "site-manifest.json");
  if (sourceChanges.some((x) => x.path === "site-manifest.json")) {
    const product = finalState.manifest.products.find((x) => x.id === context.approval.productId);
    const m = sourceChanges.find((x) => x.path === "site-manifest.json");
    m.promotedBytes = Buffer.from(pretty(finalState.manifest), "utf8");
    m.sourcePath = finalManifestPath;
    void product;
  } else if (context.approval.submissionType !== "PRESENTATION_UPDATE") {
    throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Release candidate has no approved site-manifest proposal.");
  }
  const finalModulePath = path.join(context.candidateRoot, "proposed-source", "products", context.approval.productId, "module.json");
  if (afterModule && context.approval.submissionType === "NEW_PRODUCT") {
    const existing = sourceChanges.find((x) => x.path === "products/" + context.approval.productId + "/module.json");
    if (!existing) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "New product proposal has no approved module path.");
    existing.promotedBytes = Buffer.from(pretty(afterModule), "utf8");
    existing.sourcePath = finalModulePath;
  }
  const beforeRecord = (baseManifest.products || []).find((x) => x.id === context.approval.productId) || null;
  const afterRecord = finalState.manifest.products.find((x) => x.id === context.approval.productId) || null;
  assertCanonicalPromotionScope(baseManifest, finalState.manifest, context.approval.productId, context.approval.submissionType, baseModule, afterModule);
  const delta = classifyCanonicalDelta({ manifest: baseManifest, record: beforeRecord, module: baseModule }, { manifest: finalState.manifest, record: afterRecord, module: afterModule }, context.approval, plan.objects.filter((x) => x.role === "artifact").length);
  if (!delta.matches) throw new PublicationError("CANONICAL_PROMOTION_FAILED", "Promoted canonical semantic delta differs from owner-approved deltas.", { delta });
  const afterBytes = Buffer.from(pretty(finalState.manifest), "utf8");
  const changesToCommit = [...sourceChanges.filter((x) => x.path !== "site-manifest.json")];
  if (sourceChanges.some((x) => x.path === "site-manifest.json")) changesToCommit.push({ ...sourceChanges.find((x) => x.path === "site-manifest.json"), sourcePath: finalManifestPath, promotedBytes: afterBytes });
  if (context.approval.submissionType === "NEW_PRODUCT") {
    const m = changesToCommit.find((x) => x.path === "products/" + context.approval.productId + "/module.json");
    if (m) m.promotedBytes = Buffer.from(pretty(afterModule), "utf8");
  }
  const expectedBaseTree = runGit(["show", "-s", "--format=%T", context.approval.baseSiteCommit]).stdout;
  if (expectedBaseTree !== context.approval.baseSiteTree) throw new PublicationError("APPROVAL_STALE", "Approved base site tree does not match its commit.");
  const candidateSource = gitCloneCandidate(context.approval.baseSiteCommit, cloneDir, changesToCommit, context.ownerApproval.approvedAt);
  const committedManifestPath = path.join(cloneDir, "site-manifest.json");
  const manifestSha = sha256(await fsp.readFile(committedManifestPath));
  const outPublic = path.join(stage, "public");
  const buildFile = path.join(cloneDir, "scripts", "build-site.ps1");
  const build = spawnSync("pwsh", ["-NoProfile", "-File", buildFile, "-ProductsDir", path.join(cloneDir, "products"), "-ManifestPath", committedManifestPath,
    "-OutDir", outPublic, "-TruthCommit", candidateSource.commit, "-TruthTree", candidateSource.tree, "-TruthCommittedAt", candidateSource.committedAt],
  { cwd: cloneDir, encoding: "utf8", windowsHide: true, timeout: 900000, maxBuffer: 64 * 1024 * 1024 });
  if (build.error || build.status !== 0 || !exists(outPublic)) throw new PublicationError("SITE_QUALIFICATION_FAILED", "Existing build-site.ps1 failed against the isolated candidate source.");
  // The existing builder accepts alternate manifest input for rendering and Truth, but historically copied the base manifest file.
  // Bind the emitted source file to the exact alternate manifest; this is byte-copy packaging, not a second site builder.
  await fsp.copyFile(committedManifestPath, path.join(outPublic, "site-manifest.json"));
  const publicTruth = readJson(path.join(outPublic, "truth", "index.json"));
  const routes = parseSitemap(await fsp.readFile(path.join(outPublic, "sitemap.xml"), "utf8")).sort();
  const payloadManifest = await createSitePayloadManifest(outPublic, { commit: candidateSource.commit, tree: candidateSource.tree, candidateId: context.approval.candidateId, candidateDigest: context.approval.candidateDigest }, manifestSha);
  await writeJson(path.join(stage, "site-payload-manifest.json"), payloadManifest);
  const predecessorProducts = [];
  for (const product of baseManifest.products || []) {
    const truthPath = path.join(outPublic, "truth", "products", product.id + ".json");
    if (exists(truthPath)) {
      const modulePath = path.join(cloneDir, "products", product.id, "module.json");
      const module = exists(modulePath) ? readJson(modulePath) : null;
      predecessorProducts.push({ id: product.id, truthProjection: truthProductProjection(readJson(truthPath)), commerceLabel: module?.commerce?.label || null });
    }
  }
  const candidateProduct = finalState.manifest.products.find((x) => x.id === context.approval.productId);
  const candidateTruthDocPath = path.join(outPublic, "truth", "products", context.approval.productId + ".json");
  const candidateTruthDoc = exists(candidateTruthDocPath) ? readJson(candidateTruthDocPath) : null;
  const routesExpected = routes;
  const promotion = {
    receiptSchemaVersion: 1, state: "SITE_PAYLOAD_PENDING_QUALIFICATION", candidateId: context.approval.candidateId, candidateDigest: context.approval.candidateDigest,
    approvalPackageDigest: context.approval.approvalPackageDigest, approvalId: context.ownerApproval.approvalId, ownerApprovalRecord: context.ownerRecord, artifactReceiptId: artifactReceipt.receiptId,
    publisherCommit: context.approval.publisherCommit, publisherTree: context.approval.publisherTree,
    candidateSourceCommit: candidateSource.commit, candidateSourceTree: candidateSource.tree, candidateSourceCommittedAt: candidateSource.committedAt,
    baseSiteCommit: context.approval.baseSiteCommit, baseSiteTree: context.approval.baseSiteTree, siteManifestSha256: manifestSha,
    payloadSha256: payloadManifest.payloadSha256, payloadFileCount: payloadManifest.payloadFileCount, payloadManifestPath: path.join(stage, "site-payload-manifest.json"),
    publicDir: outPublic, routeCount: routes.length, expectedRoutes: routesExpected, expectedSourceCommit: candidateSource.commit,
    expectedSourceTree: candidateSource.tree, expectedProductCount: publicTruth.productCount, productRoute: candidateProduct.route,
    truthProductRoute: "/truth/products/" + context.approval.productId + ".json", truthFileRoute: "/truth-files/" + context.approval.productId + "/",
    expectedProduct: { id: candidateProduct.id, publicVersion: candidateProduct.release?.publicVersion ?? null, releaseRecordUrl: plan.objects.find((x) => x.role === "release-record")?.publicUrl ?? candidateProduct.verification?.receiptUrl ?? null,
      commerceLabel: afterModule?.commerce?.label ?? null,
      artifactUrls: (candidateProduct.artifacts || []).map((x) => x.downloadUrl).filter(Boolean), artifacts: candidateProduct.artifacts || [],
      truthProjection: candidateTruthDoc ? truthProductProjection(candidateTruthDoc) : null },
    predecessorProducts, expectedHomepageSha256: sha256(await fsp.readFile(path.join(outPublic, "index.html"))),
    semanticDelta: delta, rollbackPlan: rollbackPlan(context, { candidateSourceCommit: candidateSource.commit }, null)
  };
  await writeJson(path.join(stage, "promotion-receipt.json"), promotion);
  await writeJson(path.join(stage, "canonical-before.json"), { manifest: baseManifest, product: beforeRecord, module: baseModule });
  await writeJson(path.join(stage, "canonical-after.json"), { manifest: finalState.manifest, product: afterRecord, module: afterModule });
  await writeJson(path.join(stage, "canonical-semantic-delta.json"), delta);
  return { command: "promote", state: promotion.state, promotionReceiptPath: path.join(stage, "promotion-receipt.json"), candidateSourceCommit: candidateSource.commit,
    candidateSourceTree: candidateSource.tree, payloadFileCount: payloadManifest.payloadFileCount, payloadSha256: payloadManifest.payloadSha256, routeCount: routes.length, semanticDeltaMatches: delta.matches, rollbackPlan: promotion.rollbackPlan };
}

const REQUIRED_QUALIFICATION = [
  ["PF_PRODUCT", "node", "scripts/test-pf-product.mjs"], ["P3_P5_INTEGRATION_TESTS", "node", "scripts/test-pf-product-p3-p5.mjs"], ["P6_APPROVAL_TESTS", "node", "scripts/test-pf-product-p6.mjs"],
  ["P7_TESTS", "node", "scripts/test-pf-product-p7.mjs"], ["P8_TESTS", "node", "scripts/test-pf-product-p8.mjs"], ["P9_TESTS", "node", "scripts/test-pf-product-p9.mjs"],
  ["LEGACY_CAPSULE_TESTS", "pwsh", "scripts/test-product-capsule.ps1"], ["H13", "pwsh", "scripts/test-h13-modular-products.ps1"],
  ["H11", "pwsh", "scripts/test-h11-public-truth.ps1"], ["H12", "pwsh", "scripts/test-h12-truth-discovery.ps1"], ["TRUTH_FILES", "pwsh", "scripts/test-truth-files.ps1"],
  ["RELEASE_TRUTH", "pwsh", "scripts/test-release-truth.ps1"], ["RECEIPTS", "pwsh", "scripts/test-receipts-invariants.ps1"],
  ["H9_BINDING", "pwsh", "scripts/test-h9-binding.ps1"], ["H9_HOME", "pwsh", "scripts/test-h9-homepage.ps1"]
];
function testCount(name, output) {
  const s = String(output || "");
  const match = s.match(/(?:tests?|assertions?|checks?)\s*[:=]?\s*(\d+)\s*(?:passed|pass)/i) || s.match(/(\d+)\s+passed\b/i);
  return match ? Number(match[1]) : name === "GIT_DIFF_CHECK" ? 0 : null;
}
function runQualificationCommand(kind, file) {
  const command = kind === "node" ? [process.execPath, [path.join(ROOT, file)]] : ["pwsh", ["-NoProfile", "-File", path.join(ROOT, file)]];
  const r = spawnSync(command[0], command[1], { cwd: ROOT, encoding: "utf8", windowsHide: true, timeout: 900000, maxBuffer: 64 * 1024 * 1024 });
  return { status: !r.error && r.status === 0 ? "PASS" : "FAIL", count: testCount(file, r.stdout + "\n" + r.stderr), exitCode: r.status ?? 2 };
}
export async function qualifyPromotedPayload(stageDirArg) {
  const stage = path.resolve(stageDirArg), promotionPath = path.join(stage, "promotion-receipt.json"), manifestPath = path.join(stage, "site-payload-manifest.json");
  if (!exists(promotionPath) || !exists(manifestPath)) throw new PublicationError("SITE_QUALIFICATION_FAILED", "Promotion receipt or payload manifest is missing.");
  const promotion = readJson(promotionPath), payloadManifest = readJson(manifestPath);
  if (promotion.state !== "SITE_PAYLOAD_PENDING_QUALIFICATION" || promotion.payloadSha256 !== payloadManifest.payloadSha256) throw new PublicationError("SITE_QUALIFICATION_FAILED", "Payload is stale or already qualified.");
  const frozen = await verifySitePayload(path.join(stage, "public"), payloadManifest);
  if (!frozen.ok) throw new PublicationError("SITE_QUALIFICATION_FAILED", "Payload bytes changed after promotion.");
  const refresh = spawnSync("pwsh", ["-NoProfile", "-File", path.join(ROOT, "scripts", "build-site.ps1")], { cwd: ROOT, encoding: "utf8", windowsHide: true, timeout: 900000, maxBuffer: 64 * 1024 * 1024 });
  if (refresh.error || refresh.status !== 0) throw new PublicationError("SITE_QUALIFICATION_FAILED", "Canonical public output refresh failed.");
  const results = {};
  for (const [id, kind, file] of REQUIRED_QUALIFICATION) results[id] = runQualificationCommand(kind, file);
  const diff = spawnSync("git", ["diff", "--check"], { cwd: ROOT, encoding: "utf8", windowsHide: true, timeout: 30000 });
  results.GIT_DIFF_CHECK = { status: !diff.error && diff.status === 0 ? "PASS" : "FAIL", count: null, exitCode: diff.status ?? 2 };
  const allPass = Object.values(results).every((x) => x.status === "PASS");
  const after = await verifySitePayload(path.join(stage, "public"), payloadManifest);
  if (!after.ok) results.QUALIFIED_BYTES_EQUAL_DEPLOY_BYTES = { status: "FAIL", count: null };
  else results.QUALIFIED_BYTES_EQUAL_DEPLOY_BYTES = { status: "PASS", count: payloadManifest.payloadFileCount };
  const qualified = allPass && after.ok;
  const qualification = { qualificationSchemaVersion: 1, state: qualified ? "SITE_PAYLOAD_QUALIFIED_UNDEPLOYED" : "SITE_QUALIFICATION_FAILED",
    candidateId: promotion.candidateId, candidateDigest: promotion.candidateDigest, publisherCommit: promotion.publisherCommit, publisherTree: promotion.publisherTree,
    candidateSourceCommit: promotion.candidateSourceCommit, candidateSourceTree: promotion.candidateSourceTree, payloadSha256: payloadManifest.payloadSha256,
    payloadFileCount: payloadManifest.payloadFileCount, payloadManifestSha256: sha256(await fsp.readFile(manifestPath)), qualifiedBytesEqualDeployBytes: after.ok,
    results, qualifiedAt: new Date().toISOString(), livePublication: "NOT_RUN" };
  await writeJson(path.join(stage, "site-payload-qualification.json"), qualification);
  promotion.state = qualification.state;
  promotion.qualificationPath = path.join(stage, "site-payload-qualification.json");
  await writeJson(promotionPath, promotion);
  if (!qualified) throw new PublicationError("SITE_QUALIFICATION_FAILED", "One or more required qualification suites failed.", { results });
  return { state: qualification.state, results, payloadSha256: qualification.payloadSha256, payloadFileCount: qualification.payloadFileCount, qualificationPath: path.join(stage, "site-payload-qualification.json") };
}

async function deployCommand(packageDir, payloadArg, args) {
  const { positional, flags } = parseArgs(args);
  if (flags.live) requireNoLive(flags);
  requireFixtureMode(flags);
  const context = await loadFrozenPackage(packageDir, { ...keyAndApprovalFlags(flags), action: "DEPLOY_SITE" });
  const stage = path.resolve(payloadArg), promotionPath = path.join(stage, "promotion-receipt.json"), qualificationPath = path.join(stage, "site-payload-qualification.json");
  if (!exists(promotionPath) || !exists(qualificationPath)) throw new PublicationError("SITE_QUALIFICATION_FAILED", "A qualified promoted payload is required.");
  const promotion = readJson(promotionPath), qualification = readJson(qualificationPath), payloadManifest = readJson(path.join(stage, "site-payload-manifest.json"));
  if (promotion.state !== "SITE_PAYLOAD_QUALIFIED_UNDEPLOYED" || qualification.state !== "SITE_PAYLOAD_QUALIFIED_UNDEPLOYED" || !qualification.qualifiedBytesEqualDeployBytes ||
      promotion.approvalPackageDigest !== context.approval.approvalPackageDigest || qualification.candidateId !== context.approval.candidateId || qualification.payloadSha256 !== payloadManifest.payloadSha256) {
    throw new PublicationError("SITE_QUALIFICATION_FAILED", "Qualified payload does not match the signed candidate.");
  }
  const bytes = await verifySitePayload(path.join(stage, "public"), payloadManifest);
  if (!bytes.ok) throw new PublicationError("SITE_QUALIFICATION_FAILED", "Qualified bytes changed before deployment.");
  const production = currentProductionFixture(flags);
  if (isCurrentVerifiedPayload(production, payloadManifest, promotion)) {
    const deployment = { schemaVersion: 1, state: "ALREADY_CURRENT_VERIFIED", project: BASE_PROJECT, branch: BASE_BRANCH,
      deploymentId: production.deploymentId, deploymentUrl: production.deploymentUrl, command: null, payloadSha256: payloadManifest.payloadSha256,
      uploaded: false, postUploadVerification: "CURRENT_PAYLOAD_ALREADY_VERIFIED", automaticRetry: false, productionMutated: false };
    const artifactPublicationReceipt = readJson(path.join(context.candidateRoot, "p7-artifacts", "artifact-publication-receipt.json"));
    const recordPath = path.join(stage, "publication-record.json");
    const publicationRecord = { schemaVersion: 1, state: deployment.state, approvalPackagePath: packageDir, approvalId: context.ownerApproval.approvalId,
      approval: context.approval, stageApprovals: { publish: artifactPublicationReceipt.ownerApprovalRecord, promote: promotion.ownerApprovalRecord, deploy: context.ownerRecord },
      artifactPublicationReceipt,
      promotion, payloadManifest, deployment, expectedRoutes: promotion.expectedRoutes, expectedSourceCommit: promotion.expectedSourceCommit, expectedSourceTree: promotion.expectedSourceTree,
      expectedProductCount: promotion.expectedProductCount, productRoute: promotion.productRoute, truthProductRoute: promotion.truthProductRoute, truthFileRoute: promotion.truthFileRoute,
      expectedProduct: promotion.expectedProduct, predecessorProducts: promotion.predecessorProducts, expectedHomepageSha256: promotion.expectedHomepageSha256, rollbackPlan: promotion.rollbackPlan };
    await writeJson(recordPath, publicationRecord);
    return { command: "deploy-site", state: deployment.state, deploymentId: deployment.deploymentId, deploymentUrl: deployment.deploymentUrl,
      publicationRecordPath: recordPath, duplicateDeploymentCreated: false, productionMutated: false };
  }
  assertProductionBase(context.approval, production);
  const command = buildPagesDeployCommand(path.join(stage, "public"), { projectName: BASE_PROJECT, branch: BASE_BRANCH, commitHash: promotion.candidateSourceCommit,
    commitMessage: "Proof Foundry product publication " + context.approval.candidateId });
  const deployRecordPath = path.join(stage, "pages-deployment.json");
  if (exists(deployRecordPath)) {
    const prior = readJson(deployRecordPath);
    assertNoDuplicateDeployment(prior, payloadManifest.payloadSha256);
  }
  if (flags["dry-run"]) {
    const report = { state: "DRY_RUN_ONLY", project: BASE_PROJECT, branch: BASE_BRANCH, command, payloadSha256: payloadManifest.payloadSha256, mutationPerformed: false };
    await writeJson(path.join(stage, "pages-deploy-dry-run.json"), report);
    return { command: "deploy-site", ...report };
  }
  const fixture = fixtureRoot(flags), transport = new FilePagesFixtureTransport(fixture, { failVerification: flags["fail-verification"] === true });
  const uploaded = await transport.deploy(path.join(stage, "public"), payloadManifest, command);
  const verified = await transport.verify(uploaded, payloadManifest);
  const deployment = { schemaVersion: 1, state: classifyPagesUpload(true, verified), project: BASE_PROJECT, branch: BASE_BRANCH,
    deploymentId: uploaded.deploymentId, deploymentUrl: uploaded.deploymentUrl, command, payloadSha256: payloadManifest.payloadSha256, uploaded: true,
    postUploadVerification: verified ? "PASS" : "FAIL", automaticRetry: false, productionMutated: false, fixtureRoot: fixture };
  await writeJson(deployRecordPath, deployment);
  const artifactPublicationReceipt = readJson(path.join(context.candidateRoot, "p7-artifacts", "artifact-publication-receipt.json"));
  const publicationRecord = { schemaVersion: 1, state: deployment.state, approvalPackagePath: packageDir, approvalId: context.ownerApproval.approvalId,
    approval: context.approval, stageApprovals: { publish: artifactPublicationReceipt.ownerApprovalRecord, promote: promotion.ownerApprovalRecord, deploy: context.ownerRecord }, artifactPublicationReceipt,
    promotion, payloadManifest, deployment, expectedRoutes: promotion.expectedRoutes, expectedSourceCommit: promotion.expectedSourceCommit, expectedSourceTree: promotion.expectedSourceTree,
    expectedProductCount: promotion.expectedProductCount, productRoute: promotion.productRoute, truthProductRoute: promotion.truthProductRoute, truthFileRoute: promotion.truthFileRoute,
    expectedProduct: promotion.expectedProduct, predecessorProducts: promotion.predecessorProducts, expectedHomepageSha256: promotion.expectedHomepageSha256,
    rollbackPlan: promotion.rollbackPlan };
  const recordPath = path.join(stage, "publication-record.json");
  await writeJson(recordPath, publicationRecord);
  return { command: "deploy-site", state: deployment.state, deploymentId: deployment.deploymentId, deploymentUrl: deployment.deploymentUrl,
    publicationRecordPath: recordPath, automaticRetry: false, productionMutated: false, fixtureOnly: true };
}

async function verifyLiveCommand(recordArg, args) {
  const { positional, flags } = parseArgs(args);
  if (!flags.fixture && !flags["live-read-only"]) throw new PublicationError("LIVE_ORIGIN_MODE_REQUIRED", "Use --fixture with local public-origin files, or explicitly authorize a read-only live check.");
  const recordPath = path.resolve(recordArg), record = readJson(recordPath);
  if (!["DEPLOYED_FIXTURE_VERIFIED", "DEPLOYED_UNVERIFIED", "ALREADY_CURRENT_VERIFIED"].includes(record.deployment?.state)) throw new PublicationError("DEPLOYMENT_RECORD_REQUIRED", "A Pages deployment receipt is required before live closure.");
  if (!flags["owner-approval"] || !flags["owner-public-key"]) throw new PublicationError("OWNER_APPROVAL_REQUIRED", "A signed VERIFY_LIVE action is required.");
  const approval = readJson(path.resolve(flags["owner-approval"])), key = fs.readFileSync(path.resolve(flags["owner-public-key"]));
  const verifiedLiveApproval = verifyOwnerApproval(record.approval, approval, key, "VERIFY_LIVE");
  record.stageApprovals = { ...(record.stageApprovals || {}), verifyLive: approval };
  verifyPublisherAncestry(record.approval);
  validatePublicationRecordChain(record, key);
  let fetchPublic;
  if (flags.fixture) {
    const root = fixtureRoot(flags);
    fetchPublic = (url) => readDirectoryPublic(root, url);
  } else {
    if (!flags["live-read-only"]) throw new PublicationError("LIVE_ORIGIN_MODE_REQUIRED");
    fetchPublic = async (url) => {
      const u = new URL(url);
      if (!["theprooffoundry.com", "downloads.theprooffoundry.com"].includes(u.hostname) || u.protocol !== "https:") throw new PublicationError("UNAPPROVED_PUBLIC_ORIGIN");
      const response = await fetch(u, { method: "GET", redirect: "error", cache: "no-store" });
      return { status: response.status, bytes: Buffer.from(await response.arrayBuffer()), headers: Object.fromEntries(response.headers.entries()) };
    };
  }
  const result = await verifyLivePublication(record, fetchPublic);
  const recordDir = path.dirname(recordPath), livePath = path.join(recordDir, "live-verification.json");
  await writeJson(livePath, result);
  if (result.state === "PUBLISHED_VERIFIED") {
    const finalReceipt = { receiptSchemaVersion: 1, state: "PUBLISHED_VERIFIED", publisherCommit: record.promotion.publisherCommit, publisherTree: record.promotion.publisherTree,
      candidateId: record.approval.candidateId, candidateDigest: record.approval.candidateDigest, approvalId: record.approval.approvalId,
      stageApprovalIds: { publish: record.stageApprovals.publish.approvalId, promote: record.stageApprovals.promote.approvalId,
        deploy: record.stageApprovals.deploy.approvalId, verifyLive: verifiedLiveApproval.approvalId },
      approvalPackageDigest: record.approval.approvalPackageDigest, artifactPublicationReceiptId: record.artifactPublicationReceipt.receiptId,
      canonicalPromotionCommit: record.promotion.candidateSourceCommit, canonicalPromotionTree: record.promotion.candidateSourceTree,
      sitePayloadSha256: record.payloadManifest.payloadSha256, pagesDeploymentId: record.deployment.deploymentId, pagesDeploymentUrl: record.deployment.deploymentUrl,
      productionPredecessor: { commit: record.approval.baseSiteCommit, tree: record.approval.baseSiteTree }, productionSource: { commit: result.checks.sourceBinding.commit, tree: result.checks.sourceBinding.tree },
      liveTruthSha256: result.checks[SITE_ORIGIN + "/truth/index.json"].sha256, liveArtifactDigests: result.checks.liveArtifacts, verification: result, rollbackPlan: record.rollbackPlan };
    await writeJson(path.join(recordDir, "publication-receipt.json"), finalReceipt);
    await fsp.writeFile(path.join(recordDir, "publication-closure.md"), ["# Publication closure", "", "State: PUBLISHED_VERIFIED", "", "Candidate: " + record.approval.candidateId,
      "Payload SHA-256: " + record.payloadManifest.payloadSha256, "Pages deployment: " + record.deployment.deploymentId, "", "Rollback remains a plan; no rollback was executed.", ""].join("\n"), "utf8");
    record.state = "PUBLISHED_VERIFIED";
    await writeJson(recordPath, record);
  } else { record.state = result.state; record.liveVerificationPath = livePath; await writeJson(recordPath, record); }
  return { command: "verify-live", state: result.state, liveVerificationPath: livePath, checks: result.checks, errors: result.errors };
}

export async function runP7P9Command(operation, positional, extraArgs = []) {
  try {
    if (operation === "publish-artifacts") return await publishCommand(positional[0], extraArgs);
    if (operation === "promote") return await promoteCommand(positional[0], positional[1], extraArgs);
    if (operation === "deploy-site") return await deployCommand(positional[0], positional[1], extraArgs);
    if (operation === "verify-live") return await verifyLiveCommand(positional[0], extraArgs);
    if (operation === "qualify-payload") return await qualifyPromotedPayload(positional[0]);
    throw new PublicationError("UNKNOWN_COMMAND", "Unsupported publication command.");
  } catch (error) {
    return { status: "HOLD", code: error?.code || "PUBLICATION_HOLD", error: error?.message || "Publication stage failed closed.", details: error?.details || {} };
  }
}

export function makeOwnerApprovalForFixture(approval, privateKey, actions, approvedAt = "2026-09-29T00:00:00.000Z") {
  const record = {
    approvalVersion: 1, decision: "OWNER_APPROVED", approvalPackageDigest: approval.approvalPackageDigest,
    candidateId: approval.candidateId, candidateDigest: approval.candidateDigest, capsuleSha256: approval.capsuleSha256,
    publisherCommit: approval.publisherCommit, publisherTree: approval.publisherTree, baseSiteCommit: approval.baseSiteCommit, baseSiteTree: approval.baseSiteTree,
    productId: approval.productId, submissionType: approval.submissionType, artifactSha256: approval.artifactSha256,
    approvedActions: [...actions].sort(), approvedAt, signatureAlgorithm: "Ed25519"
  };
  record.signerKeyId = ownerKeyId(crypto.createPublicKey(privateKey));
  record.approvalId = approvalIdPayload(record);
  record.signature = crypto.sign(null, approvalSigningPayload(record), privateKey).toString("base64");
  return record;
}
