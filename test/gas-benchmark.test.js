const { expect } = require("chai");
const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

/**
 * Gas Benchmark - 雙層合規架構成本量化
 *
 * L0：純 ERC-20 transfer (baseline)
 * L1：ERC-3643 transfer (五階段合規檢查)
 * L2：PBM safeTransferFrom (規則數=1，僅 WhitelistRule)
 * L3：PBM safeTransferFrom (規則數=5，五個規則全啟用)
 *
 * 每個 case 執行 12 次，丟棄前 2 次 (warm-up)，取後 10 次的 mean / median。
 */
describe("Gas Benchmark - 雙層合規架構成本量化", function () {
  this.timeout(600_000);

  const ITERATIONS = 12;
  const WARMUP = 2;

  const JURISDICTION_TW = ethers.encodeBytes32String("TW");
  const TIER_STANDARD = ethers.keccak256(ethers.toUtf8Bytes("TIER_STANDARD"));
  const IDENTITY_HASH = ethers.keccak256(ethers.toUtf8Bytes("KYC_HASH"));
  const COUNTRY_TW = 158;
  const AssetType = { ERC20: 0, ERC721: 1, ERC1155: 2 };

  // 收集每個 it() 的 measurement
  const results = [];

  function summarize(label, description, gasUsedSamples) {
    const measured = gasUsedSamples.slice(WARMUP).map(Number);
    const sorted = [...measured].sort((a, b) => a - b);
    const sum = measured.reduce((a, b) => a + b, 0);
    const mean = sum / measured.length;
    const median =
      measured.length % 2 === 0
        ? (sorted[measured.length / 2 - 1] + sorted[measured.length / 2]) / 2
        : sorted[Math.floor(measured.length / 2)];
    return {
      label,
      description,
      mean: Math.round(mean),
      median: Math.round(median),
      min: sorted[0],
      max: sorted[sorted.length - 1],
      raw: measured,
    };
  }

  async function runMeasure(label, description, txFn) {
    const samples = [];
    for (let i = 0; i < ITERATIONS; i++) {
      const tx = await txFn(i);
      const receipt = await tx.wait();
      samples.push(receipt.gasUsed);
    }
    const r = summarize(label, description, samples);
    results.push(r);
    return r;
  }

  // ============================================================
  // L0：純 ERC-20 transfer (baseline)
  // ============================================================
  it("L0: 純 ERC-20 transfer (baseline)", async function () {
    const [, alice, bob] = await ethers.getSigners();

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const erc20 = await MockERC20.deploy("Test Token", "TST");
    await erc20.waitForDeployment();

    await erc20.mint(alice.address, ethers.parseEther("1000000"));

    // 預熱：bob 的 storage slot 從 0 → 非 0 只發生一次，避免影響後續測量
    await (await erc20.connect(alice).transfer(bob.address, 1n)).wait();

    const r = await runMeasure(
      "L0",
      "純 ERC-20 transfer (baseline)",
      () => erc20.connect(alice).transfer(bob.address, 1n),
    );

    console.log(`  [L0] mean=${r.mean}  median=${r.median}  min=${r.min}  max=${r.max}`);
    expect(r.mean).to.be.greaterThan(0);
  });

  // ============================================================
  // L1：ERC-3643 transfer (五階段合規檢查)
  // ============================================================
  it("L1: ERC-3643 transfer (五階段檢查)", async function () {
    const [owner, agent, alice, bob] = await ethers.getSigners();

    const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
    const ccid = await CCIDRegistry.deploy();
    await ccid.waitForDeployment();

    const ClaimTopicsRegistry = await ethers.getContractFactory(
      "ClaimTopicsRegistry",
    );
    const claimTopics = await ClaimTopicsRegistry.deploy();
    await claimTopics.waitForDeployment();

    const TrustedIssuersRegistry = await ethers.getContractFactory(
      "TrustedIssuersRegistry",
    );
    const trustedIssuers = await TrustedIssuersRegistry.deploy();
    await trustedIssuers.waitForDeployment();

    const IdentityRegistry =
      await ethers.getContractFactory("IdentityRegistry");
    const identityRegistry = await IdentityRegistry.deploy(
      await trustedIssuers.getAddress(),
      await claimTopics.getAddress(),
      await ccid.getAddress(),
    );
    await identityRegistry.waitForDeployment();

    const ComplianceModule =
      await ethers.getContractFactory("ComplianceModule");
    const compliance = await ComplianceModule.deploy(
      await identityRegistry.getAddress(),
    );
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

    // 註冊 alice、bob 身份
    await ccid.registerIdentity(alice.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.registerIdentity(bob.address, IDENTITY_HASH, TIER_STANDARD);
    await identityRegistry.registerIdentity(
      alice.address,
      alice.address,
      COUNTRY_TW,
    );
    await identityRegistry.registerIdentity(
      bob.address,
      bob.address,
      COUNTRY_TW,
    );

    // mint 給 alice
    await security
      .connect(agent)
      .mint(alice.address, ethers.parseEther("1000000"));

    // 預熱：先轉一次讓 bob 的 balance slot 變熱
    await (await security.connect(alice).transfer(bob.address, 1n)).wait();

    const r = await runMeasure(
      "L1",
      "ERC-3643 transfer (paused / frozen / unfrozen / identity / compliance)",
      () => security.connect(alice).transfer(bob.address, 1n),
    );

    console.log(`  [L1] mean=${r.mean}  median=${r.median}  min=${r.min}  max=${r.max}`);
    expect(r.mean).to.be.greaterThan(0);
  });

  // ============================================================
  // 共用：部署 PBM 環境並可選地註冊規則
  // ============================================================
  async function deployPBMStack(ruleNames /* array of "WHITELIST" / "AML" / "FX" / "COLLATERAL" / "CASH" */) {
    const [owner, alice, bob] = await ethers.getSigners();

    // CCID
    const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
    const ccid = await CCIDRegistry.deploy();
    await ccid.waitForDeployment();

    // 註冊 alice、bob 身份 + 管轄區核准
    await ccid.registerIdentity(alice.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.registerIdentity(bob.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.approveJurisdiction(alice.address, JURISDICTION_TW);
    await ccid.approveJurisdiction(bob.address, JURISDICTION_TW);

    // Mock Chainlink ACE
    const MockChainlinkACE =
      await ethers.getContractFactory("MockChainlinkACE");
    const ace = await MockChainlinkACE.deploy();
    await ace.waitForDeployment();

    // Policy Manager
    const GL1PolicyManager =
      await ethers.getContractFactory("GL1PolicyManager");
    const manager = await GL1PolicyManager.deploy(
      await ace.getAddress(),
      await ccid.getAddress(),
      owner.address, // off-chain rule engine (不會被調用)
    );
    await manager.waitForDeployment();

    // PBM Token (先用 owner 作為臨時 wrapper)
    const PBMToken = await ethers.getContractFactory("PBMToken");
    const pbm = await PBMToken.deploy(owner.address);
    await pbm.waitForDeployment();

    // Policy Wrapper
    const GL1PolicyWrapper =
      await ethers.getContractFactory("GL1PolicyWrapper");
    const wrapper = await GL1PolicyWrapper.deploy(
      JURISDICTION_TW,
      await manager.getAddress(),
      await pbm.getAddress(),
      owner.address,
    );
    await wrapper.waitForDeployment();

    await pbm.updateWrapper(await wrapper.getAddress());
    await manager.setJurisdictionEnabled(JURISDICTION_TW, true);

    // ============ 部署並註冊規則 ============
    const ruleAddrs = {};

    if (ruleNames.includes("WHITELIST")) {
      const Whitelist = await ethers.getContractFactory("WhitelistRule");
      const whitelist = await Whitelist.deploy();
      await whitelist.waitForDeployment();
      // 將 bob 加入白名單，避免 transfer 被擋
      await whitelist.addToWhitelist(bob.address, "Bob Shop", "RETAIL");
      ruleAddrs.WHITELIST = await whitelist.getAddress();
    }
    if (ruleNames.includes("AML")) {
      const AML = await ethers.getContractFactory("AMLThresholdRule");
      const aml = await AML.deploy();
      await aml.waitForDeployment();
      ruleAddrs.AML = await aml.getAddress();
    }
    if (ruleNames.includes("FX")) {
      const FX = await ethers.getContractFactory("FXLimitRule");
      const fx = await FX.deploy(await ccid.getAddress());
      await fx.waitForDeployment();
      ruleAddrs.FX = await fx.getAddress();
    }
    if (ruleNames.includes("COLLATERAL")) {
      const Coll = await ethers.getContractFactory("CollateralRule");
      const coll = await Coll.deploy(15000); // 150% min ratio
      await coll.waitForDeployment();
      ruleAddrs.COLLATERAL = await coll.getAddress();
    }
    if (ruleNames.includes("CASH")) {
      const Cash = await ethers.getContractFactory("CashAdequacyRule");
      const cash = await Cash.deploy();
      await cash.waitForDeployment();
      ruleAddrs.CASH = await cash.getAddress();
    }

    // 在 PolicyManager 註冊規則集，並設為管轄區規則
    const ruleIds = [];
    let priority = 1;
    for (const name of ruleNames) {
      const ruleId = ethers.keccak256(ethers.toUtf8Bytes("RULE_" + name));
      await manager.registerRuleSet(
        ruleId,
        name,
        true, // isOnChain
        ruleAddrs[name],
        priority++,
      );
      ruleIds.push(ruleId);
    }
    if (ruleIds.length > 0) {
      await manager.setJurisdictionRules(JURISDICTION_TW, ruleIds);
    }

    // 部署底層 ERC20，給 alice mint
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const erc20 = await MockERC20.deploy("Cash", "CASH");
    await erc20.waitForDeployment();
    await erc20.mint(alice.address, ethers.parseEther("1000000"));

    // alice approve & wrap (alice 暫時豁免讓 wrap 成功)
    await wrapper.setComplianceExemption(alice.address, true);
    await erc20
      .connect(alice)
      .approve(await wrapper.getAddress(), ethers.MaxUint256);
    const wrapAmount = ethers.parseEther("100000");
    const emptyProof = {
      proofType: ethers.encodeBytes32String("KYC"),
      credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
      issuedAt: Math.floor(Date.now() / 1000) - 3600,
      expiresAt: Math.floor(Date.now() / 1000) + 86400,
      issuer: ethers.ZeroAddress,
      signature: "0x",
    };
    await wrapper
      .connect(alice)
      .wrap(
        AssetType.ERC20,
        await erc20.getAddress(),
        0,
        wrapAmount,
        emptyProof,
      );

    // 取消豁免，讓後續 transfer 走完整合規路徑
    await wrapper.setComplianceExemption(alice.address, false);

    const pbmTokenId = await wrapper.computePBMTokenId(
      AssetType.ERC20,
      await erc20.getAddress(),
      0,
    );

    return { alice, bob, pbm, pbmTokenId };
  }

  // ============================================================
  // L2：PBM safeTransferFrom (規則數=1，WhitelistRule)
  // ============================================================
  it("L2: PBM safeTransferFrom (規則數=1, WhitelistRule)", async function () {
    const { alice, bob, pbm, pbmTokenId } = await deployPBMStack([
      "WHITELIST",
    ]);

    // 預熱：先轉一次，讓 bob 的 ERC1155 balance slot 從 0 → 非 0 一次性發生
    await (
      await pbm
        .connect(alice)
        .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x")
    ).wait();

    const r = await runMeasure(
      "L2",
      "PBM safeTransferFrom (外層動態合規 + 底層靜態合規, rules=1 [WHITELIST])",
      () =>
        pbm
          .connect(alice)
          .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x"),
    );

    console.log(`  [L2] mean=${r.mean}  median=${r.median}  min=${r.min}  max=${r.max}`);
    expect(r.mean).to.be.greaterThan(0);
  });

  // ============================================================
  // L3：PBM safeTransferFrom (規則數=5, 全部規則啟用)
  // ============================================================
  it("L3: PBM safeTransferFrom (規則數=5, 全部規則啟用)", async function () {
    const { alice, bob, pbm, pbmTokenId } = await deployPBMStack([
      "WHITELIST",
      "AML",
      "FX",
      "COLLATERAL",
      "CASH",
    ]);

    // 預熱：先轉一次，讓 storage slots 全部 wake up
    await (
      await pbm
        .connect(alice)
        .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x")
    ).wait();

    const r = await runMeasure(
      "L3",
      "PBM safeTransferFrom (rules=5: WHITELIST, AML, FX, COLLATERAL, CASH)",
      () =>
        pbm
          .connect(alice)
          .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x"),
    );

    console.log(`  [L3] mean=${r.mean}  median=${r.median}  min=${r.min}  max=${r.max}`);
    expect(r.mean).to.be.greaterThan(0);
  });

  // ============================================================
  // 收尾：產生 Markdown 與 CSV
  // ============================================================
  after(function () {
    if (results.length === 0) {
      console.log("\n[gas-benchmark] no results collected");
      return;
    }

    // 排序按照 L0 → L3
    const order = ["L0", "L1", "L2", "L3"];
    const ordered = order
      .map((lab) => results.find((r) => r.label === lab))
      .filter(Boolean);

    const baseline = ordered.find((r) => r.label === "L0");
    const baselineMean = baseline ? baseline.mean : null;

    const rows = ordered.map((r, idx) => {
      const vsL0 =
        baselineMean && baselineMean > 0
          ? ((r.mean / baselineMean - 1) * 100).toFixed(2) + "%"
          : "—";
      const prev = idx > 0 ? ordered[idx - 1] : null;
      const vsPrev =
        prev && prev.mean > 0
          ? ((r.mean / prev.mean - 1) * 100).toFixed(2) + "%"
          : "—";
      return {
        level: r.label,
        description: r.description,
        mean: r.mean,
        median: r.median,
        min: r.min,
        max: r.max,
        vsL0,
        vsPrev,
      };
    });

    // ===== Markdown =====
    const md = [];
    md.push("# Gas Benchmark — 雙層合規架構成本量化\n");
    md.push(
      `Iterations per case: **${ITERATIONS}** (前 ${WARMUP} 次 warm-up 丟棄，後 ${ITERATIONS - WARMUP} 次取統計值)\n`,
    );
    md.push("");
    md.push(
      "| Level | Description | Mean Gas | Median Gas | Min Gas | Max Gas | vs L0 | vs Previous |",
    );
    md.push(
      "|-------|-------------|---------:|-----------:|--------:|--------:|------:|------------:|",
    );
    for (const row of rows) {
      md.push(
        `| ${row.level} | ${row.description} | ${row.mean.toLocaleString()} | ${row.median.toLocaleString()} | ${row.min.toLocaleString()} | ${row.max.toLocaleString()} | ${row.vsL0} | ${row.vsPrev} |`,
      );
    }
    md.push("");
    md.push("## Raw samples (post-warmup)\n");
    for (const r of ordered) {
      md.push(`- **${r.label}**: ${r.raw.join(", ")}`);
    }
    md.push("");

    const mdPath = path.join(__dirname, "..", "gas-benchmark-results.md");
    fs.writeFileSync(mdPath, md.join("\n"), "utf8");

    // ===== CSV =====
    const csv = [];
    csv.push(
      "level,description,mean_gas,median_gas,min_gas,max_gas,vs_L0_pct,vs_prev_pct",
    );
    for (const row of rows) {
      const vsL0Num = row.vsL0.endsWith("%") ? row.vsL0.slice(0, -1) : "";
      const vsPrevNum = row.vsPrev.endsWith("%") ? row.vsPrev.slice(0, -1) : "";
      const desc = `"${row.description.replace(/"/g, '""')}"`;
      csv.push(
        `${row.level},${desc},${row.mean},${row.median},${row.min},${row.max},${vsL0Num},${vsPrevNum}`,
      );
    }
    const csvPath = path.join(__dirname, "..", "gas-benchmark-results.csv");
    fs.writeFileSync(csvPath, csv.join("\n"), "utf8");

    console.log(`\n[gas-benchmark] wrote ${mdPath}`);
    console.log(`[gas-benchmark] wrote ${csvPath}`);
  });
});
