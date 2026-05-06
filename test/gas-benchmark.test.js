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
 * Hardhat EVM 為確定性執行環境：給定相同 calldata 與 storage 狀態，
 * gas 必然相同。每個 case 先做一次預熱轉帳（消除 SSTORE 0→非0 的
 * 一次性 +17k gas 開戶成本），接著測量一次即代表穩態 gas。
 */
describe("Gas Benchmark - 雙層合規架構成本量化", function () {
  this.timeout(600_000);

  const JURISDICTION_TW = ethers.encodeBytes32String("TW");
  const TIER_STANDARD = ethers.keccak256(ethers.toUtf8Bytes("TIER_STANDARD"));
  const IDENTITY_HASH = ethers.keccak256(ethers.toUtf8Bytes("KYC_HASH"));
  const COUNTRY_TW = 158;
  const AssetType = { ERC20: 0, ERC721: 1, ERC1155: 2 };

  const results = [];

  async function measure(label, description, txFn) {
    const tx = await txFn();
    const receipt = await tx.wait();
    const gas = Number(receipt.gasUsed);
    results.push({ label, description, gas });
    return gas;
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

    // 預熱：bob 的 storage slot 從 0 → 非 0 一次性發生，避免影響測量
    await (await erc20.connect(alice).transfer(bob.address, 1n)).wait();

    const gas = await measure(
      "L0",
      "ERC-20 transfer() — 無合規基線",
      () => erc20.connect(alice).transfer(bob.address, 1n),
    );

    console.log(`  [L0] gas = ${gas}`);
    expect(gas).to.be.greaterThan(0);
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

    await security
      .connect(agent)
      .mint(alice.address, ethers.parseEther("1000000"));

    // 預熱
    await (await security.connect(alice).transfer(bob.address, 1n)).wait();

    const gas = await measure(
      "L1",
      "ERC-3643 transfer() — 底層靜態合規（暫停/凍結/未凍結餘額/身份驗證/合規模組）",
      () => security.connect(alice).transfer(bob.address, 1n),
    );

    console.log(`  [L1] gas = ${gas}`);
    expect(gas).to.be.greaterThan(0);
  });

  // ============================================================
  // 共用：部署 PBM 環境並可選地註冊規則
  // ============================================================
  async function deployPBMStack(ruleNames, extraColdRules = 0) {
    const [owner, alice, bob] = await ethers.getSigners();

    const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
    const ccid = await CCIDRegistry.deploy();
    await ccid.waitForDeployment();

    await ccid.registerIdentity(alice.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.registerIdentity(bob.address, IDENTITY_HASH, TIER_STANDARD);
    await ccid.approveJurisdiction(alice.address, JURISDICTION_TW);
    await ccid.approveJurisdiction(bob.address, JURISDICTION_TW);

    const MockChainlinkACE =
      await ethers.getContractFactory("MockChainlinkACE");
    const ace = await MockChainlinkACE.deploy();
    await ace.waitForDeployment();

    const GL1PolicyManager =
      await ethers.getContractFactory("GL1PolicyManager");
    const manager = await GL1PolicyManager.deploy(
      await ace.getAddress(),
      await ccid.getAddress(),
      owner.address,
    );
    await manager.waitForDeployment();

    const PBMToken = await ethers.getContractFactory("PBMToken");
    const pbm = await PBMToken.deploy(owner.address);
    await pbm.waitForDeployment();

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

    const ruleAddrs = {};

    if (ruleNames.includes("WHITELIST")) {
      const Whitelist = await ethers.getContractFactory("WhitelistRule");
      const whitelist = await Whitelist.deploy();
      await whitelist.waitForDeployment();
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
      const coll = await Coll.deploy(15000);
      await coll.waitForDeployment();
      ruleAddrs.COLLATERAL = await coll.getAddress();
    }
    if (ruleNames.includes("CASH")) {
      const Cash = await ethers.getContractFactory("CashAdequacyRule");
      const cash = await Cash.deploy();
      await cash.waitForDeployment();
      ruleAddrs.CASH = await cash.getAddress();
    }

    const ruleIds = [];
    let priority = 1;
    for (const name of ruleNames) {
      const ruleId = ethers.keccak256(ethers.toUtf8Bytes("RULE_" + name));
      await manager.registerRuleSet(
        ruleId,
        name,
        true,
        ruleAddrs[name],
        priority++,
      );
      ruleIds.push(ruleId);
    }

    // 額外註冊 N 條獨立部署的 WhitelistRule（用於 L4 壓力測試 rules=100）
    // 每條規則都是「全新合約地址 + 全新 storage」，模擬生產環境 N 條異質規則
    // 確保每次 evaluate() 都觸發 cold account access 與 cold SLOAD
    if (extraColdRules > 0) {
      const Whitelist = await ethers.getContractFactory("WhitelistRule");
      for (let i = 0; i < extraColdRules; i++) {
        const w = await Whitelist.deploy();
        await w.waitForDeployment();
        await w.addToWhitelist(bob.address, "Bob Shop " + i, "RETAIL");

        const coldId = ethers.keccak256(
          ethers.toUtf8Bytes("RULE_COLD_" + i),
        );
        await manager.registerRuleSet(
          coldId,
          "COLD_" + i,
          true,
          await w.getAddress(),
          priority++,
        );
        ruleIds.push(coldId);
      }
    }

    if (ruleIds.length > 0) {
      await manager.setJurisdictionRules(JURISDICTION_TW, ruleIds);
    }

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    const erc20 = await MockERC20.deploy("Cash", "CASH");
    await erc20.waitForDeployment();
    await erc20.mint(alice.address, ethers.parseEther("1000000"));

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

    // 預熱
    await (
      await pbm
        .connect(alice)
        .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x")
    ).wait();

    const gas = await measure(
      "L2",
      "PBM safeTransferFrom() — 外層動態合規 (rules=1, WHITELIST)",
      () =>
        pbm
          .connect(alice)
          .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x"),
    );

    console.log(`  [L2] gas = ${gas}`);
    expect(gas).to.be.greaterThan(0);
  });

  // ============================================================
  // L3：PBM safeTransferFrom (規則數=5, 全部為獨立部署的 WhitelistRule)
  // ============================================================
  it("L3: PBM safeTransferFrom (規則數=5, 同質規則)", async function () {
    // 1 基礎 WhitelistRule + 4 條獨立部署的 WhitelistRule (共 5)
    const { alice, bob, pbm, pbmTokenId } = await deployPBMStack(
      ["WHITELIST"],
      4,
    );

    // 預熱
    await (
      await pbm
        .connect(alice)
        .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x")
    ).wait();

    const gas = await measure(
      "L3",
      "PBM safeTransferFrom() — 外層動態合規 (rules=5, 同質: 5×WhitelistRule)",
      () =>
        pbm
          .connect(alice)
          .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x"),
    );

    console.log(`  [L3] gas = ${gas}`);
    expect(gas).to.be.greaterThan(0);
  });

  // ============================================================
  // L4：PBM safeTransferFrom (規則數=100, 全部為獨立部署的 WhitelistRule)
  // ============================================================
  it("L4: PBM safeTransferFrom (規則數=100, 同質規則壓力測試)", async function () {
    // 1 基礎 WhitelistRule + 99 條獨立部署的 WhitelistRule (共 100)
    const { alice, bob, pbm, pbmTokenId } = await deployPBMStack(
      ["WHITELIST"],
      99,
    );

    // 預熱
    await (
      await pbm
        .connect(alice)
        .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x")
    ).wait();

    const gas = await measure(
      "L4",
      "PBM safeTransferFrom() — 外層動態合規 (rules=100, 同質: 100×WhitelistRule)",
      () =>
        pbm
          .connect(alice)
          .safeTransferFrom(alice.address, bob.address, pbmTokenId, 1n, "0x"),
    );

    console.log(`  [L4] gas = ${gas}`);
    expect(gas).to.be.greaterThan(0);
  });

  // ============================================================
  // 收尾：產生 Markdown 與 CSV
  // ============================================================
  after(function () {
    if (results.length === 0) {
      console.log("\n[gas-benchmark] no results collected");
      return;
    }

    const order = ["L0", "L1", "L2", "L3", "L4"];
    const ordered = order
      .map((lab) => results.find((r) => r.label === lab))
      .filter(Boolean);

    const baseline = ordered.find((r) => r.label === "L0");
    const baselineGas = baseline ? baseline.gas : null;

    // ETH 成本估算：採用 5 gwei（反映 post-Dencun 升級後 L1 平均水準）
    const GAS_PRICE_GWEI = 5;
    // USD 換算採用 ETH = 2,355 USD 假設
    const ETH_PRICE_USD = 2355;
    const ethCost = (gas) => (gas * GAS_PRICE_GWEI) / 1e9;
    const usdCost = (gas) => ethCost(gas) * ETH_PRICE_USD;

    const rows = ordered.map((r, idx) => {
      const vsL0 =
        baselineGas && baselineGas > 0
          ? ((r.gas / baselineGas - 1) * 100).toFixed(2) + "%"
          : "—";
      const prev = idx > 0 ? ordered[idx - 1] : null;
      const vsPrev =
        prev && prev.gas > 0
          ? ((r.gas / prev.gas - 1) * 100).toFixed(2) + "%"
          : "—";
      return {
        level: r.label,
        description: r.description,
        gas: r.gas,
        eth: ethCost(r.gas).toFixed(7),
        usd: usdCost(r.gas).toFixed(4),
        vsL0,
        vsPrev,
      };
    });

    // ===== Markdown =====
    const md = [];
    md.push("# Gas Benchmark — 雙層合規架構成本量化\n");
    md.push("## 量測說明\n");
    md.push(
      "- **量測環境**：Hardhat EVM（確定性執行環境）。給定相同 calldata 與 storage 狀態，gas 必然相同，故每個 case 先做一次預熱轉帳消除 SSTORE 0→非0 開戶成本，後測一次即為穩態 gas。",
    );
    md.push(
      "- **轉帳函數選擇**：L0/L1 使用 `transfer(to, amount)`（ERC-20 / ERC-3643 規範的主要轉帳入口）；L2/L3/L4 使用 `safeTransferFrom(from, to, id, amount, data)`（ERC-1155 規範本身未定義 `transfer()`，`safeTransferFrom` 為 ERC-1155 規範的主要轉帳入口）。兩者皆為各自代幣標準的最低成本轉帳路徑，符合公平比較原則。",
    );
    md.push(
      "- **架構分層**：L1 量測**底層靜態合規**（ERC-3643 身份/凍結/暫停）；L2/L3/L4 量測**外層動態合規**（PBM Wrapper → PolicyManager → Rules）。雙層在實務上於不同時機觸發——靜態合規於 wrap/unwrap 邊界攤銷，動態合規於每筆 PBM 轉帳付費。",
    );
    md.push(
      "- **同質規則設計**：L2/L3/L4 均使用同一種規則類型（`WhitelistRule`），但每條規則都是**獨立部署**的合約實例（不同地址、獨立 storage）。每次 `evaluate()` 在單筆 tx 內均為首次存取對應合約與 slot，皆觸發 EIP-2929 cold access。此設計排除「不同規則 evaluate() 內部成本不同」的變因，使邊際成本恆定，便於驗證架構的線性可擴展性。",
    );
    md.push("");
    md.push(`> ETH 成本採用 ${GAS_PRICE_GWEI} gwei（反映 post-Dencun 升級後 Ethereum L1 平均 gas price 水準）；USD 換算採用 ETH = $${ETH_PRICE_USD.toLocaleString()} 假設。`);
    md.push("");
    md.push(`| Level | Description | Gas | ETH @ ${GAS_PRICE_GWEI} gwei | USD @ $${ETH_PRICE_USD}/ETH | vs L0 | vs Previous |`);
    md.push("|-------|-------------|----:|--------------:|----------------:|------:|------------:|");
    for (const row of rows) {
      md.push(
        `| ${row.level} | ${row.description} | ${row.gas.toLocaleString()} | ${row.eth} | $${row.usd} | ${row.vsL0} | ${row.vsPrev} |`,
      );
    }
    md.push("");

    const mdPath = path.join(__dirname, "..", "gas-benchmark-results.md");
    fs.writeFileSync(mdPath, md.join("\n"), "utf8");

    // ===== CSV =====
    const csv = [];
    csv.push(`level,description,gas,eth_at_${GAS_PRICE_GWEI}gwei,usd_at_${ETH_PRICE_USD}usd_per_eth,vs_L0_pct,vs_prev_pct`);
    for (const row of rows) {
      const vsL0Num = row.vsL0.endsWith("%") ? row.vsL0.slice(0, -1) : "";
      const vsPrevNum = row.vsPrev.endsWith("%") ? row.vsPrev.slice(0, -1) : "";
      const desc = `"${row.description.replace(/"/g, '""')}"`;
      csv.push(
        `${row.level},${desc},${row.gas},${row.eth},${row.usd},${vsL0Num},${vsPrevNum}`,
      );
    }
    const csvPath = path.join(__dirname, "..", "gas-benchmark-results.csv");
    fs.writeFileSync(csvPath, csv.join("\n"), "utf8");

    console.log(`\n[gas-benchmark] wrote ${mdPath}`);
    console.log(`[gas-benchmark] wrote ${csvPath}`);
  });
});
