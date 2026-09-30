import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {
  MemoryR2FixtureTransport, buildR2Plan, buildR2PutCommand, makeArtifactDryRun,
  makeOwnerApprovalForFixture, publishArtifactPlan, runP7P9Command, sha256, verifyArtifactReceipt, verifyOwnerApproval
} from "./pf-product-p7-p9.mjs";

const TEMP = await fs.mkdtemp(path.join(os.tmpdir(), "pf-product-p7-tests-"));
let passed = 0;
function check(value, description) { assert.ok(value, description); passed++; }
function signed(approval, privateKey, actions, overrides = {}) {
  return makeOwnerApprovalForFixture({ ...approval, ...overrides }, privateKey, actions, "2026-09-29T00:00:00.000Z");
}

try {
  const candidateRoot = path.join(TEMP, "candidate");
  const artifactPath = path.join(candidateRoot, "candidate-artifacts", "release", "artifacts", "fixture-1.2.3.zip");
  const checksumPath = path.join(candidateRoot, "submitted-capsule", "release", "SHA256SUMS.txt");
  const releasePath = path.join(candidateRoot, "submitted-capsule", "release", "release.json");
  await fs.mkdir(path.dirname(artifactPath), { recursive: true });
  await fs.mkdir(path.dirname(checksumPath), { recursive: true });
  const artifactBytes = Buffer.from("synthetic p7 release bytes\n");
  const artifactHash = sha256(artifactBytes);
  const pair = crypto.generateKeyPairSync("ed25519");
  const publicPem = pair.publicKey.export({ type: "spki", format: "pem" });
  await fs.writeFile(artifactPath, artifactBytes);
  await fs.writeFile(checksumPath, artifactHash + "  release/artifacts/fixture-1.2.3.zip\n");
  const release = { productId: "fixture-product", version: "1.2.3", artifacts: [{ path: "release/artifacts/fixture-1.2.3.zip", sha256: artifactHash }] };
  await fs.writeFile(releasePath, JSON.stringify(release, null, 2) + "\n");
  const context = {
    candidateRoot,
    approval: {
      approvalPackageDigest: "a".repeat(64), candidateId: "pfc-fixture-p7", candidateDigest: "b".repeat(64), capsuleSha256: "c".repeat(64),
      publisherCommit: "1".repeat(40), publisherTree: "2".repeat(40), baseSiteCommit: "3".repeat(40), baseSiteTree: "4".repeat(40),
      productId: "fixture-product", submissionType: "NEW_VERSION", artifactSha256: [artifactHash],
      artifactInventory: [{ packagePath: "release/artifacts/fixture-1.2.3.zip", sizeBytes: artifactBytes.length, computedSha256: artifactHash, platform: "Windows" }]
    },
    state: { releaseVersion: "1.2.3" },
    capsule: { productId: "fixture-product", releaseVersion: "1.2.3", checksumPath: "release/SHA256SUMS.txt", releaseManifestPath: "release/release.json" },
    release,
    ownerApproval: { approvalId: "e".repeat(64) }
  };
  const allActions = ["PUBLISH_ARTIFACTS", "PROMOTE_CANONICAL_STATE", "DEPLOY_SITE", "VERIFY_LIVE"];
  context.ownerRecord = makeOwnerApprovalForFixture(context.approval, pair.privateKey, allActions);
  context.ownerPublicKey = Buffer.from(publicPem);
  context.ownerApproval = { approvalId: context.ownerRecord.approvalId, approvedAt: context.ownerRecord.approvedAt };
  const plan = await buildR2Plan(context);
  check(plan.bucket === "proof-foundry-downloads" && plan.objectCount === 3, "R2 plan freezes bucket and artifact/checksum/release object count");
  check(plan.objects[0].objectKey === "fixture-product/v1.2.3/fixture-1.2.3.zip" && plan.objects[0].byteLength === artifactBytes.length && plan.objects[0].sha256 === artifactHash, "R2 artifact key, length, and digest bind to candidate bytes");
  check(plan.objects[0].publicUrl === "https://downloads.theprooffoundry.com/fixture-product/v1.2.3/fixture-1.2.3.zip", "public URL is derived from the immutable approved object key");
  check(plan.commands.every((command) => command.includes(" --remote ")), "every planned R2 command explicitly targets remote storage");
  assert.throws(() => buildR2PutCommand(plan.objects[0], { remote: false }), /remote storage/);
  check(true, "R2 command generation rejects a missing --remote selection");
  assert.throws(() => buildR2PutCommand(plan.objects[0], { remote: true, bucket: "wrong-bucket" }), /fixed by the publisher contract/);
  check(true, "wrong R2 bucket is rejected");
  assert.throws(() => buildR2PutCommand({ ...plan.objects[0], objectKey: "fixture-product/v1.2.3/../other.zip" }, { remote: true }), /versioned product release object/);
  check(true, "wrong or traversing object path is rejected");
  const blockedPublish = await runP7P9Command("publish-artifacts", ["unused-package"], ["--live"]);
  check(blockedPublish.status === "HOLD" && blockedPublish.code === "LIVE_MUTATION_DISABLED", "artifact command with --live fails before package access or transport");
  const blockedPromote = await runP7P9Command("promote", ["unused-package", "unused-receipt"], ["--live", "--fixture"]);
  check(blockedPromote.status === "HOLD" && blockedPromote.code === "LIVE_MUTATION_DISABLED", "canonical promotion rejects --live even when fixture is also present");
  const blockedDeploy = await runP7P9Command("deploy-site", ["unused-package", "unused-payload"], ["--live", "--fixture"]);
  check(blockedDeploy.status === "HOLD" && blockedDeploy.code === "LIVE_MUTATION_DISABLED", "Pages command rejects --live even when fixture is also present");
  const dryRun = makeArtifactDryRun(context.ownerApproval.approvalId, plan);
  check(dryRun.state === "DRY_RUN_ONLY" && dryRun.mutationPerformed === false, "dry-run emits the exact plan without calling a transport");

  const expected = { ...context.approval };
  const record = signed(expected, pair.privateKey, allActions);
  check(verifyOwnerApproval(expected, record, publicPem, "PUBLISH_ARTIFACTS").approvalId === record.approvalId, "valid owner signature consumes an action-scoped approval");
  const narrow = signed(expected, pair.privateKey, ["PUBLISH_ARTIFACTS"]);
  assert.throws(() => verifyOwnerApproval(expected, narrow, publicPem, "DEPLOY_SITE"), /APPROVED_ACTION_REQUIRED/);
  check(true, "artifact-only approval cannot authorize Pages deployment");
  assert.throws(() => verifyOwnerApproval(expected, signed(expected, pair.privateKey, allActions, { candidateDigest: "f".repeat(64) }), publicPem, "PUBLISH_ARTIFACTS"), /APPROVAL_STALE/);
  check(true, "wrong candidate binding is rejected");
  assert.throws(() => verifyOwnerApproval(expected, signed(expected, pair.privateKey, allActions, { publisherCommit: "9".repeat(40) }), publicPem, "PUBLISH_ARTIFACTS"), /APPROVAL_STALE/);
  check(true, "wrong publisher commit is rejected");
  assert.throws(() => verifyOwnerApproval(expected, signed(expected, pair.privateKey, allActions, { approvalPackageDigest: "8".repeat(64) }), publicPem, "PUBLISH_ARTIFACTS"), /APPROVAL_STALE/);
  check(true, "stale approval-package digest is rejected");
  assert.throws(() => verifyOwnerApproval(expected, signed(expected, pair.privateKey, allActions, { artifactSha256: ["7".repeat(64)] }), publicPem, "PUBLISH_ARTIFACTS"), /APPROVAL_STALE/);
  check(true, "wrong artifact digest is rejected");

  const partialTransport = new MemoryR2FixtureTransport({ failPutAt: 2 });
  const partial = await publishArtifactPlan(context, plan, partialTransport, { remote: true });
  check(partial.status === "PARTIAL_PUBLICATION_HOLD" && partial.receipt.state !== "PUBLISHED", "partial R2 failure remains on hold and never claims publication");
  check(partial.ledger[0].state === "WRITTEN_VERIFIED" && partial.ledger[1].state === "WRITE_FAILED" && partialTransport.objects.size === 1, "partial ledger preserves successful immutable objects without deleting them");
  check(partialTransport.deletedKeys.length === 0, "partial failure performs no automatic R2 delete");

  const idempotentTransport = new MemoryR2FixtureTransport();
  const first = await publishArtifactPlan(context, plan, idempotentTransport, { remote: true });
  const putCount = idempotentTransport.putCount;
  const second = await publishArtifactPlan(context, plan, idempotentTransport, { remote: true });
  check(first.status === "ARTIFACTS_PUBLISHED_VERIFIED" && second.status === "ARTIFACTS_PUBLISHED_VERIFIED", "all public fixture bytes verify before verified state");
  check(idempotentTransport.putCount === putCount && second.ledger.every((row) => row.state === "ALREADY_PRESENT_VERIFIED"), "identical existing objects are idempotent and never overwritten");
  check(await verifyArtifactReceipt(second.receipt, context, plan, (object) => idempotentTransport.fetchPublic(object)), "verified receipt binds a signed publish approval, candidate, plan, and freshly fetched public digests");
  idempotentTransport.objects.set(plan.objects[0].objectKey, { bytes: Buffer.from("public object changed after receipt"), headers: {} });
  check(!(await verifyArtifactReceipt(second.receipt, context, plan, (object) => idempotentTransport.fetchPublic(object))), "P8-style receipt validation refetches public bytes and detects later drift");

  const conflictTransport = new MemoryR2FixtureTransport();
  const firstObject = plan.objects[0];
  conflictTransport.objects.set(firstObject.objectKey, { bytes: Buffer.from("conflict"), headers: { "content-type": firstObject.contentType, "content-disposition": firstObject.contentDisposition, "cache-control": firstObject.cachePolicy } });
  const conflict = await publishArtifactPlan(context, plan, conflictTransport, { remote: true });
  check(conflict.ledger[0].failureCode === "IMMUTABLE_OBJECT_CONFLICT", "a pre-existing conflicting versioned key is rejected");

  const badPublic = new MemoryR2FixtureTransport({ publicOverrides: { [firstObject.objectKey]: { status: 200, bytes: Buffer.from("wrong public bytes"), headers: {} } } });
  const mismatch = await publishArtifactPlan(context, plan, badPublic, { remote: true });
  check(mismatch.status === "ARTIFACT_VERIFICATION_FAILED" && !(await verifyArtifactReceipt(mismatch.receipt, context, plan, (object) => badPublic.fetchPublic(object))), "public digest mismatch blocks verified receipt and therefore P8");
  console.log("PF PRODUCT P7 TESTS: " + passed + " passed, 0 failed");
} catch (error) {
  console.error("PF PRODUCT P7 TESTS: " + passed + " passed, 1 failed");
  console.error(error?.stack || String(error));
  process.exitCode = 1;
} finally {
  await fs.rm(TEMP, { recursive: true, force: true });
}
