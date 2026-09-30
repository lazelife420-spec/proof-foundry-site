import assert from "node:assert/strict";
import { makeOwnerApprovalForFixture, validatePublicationRecordChain, verifyLivePublication, sha256 } from "./pf-product-p7-p9.mjs";
import crypto from "node:crypto";

let passed = 0;
function check(value, description) { assert.ok(value, description); passed++; }
const site = "https://theprooffoundry.com";
const downloads = "https://downloads.theprooffoundry.com";
const productId = "fixture-product";
const artifactBytes = Buffer.from("synthetic p9 live artifact\n");
const artifactHash = sha256(artifactBytes);
const artifactUrl = downloads + "/fixture-product/v1.2.3/fixture.zip";
const releaseUrl = downloads + "/fixture-product/v1.2.3/release.json";
const routeList = ["/", "/software/", "/fixture-product/", "/proof/", "/truth/", "/truth/index.json", "/truth/products/fixture-product.json", "/truth/products/other-product.json", "/truth-files/", "/truth-files/fixture-product/", "/sitemap.xml", "/robots.txt"];

function productDoc(id, route, status, version, url, digest, label) {
  return { id, route, productStatus: status, release: { publicVersion: version, releaseStatus: "PUBLIC_RELEASE" },
    download: { available: true, url, sha256: digest, sha256Url: url ? url.replace(/[^/]+$/, "SHA256SUMS.txt") : null, label },
    artifacts: url ? [{ filename: "fixture.zip", sizeBytes: artifactBytes.length, sha256: digest, downloadUrl: url }] : [],
    verification: { status: "PENDING" }, commerce: label ? { label } : null };
}
function projection(doc) {
  return { id: doc.id, route: doc.route, productStatus: doc.productStatus, release: doc.release, download: doc.download, artifacts: doc.artifacts, verification: doc.verification, commerce: doc.commerce ?? null };
}
function sitemap(routes) { return "<?xml version=\"1.0\"?><urlset>" + routes.map((route) => "<url><loc>" + site + route + "</loc></url>").join("") + "</urlset>"; }
function fixture({ sourceCommit = "1".repeat(40), productVersion = "1.2.3", artifact = artifactBytes, routeOverride = routeList, otherStatus = "PUBLIC_RELEASE", commerceLabel = "Free download" } = {}) {
  const targetDoc = productDoc(productId, "/fixture-product/", "PUBLIC_RELEASE", productVersion, artifactUrl, artifactHash, commerceLabel);
  const otherDoc = productDoc("other-product", "/other-product/", otherStatus, "4.0.0", null, null, "Paid download");
  const index = { source: { commit: sourceCommit, tree: "2".repeat(40) }, productCount: 2, products: [] };
  const homepageBytes = Buffer.from("<h1>Frozen fixture homepage</h1>\n");
  const productBytes = Buffer.from("<h1>Fixture Product</h1><p>v1.2.3</p><a href=\"" + artifactUrl + "\">Download</a>");
  const softwareBytes = Buffer.from("<h1>Software</h1><article>Fixture Product v1.2.3 Free download " + artifactUrl + "</article><article>Other product Paid download</article>");
  const truthFileBytes = Buffer.from("<h1>Fixture Product Truth File</h1><p>v1.2.3</p><code>" + artifactHash + "</code>");
  const routes = new Map([
    [site + "/", { status: 200, bytes: homepageBytes }],
    [site + "/software/", { status: 200, bytes: softwareBytes }],
    [site + "/fixture-product/", { status: 200, bytes: productBytes }],
    [site + "/proof/", { status: 200, bytes: Buffer.from("proof") }],
    [site + "/truth/", { status: 200, bytes: Buffer.from("truth") }],
    [site + "/truth/index.json", { status: 200, bytes: Buffer.from(JSON.stringify(index)) }],
    [site + "/truth/products/fixture-product.json", { status: 200, bytes: Buffer.from(JSON.stringify(targetDoc)) }],
    [site + "/truth/products/other-product.json", { status: 200, bytes: Buffer.from(JSON.stringify(otherDoc)) }],
    [site + "/truth-files/", { status: 200, bytes: Buffer.from("truth files") }],
    [site + "/truth-files/fixture-product/", { status: 200, bytes: truthFileBytes }],
    [site + "/sitemap.xml", { status: 200, bytes: Buffer.from(sitemap(routeOverride)) }],
    [site + "/robots.txt", { status: 200, bytes: Buffer.from("User-agent: *") }],
    [downloads + "/fixture-product/v1.2.3/release.json", { status: 200, bytes: Buffer.from(JSON.stringify({ productId, version: "1.2.3", artifacts: [{ sha256: artifactHash }] })) }],
    [artifactUrl, { status: 200, bytes: artifact }]
  ]);
  const record = {
    approval: { productId }, expectedRoutes: [...routeList], expectedSourceCommit: sourceCommit, expectedSourceTree: "2".repeat(40), expectedProductCount: 2,
    productRoute: "/fixture-product/", truthProductRoute: "/truth/products/fixture-product.json", truthFileRoute: "/truth-files/fixture-product/",
    expectedProduct: { id: productId, publicVersion: "1.2.3", releaseRecordUrl: releaseUrl, commerceLabel: "Free download", artifactUrls: [artifactUrl],
      artifacts: [{ filename: "fixture.zip", sizeBytes: artifactBytes.length, sha256: artifactHash, downloadUrl: artifactUrl }], truthProjection: projection(targetDoc) },
    predecessorProducts: [{ id: "other-product", truthProjection: projection(otherDoc), commerceLabel: "Paid download" }],
    expectedHomepageSha256: sha256(homepageBytes)
  };
  return { record, fetchPublic: async (url) => routes.get(url) || { status: 404, bytes: Buffer.alloc(0), headers: {} }, routes };
}

try {
  const full = fixture();
  const success = await verifyLivePublication(full.record, full.fetchPublic);
  check(success.state === "PUBLISHED_VERIFIED", "all truth, product, artifact, route, commerce, and homepage fixture checks produce PUBLISHED_VERIFIED");
  check(success.checks.sourceBinding.status === "PASS" && success.checks.routes.count === routeList.length && success.checks.liveArtifacts[0].matchesApproved, "closure records source binding, complete routes, and live artifact digest evidence");

  const approvalKey = crypto.generateKeyPairSync("ed25519");
  const approvalPublicPem = approvalKey.publicKey.export({ type: "spki", format: "pem" });
  const chainApproval = { approvalPackageDigest: "a".repeat(64), candidateId: "pfc-chain-fixture", candidateDigest: "b".repeat(64), capsuleSha256: "c".repeat(64),
    publisherCommit: "1".repeat(40), publisherTree: "2".repeat(40), baseSiteCommit: "3".repeat(40), baseSiteTree: "4".repeat(40),
    productId, submissionType: "NEW_VERSION", artifactSha256: [artifactHash] };
  const p7Approval = makeOwnerApprovalForFixture(chainApproval, approvalKey.privateKey, ["PUBLISH_ARTIFACTS"]);
  const p8Approval = makeOwnerApprovalForFixture(chainApproval, approvalKey.privateKey, ["PROMOTE_CANONICAL_STATE"]);
  const deployApproval = makeOwnerApprovalForFixture(chainApproval, approvalKey.privateKey, ["DEPLOY_SITE"]);
  const payloadHash = "d".repeat(64), promotionCommit = "5".repeat(40), promotionTree = "6".repeat(40), promotionManifestHash = "7".repeat(64);
  const receiptId = "8".repeat(32);
  const artifactReceipt = { state: "ARTIFACTS_PUBLISHED_VERIFIED", candidateId: chainApproval.candidateId, productId, approvalPackageDigest: chainApproval.approvalPackageDigest,
    approvalId: p7Approval.approvalId, ownerApprovalRecord: p7Approval, receiptId, objectLedger: [{ state: "WRITTEN_VERIFIED", digestMatch: true }] };
  const promotion = { candidateId: chainApproval.candidateId, candidateDigest: chainApproval.candidateDigest, approvalPackageDigest: chainApproval.approvalPackageDigest,
    approvalId: p8Approval.approvalId, ownerApprovalRecord: p8Approval, artifactReceiptId: receiptId, state: "SITE_PAYLOAD_QUALIFIED_UNDEPLOYED",
    payloadSha256: payloadHash, candidateSourceCommit: promotionCommit, candidateSourceTree: promotionTree, siteManifestSha256: promotionManifestHash };
  const chainRecord = { approval: chainApproval, approvalId: deployApproval.approvalId,
    stageApprovals: { publish: p7Approval, promote: p8Approval, deploy: deployApproval }, artifactPublicationReceipt: artifactReceipt, promotion,
    payloadManifest: { payloadSha256: payloadHash, manifestSha256: promotionManifestHash, sourceIdentity: { commit: promotionCommit, tree: promotionTree } },
    deployment: { payloadSha256: payloadHash, project: "proof-foundry-site", branch: "main", state: "DEPLOYED_FIXTURE_VERIFIED" },
    expectedRoutes: ["/"], expectedProduct: { artifacts: [{ sha256: artifactHash }] } };
  check(validatePublicationRecordChain(chainRecord, approvalPublicPem), "publication chain validates separately signed publish, promote, and deploy actions");
  const wrongStage = structuredClone(chainRecord);
  wrongStage.promotion.approvalId = wrongStage.stageApprovals.publish.approvalId;
  assert.throws(() => validatePublicationRecordChain(wrongStage, approvalPublicPem), /Canonical promotion or qualified payload/);
  check(true, "stage receipt cannot substitute another action approval ID");

  const wrongSource = fixture();
  wrongSource.record.expectedSourceCommit = "9".repeat(40);
  const sourceResult = await verifyLivePublication(wrongSource.record, wrongSource.fetchPublic);
  check(sourceResult.state === "LIVE_TRUTH_MISMATCH", "truth commit/tree mismatch prevents publication closure");

  const wrongProduct = fixture();
  const productKey = site + "/truth/products/fixture-product.json";
  const changedProduct = productDoc(productId, "/fixture-product/", "PUBLIC_RELEASE", "1.2.4", artifactUrl, artifactHash, "Free download");
  wrongProduct.routes.set(productKey, { status: 200, bytes: Buffer.from(JSON.stringify(changedProduct)) });
  const productResult = await verifyLivePublication(wrongProduct.record, wrongProduct.fetchPublic);
  check(productResult.state === "LIVE_TRUTH_MISMATCH", "product semantic/version mismatch prevents closure");

  const wrongArtifact = fixture({ artifact: Buffer.from("different artifact bytes") });
  const artifactResult = await verifyLivePublication(wrongArtifact.record, wrongArtifact.fetchPublic);
  check(artifactResult.state === "LIVE_ARTIFACT_MISMATCH", "live artifact digest mismatch prevents closure");

  const unrelatedProduct = fixture();
  const heldOther = productDoc("other-product", "/other-product/", "HOLD", "4.0.0", null, null, "Paid download");
  unrelatedProduct.routes.set(site + "/truth/products/other-product.json", { status: 200, bytes: Buffer.from(JSON.stringify(heldOther)) });
  const unrelatedResult = await verifyLivePublication(unrelatedProduct.record, unrelatedProduct.fetchPublic);
  check(unrelatedResult.state === "UNRELATED_REGRESSION" && unrelatedResult.unrelatedProductStateChange === "CHANGED", "unrelated product drift prevents closure");

  const commerceDrift = fixture();
  commerceDrift.routes.set(site + "/software/", { status: 200, bytes: Buffer.from("<h1>Software</h1><article>Fixture Product v1.2.3 Free download " + artifactUrl + "</article><article>Other product free download</article>") });
  const commerceResult = await verifyLivePublication(commerceDrift.record, commerceDrift.fetchPublic);
  check(commerceResult.state === "UNRELATED_REGRESSION" && commerceResult.unrelatedCommerceChange === "CHANGED", "unrelated commerce/acquisition label drift prevents closure: " + JSON.stringify({ state: commerceResult.state, flags: commerceResult.unrelatedCommerceChange, errors: commerceResult.errors }));

  const routeDrift = fixture({ routeOverride: routeList.filter((route) => route !== "/proof/") });
  const routeResult = await verifyLivePublication(routeDrift.record, routeDrift.fetchPublic);
  check(routeResult.state === "UNRELATED_REGRESSION" && routeResult.unrelatedRouteChange === "CHANGED", "sitemap route regression prevents closure");

  const homepageDrift = fixture();
  homepageDrift.routes.set(site + "/", { status: 200, bytes: Buffer.from("changed homepage") });
  const homepageResult = await verifyLivePublication(homepageDrift.record, homepageDrift.fetchPublic);
  check(homepageResult.state === "UNRELATED_REGRESSION" && homepageResult.unrelatedHomepageChange === "CHANGED", "unapproved homepage change prevents closure");

  const routeFailure = fixture();
  routeFailure.routes.set(site + "/truth-files/fixture-product/", { status: 503, bytes: Buffer.from("unavailable") });
  const routeFailureResult = await verifyLivePublication(routeFailure.record, routeFailure.fetchPublic);
  check(routeFailureResult.state === "LIVE_ROUTE_REGRESSION", "non-200 required route is distinguished from truth mismatch");
  console.log("PF PRODUCT P9 TESTS: " + passed + " passed, 0 failed");
} catch (error) {
  console.error("PF PRODUCT P9 TESTS: " + passed + " passed, 1 failed");
  console.error(error?.stack || String(error));
  process.exitCode = 1;
}
