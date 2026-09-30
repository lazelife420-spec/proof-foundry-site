import fs from "node:fs";
import fsp from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const CLI = path.join(ROOT, "scripts", "pf-product.mjs");
const BUILD = path.join(ROOT, "scripts", "build-site.ps1");
const BASE_COMMIT = "d52eedb6fcbf5ead060318e8fee0e60406dc19a2";
const BASE_TREE = "32cf38d80988871a9fcd29410bbea2fd0b6d7c0f";
const BASE_MANIFEST_SHA256 = "947cb391f264781ce7ddd5f3c86c7cb81684daf9d2a2fd725ab0da2510bb27f9";
const PROTECTED_MASTER = path.dirname(path.resolve(ROOT, git(["rev-parse", "--git-common-dir"])));
const DEFAULT_CANDIDATE_HOME = path.join(os.tmpdir(), "pf-product-publisher-candidates");
const SUBMISSION_TYPES = new Set(["NEW_PRODUCT", "NEW_VERSION", "PRESENTATION_UPDATE"]);
const PUBLISHER_SOURCE_PATHS = new Set([
  "P0_CURRENT_PUBLISHING_ARCHITECTURE.md", "PRODUCT_PUBLISHING_CAPSULE_V1.md",
  "P3_CANDIDATE_MATERIALIZATION.md", "P4_PRODUCT_PREVIEW.md", "P5_PRODUCT_QUALIFICATION.md",
  "P5C_PUBLISHER_SOURCE_FREEZE.md", "P6_OWNER_APPROVAL_BOUNDARY.md", "pf-product.ps1",
  "schemas/product-publishing-capsule-v1.schema.json", "schemas/product-release-submission-v1.schema.json",
  "schemas/product-candidate-approval-v1.schema.json", "schemas/product-owner-approval-v1.schema.json",
  "scripts/pf-product.mjs", "scripts/pf-product-p3-p5.mjs", "scripts/pf-product-p7-p9.mjs",
  "scripts/test-pf-product.mjs", "scripts/test-pf-product-p3-p5.mjs", "scripts/test-pf-product-p6.mjs",
  "scripts/test-pf-product-p7.mjs", "scripts/test-pf-product-p8.mjs", "scripts/test-pf-product-p9.mjs",
  "P7_P9_PUBLICATION_ENGINE.md"
]);
const TESTS = [
  { id: "PF_PRODUCT", kind: "node", file: "scripts/test-pf-product.mjs" },
  { id: "LEGACY_CAPSULE", kind: "pwsh", file: "scripts/test-product-capsule.ps1" },
  { id: "H9_BINDING", kind: "pwsh", file: "scripts/test-h9-binding.ps1" },
  { id: "H9_HOME", kind: "pwsh", file: "scripts/test-h9-homepage.ps1" },
  { id: "H13", kind: "pwsh", file: "scripts/test-h13-modular-products.ps1" },
  { id: "RELEASE_TRUTH", kind: "pwsh", file: "scripts/test-release-truth.ps1" },
  { id: "RECEIPTS", kind: "pwsh", file: "scripts/test-receipts-invariants.ps1" },
  { id: "TRUTH_FILES", kind: "pwsh", file: "scripts/test-truth-files.ps1" },
  { id: "H11", kind: "pwsh", file: "scripts/test-h11-public-truth.ps1" },
  { id: "H12", kind: "pwsh", file: "scripts/test-h12-truth-discovery.ps1" }
];
const SECRETISH = /(?:-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----|\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|sk_(?:live|test)_[A-Za-z0-9]{16,}|AKIA[0-9A-Z]{16})\b|\bBearer\s+[A-Za-z0-9._~+/-]{24,})/i;
const ACTIVE_HTML = /<\s*(?:script|iframe|object|embed|form)\b|\bon[a-z]{3,}\s*=\s*["']/i;

function sorted(value) {
  if (Array.isArray(value)) return value.map(sorted);
  if (value && typeof value === "object") {
    const out = {};
    for (const key of Object.keys(value).sort((a, b) => a.localeCompare(b, "en"))) out[key] = sorted(value[key]);
    return out;
  }
  return value;
}
function canonical(value) { return JSON.stringify(sorted(value)); }
function pretty(value) { return JSON.stringify(sorted(value), null, 2) + "\n"; }
function shaBytes(bytes) { return crypto.createHash("sha256").update(bytes).digest("hex"); }
async function shaFile(file) { return shaBytes(await fsp.readFile(file)); }
function isWithin(parent, child) {
  const rel = path.relative(path.resolve(parent), path.resolve(child));
  return rel === "" || (rel !== ".." && !rel.startsWith(".." + path.sep) && !path.isAbsolute(rel));
}
function safeRel(rel) {
  return typeof rel === "string" && rel.length > 0 && !rel.includes("\\") && !rel.startsWith("/") &&
    !/^[A-Za-z]:/.test(rel) && !/[:?#]/.test(rel) &&
    rel.split("/").every((p) => p && p !== "." && p !== ".." && /^[A-Za-z0-9._-]+$/.test(p));
}
function assertRepoRelative(rel) { if (!safeRel(rel)) throw new Error("unsafe repository-relative candidate path"); }
function p2Run(capsuleDir) {
  const r = spawnSync(process.execPath, [CLI, "validate", capsuleDir], {
    cwd: ROOT, encoding: "utf8", timeout: 300000, maxBuffer: 16 * 1024 * 1024, windowsHide: true
  });
  let report;
  try { report = JSON.parse(r.stdout || ""); } catch { throw new Error("Capsule validation did not return a structured report."); }
  if (r.error) throw new Error("Capsule validation process could not start.");
  return { report, exitCode: r.status ?? 2 };
}
function git(args) {
  const r = spawnSync("git", args, { cwd: ROOT, encoding: "utf8", timeout: 15000, windowsHide: true });
  if (r.error || r.status !== 0) throw new Error("Could not verify the frozen source binding.");
  return (r.stdout || "").trim();
}
async function verifyBase() {
  const commit = git(["rev-parse", "HEAD"]);
  const tree = git(["show", "-s", "--format=%T", "HEAD"]);
  const baseTree = git(["show", "-s", "--format=%T", BASE_COMMIT]);
  const committedAt = git(["show", "-s", "--format=%cI", BASE_COMMIT]);
  const mergeBase = git(["merge-base", "HEAD", BASE_COMMIT]);
  const trackedStatus = git(["status", "--porcelain", "--untracked-files=all"]);
  const manifestSha256 = await shaFile(path.join(ROOT, "site-manifest.json"));
  if (baseTree !== BASE_TREE || mergeBase !== BASE_COMMIT) throw new Error("Checkout is not based on the frozen P0-P2 baseline.");
  for (const line of trackedStatus.split(/\r?\n/).filter(Boolean)) {
    const rel = gitStatusPath(line).replaceAll("\\", "/");
    if (!PUBLISHER_SOURCE_PATHS.has(rel)) throw new Error("Non-publisher source differs from the frozen site baseline.");
  }
  if (manifestSha256 !== BASE_MANIFEST_SHA256) throw new Error("Canonical manifest differs from the frozen P0-P2 receipt.");
  return { commit: BASE_COMMIT, tree: BASE_TREE, committedAt, manifestSha256,
    publisherCommit: commit, publisherTree: tree };
}
function gitStatusPath(line) {
  if (line.length >= 3 && line[2] === " ") return line.slice(3);
  if (line.length >= 2 && line[1] === " ") return line.slice(2);
  throw new Error("Git status returned an unsupported porcelain path record.");
}
function publisherWorkingTreeIsClean() {
  return git(["status", "--porcelain", "--untracked-files=all"]) === "";
}
async function walkFiles(root) {
  const result = [];
  async function walk(dir, prefix) {
    const entries = await fsp.readdir(dir, { withFileTypes: true });
    entries.sort((a, b) => a.name.localeCompare(b.name, "en"));
    for (const entry of entries) {
      const rel = prefix ? prefix + "/" + entry.name : entry.name;
      const full = path.join(dir, entry.name), stat = await fsp.lstat(full);
      if (stat.isSymbolicLink()) throw new Error("Candidate inputs cannot contain symbolic links or reparse points.");
      if (stat.isDirectory()) await walk(full, rel);
      else if (stat.isFile()) result.push({ path: rel, full, bytes: stat.size });
      else throw new Error("Candidate input contains an unsupported filesystem entry.");
    }
  }
  await walk(path.resolve(root), "");
  return result.sort((a, b) => a.path.localeCompare(b.path, "en"));
}
async function inventoryDir(root) {
  const files = await walkFiles(root), lines = [];
  for (const f of files) lines.push(f.path + "\0" + f.bytes + "\0" + await shaFile(f.full) + "\n");
  return { files, sha256: shaBytes(Buffer.from(lines.join(""), "utf8")) };
}
async function normalizedInventoryDir(root) {
  const files = await walkFiles(root), lines = [];
  for (const f of files) {
    let bytes = await fsp.readFile(f.full);
    if (/\.(?:html|svg|json|xml|txt|css|js|mjs)$/i.test(f.path)) {
      bytes = Buffer.from(normalizePreviewText(f.path, bytes.toString("utf8")), "utf8");
    }
    lines.push(f.path + "\0" + bytes.length + "\0" + shaBytes(bytes) + "\n");
  }
  return shaBytes(Buffer.from(lines.join(""), "utf8"));
}
function normalizePreviewText(rel, value) {
  let text = value.replace(/("generatedAt"\s*:\s*")[^"]+(\")/g, "$1[BUILD_TIME]$2");
  if (/\.(?:html|svg)$/i.test(rel)) {
    text = text.replace(/style="([^"]*)"/g, (whole, body) => {
      const declarations = body.split(";").filter(Boolean);
      if (!declarations.length || !declarations.every((x) => x.trim().startsWith("--product-"))) return whole;
      const names = declarations.map((x) => x.slice(0, x.indexOf(":")).trim());
      if (new Set(names).size !== names.length) return whole;
      return "style=\"" + declarations.sort((a, b) => a.localeCompare(b, "en")).join(";") + "\"";
    });
  }
  return text;
}
async function compareTreesWithBuildNormalization(actualRoot, expectedRoot) {
  const actual = await walkFiles(actualRoot), expected = await walkFiles(expectedRoot);
  const actualByPath = new Map(actual.map((f) => [f.path, f]));
  const expectedByPath = new Map(expected.map((f) => [f.path, f]));
  if (actualByPath.size !== expectedByPath.size || [...actualByPath.keys()].some((p) => !expectedByPath.has(p))) return false;
  for (const [rel, a] of actualByPath) {
    const e = expectedByPath.get(rel);
    if (/\.(?:html|svg|json|xml|txt|css|js|mjs)$/i.test(rel)) {
      const [aText, eText] = await Promise.all([fsp.readFile(a.full, "utf8"), fsp.readFile(e.full, "utf8")]);
      if (normalizePreviewText(rel, aText) !== normalizePreviewText(rel, eText)) return false;
    } else if (a.bytes !== e.bytes || await shaFile(a.full) !== await shaFile(e.full)) return false;
  }
  return true;
}
async function parseJsonFile(file) { return JSON.parse(await fsp.readFile(file, "utf8")); }
function semverParts(s) {
  const m = String(s || "").match(/^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/);
  if (!m) return null;
  return { core: m.slice(1, 4).map(Number), pre: m[4] ? m[4].split(".") : null };
}
function compareSemver(a, b) {
  const x = semverParts(a), y = semverParts(b);
  if (!x || !y) return null;
  for (let i = 0; i < 3; i++) if (x.core[i] !== y.core[i]) return x.core[i] > y.core[i] ? 1 : -1;
  if (!x.pre && !y.pre) return 0;
  if (!x.pre) return 1;
  if (!y.pre) return -1;
  const n = Math.min(x.pre.length, y.pre.length);
  for (let i = 0; i < n; i++) {
    const an = /^\d+$/.test(x.pre[i]), bn = /^\d+$/.test(y.pre[i]);
    if (an && bn) {
      const av = Number(x.pre[i]), bv = Number(y.pre[i]);
      if (av !== bv) return av > bv ? 1 : -1;
    } else if (an !== bn) return an ? -1 : 1;
    else if (x.pre[i] !== y.pre[i]) return x.pre[i] > y.pre[i] ? 1 : -1;
  }
  return x.pre.length === y.pre.length ? 0 : x.pre.length > y.pre.length ? 1 : -1;
}
function mediaType(file) {
  const lower = file.toLowerCase();
  if (lower.endsWith(".zip")) return "application/zip";
  if (lower.endsWith(".msi")) return "application/x-msi";
  if (lower.endsWith(".exe")) return "application/vnd.microsoft.portable-executable";
  if (lower.endsWith(".apk")) return "application/vnd.android.package-archive";
  if (lower.endsWith(".dmg")) return "application/x-apple-diskimage";
  if (lower.endsWith(".pdf")) return "application/pdf";
  if (lower.endsWith(".json")) return "application/json";
  if (lower.endsWith(".txt")) return "text/plain";
  if (lower.endsWith(".tar.gz") || lower.endsWith(".gz")) return "application/gzip";
  return "application/octet-stream";
}
function releaseSeal(p) {
  const rel = structuredClone(p?.release || {});
  delete rel.candidateVersion;
  return {
    publicReleaseProjection: rel,
    artifacts: (p?.artifacts || []).map((a) => ({
      filename: a.filename ?? null, sizeBytes: a.sizeBytes ?? null, sha256: a.sha256 ?? null,
      downloadUrl: a.downloadUrl ?? null, sha256Url: a.sha256Url ?? null,
      platform: a.platform ?? null, distType: a.distType ?? null, signingStatus: a.signingStatus ?? null
    })),
    downloadUrl: p?.downloadUrl ?? null, sha256Url: p?.sha256Url ?? null, sha256: p?.sha256 ?? null,
    verification: p?.verification ?? null
  };
}
function safeNewProductRecord(capsule, module) {
  const name = String(module.brand?.name || module.meta?.title || capsule.productId);
  const summary = String(module.card?.summary || module.hero?.lede || module.meta?.description || "Candidate product.");
  const valueLine = String(module.card?.tagline || module.hero?.lede || "Candidate product presentation.");
  return {
    id: capsule.productId, name, displayName: name, route: module.route,
    state: "coming", productStatus: "UNRELEASED", platforms: capsule.platforms, platform: capsule.platforms.join(" + "),
    summary, cardSummary: summary, description: String(module.meta?.description || summary),
    cta: "View preview", visible: false,
    presentation: { valueLine, downloadUnavailable: true, downloadNotice: "Local candidate preview; no public download is published." },
    release: { publicVersion: null, candidateVersion: capsule.releaseVersion, releaseStatus: "UNRELEASED" },
    artifacts: [], evidence: [], proofLinks: [], tests: [],
    verification: { status: "NOT_VERIFIED" },
    downloadUrl: null, sha256Url: null, sha256: null,
    proofStatus: "Unverified", releaseNote: "Candidate preview only. No public release has been published."
  };
}
function htmlEscape(value) {
  return String(value ?? "").replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#39;");
}
function presentationWarnings(type, before, after) {
  if (type !== "NEW_VERSION" || canonical(before) === canonical(after)) return [];
  return ["NEW_VERSION_PRESENTATION_DELTA: submitted product presentation differs from the current module; owner should confirm these changes belong with the version candidate."];
}
async function createPlan(capsuleDir, validationReport, base) {
  const c = await parseJsonFile(path.join(capsuleDir, "capsule.json"));
  const submittedModule = await parseJsonFile(path.join(capsuleDir, "product", "module.json"));
  const release = await parseJsonFile(path.join(capsuleDir, "release", "release.json"));
  if (!SUBMISSION_TYPES.has(c.submissionType)) throw new Error("Unsupported submission type.");
  const manifest = await parseJsonFile(path.join(ROOT, "site-manifest.json"));
  const manifestProduct = (manifest.products || []).find((p) => p.id === c.productId) || null;
  const productDir = path.join(ROOT, "products", c.productId);
  const moduleFile = path.join(productDir, "module.json");
  const baseModule = fs.existsSync(moduleFile) ? await parseJsonFile(moduleFile) : null;
  if (c.submissionType === "NEW_PRODUCT" && (manifestProduct || baseModule)) throw new Error("NEW_PRODUCT identity already exists.");
  if (c.submissionType !== "NEW_PRODUCT" && (!manifestProduct || !baseModule)) throw new Error("Update submission requires an existing product and module.");
  if (manifestProduct?.release?.releaseStatus === "WITHDRAWN" && c.submissionType === "NEW_VERSION") throw new Error("A withdrawn product cannot be reintroduced by this tranche.");
  const effectiveModule = structuredClone(submittedModule);
  let compatibilityWarning = null;
  if (baseModule?.homepage?.mediaDisclosure && effectiveModule.homepage &&
      !Object.hasOwn(effectiveModule.homepage, "mediaDisclosure")) {
    effectiveModule.homepage.mediaDisclosure = baseModule.homepage.mediaDisclosure;
    compatibilityWarning = "P2_SCHEMA_COMPATIBILITY_PRESERVED: retained canonical homepage.mediaDisclosure because the current Capsule module schema does not admit this renderer field.";
  }
  const warnings = presentationWarnings(c.submissionType, baseModule, effectiveModule);
  if (compatibilityWarning) warnings.push(compatibilityWarning);
  if (baseModule) {
    if (submittedModule.id !== baseModule.id || submittedModule.route !== baseModule.route) throw new Error("Update candidate cannot change product identity or route.");
    if (submittedModule.lifecycle !== baseModule.lifecycle || submittedModule.visibility !== baseModule.visibility) throw new Error("Update candidate cannot change publication lifecycle or visibility.");
    if (canonical(submittedModule.commerce) !== canonical(baseModule.commerce)) throw new Error("Commerce changes are outside P3-P5 candidate authority.");
  } else {
    effectiveModule.lifecycle = "preview";
    effectiveModule.visibility = "hidden";
    effectiveModule.commerce = { status: "COMING_SOON", label: "Coming soon" };
  }
  if (c.submissionType === "PRESENTATION_UPDATE" && manifestProduct.release.publicVersion !== c.releaseVersion) throw new Error("PRESENTATION_UPDATE must preserve the canonical public version.");
  if (c.submissionType === "NEW_VERSION") {
    const oldVersion = manifestProduct.release?.publicVersion || manifestProduct.release?.candidateVersion;
    if (oldVersion && compareSemver(c.releaseVersion, oldVersion) <= 0) throw new Error("NEW_VERSION must exceed the current public/candidate version.");
  }
  const contentPath = path.join(capsuleDir, "product", "content.html");
  if (fs.existsSync(contentPath)) {
    const submittedContent = await fsp.readFile(contentPath);
    const currentContentPath = path.join(productDir, "content.html");
    const unchangedCanonicalContent = fs.existsSync(currentContentPath) &&
      submittedContent.equals(await fsp.readFile(currentContentPath));
    if (!unchangedCanonicalContent) {
      const content = submittedContent.toString("utf8");
      if (SECRETISH.test(content) || ACTIVE_HTML.test(content)) throw new Error("Changed submitted content contains a blocked secret-like value or active HTML.");
    }
  }
  const sourceFiles = new Map();
  function addSource(rel, bytes, reason) {
    assertRepoRelative(rel);
    sourceFiles.set(rel, { bytes: Buffer.from(bytes), authorityReason: reason });
  }
  if (!baseModule || canonical(effectiveModule) !== canonical(baseModule)) {
    addSource("products/" + c.productId + "/module.json", Buffer.from(pretty(effectiveModule), "utf8"),
      c.submissionType === "NEW_PRODUCT" ? "New candidate module normalized to preview/hidden pending a later publication decision." : "Submitted product presentation module; semantic module changes are explicitly included.");
  }
  if (fs.existsSync(contentPath)) addSource("products/" + c.productId + "/content.html", await fsp.readFile(contentPath), "Submitted product narrative content.");
  for (const [from, to] of [["product/logo.svg", "logo.svg"], ["product/wordmark.svg", "wordmark.svg"]]) {
    const file = path.join(capsuleDir, from);
    if (fs.existsSync(file)) addSource("products/" + c.productId + "/" + to, await fsp.readFile(file), "Submitted product brand asset.");
  }
  const mediaDir = path.join(capsuleDir, "product", "media");
  if (fs.existsSync(mediaDir)) {
    const moduleText = canonical(effectiveModule);
    const contentText = fs.existsSync(contentPath) ? await fsp.readFile(contentPath, "utf8") : "";
    for (const f of await walkFiles(mediaDir)) {
      const bytes = await fsp.readFile(f.full);
      const newAssetRef = "/assets/products/" + c.productId + "/media/" + f.path;
      const legacyAssetRef = "/assets/" + c.productId + "/" + f.path;
      let mapped = false;
      if (moduleText.includes(newAssetRef) || contentText.includes(newAssetRef)) {
        addSource("products/" + c.productId + "/media/" + f.path, bytes, "Submitted media referenced through Product Module V2 product-local assets.");
        mapped = true;
      }
      if (moduleText.includes(legacyAssetRef) || contentText.includes(legacyAssetRef)) {
        addSource("assets/" + c.productId + "/" + f.path, bytes, "Submitted media referenced through the existing product asset namespace.");
        mapped = true;
      }
      if (!mapped) throw new Error("Submitted product media has no declared module/content reference.");
    }
  }
  if (c.submissionType === "NEW_PRODUCT") manifest.products.push(safeNewProductRecord(c, effectiveModule));
  else if (c.submissionType === "NEW_VERSION") manifestProduct.release.candidateVersion = c.releaseVersion;
  if (c.submissionType !== "PRESENTATION_UPDATE") {
    addSource("site-manifest.json", Buffer.from(pretty(manifest), "utf8"),
      c.submissionType === "NEW_PRODUCT" ?
        "Add a hidden UNRELEASED candidate record without public artifact URLs or VERIFIED state." :
        "Set candidateVersion only; preserve current public version, artifacts, URLs, verification, receipts, and source commit.");
  }
  const changes = [], proposedFiles = new Map();
  for (const [rel, item] of [...sourceFiles.entries()].sort((a, b) => a[0].localeCompare(b[0], "en"))) {
    const basePath = path.join(ROOT, ...rel.split("/"));
    const exists = fs.existsSync(basePath), pre = exists ? await fsp.readFile(basePath) : null;
    if (pre && pre.equals(item.bytes)) continue;
    const operation = exists ? "MODIFY" : "ADD";
    const allowed = rel === "site-manifest.json" || rel.startsWith("products/" + c.productId + "/") || rel.startsWith("assets/" + c.productId + "/");
    if (!allowed) throw new Error("Materialization attempted a path outside product/canonical-state scope.");
    changes.push({ path: rel, operation, preImageSha256: pre ? shaBytes(pre) : null,
      postImageSha256: shaBytes(item.bytes), authorityReason: item.authorityReason });
    proposedFiles.set(rel, item.bytes);
  }
  const candidateRecord = c.submissionType === "NEW_PRODUCT"
    ? manifest.products.find((p) => p.id === c.productId)
    : manifestProduct;
  const sourceProducts = structuredClone(manifest.products);
  const stateSourceBytes = Buffer.from(pretty({ products: sourceProducts }), "utf8");
  const stateSourceSha256 = shaBytes(stateSourceBytes);
  const artifactInventory = [];
  for (const a of c.artifactRefs || []) {
    const bytes = await fsp.readFile(path.join(capsuleDir, ...a.path.split("/")));
    artifactInventory.push({
      packagePath: a.path, filename: path.posix.basename(a.path), platform: a.platform,
      sizeBytes: bytes.length, declaredSha256: String(a.sha256).toLowerCase(),
      computedSha256: shaBytes(bytes), mimeType: mediaType(a.path), publicDownload: "NOT_PUBLISHED"
    });
  }
  const evidenceById = new Map((release.evidence || []).map((e) => [e.id, e]));
  const evidenceInventory = [];
  for (const e of release.evidence || []) {
    const bytes = await fsp.readFile(path.join(capsuleDir, ...e.path.split("/")));
    evidenceInventory.push({ id: e.id, kind: e.kind, packagePath: e.path, sizeBytes: bytes.length, sha256: shaBytes(bytes) });
  }
  const claims = (release.claims || []).map((claim) => ({
    id: claim.id, summary: claim.summary,
    evidence: (claim.evidenceIds || []).map((id) => {
      const item = evidenceById.get(id);
      return item ? { id: item.id, kind: item.kind, packagePath: item.path, assessment: "SUPPLIED_UNADJUDICATED" } : { id, assessment: "UNSUPPORTED" };
    }),
    verificationDimension: "SUBMITTED_PRODUCT_CLAIM",
    verdict: (claim.evidenceIds || []).length ? "UNRESOLVED" : "UNSUPPORTED",
    authoritative: false
  }));
  const stateProduct = candidateRecord ? structuredClone(candidateRecord) : null;
  const proposedProductState = {
    productId: c.productId, requestedLifecycle: c.requestedLifecycle,
    effectiveLifecycle: effectiveModule.lifecycle, effectiveVisibility: effectiveModule.visibility,
    releaseStatus: stateProduct?.release?.releaseStatus || null,
    currentPublicVersion: stateProduct?.release?.publicVersion ?? null,
    candidateVersion: stateProduct?.release?.candidateVersion ?? null,
    verificationStatus: stateProduct?.verification?.status || "NOT_VERIFIED",
    publicDownloadForSubmittedArtifacts: artifactInventory.length ? "NOT_PUBLISHED" : "NO_NEW_ARTIFACT",
    candidateArtifacts: artifactInventory
  };
  const digestInputs = {
    candidateSchemaVersion: 1, baseCommit: base.commit, baseTree: base.tree,
    baseManifestSha256: base.manifestSha256, capsuleSha256: validationReport.capsuleSha256,
    submissionType: c.submissionType, productId: c.productId, releaseVersion: c.releaseVersion,
    proposedPaths: changes, candidateStateSourceSha256: stateSourceSha256,
    artifacts: artifactInventory, evidence: evidenceInventory, claims,
    qualificationProfiles: c.qualificationProfiles || []
  };
  const candidateDigest = shaBytes(Buffer.from(canonical(digestInputs), "utf8"));
  const candidateId = "pfc-" + candidateDigest.slice(0, 24);
  const candidateState = {
    candidateSchemaVersion: 1, candidateId, candidateDigest,
    createdFromCapsuleSha256: validationReport.capsuleSha256,
    submissionType: c.submissionType, productId: c.productId, releaseVersion: c.releaseVersion,
    requestedLifecycle: c.requestedLifecycle, baseCommit: base.commit, baseTree: base.tree,
    baseManifestSha256: base.manifestSha256, proposedPaths: changes, proposedProductState,
    artifacts: artifactInventory, evidence: evidenceInventory, claims,
    qualificationProfiles: c.qualificationProfiles || [], candidateStateSourceSha256: stateSourceSha256,
    validationResult: { status: validationReport.status, module: validationReport.moduleValidation?.status || "FAIL" },
    publicationState: "VALID_UNVERIFIED", warnings
  };
  const candidateStateBytes = Buffer.from(pretty(candidateState), "utf8");
  return {
    c, release, effectiveModule, manifest, candidateRecord, sourceProducts, proposedFiles, changes,
    artifactInventory, evidenceInventory, claims, candidateState, candidateStateBytes,
    candidateStateSha256: shaBytes(candidateStateBytes), stateSourceBytes, stateSourceSha256,
    candidateDigest, candidateId, validationReport, base, warnings
  };
}
async function copyTree(source, dest) {
  const stat = await fsp.lstat(source);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error("Expected a real directory for candidate staging.");
  await fsp.mkdir(dest, { recursive: true });
  for (const entry of await fsp.readdir(source, { withFileTypes: true })) {
    const from = path.join(source, entry.name), to = path.join(dest, entry.name), child = await fsp.lstat(from);
    if (child.isSymbolicLink()) throw new Error("Symbolic links are not allowed in candidate staging.");
    if (child.isDirectory()) await copyTree(from, to);
    else if (child.isFile()) { await fsp.mkdir(path.dirname(to), { recursive: true }); await fsp.copyFile(from, to); }
    else throw new Error("Unsupported candidate staging entry.");
  }
}
async function writeBundle(stage, capsuleDir, plan) {
  await fsp.mkdir(stage, { recursive: true });
  await copyTree(capsuleDir, path.join(stage, "submitted-capsule"));
  for (const [rel, bytes] of plan.proposedFiles) {
    const target = path.join(stage, "proposed-source", ...rel.split("/"));
    await fsp.mkdir(path.dirname(target), { recursive: true });
    await fsp.writeFile(target, bytes);
  }
  await fsp.writeFile(path.join(stage, "candidate-state.json"), plan.candidateStateBytes);
  await fsp.writeFile(path.join(stage, "candidate-state-source.json"), plan.stateSourceBytes);
  await fsp.writeFile(path.join(stage, "candidate-changed-paths.json"), pretty(plan.changes), "utf8");
  for (const a of plan.artifactInventory) {
    const dst = path.join(stage, "candidate-artifacts", ...a.packagePath.split("/"));
    await fsp.mkdir(path.dirname(dst), { recursive: true });
    await fsp.copyFile(path.join(capsuleDir, ...a.packagePath.split("/")), dst);
  }
  for (const e of plan.evidenceInventory) {
    const dst = path.join(stage, "candidate-evidence", ...e.packagePath.split("/"));
    await fsp.mkdir(path.dirname(dst), { recursive: true });
    await fsp.copyFile(path.join(capsuleDir, ...e.packagePath.split("/")), dst);
  }
  await fsp.writeFile(path.join(stage, "materialization-receipt.json"), pretty({
    receiptSchemaVersion: 1, candidateId: plan.candidateId, candidateDigest: plan.candidateDigest,
    candidateStateSha256: plan.candidateStateSha256, capsuleSha256: plan.validationReport.capsuleSha256,
    createdAt: new Date().toISOString(), createdBy: "pf-product materialize",
    publicationState: "VALID_UNVERIFIED"
  }), "utf8");
}
function parseMaterializeArgs(args) {
  let outputDir = DEFAULT_CANDIDATE_HOME;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--output-dir" && args[i + 1]) { outputDir = path.resolve(args[++i]); continue; }
    throw new Error("Only --output-dir <directory> is supported.");
  }
  return outputDir;
}
async function safeOutputBase(outputDir, capsuleDir) {
  if (isWithin(ROOT, outputDir) || isWithin(outputDir, ROOT) ||
      isWithin(capsuleDir, outputDir) || isWithin(outputDir, capsuleDir) ||
      isWithin(PROTECTED_MASTER, outputDir) || isWithin(outputDir, PROTECTED_MASTER)) {
    throw new Error("Candidate output must remain outside source checkouts and the Capsule.");
  }
  await fsp.mkdir(outputDir, { recursive: true });
  const stat = await fsp.lstat(outputDir);
  if (stat.isSymbolicLink() || !stat.isDirectory()) throw new Error("Candidate output root must be a real directory.");
  return await fsp.realpath(outputDir);
}
async function exactCandidateFiles(candidateRoot, plan) {
  const actual = new Set((await walkFiles(candidateRoot)).map((f) => f.path));
  const required = new Set(["candidate-state.json", "candidate-state-source.json", "candidate-changed-paths.json", "materialization-receipt.json"]);
  for (const rel of plan.proposedFiles.keys()) required.add("proposed-source/" + rel);
  for (const a of plan.artifactInventory) required.add("candidate-artifacts/" + a.packagePath);
  for (const e of plan.evidenceInventory) required.add("candidate-evidence/" + e.packagePath);
  for (const f of await walkFiles(path.join(candidateRoot, "submitted-capsule"))) required.add("submitted-capsule/" + f.path);
  const optionalPrefixes = ["preview-site/", "owner-review-package/"], optionalFiles = new Set(["preview-receipt.json", "qualification-record.json"]);
  for (const rel of actual) {
    if (required.has(rel) || optionalFiles.has(rel) || optionalPrefixes.some((p) => rel.startsWith(p))) continue;
    return { ok: false, finding: "Unexpected candidate path: " + rel };
  }
  for (const rel of required) if (!actual.has(rel)) return { ok: false, finding: "Candidate path is missing: " + rel };
  return { ok: true };
}
async function verifyCandidate(candidateRoot, options = {}) {
  const root = path.resolve(candidateRoot), stat = await fsp.lstat(root);
  if (!stat.isDirectory() || stat.isSymbolicLink()) throw new Error("Candidate path must be a real directory.");
  if (isWithin(ROOT, root) || isWithin(root, ROOT) || isWithin(PROTECTED_MASTER, root) || isWithin(root, PROTECTED_MASTER)) {
    throw new Error("Candidate must remain outside source checkouts.");
  }
  const base = await verifyBase(), state = await parseJsonFile(path.join(root, "candidate-state.json"));
  const receipt = await parseJsonFile(path.join(root, "materialization-receipt.json"));
  const capsuleDir = path.join(root, "submitted-capsule"), p2 = p2Run(capsuleDir);
  if (p2.exitCode !== 0 || p2.report.status !== "VALID_UNVERIFIED") throw new Error("Candidate Capsule no longer passes P2 validation.");
  const plan = await createPlan(capsuleDir, p2.report, base);
  if (plan.candidateId !== state.candidateId || plan.candidateDigest !== state.candidateDigest ||
      canonical(plan.candidateState) !== canonical(state)) throw new Error("Candidate state/digest does not match Capsule and frozen base.");
  if (receipt.candidateId !== plan.candidateId || receipt.candidateDigest !== plan.candidateDigest ||
      receipt.candidateStateSha256 !== plan.candidateStateSha256 || !Number.isFinite(Date.parse(receipt.createdAt))) {
    throw new Error("Materialization receipt does not bind to candidate state.");
  }
  const setCheck = await exactCandidateFiles(root, plan);
  if (!setCheck.ok) throw new Error(setCheck.finding);
  const changed = await parseJsonFile(path.join(root, "candidate-changed-paths.json"));
  if (canonical(changed) !== canonical(plan.changes)) throw new Error("Changed-path manifest does not match candidate source.");
  if (shaBytes(await fsp.readFile(path.join(root, "candidate-state-source.json"))) !== plan.stateSourceSha256) throw new Error("Candidate state source changed.");
  for (const [rel, bytes] of plan.proposedFiles) {
    const actual = await fsp.readFile(path.join(root, "proposed-source", ...rel.split("/")));
    if (!actual.equals(bytes)) throw new Error("Candidate source bytes changed.");
  }
  for (const a of plan.artifactInventory) {
    const actual = await fsp.readFile(path.join(root, "candidate-artifacts", ...a.packagePath.split("/")));
    if (actual.length !== a.sizeBytes || shaBytes(actual) !== a.computedSha256) throw new Error("Candidate artifact bytes differ from submitted bytes.");
  }
  for (const e of plan.evidenceInventory) {
    const actual = await fsp.readFile(path.join(root, "candidate-evidence", ...e.packagePath.split("/")));
    if (actual.length !== e.sizeBytes || shaBytes(actual) !== e.sha256) throw new Error("Candidate evidence bytes differ from submitted bytes.");
  }
  const previewDir = path.join(root, "preview-site"), previewReceiptPath = path.join(root, "preview-receipt.json");
  if (fs.existsSync(previewDir) !== fs.existsSync(previewReceiptPath)) throw new Error("Preview output and preview receipt must exist together.");
  if (options.checkPreview && fs.existsSync(previewReceiptPath)) {
    const pr = await parseJsonFile(previewReceiptPath), tree = await inventoryDir(previewDir);
    if (pr.candidateDigest !== plan.candidateDigest || pr.sitePayloadSha256 !== tree.sha256) throw new Error("Preview output differs from its receipt.");
  }
  if (fs.existsSync(path.join(root, "qualification-record.json"))) {
    const q = await parseJsonFile(path.join(root, "qualification-record.json"));
    if (q.candidateDigest !== plan.candidateDigest || q.candidateId !== plan.candidateId ||
        q.publicationState !== "QUALIFIED_UNPUBLISHED") throw new Error("Qualification record does not bind to candidate.");
  }
  return { root, base, plan, state };
}
function emit(value, exitCode, silent = false) {
  if (!silent) console.log(JSON.stringify(value, null, 2));
  return { exitCode, report: value };
}
async function materializeCommand(capsuleArg, args) {
  if (!capsuleArg) return jsonReport({ status: "INVALID", error: "A Capsule directory is required." }, 2);
  const capsuleDir = path.resolve(process.cwd(), capsuleArg);
  try {
    const stat = await fsp.lstat(capsuleDir);
    if (!stat.isDirectory() || stat.isSymbolicLink()) return jsonReport({ status: "INVALID", error: "Capsule input must be a real directory." }, 2);
    const p2 = p2Run(capsuleDir);
    if (p2.exitCode !== 0 || p2.report.status !== "VALID_UNVERIFIED") return jsonReport({ status: "INVALID", validation: p2.report, publicationState: "INVALID" }, 1);
    const base = await verifyBase(), plan = await createPlan(capsuleDir, p2.report, base);
    const outputBase = await safeOutputBase(parseMaterializeArgs(args), capsuleDir);
    const final = path.join(outputBase, plan.candidateId);
    if (fs.existsSync(final)) {
      const existing = await verifyCandidate(final);
      if (existing.plan.candidateDigest !== plan.candidateDigest) throw new Error("Candidate ID collision.");
      return jsonReport({
        command: "materialize", status: "VALID_UNVERIFIED", reused: true, candidateId: plan.candidateId,
        candidatePath: final, candidateDigest: plan.candidateDigest, candidateStateSha256: plan.candidateStateSha256,
        changedPaths: plan.changes, artifacts: plan.artifactInventory, publicationState: "VALID_UNVERIFIED",
        exactNextAction: "Run pf-product preview " + final
      }, 0);
    }
    const stage = await fsp.mkdtemp(path.join(outputBase, ".pf-product-stage-" + plan.candidateId + "-"));
    try {
      await writeBundle(stage, capsuleDir, plan);
      await fsp.rename(stage, final);
    } catch (error) {
      const resolved = path.resolve(stage), basePath = path.resolve(outputBase) + path.sep;
      if (resolved.startsWith(basePath) && path.basename(resolved).startsWith(".pf-product-stage-")) await fsp.rm(resolved, { recursive: true, force: true });
      throw error;
    }
    return jsonReport({
      command: "materialize", status: "VALID_UNVERIFIED", reused: false, candidateId: plan.candidateId,
      candidatePath: final, candidateDigest: plan.candidateDigest, candidateStateSha256: plan.candidateStateSha256,
      changedPaths: plan.changes, artifacts: plan.artifactInventory, publicationState: "VALID_UNVERIFIED",
      exactNextAction: "Run pf-product preview " + final
    }, 0);
  } catch {
    return jsonReport({ command: "materialize", status: "INVALID", publicationState: "INVALID", error: "Candidate materialization failed validation or source-scope checks; inspect the Capsule and frozen-baseline binding." }, 1);
  }
}
async function copyCandidateProduct(tempProducts, plan) {
  await copyTree(path.join(ROOT, "products"), tempProducts);
  const id = plan.c.productId, target = path.join(tempProducts, id);
  await fsp.mkdir(target, { recursive: true });
  const module = structuredClone(plan.effectiveModule);
  module.lifecycle = "preview"; module.visibility = "hidden";
  await fsp.writeFile(path.join(target, "module.json"), pretty(module), "utf8");
  const capsule = path.join(plan.candidateRoot, "submitted-capsule");
  for (const [from, to] of [["product/content.html", "content.html"], ["product/logo.svg", "logo.svg"], ["product/wordmark.svg", "wordmark.svg"]]) {
    const src = path.join(capsule, from);
    if (fs.existsSync(src)) await fsp.copyFile(src, path.join(target, to));
  }
  const media = path.join(capsule, "product", "media");
  if (fs.existsSync(media)) {
    for (const f of await walkFiles(media)) {
      const dest = path.join(target, "media", ...f.path.split("/"));
      await fsp.mkdir(path.dirname(dest), { recursive: true });
      await fsp.copyFile(f.full, dest);
    }
  }
}
async function runBuild(options) {
  const args = ["-NoProfile", "-File", BUILD, "-OutDir", options.outDir, "-ProductsDir", options.productsDir,
    "-ManifestPath", options.manifestPath, "-TruthCommit", options.base.commit,
    "-TruthTree", options.base.tree, "-TruthCommittedAt", options.base.committedAt];
  if (options.stateSourcePath) args.push("-StateSourcePath", options.stateSourcePath);
  if (options.previewId) args.push("-PreviewProductId", options.previewId);
  const r = spawnSync("pwsh", args, { cwd: ROOT, encoding: "utf8", timeout: 240000, maxBuffer: 32 * 1024 * 1024, windowsHide: true });
  return { ok: !r.error && r.status === 0, output: (r.stdout || "") + "\n" + (r.stderr || "") };
}
function addPreviewPanel(html, plan, kind) {
  const id = htmlEscape(plan.c.productId), name = htmlEscape(plan.effectiveModule.brand?.name || plan.c.productId);
  const version = htmlEscape(plan.c.releaseVersion);
  const artifactLine = plan.artifactInventory.length
    ? "<p>Candidate artifact availability: <strong>PUBLIC_DOWNLOAD = NOT_PUBLISHED</strong>. No future download URL is shown.</p>"
    : "<p>No new artifact bytes are proposed; existing public release facts remain unchanged.</p>";
  const current = plan.candidateState.proposedProductState.currentPublicVersion;
  const currentLine = current ? "<p>Current public version remains v" + htmlEscape(current) + ".</p>" : "";
  const productPanel = "<section class=\"product-preview-notice\" data-candidate=\"" + id + "\" aria-label=\"Candidate status\">" +
    "<p><strong>PREVIEW</strong> · <strong>UNVERIFIED</strong> · <strong>NOT PUBLIC</strong></p>" +
    "<h2>Candidate review</h2><p>" + name + " · " + htmlEscape(plan.c.submissionType) + " · proposed v" + version + "</p>" +
    currentLine + artifactLine +
    "<p><a href=\"candidate-truth.json\">Candidate truth projection</a> · <a href=\"candidate-receipt.json\">Submitted evidence receipt</a></p></section>";
  const catalogPanel = "<aside class=\"product-preview-notice\" data-candidate=\"" + id + "\"><strong>PREVIEW · UNVERIFIED · NOT PUBLIC</strong>" +
    "<p>" + name + " · proposed v" + version + "</p>" + artifactLine +
    "<p><a href=\"../" + id + "/\">Open candidate page</a> · <a href=\"../" + id + "/candidate-truth.json\">Candidate truth</a></p></aside>";
  const homePanel = "<aside class=\"product-preview-notice\" data-candidate=\"" + id + "\"><strong>PREVIEW · UNVERIFIED · NOT PUBLIC</strong>" +
    "<p>" + name + " · proposed v" + version + "</p>" + artifactLine +
    "<p><a href=\"" + id + "/\">Open candidate page</a> · <a href=\"" + id + "/candidate-truth.json\">Candidate truth</a></p></aside>";
  const panel = kind === "product" ? productPanel : kind === "catalog" ? catalogPanel : homePanel;
  return /<\/body\s*>/i.test(html) ? html.replace(/<\/body\s*>/i, panel + "\n</body>") : html + panel;
}
function candidateProjections(plan) {
  const state = plan.candidateState.proposedProductState;
  const truth = {
    projectionSchemaVersion: 1, candidateId: plan.candidateId, candidateDigest: plan.candidateDigest,
    label: ["PREVIEW", "UNVERIFIED", "NOT PUBLIC"],
    product: { id: plan.c.productId, name: plan.effectiveModule.brand?.name || plan.c.productId, route: plan.effectiveModule.route },
    submissionType: plan.c.submissionType,
    release: { currentPublicVersion: state.currentPublicVersion, proposedVersion: plan.c.releaseVersion, canonicalStatus: state.releaseStatus },
    download: { submittedCandidateAvailability: plan.artifactInventory.length ? "NOT_PUBLISHED" : "NO_NEW_ARTIFACT",
      candidateUrl: null, existingPublicReleaseUnchanged: Boolean(state.currentPublicVersion) },
    artifacts: plan.artifactInventory,
    sourceBinding: { baseCommit: plan.base.commit, baseTree: plan.base.tree, capsuleSha256: plan.validationReport.capsuleSha256 },
    status: "VALID_UNVERIFIED", authoritativePublicTruth: false
  };
  const receipt = {
    candidateReceiptSchemaVersion: 1, candidateId: plan.candidateId, candidateDigest: plan.candidateDigest,
    receiptKind: "LOCAL_SUBMISSION_INVENTORY", status: "UNVERIFIED_CANDIDATE_EVIDENCE",
    capsuleSha256: plan.validationReport.capsuleSha256,
    artifacts: plan.artifactInventory.map((a) => ({
      filename: a.filename, packagePath: a.packagePath, platform: a.platform, sizeBytes: a.sizeBytes,
      sha256: a.computedSha256, mimeType: a.mimeType, publicDownload: "NOT_PUBLISHED"
    })),
    evidence: plan.evidenceInventory, claims: plan.claims,
    semanticClaimAdjudication: "NOT_RUN", publicReceiptId: null, authoritative: false
  };
  return { truth, receipt };
}
function previewFailure(silent, value) { return emit(value, 1, silent); }
async function previewCommand(candidateArg, silent = false) {
  if (!candidateArg) return emit({ status: "INVALID", error: "A candidate directory is required." }, 2, silent);
  let temp;
  try {
    const candidate = await verifyCandidate(path.resolve(process.cwd(), candidateArg));
    const { plan, base, root } = candidate; plan.candidateRoot = root;
    temp = await fsp.mkdtemp(path.join(os.tmpdir(), "pf-product-p3p5-preview-"));
    const baseOut = path.join(temp, "base-site"), candidateOut = path.join(temp, "candidate-build");
    const stagedProducts = path.join(temp, "products");
    await copyCandidateProduct(stagedProducts, plan);
    const baseBuild = await runBuild({ outDir: baseOut, productsDir: path.join(ROOT, "products"), manifestPath: path.join(ROOT, "site-manifest.json"), base });
    if (!baseBuild.ok) throw new Error("Base site build failed.");
    const candidateBuild = await runBuild({
      outDir: candidateOut, productsDir: stagedProducts, manifestPath: path.join(ROOT, "site-manifest.json"),
      stateSourcePath: path.join(root, "candidate-state-source.json"), previewId: plan.c.productId, base
    });
    if (!candidateBuild.ok) throw new Error("Candidate preview build failed.");
    const candidatePreview = path.join(candidateOut, "__preview", plan.c.productId);
    const sources = {
      product: path.join(candidatePreview, "index.html"),
      catalog: path.join(candidateOut, "__preview", "software", "index.html"),
      home: path.join(candidateOut, "__preview", "index.html")
    };
    if (!Object.values(sources).every((f) => fs.existsSync(f))) throw new Error("Existing preview renderer omitted a candidate route.");
    if (fs.existsSync(path.join(baseOut, "__preview"))) throw new Error("Preview namespace collides with the public baseline.");
    const final = path.join(root, "preview-site"), stage = path.join(temp, "assembled-preview");
    await copyTree(baseOut, stage);
    const previewProduct = path.join(stage, "__preview", plan.c.productId);
    await fsp.mkdir(previewProduct, { recursive: true });
    const assetsFrom = path.join(candidateOut, "assets", "products", plan.c.productId);
    const assetsTo = path.join(previewProduct, "assets", "products", plan.c.productId);
    if (fs.existsSync(assetsFrom)) await copyTree(assetsFrom, assetsTo);
    const legacyAssetsFrom = path.join(baseOut, "assets", plan.c.productId);
    const legacyAssetsTo = path.join(previewProduct, "assets", plan.c.productId);
    if (fs.existsSync(legacyAssetsFrom)) await copyTree(legacyAssetsFrom, legacyAssetsTo);
    const proposedAssets = path.join(root, "proposed-source", "assets", plan.c.productId);
    if (fs.existsSync(proposedAssets)) {
      for (const f of await walkFiles(proposedAssets)) {
        const dest = path.join(legacyAssetsTo, ...f.path.split("/"));
        await fsp.mkdir(path.dirname(dest), { recursive: true });
        await fsp.copyFile(f.full, dest);
      }
    }
    const assetFrom = "/assets/products/" + plan.c.productId + "/";
    const assetTo = "/__preview/" + plan.c.productId + "/assets/products/" + plan.c.productId + "/";
    async function copyRoute(from, to, kind) {
      let html = await fsp.readFile(from, "utf8");
      html = html.replaceAll(assetFrom, assetTo);
      html = html.replaceAll("/assets/" + plan.c.productId + "/", "/__preview/" + plan.c.productId + "/assets/" + plan.c.productId + "/");
      html = html.replace(/<meta content=\"https:\/\/theprooffoundry\.com\/[^\"]*\" property=\"og:url\"\/>/gi, "");
      html = addPreviewPanel(html, plan, kind);
      await fsp.mkdir(path.dirname(to), { recursive: true });
      await fsp.writeFile(to, html, "utf8");
    }
    await copyRoute(sources.product, path.join(previewProduct, "index.html"), "product");
    await copyRoute(sources.catalog, path.join(stage, "__preview", "software", "index.html"), "catalog");
    const homepageIncluded = plan.effectiveModule.homepage?.visibility === "visible";
    const routes = ["/__preview/" + plan.c.productId + "/", "/__preview/software/"];
    if (homepageIncluded) {
      await copyRoute(sources.home, path.join(stage, "__preview", "index.html"), "home");
      routes.push("/__preview/");
    }
    const projection = candidateProjections(plan);
    await fsp.writeFile(path.join(previewProduct, "candidate-truth.json"), pretty(projection.truth), "utf8");
    await fsp.writeFile(path.join(previewProduct, "candidate-receipt.json"), pretty(projection.receipt), "utf8");
    const baseTree = await inventoryDir(baseOut);
    for (const f of baseTree.files) {
      const compareFile = path.join(stage, ...f.path.split("/"));
      if (!fs.existsSync(compareFile) || await shaFile(compareFile) !== await shaFile(f.full)) throw new Error("Candidate changed a normal public output path.");
    }
    const payload = await inventoryDir(stage);
    const receipt = {
      previewReceiptSchemaVersion: 1, candidateId: plan.candidateId, candidateDigest: plan.candidateDigest,
      candidateStateSha256: plan.candidateStateSha256, basePublicPayloadSha256: baseTree.sha256,
      sitePayloadSha256: payload.sha256, routesGenerated: routes, homepageIncluded,
      previewOnly: true, livePublication: "NOT_RUN"
    };
    const receiptPath = path.join(root, "preview-receipt.json");
    if (fs.existsSync(final)) {
      const current = await inventoryDir(final), old = await parseJsonFile(receiptPath);
      if (old.candidateDigest !== plan.candidateDigest || old.candidateId !== plan.candidateId || old.sitePayloadSha256 !== current.sha256 ||
          !await compareTreesWithBuildNormalization(final, stage)) throw new Error("Existing preview differs from a fresh candidate render; refusing to overwrite it.");
      const scratch = path.resolve(stage), tempPath = path.resolve(temp) + path.sep;
      if (scratch.startsWith(tempPath) && path.basename(scratch) === "assembled-preview") await fsp.rm(scratch, { recursive: true, force: true });
    } else {
      await fsp.rename(stage, final);
      await fsp.writeFile(receiptPath, pretty(receipt), "utf8");
    }
    const finalReceipt = await parseJsonFile(receiptPath);
    return emit({
      command: "preview", status: "PASS", candidateId: plan.candidateId, previewRoot: final,
      routesGenerated: routes, productRoute: "/__preview/" + plan.c.productId + "/",
      catalogRoute: "/__preview/software/", homepageIncluded,
      candidateStateSha256: plan.candidateStateSha256, sitePayloadSha256: finalReceipt.sitePayloadSha256,
      warnings: [
        "Local/static preview only; no Pages preview or production deployment occurred.",
        "Submitted claims remain assertions; semantic evidence adjudication is unresolved.",
        plan.artifactInventory.length ? "Candidate artifact bytes are not publicly published; no candidate download URL is emitted." : "No new artifact bytes were submitted."
      ]
    }, 0, silent);
  } catch {
    return previewFailure(silent, { command: "preview", status: "FAIL", error: "Candidate preview could not be produced safely; source binding, route namespace, or build validation failed." });
  } finally {
    if (temp) {
      const resolved = path.resolve(temp), basePath = path.resolve(os.tmpdir()) + path.sep;
      if (resolved.startsWith(basePath) && path.basename(resolved).startsWith("pf-product-p3p5-preview-")) await fsp.rm(resolved, { recursive: true, force: true });
    }
  }
}
function extractCounts(text) {
  const matches = [...String(text).matchAll(/(\d+)\s+passed,\s*(\d+)\s+failed/gi)];
  if (matches.length) return { passed: Number(matches.at(-1)[1]), failed: Number(matches.at(-1)[2]) };
  return { passed: (String(text).match(/\bPASS:/g) || []).length, failed: (String(text).match(/\bFAIL:/g) || []).length };
}
async function runRegressionSuite(spec) {
  const abs = path.join(ROOT, spec.file);
  if (!fs.existsSync(abs)) return { id: spec.id, script: spec.file, status: "FAIL", passed: 0, failed: 1 };
  const command = spec.kind === "node" ? process.execPath : "pwsh";
  const args = spec.kind === "node" ? [abs] : ["-NoProfile", "-File", abs];
  const r = spawnSync(command, args, { cwd: ROOT, encoding: "utf8", timeout: 900000, maxBuffer: 64 * 1024 * 1024, windowsHide: true });
  const counts = extractCounts((r.stdout || "") + "\n" + (r.stderr || ""));
  return { id: spec.id, script: spec.file, status: !r.error && r.status === 0 && counts.failed === 0 ? "PASS" : "FAIL",
    passed: counts.passed, failed: counts.failed };
}
async function buildCandidateSite(candidate) {
  const { root, plan, base } = candidate, temp = await fsp.mkdtemp(path.join(os.tmpdir(), "pf-product-p3p5-qualify-build-"));
  try {
    const products = path.join(temp, "products"), out = path.join(temp, "public");
    await copyTree(path.join(ROOT, "products"), products);
    for (const [rel, bytes] of plan.proposedFiles) {
      if (!rel.startsWith("products/")) continue;
      const dest = path.join(products, ...rel.slice("products/".length).split("/"));
      await fsp.mkdir(path.dirname(dest), { recursive: true });
      await fsp.writeFile(dest, bytes);
    }
    const candidateManifest = path.join(root, "proposed-source", "site-manifest.json");
    const manifestPath = fs.existsSync(candidateManifest) ? candidateManifest : path.join(ROOT, "site-manifest.json");
    const result = await runBuild({ outDir: out, productsDir: products, manifestPath, base });
    if (!result.ok) return { ok: false, sha256: null };
    for (const [rel, bytes] of plan.proposedFiles) {
      if (!rel.startsWith("assets/")) continue;
      const dest = path.join(out, ...rel.split("/"));
      await fsp.mkdir(path.dirname(dest), { recursive: true });
      await fsp.writeFile(dest, bytes);
    }
    return { ok: true, sha256: await normalizedInventoryDir(out) };
  } finally {
    const resolved = path.resolve(temp), basePath = path.resolve(os.tmpdir()) + path.sep;
    if (resolved.startsWith(basePath) && path.basename(resolved).startsWith("pf-product-p3p5-qualify-build-")) await fsp.rm(resolved, { recursive: true, force: true });
  }
}
async function refreshCanonicalPublic() {
  const r = spawnSync("pwsh", ["-NoProfile", "-File", BUILD], {
    cwd: ROOT, encoding: "utf8", timeout: 180000, maxBuffer: 16 * 1024 * 1024, windowsHide: true
  });
  return !r.error && r.status === 0;
}
function sourceScopeResult(candidate) {
  const status = git(["status", "--porcelain", "--untracked-files=all"]);
  for (const line of status.split(/\r?\n/).filter(Boolean)) {
    const rel = gitStatusPath(line).replaceAll("\\", "/");
    if (!PUBLISHER_SOURCE_PATHS.has(rel)) return { status: "FAIL", findings: ["Untracked or modified source exists outside the declared publisher implementation."] };
  }
  for (const change of candidate.plan.changes) {
    if (!(change.path === "site-manifest.json" || change.path.startsWith("products/" + candidate.plan.c.productId + "/") ||
        change.path.startsWith("assets/" + candidate.plan.c.productId + "/"))) {
      return { status: "FAIL", findings: ["Candidate path is outside product/canonical-state scope."] };
    }
    if (change.operation === "DELETE") return { status: "FAIL", findings: ["DELETE operations are not supported in P3-P5."] };
  }
  if (candidate.plan.c.submissionType === "PRESENTATION_UPDATE" && candidate.plan.changes.some((x) => x.path === "site-manifest.json")) {
    return { status: "FAIL", findings: ["PRESENTATION_UPDATE may not alter site-manifest.json."] };
  }
  return { status: "PASS", findings: [] };
}
async function publicStateResult(candidate) {
  const { root, plan } = candidate;
  const baseManifest = await parseJsonFile(path.join(ROOT, "site-manifest.json"));
  const candidatePath = path.join(root, "proposed-source", "site-manifest.json");
  const manifest = fs.existsSync(candidatePath) ? await parseJsonFile(candidatePath) : baseManifest;
  const baseProduct = (baseManifest.products || []).find((p) => p.id === plan.c.productId) || null;
  const candidateProduct = (manifest.products || []).find((p) => p.id === plan.c.productId) || null;
  if (plan.c.submissionType === "NEW_PRODUCT") {
    if (!candidateProduct || candidateProduct.visible !== false || candidateProduct.release?.releaseStatus !== "UNRELEASED" ||
        candidateProduct.verification?.status === "VERIFIED" || candidateProduct.downloadUrl ||
        (candidateProduct.artifacts || []).some((a) => a.downloadUrl || a.sha256Url)) {
      return { status: "FAIL", findings: ["New candidate must remain hidden, UNRELEASED, unverified, and without public artifact URLs."] };
    }
  } else {
    if (!baseProduct || !candidateProduct || canonical(releaseSeal(baseProduct)) !== canonical(releaseSeal(candidateProduct))) {
      return { status: "FAIL", findings: ["Canonical release fields, artifacts, URLs, verification, receipt, or source commit changed."] };
    }
    if (plan.c.submissionType === "PRESENTATION_UPDATE" && canonical(baseProduct) !== canonical(candidateProduct)) {
      return { status: "FAIL", findings: ["PRESENTATION_UPDATE changed a canonical product-state record."] };
    }
    if (plan.c.submissionType === "NEW_VERSION" && candidateProduct.release?.candidateVersion !== plan.c.releaseVersion) {
      return { status: "FAIL", findings: ["NEW_VERSION candidateVersion differs from the submitted version."] };
    }
  }
  return { status: "PASS", findings: [] };
}
async function previewDimensionChecks(candidate, previewReport) {
  const out = {
    PRESENTATION_VALID: { status: "FAIL", findings: [] },
    ROUTE_VALID: { status: "FAIL", findings: [] },
    DISCOVERY_VALID: { status: "FAIL", findings: [] },
    TRUTH_PROJECTION_VALID: { status: "FAIL", findings: [] },
    RECEIPT_PROJECTION_VALID: { status: "FAIL", findings: [] }
  };
  if (previewReport.status !== "PASS") {
    for (const result of Object.values(out)) result.findings.push("Local preview build did not pass.");
    return out;
  }
  const { root, plan } = candidate, previewRoot = path.join(root, "preview-site"), id = plan.c.productId;
  const productPagePath = path.join(previewRoot, "__preview", id, "index.html");
  const productPage = await fsp.readFile(productPagePath, "utf8");
  const phrases = ["PREVIEW", "UNVERIFIED", "NOT PUBLIC"];
  const presentationOk = phrases.every((phrase) => productPage.includes(phrase)) &&
    (!plan.artifactInventory.length || productPage.includes("PUBLIC_DOWNLOAD = NOT_PUBLISHED")) &&
    !productPage.includes("downloads.theprooffoundry.com/" + id + "/v" + plan.c.releaseVersion + "/");
  out.PRESENTATION_VALID = { status: presentationOk ? "PASS" : "FAIL", findings: presentationOk ? [] : ["Preview presentation lacks required status or unpublished-download boundary."] };

  const normalRoute = path.join(previewRoot, id, "index.html");
  const catalogPath = path.join(previewRoot, "__preview", "software", "index.html");
  const catalogPage = fs.existsSync(catalogPath) ? await fsp.readFile(catalogPath, "utf8") : "";
  const homepagePath = path.join(previewRoot, "__preview", "index.html");
  const homepagePage = fs.existsSync(homepagePath) ? await fsp.readFile(homepagePath, "utf8") : "";
  const routeList = (await parseJsonFile(path.join(root, "preview-receipt.json"))).routesGenerated;
  const routesPresent = fs.existsSync(productPagePath) && fs.existsSync(catalogPath) &&
    (!routeList.includes("/__preview/") || fs.existsSync(homepagePath));
  const previewRouteOk = routesPresent && /noindex,\s*nofollow/i.test(productPage) &&
    /noindex,\s*nofollow/i.test(catalogPage) &&
    (!routeList.includes("/__preview/") || /noindex,\s*nofollow/i.test(homepagePage)) &&
    !((plan.c.submissionType === "NEW_PRODUCT") && fs.existsSync(normalRoute));
  out.ROUTE_VALID = { status: previewRouteOk ? "PASS" : "FAIL", findings: previewRouteOk ? [] : ["Candidate route is missing, public, or not marked noindex/nofollow."] };

  const sitemap = await fsp.readFile(path.join(previewRoot, "sitemap.xml"), "utf8");
  const discoveryOk = !sitemap.includes("/__preview/");
  out.DISCOVERY_VALID = { status: discoveryOk ? "PASS" : "FAIL", findings: discoveryOk ? [] : ["Preview routes entered the normal public sitemap."] };

  const normalTruth = await parseJsonFile(path.join(previewRoot, "truth", "index.json"));
  const truthPath = path.join(previewRoot, "__preview", id, "candidate-truth.json");
  const truth = await parseJsonFile(truthPath);
  const candidateExcluded = plan.c.submissionType !== "NEW_PRODUCT" || !(normalTruth.products || []).some((p) => p.id === id);
  const truthOk = candidateExcluded && truth.authoritativePublicTruth === false && truth.download?.candidateUrl === null && truth.status === "VALID_UNVERIFIED";
  out.TRUTH_PROJECTION_VALID = { status: truthOk ? "PASS" : "FAIL", findings: truthOk ? [] : ["Candidate state leaked into public Truth or claims public authority."] };

  const receiptPath = path.join(previewRoot, "__preview", id, "candidate-receipt.json");
  const receipt = await parseJsonFile(receiptPath);
  const receiptOk = receipt.authoritative === false && receipt.semanticClaimAdjudication === "NOT_RUN" &&
    receipt.artifacts.every((a) => a.publicDownload === "NOT_PUBLISHED");
  out.RECEIPT_PROJECTION_VALID = { status: receiptOk ? "PASS" : "FAIL", findings: receiptOk ? [] : ["Candidate receipt projection claims authority or live downloads."] };
  return out;
}
function claimEvidenceAssessment(plan) {
  return plan.claims.map((c) => ({
    claim: c.summary, claimId: c.id, evidenceSupplied: c.evidence,
    evidenceType: c.evidence.map((e) => e.kind || "missing"),
    verificationDimension: c.verificationDimension, verdict: c.verdict, authoritative: false
  }));
}
function jsonReport(value, exitCode) { console.log(JSON.stringify(value, null, 2)); return exitCode; }
function publisherIdentity(requireFrozen = false) {
  const commit = git(["rev-parse", "HEAD"]), tree = git(["show", "-s", "--format=%T", "HEAD"]);
  if (git(["merge-base", "HEAD", BASE_COMMIT]) !== BASE_COMMIT) throw new Error("Publisher source is not based on the frozen site commit.");
  if (requireFrozen) {
    if (!publisherWorkingTreeIsClean()) throw new Error("Owner-review freeze requires a clean committed publisher tree.");
    for (const rel of PUBLISHER_SOURCE_PATHS) {
      const r = spawnSync("git", ["cat-file", "-e", "HEAD:" + rel], { cwd: ROOT, encoding: "utf8", timeout: 15000, windowsHide: true });
      if (r.error || r.status !== 0) throw new Error("Publisher source inventory is not fully committed.");
    }
  }
  return { publisherCommit: commit, publisherTree: tree, baseSiteCommit: BASE_COMMIT, baseSiteTree: BASE_TREE };
}
export function computeCandidatePayloadSha256(plan) {
  const payload = {
    candidateId: plan.candidateId, candidateDigest: plan.candidateDigest,
    capsuleSha256: plan.validationReport.capsuleSha256, candidateStateSha256: plan.candidateStateSha256,
    candidateStateSourceSha256: plan.stateSourceSha256,
    proposedPaths: plan.changes.map((x) => ({ path: x.path, operation: x.operation, preImageSha256: x.preImageSha256, postImageSha256: x.postImageSha256 })),
    artifactInventory: plan.artifactInventory.map((x) => ({ packagePath: x.packagePath, sizeBytes: x.sizeBytes, sha256: x.computedSha256 })),
    evidenceInventory: plan.evidenceInventory.map((x) => ({ packagePath: x.packagePath, sizeBytes: x.sizeBytes, sha256: x.sha256 }))
  };
  return shaBytes(Buffer.from(canonical(payload), "utf8"));
}
export function deterministicApprovalDigest(approval) {
  const { createdAt, approvalPackageDigest, ...stable } = approval;
  return shaBytes(Buffer.from(canonical(stable), "utf8"));
}
export function approvalBindingMatches(expected, record) {
  const fields = ["candidateId", "candidateDigest", "capsuleSha256", "publisherCommit", "baseSiteCommit", "productId"];
  if (!expected || !record || fields.some((field) => expected[field] !== record[field])) return false;
  return canonical(expected.artifactSha256 || []) === canonical(record.artifactSha256 || []);
}
function delta(changed, details = {}) { return { changed: changed ? "YES" : "NO", ...details }; }
function approvalDeltas(plan) {
  const beforeModule = plan.candidateRecord && fs.existsSync(path.join(ROOT, "products", plan.c.productId, "module.json"))
    ? JSON.parse(fs.readFileSync(path.join(ROOT, "products", plan.c.productId, "module.json"), "utf8")) : null;
  const afterModule = plan.effectiveModule;
  const presentationChanged = plan.changes.some((x) => x.path !== "site-manifest.json");
  const manifestChanged = plan.changes.some((x) => x.path === "site-manifest.json");
  const releaseProjection = (record) => record ? {
    lifecycle: record.lifecycle ?? null, visible: record.visible ?? null,
    release: record.release ?? null, verification: record.verification ?? null
  } : null;
  const candidateManifestPath = path.join(ROOT, "site-manifest.json");
  const actualBaseManifest = JSON.parse(fs.readFileSync(candidateManifestPath, "utf8"));
  const oldRecord = actualBaseManifest.products?.find((x) => x.id === plan.c.productId) || null;
  const afterRecord = plan.candidateRecord;
  const commerceChanged = canonical(beforeModule?.commerce ?? null) !== canonical(afterModule?.commerce ?? null);
  const routeChanged = (beforeModule?.route ?? null) !== (afterModule?.route ?? null);
  const homepageChanged = Boolean(beforeModule) && canonical(beforeModule.homepage ?? null) !== canonical(afterModule.homepage ?? null);
  const releaseTruthChanged = canonical(releaseProjection(oldRecord)) !== canonical(releaseProjection(afterRecord));
  return {
    canonicalStateDelta: delta(plan.changes.length > 0, { changedPaths: plan.changes.map((x) => x.path) }),
    productPresentationChange: delta(presentationChanged, { paths: plan.changes.filter((x) => x.path !== "site-manifest.json").map((x) => x.path) }),
    releaseTruthDelta: delta(releaseTruthChanged || manifestChanged, { manifestChanged }),
    publicReleaseTruthChange: delta(releaseTruthChanged || manifestChanged, { manifestChanged }),
    artifactChange: delta(plan.artifactInventory.length > 0, { count: plan.artifactInventory.length }),
    commerceDelta: delta(commerceChanged, { before: beforeModule?.commerce ?? null, after: afterModule?.commerce ?? null }),
    routeDelta: delta(routeChanged, { before: beforeModule?.route ?? null, after: afterModule?.route ?? null }),
    homepageChange: delta(homepageChanged, { appliesToPublicHomepage: homepageChanged && beforeModule?.visibility === "visible" }),
    truthFileChange: delta(manifestChanged, { source: manifestChanged ? "site-manifest.json" : null })
  };
}
function humanApprovalSummary(approval) {
  const rows = [
    "PROOF FOUNDRY PRODUCT CANDIDATE — FROZEN FOR OWNER REVIEW",
    "",
    "STATE = FROZEN_FOR_OWNER_REVIEW",
    "CANDIDATE_ID = " + approval.candidateId,
    "CANDIDATE_DIGEST = " + approval.candidateDigest,
    "APPROVAL_PACKAGE_DIGEST = " + approval.approvalPackageDigest,
    "PUBLISHER_COMMIT = " + approval.publisherCommit,
    "PUBLISHER_TREE = " + approval.publisherTree,
    "BASE_SITE_COMMIT = " + approval.baseSiteCommit,
    "BASE_SITE_TREE = " + approval.baseSiteTree,
    "PRODUCT_ID = " + approval.productId,
    "SUBMISSION_TYPE = " + approval.submissionType,
    "PRODUCT_PRESENTATION_CHANGE = " + approval.productPresentationChange.changed,
    "PUBLIC_RELEASE_TRUTH_CHANGE = " + approval.publicReleaseTruthChange.changed,
    "ARTIFACT_CHANGE = " + approval.artifactChange.changed,
    "COMMERCE_CHANGE = " + approval.commerceDelta.changed,
    "ROUTE_CHANGE = " + approval.routeDelta.changed,
    "HOMEPAGE_CHANGE = " + approval.homepageChange.changed,
    "TRUTH_FILE_CHANGE = " + approval.truthFileChange.changed,
    "LIVE_PUBLICATION_VALID = NOT_RUN",
    "OWNER_APPROVAL = REQUIRED_EXTERNALLY",
    "PUBLICATION_MUTATION = NOT_IMPLEMENTED"
  ];
  return rows.join("\n") + "\n";
}
async function buildApprovalPackageFiles(candidate, publisher, createdAt) {
  const { root, plan, base } = candidate;
  const qualificationPath = path.join(root, "qualification-record.json");
  const previewPath = path.join(root, "preview-receipt.json");
  if (!fs.existsSync(qualificationPath) || !fs.existsSync(previewPath)) throw new Error("A qualified preview and qualification record are required before freeze.");
  const qualification = await parseJsonFile(qualificationPath), preview = await parseJsonFile(previewPath);
  if (qualification.publicationState !== "QUALIFIED_UNPUBLISHED" || qualification.livePublication !== "NOT_RUN" ||
      qualification.candidateId !== plan.candidateId || qualification.candidateDigest !== plan.candidateDigest ||
      qualification.capsuleSha256 !== plan.validationReport.capsuleSha256 ||
      qualification.baseCommit !== base.commit || qualification.baseTree !== base.tree ||
      qualification.publisherCommit !== publisher.publisherCommit || qualification.publisherTree !== publisher.publisherTree ||
      !Object.values(qualification.qualificationDimensions || {}).every((x) => x === "PASS" || x === "NOT_RUN") ||
      Object.entries(qualification.qualificationDimensions || {}).some(([key, value]) => key !== "LIVE_PUBLICATION_VALID" && value !== "PASS") ||
      !(qualification.testResults || []).length || qualification.testResults.some((x) => x.status !== "PASS") ||
      preview.candidateDigest !== plan.candidateDigest || preview.candidateStateSha256 !== plan.candidateStateSha256) {
    throw new Error("Qualification or preview does not bind to this committed candidate and publisher source.");
  }
  const artifactSha256 = plan.artifactInventory.map((x) => x.computedSha256);
  const deltas = approvalDeltas(plan);
  const payloadSha = computeCandidatePayloadSha256(plan);
  const sourceBinding = {
    sourceBindingSchemaVersion: 1, publisherCommit: publisher.publisherCommit, publisherTree: publisher.publisherTree,
    baseSiteCommit: base.commit, baseSiteTree: base.tree, baseManifestSha256: base.manifestSha256,
    capsuleSha256: plan.validationReport.capsuleSha256, candidateDigest: plan.candidateDigest,
    candidateStateSha256: plan.candidateStateSha256, candidatePayloadSha256: payloadSha
  };
  const candidatePreview = {
    previewSchemaVersion: 1, candidateId: plan.candidateId, candidateDigest: plan.candidateDigest,
    previewIdentity: { sitePayloadSha256: preview.sitePayloadSha256, candidateStateSha256: preview.candidateStateSha256 },
    previewRoutes: preview.routesGenerated, homepageIncluded: preview.homepageIncluded === true,
    livePublication: "NOT_RUN"
  };
  const candidateQualification = {
    qualificationSchemaVersion: qualification.qualificationSchemaVersion,
    candidateId: qualification.candidateId, candidateDigest: qualification.candidateDigest,
    publisherCommit: qualification.publisherCommit, publisherTree: qualification.publisherTree,
    baseSiteCommit: qualification.baseCommit, baseSiteTree: qualification.baseTree,
    qualificationDimensions: qualification.qualificationDimensions, qualificationResults: qualification.testResults,
    canonicalPublicRefresh: qualification.canonicalPublicRefresh,
    livePublication: qualification.livePublication, knownLimits: qualification.knownLimits,
    publicationBlockers: qualification.publicationBlockers
  };
  const candidateArtifacts = {
    artifactInventorySchemaVersion: 1, candidateId: plan.candidateId, productId: plan.c.productId,
    artifactInventory: plan.artifactInventory, artifactSha256,
    evidenceInventory: plan.evidenceInventory
  };
  const approval = {
    approvalSchemaVersion: 1, approvalState: "FROZEN_FOR_OWNER_REVIEW",
    candidateId: plan.candidateId, candidateDigest: plan.candidateDigest,
    publisherCommit: publisher.publisherCommit, publisherTree: publisher.publisherTree,
    baseSiteCommit: base.commit, baseSiteTree: base.tree,
    capsuleSha256: plan.validationReport.capsuleSha256, candidateStateSha256: plan.candidateStateSha256,
    candidatePayloadSha256: payloadSha, productId: plan.c.productId, submissionType: plan.c.submissionType,
    proposedPaths: plan.changes, artifactInventory: plan.artifactInventory, artifactSha256,
    qualificationDimensions: qualification.qualificationDimensions, qualificationResults: qualification.testResults,
    previewIdentity: candidatePreview.previewIdentity, previewRoutes: candidatePreview.previewRoutes,
    ...deltas,
    knownLimits: qualification.knownLimits,
    publicationBlockers: [...qualification.publicationBlockers, "Owner approval is external and has not been granted.", "P7-P9 publication mutation is not implemented."],
    livePublication: "NOT_RUN", createdAt,
    futureOwnerApprovalRecord: {
      designOnly: true, decisionRequired: "OWNER_APPROVES_EXACT_CANDIDATE",
      bindingFields: ["candidateId", "candidateDigest", "capsuleSha256", "publisherCommit", "baseSiteCommit", "artifactSha256"],
      detachedBooleanApprovalAllowed: false, publicationMutationImplemented: false
    }
  };
  approval.approvalPackageDigest = deterministicApprovalDigest(approval);
  const files = {
    "candidate-approval.json": pretty(approval),
    "candidate-changed-paths.json": pretty(plan.changes),
    "candidate-artifacts.json": pretty(candidateArtifacts),
    "candidate-qualification.json": pretty(candidateQualification),
    "candidate-preview.json": pretty(candidatePreview),
    "candidate-source-binding.json": pretty(sourceBinding),
    "candidate-approval-summary.txt": humanApprovalSummary(approval)
  };
  return { approval, files };
}
async function freezeCommand(candidateArg) {
  if (!candidateArg) return jsonReport({ status: "INVALID", approvalState: "INVALID", error: "A candidate directory is required." }, 2);
  let stage = null;
  try {
    const candidate = await verifyCandidate(path.resolve(process.cwd(), candidateArg), { checkPreview: true });
    const publisher = publisherIdentity(true), target = path.join(candidate.root, "owner-review-package");
    const priorApproval = fs.existsSync(path.join(target, "candidate-approval.json"))
      ? await parseJsonFile(path.join(target, "candidate-approval.json")) : null;
    if (fs.existsSync(target) && !priorApproval) throw new Error("Existing owner-review package is incomplete.");
    const createdAt = priorApproval?.createdAt || new Date().toISOString();
    const built = await buildApprovalPackageFiles(candidate, publisher, createdAt);
    if (priorApproval) {
      if (priorApproval.approvalPackageDigest !== built.approval.approvalPackageDigest) throw new Error("Existing owner-review package belongs to a different candidate/source identity.");
      const current = await inventoryDir(target), expected = Object.entries(built.files).sort((a, b) => a[0].localeCompare(b[0], "en"));
      if (current.files.length !== expected.length) throw new Error("Existing owner-review package inventory differs.");
      for (const [name, contents] of expected) {
        const actual = current.files.find((x) => x.path === name);
        if (!actual || !(await fsp.readFile(actual.full)).equals(Buffer.from(contents, "utf8"))) throw new Error("Existing owner-review package differs from the frozen candidate.");
      }
      return jsonReport({ command: "freeze", status: "PASS", approvalState: "FROZEN_FOR_OWNER_REVIEW",
        candidateId: built.approval.candidateId, candidateDigest: built.approval.candidateDigest,
        approvalPackageDigest: built.approval.approvalPackageDigest, approvalPackagePath: target, reused: true,
        livePublication: "NOT_RUN", exactNextAction: "STOP for external owner review; publication authority remains zero." }, 0);
    }
    stage = path.join(candidate.root, ".owner-review-package-stage-" + crypto.randomUUID());
    await fsp.mkdir(stage, { recursive: false });
    for (const [name, contents] of Object.entries(built.files)) await fsp.writeFile(path.join(stage, name), contents, "utf8");
    await fsp.rename(stage, target); stage = null;
    return jsonReport({ command: "freeze", status: "PASS", approvalState: "FROZEN_FOR_OWNER_REVIEW",
      candidateId: built.approval.candidateId, candidateDigest: built.approval.candidateDigest,
      approvalPackageDigest: built.approval.approvalPackageDigest, approvalPackagePath: target, reused: false,
      livePublication: "NOT_RUN", exactNextAction: "STOP for external owner review; publication authority remains zero." }, 0);
  } catch {
    return jsonReport({ command: "freeze", status: "HOLD", approvalState: "INVALID",
      error: "Candidate qualification, source binding, approval package integrity, or committed publisher identity failed." }, 1);
  } finally {
    if (stage && fs.existsSync(stage) && path.basename(stage).startsWith(".owner-review-package-stage-")) {
      await fsp.rm(stage, { recursive: true, force: true });
    }
  }
}
async function qualifyCommand(candidateArg) {
  if (!candidateArg) return jsonReport({ status: "INVALID", error: "A candidate directory is required." }, 2);
  const dimensions = {
    CAPSULE_VALID: "FAIL", MATERIALIZATION_VALID: "FAIL", MODULE_VALID: "FAIL",
    PUBLIC_STATE_VALID: "FAIL", ARTIFACT_DECLARATION_VALID: "FAIL", ARTIFACT_HASH_VALID: "FAIL",
    PRESENTATION_VALID: "FAIL", ROUTE_VALID: "FAIL", DISCOVERY_VALID: "FAIL",
    TRUTH_PROJECTION_VALID: "FAIL", RECEIPT_PROJECTION_VALID: "FAIL", BUILD_VALID: "FAIL",
    SOURCE_SCOPE_VALID: "FAIL", CANONICAL_OUTPUT_VALID: "NOT_RUN", REGRESSION_VALID: "NOT_RUN", LIVE_PUBLICATION_VALID: "NOT_RUN"
  };
  try {
    const candidate = await verifyCandidate(path.resolve(process.cwd(), candidateArg), { checkPreview: true });
    const { plan, root } = candidate;
    dimensions.CAPSULE_VALID = plan.validationReport.status === "VALID_UNVERIFIED" ? "PASS" : "FAIL";
    dimensions.MATERIALIZATION_VALID = "PASS";
    dimensions.MODULE_VALID = plan.validationReport.moduleValidation?.schema === "PASS" ? "PASS" : "FAIL";
    const publicState = await publicStateResult(candidate);
    dimensions.PUBLIC_STATE_VALID = publicState.status;
    const refs = plan.c.artifactRefs || [];
    dimensions.ARTIFACT_DECLARATION_VALID = refs.length === plan.artifactInventory.length &&
      refs.every((x, i) => x.sha256.toLowerCase() === plan.artifactInventory[i].computedSha256 &&
        plan.release.artifacts?.[i]?.path === x.path &&
        plan.release.artifacts?.[i]?.sha256?.toLowerCase() === x.sha256.toLowerCase()) ? "PASS" : "FAIL";
    dimensions.ARTIFACT_HASH_VALID = plan.artifactInventory.every((a) => a.computedSha256 === a.declaredSha256 && a.sizeBytes > 0) &&
      plan.evidenceInventory.every((e) => e.sha256 && e.sizeBytes > 0) ? "PASS" : "FAIL";
    const previewResult = await previewCommand(root, true);
    const checks = await previewDimensionChecks(candidate, previewResult.report);
    for (const [name, check] of Object.entries(checks)) dimensions[name] = check.status;
    const build = await buildCandidateSite(candidate);
    dimensions.BUILD_VALID = build.ok ? "PASS" : "FAIL";
    const scope = sourceScopeResult(candidate);
    dimensions.SOURCE_SCOPE_VALID = scope.status;
    if (Object.values(dimensions).some((v) => v === "FAIL")) {
      return jsonReport({ command: "qualify", status: "INVALID", candidateId: plan.candidateId, publicationState: "INVALID",
        dimensions, findings: [...publicState.findings, ...Object.values(checks).flatMap((x) => x.findings), ...scope.findings], livePublication: "NOT_RUN" }, 1);
    }
    dimensions.CANONICAL_OUTPUT_VALID = await refreshCanonicalPublic() ? "PASS" : "FAIL";
    if (dimensions.CANONICAL_OUTPUT_VALID !== "PASS") {
      return jsonReport({ command: "qualify", status: "HOLD", candidateId: plan.candidateId,
        publicationState: "VALID_UNVERIFIED", dimensions, regressionSuites: [],
        livePublication: "NOT_RUN", blocker: "Canonical generated public output could not be refreshed from this committed source tree." }, 1);
    }
    const suites = [];
    for (const spec of TESTS) suites.push(await runRegressionSuite(spec));
    const diffCheck = spawnSync("git", ["diff", "--check"], { cwd: ROOT, encoding: "utf8", timeout: 30000, windowsHide: true });
    const stagedDiffCheck = spawnSync("git", ["diff", "--cached", "--check"], { cwd: ROOT, encoding: "utf8", timeout: 30000, windowsHide: true });
    const sourceClean = !diffCheck.error && diffCheck.status === 0 && !stagedDiffCheck.error && stagedDiffCheck.status === 0 &&
      sourceScopeResult(candidate).status === "PASS";
    dimensions.SOURCE_SCOPE_VALID = dimensions.SOURCE_SCOPE_VALID === "PASS" && sourceClean ? "PASS" : "FAIL";
    dimensions.REGRESSION_VALID = suites.every((s) => s.status === "PASS") ? "PASS" : "FAIL";
    const failedSuites = suites.filter((s) => s.status !== "PASS");
    if (failedSuites.length || dimensions.SOURCE_SCOPE_VALID !== "PASS") {
      return jsonReport({ command: "qualify", status: "HOLD", candidateId: plan.candidateId,
        publicationState: "VALID_UNVERIFIED", dimensions, regressionSuites: suites,
        gitDiffCheck: diffCheck.status === 0 ? "PASS" : "FAIL", failedSuites: failedSuites.map((s) => s.id),
        livePublication: "NOT_RUN" }, 1);
    }
    const previewReceipt = await parseJsonFile(path.join(root, "preview-receipt.json"));
    const record = {
      qualificationSchemaVersion: 1, candidateId: plan.candidateId, candidateDigest: plan.candidateDigest,
      capsuleSha256: plan.validationReport.capsuleSha256, baseCommit: candidate.base.commit, baseTree: candidate.base.tree,
      publisherCommit: candidate.base.publisherCommit, publisherTree: candidate.base.publisherTree,
      canonicalPublicRefresh: "PASS",
      proposedContentDigest: plan.candidateDigest, artifactSha256: plan.artifactInventory.map((a) => a.computedSha256),
      changedPaths: plan.changes, qualificationDimensions: dimensions, testResults: suites, gitDiffCheck: "PASS",
      previewIdentity: { routes: previewReceipt.routesGenerated, stateSha256: plan.candidateStateSha256 },
      previewPayloadSha256: previewReceipt.sitePayloadSha256, candidateBuildPayloadSha256: build.sha256,
      claimEvidenceAssessment: claimEvidenceAssessment(plan),
      knownLimits: [
        "Submitted product claims remain assertions; semantic adjudication was not performed.",
        "Repository visibility and source provenance were not independently verified.",
        "R2 artifact publication and public-byte verification were not run.",
        "Production Pages deployment and live publication checks were not run."
      ],
      publicationBlockers: ["P6 owner approval is required.", "Candidate artifact URLs are not public.", "Live publication is NOT_RUN."],
      publicationState: "QUALIFIED_UNPUBLISHED", livePublication: "NOT_RUN"
    };
    const recordPath = path.join(root, "qualification-record.json");
    if (fs.existsSync(recordPath)) {
      if (canonical(await parseJsonFile(recordPath)) !== canonical(record)) throw new Error("Immutable qualification record differs.");
    } else await fsp.writeFile(recordPath, pretty(record), "utf8");
    return jsonReport({ command: "qualify", status: "PASS", candidateId: plan.candidateId,
      publicationState: "QUALIFIED_UNPUBLISHED", dimensions, regressionSuites: suites,
      qualificationRecord: recordPath, candidateDigest: plan.candidateDigest,
      previewPayloadSha256: previewReceipt.sitePayloadSha256,
      livePublication: "NOT_RUN", exactNextAction: "STOP at READY_FOR_P6_OWNER_APPROVAL_BOUNDARY." }, 0);
  } catch {
    return jsonReport({ command: "qualify", status: "INVALID", publicationState: "INVALID",
      dimensions, error: "Candidate integrity, frozen source binding, preview isolation, or qualification checks failed." }, 1);
  }
}
export async function runProductPublisherCommand(operation, positional, extraArgs = []) {
  try {
    if (operation === "materialize") return await materializeCommand(positional, extraArgs);
    if (operation === "preview") return (await previewCommand(positional)).exitCode;
    if (operation === "qualify") return await qualifyCommand(positional);
    if (operation === "freeze") return await freezeCommand(positional);
    return jsonReport({ status: "INVALID", error: "Unknown publishing command." }, 2);
  } catch {
    return jsonReport({ status: "INVALID", publicationState: "INVALID", error: "Publishing command failed a safety or source-binding check." }, 1);
  }
}
