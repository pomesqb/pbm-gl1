const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ERC-3643 Security Token", function () {
  let ccidRegistry;
  let claimTopicsRegistry;
  let trustedIssuersRegistry;
  let identityRegistry;
  let complianceModule;
  let securityToken;
  let policyManager;
  let policyWrapper;
  let pbmToken;
  let mockERC20; // 用於 Repo 場景的現金

  let owner;
  let agent;
  let investor1;
  let investor2;
  let regulator;

  const JURISDICTION_TW = ethers.encodeBytes32String("TW");
  const TIER_STANDARD = ethers.keccak256(ethers.toUtf8Bytes("TIER_STANDARD"));
  const IDENTITY_HASH = ethers.keccak256(ethers.toUtf8Bytes("KYC_HASH"));
  const COUNTRY_TW = 158; // ISO-3166 Taiwan

  // Claim topics
  const CLAIM_TOPIC_KYC = 1;
  const CLAIM_TOPIC_AML = 2;

  // PBM Asset types
  const AssetType = { ERC20: 0, ERC721: 1, ERC1155: 2 };

  beforeEach(async function () {
    [owner, agent, investor1, investor2, regulator] = await ethers.getSigners();

    // ========== 部署 ERC-3643 生態系統 ==========

    // 1. 部署 CCIDRegistry（現有架構）
    const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
    ccidRegistry = await CCIDRegistry.deploy();
    await ccidRegistry.waitForDeployment();

    // 2. 部署 ClaimTopicsRegistry
    const ClaimTopicsRegistry = await ethers.getContractFactory(
      "ClaimTopicsRegistry",
    );
    claimTopicsRegistry = await ClaimTopicsRegistry.deploy();
    await claimTopicsRegistry.waitForDeployment();

    // 3. 部署 TrustedIssuersRegistry
    const TrustedIssuersRegistry = await ethers.getContractFactory(
      "TrustedIssuersRegistry",
    );
    trustedIssuersRegistry = await TrustedIssuersRegistry.deploy();
    await trustedIssuersRegistry.waitForDeployment();

    // 4. 部署 IdentityRegistry（橋接 CCIDRegistry）
    const IdentityRegistry =
      await ethers.getContractFactory("IdentityRegistry");
    identityRegistry = await IdentityRegistry.deploy(
      await trustedIssuersRegistry.getAddress(),
      await claimTopicsRegistry.getAddress(),
      await ccidRegistry.getAddress(),
    );
    await identityRegistry.waitForDeployment();

    // 5. 部署 ComplianceModule
    const ComplianceModule =
      await ethers.getContractFactory("ComplianceModule");
    complianceModule = await ComplianceModule.deploy(
      await identityRegistry.getAddress(),
    );
    await complianceModule.waitForDeployment();

    // 6. 部署 ERC3643Token
    const ERC3643Token = await ethers.getContractFactory("ERC3643Token");
    securityToken = await ERC3643Token.deploy(
      "GL1 Security Bond",
      "GL1BOND",
      await identityRegistry.getAddress(),
      await complianceModule.getAddress(),
    );
    await securityToken.waitForDeployment();

    // 7. 綁定代幣到 ComplianceModule
    await complianceModule.bindToken(await securityToken.getAddress());

    // 8. 設定 Agent
    const AGENT_ROLE = ethers.keccak256(ethers.toUtf8Bytes("AGENT_ROLE"));
    await securityToken.grantRole(AGENT_ROLE, agent.address);

    // ========== 設定投資者身份 ==========

    // 在 CCIDRegistry 註冊 KYC
    await ccidRegistry.registerIdentity(
      investor1.address,
      IDENTITY_HASH,
      TIER_STANDARD,
    );
    await ccidRegistry.registerIdentity(
      investor2.address,
      IDENTITY_HASH,
      TIER_STANDARD,
    );

    // 在 IdentityRegistry 註冊
    await identityRegistry.registerIdentity(
      investor1.address,
      investor1.address,
      COUNTRY_TW,
    );
    await identityRegistry.registerIdentity(
      investor2.address,
      investor2.address,
      COUNTRY_TW,
    );
  });

  // ============ ERC3643Token 基本功能 ============

  describe("ERC3643Token 基本功能", function () {
    it("應該正確部署代幣", async function () {
      expect(await securityToken.name()).to.equal("GL1 Security Bond");
      expect(await securityToken.symbol()).to.equal("GL1BOND");
      expect(await securityToken.version()).to.equal("1.0.0");
    });

    it("Agent 應該能夠 mint 給已驗證投資者", async function () {
      const amount = ethers.parseEther("1000");
      await securityToken.connect(agent).mint(investor1.address, amount);
      expect(await securityToken.balanceOf(investor1.address)).to.equal(amount);
    });

    it("mint 給未驗證地址應該失敗", async function () {
      const amount = ethers.parseEther("1000");
      await expect(
        securityToken.connect(agent).mint(regulator.address, amount),
      ).to.be.revertedWith("ERC-3643: Invalid identity");
    });

    it("Agent 應該能夠 burn 代幣", async function () {
      const amount = ethers.parseEther("1000");
      await securityToken.connect(agent).mint(investor1.address, amount);
      await securityToken
        .connect(agent)
        .burn(investor1.address, ethers.parseEther("500"));
      expect(await securityToken.balanceOf(investor1.address)).to.equal(
        ethers.parseEther("500"),
      );
    });
  });

  // ============ 合規轉帳 ============

  describe("合規轉帳", function () {
    beforeEach(async function () {
      // Mint 代幣給 investor1
      await securityToken
        .connect(agent)
        .mint(investor1.address, ethers.parseEther("1000"));
    });

    it("已驗證投資者之間應該能夠轉帳", async function () {
      const amount = ethers.parseEther("100");
      await securityToken
        .connect(investor1)
        .transfer(investor2.address, amount);
      expect(await securityToken.balanceOf(investor2.address)).to.equal(amount);
    });

    it("轉帳給未驗證地址應該失敗", async function () {
      const amount = ethers.parseEther("100");
      await expect(
        securityToken.connect(investor1).transfer(regulator.address, amount),
      ).to.be.revertedWith("ERC-3643: Invalid identity");
    });
  });

  // ============ 凍結功能 ============

  describe("凍結功能", function () {
    beforeEach(async function () {
      await securityToken
        .connect(agent)
        .mint(investor1.address, ethers.parseEther("1000"));
    });

    it("Agent 應該能夠凍結整個錢包", async function () {
      await securityToken
        .connect(agent)
        .setAddressFrozen(investor1.address, true);
      expect(await securityToken.isFrozen(investor1.address)).to.be.true;

      // 凍結後轉帳應該失敗
      await expect(
        securityToken
          .connect(investor1)
          .transfer(investor2.address, ethers.parseEther("100")),
      ).to.be.revertedWith("ERC-3643: Frozen wallet");
    });

    it("Agent 應該能夠部分凍結代幣", async function () {
      await securityToken
        .connect(agent)
        .freezePartialTokens(investor1.address, ethers.parseEther("800"));
      expect(await securityToken.getFrozenTokens(investor1.address)).to.equal(
        ethers.parseEther("800"),
      );

      // 轉帳超過未凍結餘額應該失敗
      await expect(
        securityToken
          .connect(investor1)
          .transfer(investor2.address, ethers.parseEther("300")),
      ).to.be.revertedWith("ERC-3643: Insufficient unfrozen balance");

      // 轉帳未凍結餘額應該成功
      await securityToken
        .connect(investor1)
        .transfer(investor2.address, ethers.parseEther("200"));
      expect(await securityToken.balanceOf(investor2.address)).to.equal(
        ethers.parseEther("200"),
      );
    });

    it("Agent 應該能夠解凍部分代幣", async function () {
      await securityToken
        .connect(agent)
        .freezePartialTokens(investor1.address, ethers.parseEther("800"));
      await securityToken
        .connect(agent)
        .unfreezePartialTokens(investor1.address, ethers.parseEther("500"));
      expect(await securityToken.getFrozenTokens(investor1.address)).to.equal(
        ethers.parseEther("300"),
      );
    });
  });

  // ============ 強制轉帳 ============

  describe("強制轉帳", function () {
    it("Agent 應該能夠強制轉帳", async function () {
      await securityToken
        .connect(agent)
        .mint(investor1.address, ethers.parseEther("1000"));

      await securityToken
        .connect(agent)
        .forcedTransfer(
          investor1.address,
          investor2.address,
          ethers.parseEther("500"),
        );

      expect(await securityToken.balanceOf(investor1.address)).to.equal(
        ethers.parseEther("500"),
      );
      expect(await securityToken.balanceOf(investor2.address)).to.equal(
        ethers.parseEther("500"),
      );
    });
  });

  // ============ 暫停功能 ============

  describe("暫停功能", function () {
    it("暫停後所有轉帳應該被拒絕", async function () {
      await securityToken
        .connect(agent)
        .mint(investor1.address, ethers.parseEther("1000"));
      await securityToken.connect(agent).pause();

      await expect(
        securityToken
          .connect(investor1)
          .transfer(investor2.address, ethers.parseEther("100")),
      ).to.be.revertedWith("ERC-3643: Token is paused");
    });

    it("恢復後應該能正常轉帳", async function () {
      await securityToken
        .connect(agent)
        .mint(investor1.address, ethers.parseEther("1000"));
      await securityToken.connect(agent).pause();
      await securityToken.connect(agent).unpause();

      await securityToken
        .connect(investor1)
        .transfer(investor2.address, ethers.parseEther("100"));
      expect(await securityToken.balanceOf(investor2.address)).to.equal(
        ethers.parseEther("100"),
      );
    });
  });

  // ============ 錢包回復 ============

  describe("錢包回復", function () {
    it("Agent 應該能夠回復錢包代幣", async function () {
      await securityToken
        .connect(agent)
        .mint(investor1.address, ethers.parseEther("1000"));

      await securityToken.connect(agent).recoveryAddress(
        investor1.address,
        investor2.address,
        investor2.address, // investorOnchainID
      );

      expect(await securityToken.balanceOf(investor1.address)).to.equal(0);
      expect(await securityToken.balanceOf(investor2.address)).to.equal(
        ethers.parseEther("1000"),
      );
    });
  });

  // ============ Identity Registry ============

  describe("Identity Registry 整合", function () {
    it("isVerified 應該檢查 CCIDRegistry KYC 狀態", async function () {
      expect(await identityRegistry.isVerified(investor1.address)).to.be.true;
    });

    it("未註冊地址應該無法通過 isVerified", async function () {
      expect(await identityRegistry.isVerified(regulator.address)).to.be.false;
    });

    it("應該能查詢投資者國家代碼", async function () {
      expect(
        await identityRegistry.investorCountry(investor1.address),
      ).to.equal(COUNTRY_TW);
    });
  });

  // ============ Compliance Module ============

  describe("Compliance Module 整合", function () {
    it("設定每人持有量上限後超額轉帳應該失敗", async function () {
      // 設定每人最大持有量為 500
      await complianceModule.setMaxTokensPerHolder(ethers.parseEther("500"));

      await securityToken
        .connect(agent)
        .mint(investor1.address, ethers.parseEther("1000"));

      // 轉帳 600 給 investor2 應該失敗（超過 500 上限）
      await expect(
        securityToken
          .connect(investor1)
          .transfer(investor2.address, ethers.parseEther("600")),
      ).to.be.revertedWith("ERC-3643: Compliance failure");

      // 轉帳 400 應該成功
      await securityToken
        .connect(investor1)
        .transfer(investor2.address, ethers.parseEther("400"));
      expect(await securityToken.balanceOf(investor2.address)).to.equal(
        ethers.parseEther("400"),
      );
    });
  });

  // ============ PBM Wrap ERC-3643（雙層架構） ============

  describe("PBM Wrap ERC-3643 — 雙層架構", function () {
    const emptyProof = {
      proofType: ethers.encodeBytes32String("KYC"),
      credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
      issuedAt: Math.floor(Date.now() / 1000) - 3600,
      expiresAt: Math.floor(Date.now() / 1000) + 86400,
      issuer: ethers.ZeroAddress,
      signature: "0x",
    };

    beforeEach(async function () {
      // 部署 PBM 生態系統
      const GL1PolicyManager =
        await ethers.getContractFactory("GL1PolicyManager");
      policyManager = await GL1PolicyManager.deploy(
        owner.address,
        await ccidRegistry.getAddress(),
        owner.address,
      );
      await policyManager.waitForDeployment();

      const PBMToken = await ethers.getContractFactory("PBMToken");
      pbmToken = await PBMToken.deploy(owner.address);
      await pbmToken.waitForDeployment();

      const GL1PolicyWrapper =
        await ethers.getContractFactory("GL1PolicyWrapper");
      policyWrapper = await GL1PolicyWrapper.deploy(
        JURISDICTION_TW,
        await policyManager.getAddress(),
        await pbmToken.getAddress(),
      );
      await policyWrapper.waitForDeployment();

      await pbmToken.updateWrapper(await policyWrapper.getAddress());
      await policyManager.setJurisdictionEnabled(JURISDICTION_TW, true);

      // 豁免合規檢查以便測試 wrap/unwrap
      await policyWrapper.setComplianceExemption(investor1.address, true);
      await policyWrapper.setComplianceExemption(investor2.address, true);

      // 部署 Mock ERC20 作為現金
      const MockERC20 = await ethers.getContractFactory("MockERC20");
      mockERC20 = await MockERC20.deploy("Mock USDC", "MUSDC");
      await mockERC20.waitForDeployment();
      await mockERC20.mint(investor2.address, ethers.parseEther("10000"));

      // Mint ERC-3643 證券給 investor1（Borrower）
      await securityToken
        .connect(agent)
        .mint(investor1.address, ethers.parseEther("1000"));
    });

    it("PBM 應該能夠 wrap ERC-3643 證券代幣", async function () {
      const bondAmount = ethers.parseEther("500");

      // investor1 approve PBM Wrapper
      await securityToken
        .connect(investor1)
        .approve(await policyWrapper.getAddress(), bondAmount);

      // 需要先在 IdentityRegistry 註冊 PolicyWrapper 地址以通過合規
      // PolicyWrapper 作為接收方需要通過 ERC-3643 的 Identity 驗證
      await ccidRegistry.registerIdentity(
        await policyWrapper.getAddress(),
        IDENTITY_HASH,
        TIER_STANDARD,
      );
      await identityRegistry.registerIdentity(
        await policyWrapper.getAddress(),
        await policyWrapper.getAddress(),
        COUNTRY_TW,
      );

      // Wrap ERC-3643 證券進 PBM
      await policyWrapper
        .connect(investor1)
        .wrap(
          AssetType.ERC20,
          await securityToken.getAddress(),
          0,
          bondAmount,
          emptyProof,
        );

      // 計算 PBM tokenId
      const bondPBMId = await policyWrapper.computePBMTokenId(
        AssetType.ERC20,
        await securityToken.getAddress(),
        0,
      );

      // 驗證 PBM 餘額
      expect(await pbmToken.balanceOf(investor1.address, bondPBMId)).to.equal(
        bondAmount,
      );

      // 驗證 ERC-3643 代幣已轉入 Wrapper
      expect(
        await securityToken.balanceOf(await policyWrapper.getAddress()),
      ).to.equal(bondAmount);
    });

    it("Repo 場景：Borrower wrap 證券 + Lender wrap 現金 → 交換 → Unwrap", async function () {
      const bondAmount = ethers.parseEther("500");
      const cashAmount = ethers.parseEther("5000");

      // ===== 1. 註冊 PolicyWrapper 到 ERC-3643 IdentityRegistry =====
      await ccidRegistry.registerIdentity(
        await policyWrapper.getAddress(),
        IDENTITY_HASH,
        TIER_STANDARD,
      );
      await identityRegistry.registerIdentity(
        await policyWrapper.getAddress(),
        await policyWrapper.getAddress(),
        COUNTRY_TW,
      );

      // ===== 2. Borrower (investor1) wrap 證券 =====
      await securityToken
        .connect(investor1)
        .approve(await policyWrapper.getAddress(), bondAmount);
      await policyWrapper
        .connect(investor1)
        .wrap(
          AssetType.ERC20,
          await securityToken.getAddress(),
          0,
          bondAmount,
          emptyProof,
        );

      // ===== 3. Lender (investor2) wrap 現金 =====
      await mockERC20
        .connect(investor2)
        .approve(await policyWrapper.getAddress(), cashAmount);
      await policyWrapper
        .connect(investor2)
        .wrap(
          AssetType.ERC20,
          await mockERC20.getAddress(),
          0,
          cashAmount,
          emptyProof,
        );

      // ===== 4. 計算 PBM tokenIds =====
      const bondPBMId = await policyWrapper.computePBMTokenId(
        AssetType.ERC20,
        await securityToken.getAddress(),
        0,
      );
      const cashPBMId = await policyWrapper.computePBMTokenId(
        AssetType.ERC20,
        await mockERC20.getAddress(),
        0,
      );

      // ===== 5. 交換 PBM（模擬 Repo 開始） =====
      await pbmToken
        .connect(investor1)
        .safeTransferFrom(
          investor1.address,
          investor2.address,
          bondPBMId,
          bondAmount,
          "0x",
        );
      await pbmToken
        .connect(investor2)
        .safeTransferFrom(
          investor2.address,
          investor1.address,
          cashPBMId,
          cashAmount,
          "0x",
        );

      // 驗證交換結果
      expect(await pbmToken.balanceOf(investor2.address, bondPBMId)).to.equal(
        bondAmount,
      );
      expect(await pbmToken.balanceOf(investor1.address, cashPBMId)).to.equal(
        cashAmount,
      );

      // ===== 6. Unwrap 取回資產（模擬 Repo 結束） =====
      await policyWrapper
        .connect(investor1)
        .unwrap(cashPBMId, cashAmount, investor1.address);
      expect(await mockERC20.balanceOf(investor1.address)).to.equal(cashAmount);

      // 需要先在 ERC-3643 IdentityRegistry 註冊 investor2
      // (已在 beforeEach 完成)
      await policyWrapper
        .connect(investor2)
        .unwrap(bondPBMId, bondAmount, investor2.address);
      expect(await securityToken.balanceOf(investor2.address)).to.equal(
        bondAmount,
      );
    });
  });

  // ============ Claim Registries ============

  describe("Claim Registries", function () {
    it("應該能夠管理 Claim Topics", async function () {
      await claimTopicsRegistry.addClaimTopic(CLAIM_TOPIC_KYC);
      await claimTopicsRegistry.addClaimTopic(CLAIM_TOPIC_AML);

      const topics = await claimTopicsRegistry.getClaimTopics();
      expect(topics.length).to.equal(2);
      expect(topics[0]).to.equal(CLAIM_TOPIC_KYC);
      expect(topics[1]).to.equal(CLAIM_TOPIC_AML);

      await claimTopicsRegistry.removeClaimTopic(CLAIM_TOPIC_KYC);
      const updatedTopics = await claimTopicsRegistry.getClaimTopics();
      expect(updatedTopics.length).to.equal(1);
    });

    it("應該能夠管理 Trusted Issuers", async function () {
      await trustedIssuersRegistry.addTrustedIssuer(agent.address, [
        CLAIM_TOPIC_KYC,
        CLAIM_TOPIC_AML,
      ]);

      expect(await trustedIssuersRegistry.isTrustedIssuer(agent.address)).to.be
        .true;
      expect(
        await trustedIssuersRegistry.hasClaimTopic(
          agent.address,
          CLAIM_TOPIC_KYC,
        ),
      ).to.be.true;

      const issuers =
        await trustedIssuersRegistry.getTrustedIssuersForClaimTopic(
          CLAIM_TOPIC_KYC,
        );
      expect(issuers.length).to.equal(1);
      expect(issuers[0]).to.equal(agent.address);
    });
  });
});
