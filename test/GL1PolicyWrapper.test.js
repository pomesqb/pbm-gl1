const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GL1 Programmable Compliance Toolkit", function () {
    let ccidRegistry;
    let policyManager;
    let policyWrapper;
    let token;
    let aceIntegration;

    let owner;
    let user1;
    let user2;
    let regulator;

    const JURISDICTION_TW = ethers.encodeBytes32String("TW");
    const TIER_STANDARD = ethers.keccak256(ethers.toUtf8Bytes("TIER_STANDARD"));

    beforeEach(async function () {
        [owner, user1, user2, regulator] = await ethers.getSigners();

        // 部署 CCIDRegistry
        const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
        ccidRegistry = await CCIDRegistry.deploy();
        await ccidRegistry.waitForDeployment();

        // 部署 GL1PolicyManager
        const GL1PolicyManager = await ethers.getContractFactory("GL1PolicyManager");
        policyManager = await GL1PolicyManager.deploy(
            owner.address, // Mock Chainlink ACE
            await ccidRegistry.getAddress(),
            owner.address  // Mock off-chain rule engine
        );
        await policyManager.waitForDeployment();

        // 部署 GL1PolicyWrapper
        const GL1PolicyWrapper = await ethers.getContractFactory("GL1PolicyWrapper");
        policyWrapper = await GL1PolicyWrapper.deploy(
            JURISDICTION_TW,
            await policyManager.getAddress()
        );
        await policyWrapper.waitForDeployment();

        // 部署 GL1CompliantToken
        const GL1CompliantToken = await ethers.getContractFactory("GL1CompliantToken");
        token = await GL1CompliantToken.deploy(
            "GL1 Security Token",
            "GL1ST",
            JURISDICTION_TW
        );
        await token.waitForDeployment();

        // 部署 ChainlinkACEIntegration (使用零地址跳過外部調用)
        const ChainlinkACEIntegration = await ethers.getContractFactory("ChainlinkACEIntegration");
        aceIntegration = await ChainlinkACEIntegration.deploy(ethers.ZeroAddress);
        await aceIntegration.waitForDeployment();

        // 配置合約
        await token.setPolicyWrapper(JURISDICTION_TW, await policyWrapper.getAddress());
        await policyManager.setJurisdictionEnabled(JURISDICTION_TW, true);
    });

    describe("CCIDRegistry", function () {
        it("應該能夠註冊身份", async function () {
            const identityHash = ethers.keccak256(ethers.toUtf8Bytes("user1_identity"));

            await ccidRegistry.registerIdentity(
                user1.address,
                identityHash,
                TIER_STANDARD
            );

            const [hash, timestamp, tier, isActive] = await ccidRegistry.getIdentity(user1.address);
            expect(hash).to.equal(identityHash);
            expect(isActive).to.be.true;
        });

        it("應該能夠核准管轄區", async function () {
            const identityHash = ethers.keccak256(ethers.toUtf8Bytes("user1_identity"));

            await ccidRegistry.registerIdentity(user1.address, identityHash, TIER_STANDARD);
            await ccidRegistry.approveJurisdiction(user1.address, JURISDICTION_TW);

            const isValid = await ccidRegistry.verifyCredential(user1.address, JURISDICTION_TW);
            expect(isValid).to.be.true;
        });

        it("未核准的管轄區應該驗證失敗", async function () {
            const identityHash = ethers.keccak256(ethers.toUtf8Bytes("user1_identity"));
            const JURISDICTION_US = ethers.encodeBytes32String("US");

            await ccidRegistry.registerIdentity(user1.address, identityHash, TIER_STANDARD);
            await ccidRegistry.approveJurisdiction(user1.address, JURISDICTION_TW);

            const isValid = await ccidRegistry.verifyCredential(user1.address, JURISDICTION_US);
            expect(isValid).to.be.false;
        });
    });

    describe("GL1PolicyWrapper", function () {
        it("應該正確設置管轄區代碼", async function () {
            const jurisdictionCode = await policyWrapper.jurisdictionCode();
            expect(jurisdictionCode).to.equal(JURISDICTION_TW);
        });

        it("應該授予正確的角色", async function () {
            const POLICY_ADMIN_ROLE = ethers.keccak256(ethers.toUtf8Bytes("POLICY_ADMIN_ROLE"));
            const hasRole = await policyWrapper.hasRole(POLICY_ADMIN_ROLE, owner.address);
            expect(hasRole).to.be.true;
        });
    });

    describe("GL1PolicyManager", function () {
        it("應該能夠註冊規則集", async function () {
            const ruleSetId = ethers.keccak256(ethers.toUtf8Bytes("KYC_RULE"));

            await policyManager.registerRuleSet(
                ruleSetId,
                "KYC",
                true,
                owner.address,
                1
            );

            const ruleSet = await policyManager.ruleSets(ruleSetId);
            expect(ruleSet.ruleType).to.equal("KYC");
            expect(ruleSet.isOnChain).to.be.true;
            expect(ruleSet.isActive).to.be.true;
        });

        it("應該能夠配置管轄區規則", async function () {
            const ruleSetId = ethers.keccak256(ethers.toUtf8Bytes("AML_RULE"));

            await policyManager.registerRuleSet(
                ruleSetId,
                "AML",
                true,
                owner.address,
                1
            );

            await policyManager.setJurisdictionRules(JURISDICTION_TW, [ruleSetId]);

            const ruleCount = await policyManager.getJurisdictionRuleCount(JURISDICTION_TW);
            expect(ruleCount).to.equal(1);
        });
    });

    describe("GL1CompliantToken", function () {
        beforeEach(async function () {
            // 鑄造一些代幣給 owner
            await token.mint(owner.address, ethers.parseEther("1000"));
        });

        it("應該正確設置代幣名稱和符號", async function () {
            expect(await token.name()).to.equal("GL1 Security Token");
            expect(await token.symbol()).to.equal("GL1ST");
        });

        it("豁免帳戶應該能夠轉帳", async function () {
            // Owner 預設是豁免的
            await token.transfer(user1.address, ethers.parseEther("100"));
            expect(await token.balanceOf(user1.address)).to.equal(ethers.parseEther("100"));
        });

        it("應該能夠設置合規豁免", async function () {
            await token.setComplianceExemption(user1.address, true);
            const isExempt = await token.complianceExempt(user1.address);
            expect(isExempt).to.be.true;
        });

        it("應該能夠暫停和恢復合約", async function () {
            await token.pause();
            expect(await token.paused()).to.be.true;

            await token.unpause();
            expect(await token.paused()).to.be.false;
        });
    });

    describe("ChainlinkACEIntegration", function () {
        it("應該能夠定義政策", async function () {
            const tx = await aceIntegration.definePolicy(
                "Taiwan Compliance Policy",
                [user1.address, user2.address],
                ethers.parseEther("1000000"),
                [JURISDICTION_TW]
            );

            const receipt = await tx.wait();

            // 檢查是否發出事件
            const events = receipt.logs;
            expect(events.length).to.be.greaterThan(0);
        });

        it("應該能夠跨鏈驗證合規", async function () {
            // 先定義政策
            await aceIntegration.definePolicy(
                "Cross Chain Policy",
                [user1.address],
                ethers.parseEther("1000000"),
                [JURISDICTION_TW, ethers.encodeBytes32String("SG")]
            );

            // 驗證跨鏈合規 (this emits an event, check event instead of return)
            const tx = await aceIntegration.verifyComplianceAcrossChains(
                user1.address,
                JURISDICTION_TW,
                ethers.encodeBytes32String("SG")
            );

            // Just verify the transaction succeeded
            const receipt = await tx.wait();
            expect(receipt.status).to.equal(1);
        });
    });

    describe("Integration Tests", function () {
        it("完整的合規流程測試", async function () {
            const identityHash = ethers.keccak256(ethers.toUtf8Bytes("user1_full_kyc"));

            // 1. 在 CCID Registry 註冊身份
            await ccidRegistry.registerIdentity(user1.address, identityHash, TIER_STANDARD);
            await ccidRegistry.approveJurisdiction(user1.address, JURISDICTION_TW);

            // 2. 驗證身份
            const isValid = await ccidRegistry.verifyCredential(user1.address, JURISDICTION_TW);
            expect(isValid).to.be.true;

            // 3. 鑄造代幣並設置豁免（測試用）
            await token.mint(owner.address, ethers.parseEther("1000"));
            await token.setComplianceExemption(user1.address, true);

            // 4. 執行轉帳
            await token.transfer(user1.address, ethers.parseEther("100"));
            expect(await token.balanceOf(user1.address)).to.equal(ethers.parseEther("100"));
        });
    });
});
