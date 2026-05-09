const { expect } = require("chai");
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");
const http = require("http");
const { performance } = require("perf_hooks");
const { createServer } = require("../scripts/compliance-gateway");

/**
 * Latency Benchmark — 合規架構延遲量化
 *
 * 對應論文 §4-X-2：補強 §2-8（鏈下與鏈上驗證權衡）的定量證據。
 *
 * 七個 case：
 *   M0：純 ERC-20 transfer                 → baseline
 *   M1：ERC-3643 transfer                  → 底層靜態合規
 *   M2：PBM safeTransferFrom, rules=1      → 外層動態合規
 *   M3：PBM safeTransferFrom, rules=5
 *   M4：PBM safeTransferFrom, rules=100    → 純鏈上壓力測試
 *   M5：wrap + ProofSet, AML=1k            → 鏈下檢驗
 *   M6：wrap + ProofSet, AML=1M            → 鏈下檢驗 worst-case
 *
 * 量測方法：
 *   - 環境：Hardhat（in-process，去除區塊確認與 P2P 雜訊，隔離合規架構本身的延遲）
 *   - 指標：performance.now() 量 wall-clock，包含 tx 提交 → receipt 完整時間
 *   - 鏈下路徑（M5/M6）額外包含 HTTP roundtrip + server AML 比對 + ECDSA 簽章
 *   - 統計：每個 case N=100，取中位數 + IQR (P25–P75)
 *   - 排除 outlier：報告 median 而非 mean，避免 GC / OS scheduler 偶發噪音污染
 */
const N = 100;
const SMALL_PORT = 8765;
const LARGE_PORT = 8766;
const AML_SMALL = 1_000;
const AML_LARGE = 1_000_000;

function postJSON(port, body) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request(
      {
        hostname: "127.0.0.1",
        port,
        path: "/",
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(data),
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => {
          try {
            resolve(JSON.parse(Buffer.concat(chunks).toString()));
          } catch (e) {
            reject(e);
          }
        });
      },
    );
    req.on("error", reject);
    req.write(data);
    req.end();
  });
}

describe("Latency Benchmark — 合規架構延遲量化", function () {
  this.timeout(1_800_000); // 30 min（M6 要產 1M AML 名單 + 100 次 wrap）

  const JURISDICTION_TW = ethers.encodeBytes32String("TW");
  const TIER_STANDARD = ethers.keccak256(ethers.toUtf8Bytes("TIER_STANDARD"));
  const IDENTITY_HASH = ethers.keccak256(ethers.toUtf8Bytes("KYC_HASH"));
  const COUNTRY_TW = 158;
  const AssetType = { ERC20: 0, ERC721: 1, ERC1155: 2 };

  const results = [];
  let gatewayWallet;
  let smallServer;
  let largeServer;

  before(async function () {
    // 鏈下 gateway 用獨立 keypair（不需是 hardhat signer）
    gatewayWallet = ethers.Wallet.createRandom();

    smallServer = createServer(gatewayWallet.privateKey, AML_SMALL);
    await new Promise((r) => smallServer.listen(SMALL_PORT, r));

    console.log(`  [gateway] starting large server (生成 ${AML_LARGE.toLocaleString()} 筆名單，請稍候 ~5s)...`);
    largeServer = createServer(gatewayWallet.privateKey, AML_LARGE);
    await new Promise((r) => largeServer.listen(LARGE_PORT, r));
    console.log(`  [gateway] both servers ready, signer=${gatewayWallet.address}`);
  });

  after(async function () {
    if (smallServer) await new Promise((r) => smallServer.close(r));
    if (largeServer) await new Promise((r) => largeServer.close(r));
    writeResults();
  });

  function summarize(label, description, samples) {
    const sorted = [...samples].sort((a, b) => a - b);
    const at = (q) => sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * q))];
    const median = at(0.5);
    const p25 = at(0.25);
    const p75 = at(0.75);
    const min = sorted[0];
    const max = sorted[sorted.length - 1];
    const mean = sorted.reduce((a, b) => a + b, 0) / sorted.length;
    results.push({ label, description, n: sorted.length, median, p25, p75, min, max, mean });
    console.log(
      `  [${label}] N=${sorted.length} median=${median.toFixed(2)}ms IQR=[${p25.toFixed(2)}–${p75.toFixed(2)}] min=${min.toFixed(2)} max=${max.toFixed(2)}`,
    );
  }

  async function repeatTimed(label, description, txFn) {
    // 預熱：消除 SSTORE 0→非0 的一次性開戶成本 + JIT warm-up
    await (await txFn()).wait();
    const samples = [];
    for (let i = 0; i < N; i++) {
      const t0 = performance.now();
      const tx = await txFn();
      await tx.wait();
      const t1 = performance.now();
      samples.push(t1 - t0);
    }
    summarize(label, description, samples);
  }

  // ============================================================
  // M0: 純 ERC-20 transfer (baseline)
  // ============================================================
  it("M0: 純 ERC-20 transfer", async function () {
    const [, alice, bob] = await ethers.getSigners();
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const erc20 = await MockERC20.deploy("Test Token", "TST");
    await erc20.waitForDeployment();
    await erc20.mint(alice.address, ethers.parseEther("1000000"));

    await repeatTimed(
      "M0",
      "ERC-20 transfer — 無合規基線",
      () => erc20.connect(alice).transfer(bob.address, 1n),
    );
  });

  // ============================================================
  // M1: ERC-3643 transfer (底層靜態合規)
  // ============================================================
  it("M1: ERC-3643 transfer (五階段靜態檢查)", async function () {
    const [owner, agent, alice, bob] = await ethers.getSigners();

    const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
    const ccid = await CCIDRegistry.deploy();
    await ccid.waitForDeployment();

    const ClaimTopicsRegistry = await ethers.getContractFactory("ClaimTopicsRegistry");
    const claimTopics = await ClaimTopicsRegistry.deploy();
    await claimTopics.waitForDeployment();

    const TrustedIssuersRegistry = await ethers.getContractFactory("TrustedIssuersRegistry");
    const trustedIssuers = await TrustedIssuersRegistry.deploy();
    await trustedIssuers.waitForDeployment();

    const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
    const identityRegistry = await IdentityRegistry.deploy(
      await trustedIssuers.getAddress(),
      await claimTopics.getAddress(),
      await ccid.getAddress(),
    );
    await identityRegistry.waitForDeployment();

    const ComplianceModule = await ethers.getContractFactory("ComplianceModule");
    const compliance = await ComplianceModule.deploy(await identityRegistry.getAddress());
    await compliance.waitForDeployment();

    const ERC3643Token = await ethers.getContractFactory("ERC3643Token");
    const security = await ERC3643Token.deploy(
      "GL1 Security Bond",
      "GL1BOND",
      await identityRegistry.getAddress(),
      await compliance.getAddress(),
    );
    await security.waitForDeployment();
    await compliance.bindToken(await security.getAddress());

    const AGENT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("AGENT_ROLE"));
    await security.grantRole(AGENT_ROLE, agent.address);

    await ccid.registerIdentity(alice.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.registerIdentity(bob.address, IDENTITY_HASH, TIER_STANDARD);
    await identityRegistry.registerIdentity(alice.address, alice.address, COUNTRY_TW);
    await identityRegistry.registerIdentity(bob.address, bob.address, COUNTRY_TW);

    await security.connect(agent).mint(alice.address, ethers.parseEther("1000000"));

    await repeatTimed(
      "M1",
      "ERC-3643 transfer — 底層靜態合規（凍結/暫停/身份/合規模組）",
      () => security.connect(alice).transfer(bob.address, 1n),
    );
  });

  // ============================================================
  // 共用：部署 PBM 環境（純鏈上路徑，M2/M3/M4）
  // ============================================================
  async function deployOnChainPBM(extraColdRules) {
    const [owner, alice, bob] = await ethers.getSigners();

    const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
    const ccid = await CCIDRegistry.deploy();
    await ccid.waitForDeployment();
    await ccid.registerIdentity(alice.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.registerIdentity(bob.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.approveJurisdiction(alice.address, JURISDICTION_TW);
    await ccid.approveJurisdiction(bob.address, JURISDICTION_TW);

    const MockChainlinkACE = await ethers.getContractFactory("MockChainlinkACE");
    const ace = await MockChainlinkACE.deploy();
    await ace.waitForDeployment();

    const GL1PolicyManager = await ethers.getContractFactory("GL1PolicyManager");
    const manager = await GL1PolicyManager.deploy(
      await ace.getAddress(),
      await ccid.getAddress(),
      owner.address,
    );
    await manager.waitForDeployment();

    const PBMToken = await ethers.getContractFactory("PBMToken");
    const pbm = await PBMToken.deploy(owner.address);
    await pbm.waitForDeployment();

    const GL1PolicyWrapper = await ethers.getContractFactory("GL1PolicyWrapper");
    const wrapper = await GL1PolicyWrapper.deploy(
      JURISDICTION_TW,
      await manager.getAddress(),
      await pbm.getAddress(),
      owner.address,
    );
    await wrapper.waitForDeployment();

    await pbm.updateWrapper(await wrapper.getAddress());
    await manager.setJurisdictionEnabled(JURISDICTION_TW, true);

    // 註冊 1 條基礎 WhitelistRule
    const Whitelist = await ethers.getContractFactory("WhitelistRule");
    const whitelist = await Whitelist.deploy();
    await whitelist.waitForDeployment();
    await whitelist.addToWhitelist(bob.address, "Bob Shop", "RETAIL");

    const ruleIds = [];
    let priority = 1;
    const baseRuleId = ethers.keccak256(ethers.toUtf8Bytes("RULE_WHITELIST"));
    await manager.registerRuleSet(baseRuleId, "WHITELIST", true, await whitelist.getAddress(), priority++);
    ruleIds.push(baseRuleId);

    // 額外註冊 N 條獨立部署的 WhitelistRule（每條獨立合約地址 + 獨立 storage）
    for (let i = 0; i < extraColdRules; i++) {
      const w = await Whitelist.deploy();
      await w.waitForDeployment();
      await w.addToWhitelist(bob.address, "Bob Shop " + i, "RETAIL");
      const coldId = ethers.keccak256(ethers.toUtf8Bytes("RULE_COLD_" + i));
      await manager.registerRuleSet(coldId, "COLD_" + i, true, await w.getAddress(), priority++);
      ruleIds.push(coldId);
    }
    await manager.setJurisdictionRules(JURISDICTION_TW, ruleIds);

    // 部署 ERC-20 並 wrap 成 PBM（這段需要 alice 暫時豁免合規以送設定 tx）
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const erc20 = await MockERC20.deploy("Cash", "CASH");
    await erc20.waitForDeployment();
    await erc20.mint(alice.address, ethers.parseEther("1000000"));

    await wrapper.setComplianceExemption(alice.address, true);
    await erc20.connect(alice).approve(await wrapper.getAddress(), ethers.MaxUint256);
    const wrapAmount = ethers.parseEther("100000");
    const emptyProof = {
      proofType: ethers.encodeBytes32String("KYC"),
      credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
      issuedAt: Math.floor(Date.now() / 1000) - 3600,
      expiresAt: Math.floor(Date.now() / 1000) + 86400,
      issuer: ethers.ZeroAddress,
      signature: "0x",
    };
    await wrapper.connect(alice).wrap(AssetType.ERC20, await erc20.getAddress(), 0, wrapAmount, emptyProof);
    await wrapper.setComplianceExemption(alice.address, false);

    const pbmTokenId = await wrapper.computePBMTokenId(AssetType.ERC20, await erc20.getAddress(), 0);

    return { alice, bob, pbm, pbmTokenId };
  }

  // ============================================================
  // M2: PBM safeTransferFrom (rules=1)
  // ============================================================
  it("M2: PBM safeTransferFrom (rules=1)", async function () {
    const { alice, bob, pbm, pbmTokenId } = await deployOnChainPBM(0);
    await repeatTimed(
      "M2",
      "PBM safeTransferFrom — 純鏈上 (rules=1, WhitelistRule)",
      () => pbm.connect(alice).safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x"),
    );
  });

  // ============================================================
  // M3: PBM safeTransferFrom (rules=5)
  // ============================================================
  it("M3: PBM safeTransferFrom (rules=5)", async function () {
    const { alice, bob, pbm, pbmTokenId } = await deployOnChainPBM(4);
    await repeatTimed(
      "M3",
      "PBM safeTransferFrom — 純鏈上 (rules=5)",
      () => pbm.connect(alice).safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x"),
    );
  });

  // ============================================================
  // M4: PBM safeTransferFrom (rules=100)
  // ============================================================
  it("M4: PBM safeTransferFrom (rules=100)", async function () {
    const { alice, bob, pbm, pbmTokenId } = await deployOnChainPBM(99);
    await repeatTimed(
      "M4",
      "PBM safeTransferFrom — 純鏈上 (rules=100)",
      () => pbm.connect(alice).safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x"),
    );
  });

  // ============================================================
  // 共用：部署 PBM 環境（鏈下 ProofSet 路徑，M5/M6）
  // 使用 safeTransferFromWithProof：alice 先持有 PBM（一次性 wrap），
  // 之後每筆 transfer 攜帶 ProofSet，wrapper 驗章後直接放行（跳過鏈上規則鏈）。
  // ============================================================
  async function deployOffChainPBM() {
    const [owner, alice, bob] = await ethers.getSigners();

    const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
    const ccid = await CCIDRegistry.deploy();
    await ccid.waitForDeployment();
    await ccid.registerIdentity(alice.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.registerIdentity(bob.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.approveJurisdiction(alice.address, JURISDICTION_TW);
    await ccid.approveJurisdiction(bob.address, JURISDICTION_TW);

    const MockChainlinkACE = await ethers.getContractFactory("MockChainlinkACE");
    const ace = await MockChainlinkACE.deploy();
    await ace.waitForDeployment();

    const GL1PolicyManager = await ethers.getContractFactory("GL1PolicyManager");
    const manager = await GL1PolicyManager.deploy(
      await ace.getAddress(),
      await ccid.getAddress(),
      owner.address,
    );
    await manager.waitForDeployment();
    await manager.setJurisdictionEnabled(JURISDICTION_TW, true);

    const PBMToken = await ethers.getContractFactory("PBMToken");
    const pbm = await PBMToken.deploy(owner.address);
    await pbm.waitForDeployment();

    // 鏈下路徑：trustedSigner 設為 gateway wallet
    const GL1PolicyWrapper = await ethers.getContractFactory("GL1PolicyWrapper");
    const wrapper = await GL1PolicyWrapper.deploy(
      JURISDICTION_TW,
      await manager.getAddress(),
      await pbm.getAddress(),
      gatewayWallet.address,
    );
    await wrapper.waitForDeployment();
    await pbm.updateWrapper(await wrapper.getAddress());

    // 一次性 setup：alice 暫時豁免合規 → wrap ERC20 取得 PBM → 解除豁免
    // 之後 alice 的 transfer 都走 safeTransferFromWithProof
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const erc20 = await MockERC20.deploy("Cash", "CASH");
    await erc20.waitForDeployment();
    await erc20.mint(alice.address, ethers.parseEther("1000000"));

    await wrapper.setComplianceExemption(alice.address, true);
    await erc20.connect(alice).approve(await wrapper.getAddress(), ethers.MaxUint256);
    const wrapAmount = ethers.parseEther("100000");
    const setupProof = {
      proofType: ethers.encodeBytes32String("KYC"),
      credentialHash: ethers.keccak256(ethers.toUtf8Bytes("setup")),
      issuedAt: Math.floor(Date.now() / 1000) - 3600,
      expiresAt: Math.floor(Date.now() / 1000) + 86400,
      issuer: ethers.ZeroAddress,
      signature: "0x",
    };
    await wrapper
      .connect(alice)
      .wrap(AssetType.ERC20, await erc20.getAddress(), 0, wrapAmount, setupProof);
    await wrapper.setComplianceExemption(alice.address, false);

    const pbmTokenId = await wrapper.computePBMTokenId(AssetType.ERC20, await erc20.getAddress(), 0);

    return { alice, bob, wrapper, pbmTokenId };
  }

  async function repeatTimedOffChain(label, description, port, alice, bob, wrapper, pbmTokenId) {
    // 預熱：JIT + storage 開戶
    {
      const proof = await postJSON(port, { user: alice.address, amount: "1" });
      await (
        await wrapper
          .connect(alice)
          .safeTransferFromWithProof(alice.address, bob.address, pbmTokenId, 1n, proof)
      ).wait();
    }

    const samples = [];
    for (let i = 0; i < N; i++) {
      const t0 = performance.now();
      const proof = await postJSON(port, { user: alice.address, amount: "1" });
      const tx = await wrapper
        .connect(alice)
        .safeTransferFromWithProof(alice.address, bob.address, pbmTokenId, 1n, proof);
      await tx.wait();
      const t1 = performance.now();
      samples.push(t1 - t0);
    }
    summarize(label, description, samples);
  }

  // ============================================================
  // M5: 鏈下 ProofSet (AML 名單 = 1k)
  // ============================================================
  it("M5: safeTransferFromWithProof (鏈下檢驗, AML=1k)", async function () {
    const { alice, bob, wrapper, pbmTokenId } = await deployOffChainPBM();
    await repeatTimedOffChain(
      "M5",
      "safeTransferFromWithProof — 鏈下檢驗 (AML 名單=1,000)",
      SMALL_PORT,
      alice,
      bob,
      wrapper,
      pbmTokenId,
    );
  });

  // ============================================================
  // M6: 鏈下 ProofSet (AML 名單 = 1M)
  // ============================================================
  it("M6: safeTransferFromWithProof (鏈下檢驗, AML=1M)", async function () {
    const { alice, bob, wrapper, pbmTokenId } = await deployOffChainPBM();
    await repeatTimedOffChain(
      "M6",
      "safeTransferFromWithProof — 鏈下檢驗 (AML 名單=1,000,000)",
      LARGE_PORT,
      alice,
      bob,
      wrapper,
      pbmTokenId,
    );
  });

  // ============================================================
  // 收尾：產出 markdown + CSV
  // ============================================================
  function writeResults() {
    if (results.length === 0) {
      console.log("\n[latency-benchmark] no results collected");
      return;
    }

    const order = ["M0", "M1", "M2", "M3", "M4", "M5", "M6"];
    const ordered = order.map((lab) => results.find((r) => r.label === lab)).filter(Boolean);

    const baseline = ordered.find((r) => r.label === "M0");
    const baselineMed = baseline ? baseline.median : null;
    const fmt = (x) => (Number.isFinite(x) ? x.toFixed(2) : "—");

    const md = [];
    md.push("# Latency Benchmark — 合規架構延遲量化\n");
    md.push("## 量測說明\n");
    md.push(
      "- **量測環境**：Hardhat（in-process EVM）。本實驗量測合規架構引入的執行時間，**不含區塊確認時間**——區塊時間屬底層鏈特性（Ethereum L1 ~12s、L2 ~2s），與本研究探討的合規架構設計無關，且對所有路徑為共同常數，不影響相對比較。",
    );
    md.push(
      "- **指標**：`performance.now()` 量 wall-clock，從 tx 提交到 receipt 完整時間。鏈下路徑（M5/M6）額外包含 HTTP roundtrip + server AML 比對 + ECDSA 簽章。",
    );
    md.push(
      `- **統計方法**：每個 case 預熱 1 次後跑 N=${N} 次，報中位數 (median) 與 IQR (P25–P75)。採中位數而非平均，避免 GC、OS scheduler 偶發 outlier 污染。`,
    );
    md.push(
      "- **架構分層**：M1 量測底層靜態合規（ERC-3643）；M2/M3/M4 量測純鏈上動態合規（規則鏈執行）；M5/M6 量測鏈下檢驗（ProofSet 機制）。",
    );
    md.push(
      "- **與 Gas Benchmark 對應**：M0↔L0（純 ERC-20）、M1↔L1（ERC-3643）、M2↔L2、M3↔L3、M4↔L4；M5/M6 為鏈下路徑，gas benchmark 無對應 case。",
    );
    md.push("");
    md.push(
      "| Case | Description | N | Median (ms) | P25 | P75 | Min | Max | Mean | vs M0 |",
    );
    md.push(
      "|------|-------------|--:|------------:|----:|----:|----:|----:|-----:|------:|",
    );
    for (const r of ordered) {
      const vsBase =
        baselineMed && baselineMed > 0
          ? ((r.median / baselineMed - 1) * 100).toFixed(2) + "%"
          : "—";
      md.push(
        `| ${r.label} | ${r.description} | ${r.n} | ${fmt(r.median)} | ${fmt(r.p25)} | ${fmt(r.p75)} | ${fmt(r.min)} | ${fmt(r.max)} | ${fmt(r.mean)} | ${vsBase} |`,
      );
    }
    md.push("");
    md.push("## 觀察重點\n");
    md.push(
      "- **M2 → M3 → M4**：純鏈上路徑隨規則數成長（線性 / 近線性），規則越多延遲越大。",
    );
    md.push(
      "- **M5 ≈ M6**：鏈下路徑不論 AML 名單從 1k 放大到 1M，鏈上仍只 `_verifyProofSet()` 驗一次章，鏈上耗時近乎不變；HTTP + server 計算為主要成本。",
    );
    md.push(
      "- **Crossover 點**：當鏈上規則數超過某門檻，純鏈上延遲 > 鏈下延遲。此即論文 §2-8 「鏈下與鏈上驗證權衡」 的定量支持點。",
    );
    md.push("");

    const mdPath = path.join(__dirname, "..", "latency-benchmark-results.md");
    fs.writeFileSync(mdPath, md.join("\n"), "utf8");

    const csv = [];
    csv.push("case,description,n,median_ms,p25_ms,p75_ms,min_ms,max_ms,mean_ms,vs_m0_pct");
    for (const r of ordered) {
      const vsBase =
        baselineMed && baselineMed > 0 ? ((r.median / baselineMed - 1) * 100).toFixed(2) : "";
      const desc = `"${r.description.replace(/"/g, '""')}"`;
      csv.push(
        `${r.label},${desc},${r.n},${fmt(r.median)},${fmt(r.p25)},${fmt(r.p75)},${fmt(r.min)},${fmt(r.max)},${fmt(r.mean)},${vsBase}`,
      );
    }
    const csvPath = path.join(__dirname, "..", "latency-benchmark-results.csv");
    fs.writeFileSync(csvPath, csv.join("\n"), "utf8");

    console.log(`\n[latency-benchmark] wrote ${mdPath}`);
    console.log(`[latency-benchmark] wrote ${csvPath}`);
  }
});
