const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("GL1 PBM Policy Wrapper", function () {
    let ccidRegistry;
    let policyManager;
    let policyWrapper;
    let pbmToken;
    let mockERC20;
    let mockERC721;
    let mockERC1155;

    let owner;
    let lender;
    let borrower;
    let regulator;

    const JURISDICTION_TW = ethers.encodeBytes32String("TW");
    const TIER_STANDARD = ethers.keccak256(ethers.toUtf8Bytes("TIER_STANDARD"));

    // Asset types
    const AssetType = {
        ERC20: 0,
        ERC721: 1,
        ERC1155: 2
    };

    beforeEach(async function () {
        [owner, lender, borrower, regulator] = await ethers.getSigners();

        // 部署 Mock ERC20
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        mockERC20 = await MockERC20.deploy("Mock USDC", "MUSDC");
        await mockERC20.waitForDeployment();

        // 部署 Mock ERC721
        const MockERC721 = await ethers.getContractFactory("MockERC721");
        mockERC721 = await MockERC721.deploy("Mock NFT", "MNFT");
        await mockERC721.waitForDeployment();

        // 部署 Mock ERC1155
        const MockERC1155 = await ethers.getContractFactory("MockERC1155");
        mockERC1155 = await MockERC1155.deploy();
        await mockERC1155.waitForDeployment();

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

        // 先部署一個臨時 wrapper 地址來創建 PBMToken
        // 然後再部署真正的 wrapper
        const tempWrapper = owner.address;
        
        // 部署 PBMToken
        const PBMToken = await ethers.getContractFactory("PBMToken");
        pbmToken = await PBMToken.deploy(tempWrapper);
        await pbmToken.waitForDeployment();

        // 部署 GL1PolicyWrapper
        const GL1PolicyWrapper = await ethers.getContractFactory("GL1PolicyWrapper");
        policyWrapper = await GL1PolicyWrapper.deploy(
            JURISDICTION_TW,
            await policyManager.getAddress(),
            await pbmToken.getAddress()
        );
        await policyWrapper.waitForDeployment();

        // 更新 PBMToken 的 wrapper
        await pbmToken.updateWrapper(await policyWrapper.getAddress());

        // 配置管轄區
        await policyManager.setJurisdictionEnabled(JURISDICTION_TW, true);

        // 鑄造測試代幣
        await mockERC20.mint(lender.address, ethers.parseEther("10000"));
        await mockERC20.mint(borrower.address, ethers.parseEther("10000"));
        await mockERC721.mint(borrower.address, 1);
        await mockERC1155.mint(borrower.address, 100, 1000);
    });

    describe("PBMToken", function () {
        it("應該正確部署 PBMToken", async function () {
            expect(await pbmToken.wrapper()).to.equal(await policyWrapper.getAddress());
        });

        it("只有 wrapper 能夠 mint", async function () {
            // 應該失敗
            await expect(
                pbmToken.mint(lender.address, 1, 100)
            ).to.be.reverted;
        });
    });

    describe("Wrap ERC20", function () {
        const emptyProof = {
            proofType: ethers.encodeBytes32String("KYC"),
            credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
            issuedAt: Math.floor(Date.now() / 1000) - 3600,
            expiresAt: Math.floor(Date.now() / 1000) + 86400,
            issuer: ethers.ZeroAddress,
            signature: "0x"
        };

        beforeEach(async function () {
            // 豁免 lender 的合規檢查以便測試
            await policyWrapper.setComplianceExemption(lender.address, true);
        });

        it("應該能夠包裝 ERC20", async function () {
            const amount = ethers.parseEther("1000");
            
            // Approve wrapper
            await mockERC20.connect(lender).approve(
                await policyWrapper.getAddress(),
                amount
            );

            // Wrap
            const tx = await policyWrapper.connect(lender).wrap(
                AssetType.ERC20,
                await mockERC20.getAddress(),
                0,
                amount,
                emptyProof
            );

            // 計算預期的 PBM tokenId
            const pbmTokenId = await policyWrapper.computePBMTokenId(
                AssetType.ERC20,
                await mockERC20.getAddress(),
                0
            );

            // 驗證 PBM 餘額
            expect(await pbmToken.balanceOf(lender.address, pbmTokenId)).to.equal(amount);

            // 驗證底層資產已轉移
            expect(await mockERC20.balanceOf(await policyWrapper.getAddress())).to.equal(amount);
        });

        it("未批准應該失敗", async function () {
            const amount = ethers.parseEther("1000");

            await expect(
                policyWrapper.connect(lender).wrap(
                    AssetType.ERC20,
                    await mockERC20.getAddress(),
                    0,
                    amount,
                    emptyProof
                )
            ).to.be.reverted;
        });
    });

    describe("Wrap ERC721", function () {
        const emptyProof = {
            proofType: ethers.encodeBytes32String("KYC"),
            credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
            issuedAt: Math.floor(Date.now() / 1000) - 3600,
            expiresAt: Math.floor(Date.now() / 1000) + 86400,
            issuer: ethers.ZeroAddress,
            signature: "0x"
        };

        beforeEach(async function () {
            await policyWrapper.setComplianceExemption(borrower.address, true);
        });

        it("應該能夠包裝 ERC721", async function () {
            const tokenId = 1;

            // Approve wrapper
            await mockERC721.connect(borrower).approve(
                await policyWrapper.getAddress(),
                tokenId
            );

            // Wrap
            await policyWrapper.connect(borrower).wrap(
                AssetType.ERC721,
                await mockERC721.getAddress(),
                tokenId,
                1,
                emptyProof
            );

            // 計算 PBM tokenId
            const pbmTokenId = await policyWrapper.computePBMTokenId(
                AssetType.ERC721,
                await mockERC721.getAddress(),
                tokenId
            );

            // 驗證
            expect(await pbmToken.balanceOf(borrower.address, pbmTokenId)).to.equal(1);
            expect(await mockERC721.ownerOf(tokenId)).to.equal(await policyWrapper.getAddress());
        });
    });

    describe("Wrap ERC1155", function () {
        const emptyProof = {
            proofType: ethers.encodeBytes32String("KYC"),
            credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
            issuedAt: Math.floor(Date.now() / 1000) - 3600,
            expiresAt: Math.floor(Date.now() / 1000) + 86400,
            issuer: ethers.ZeroAddress,
            signature: "0x"
        };

        beforeEach(async function () {
            await policyWrapper.setComplianceExemption(borrower.address, true);
        });

        it("應該能夠包裝 ERC1155", async function () {
            const tokenId = 100;
            const amount = 500;

            // Approve wrapper
            await mockERC1155.connect(borrower).setApprovalForAll(
                await policyWrapper.getAddress(),
                true
            );

            // Wrap
            await policyWrapper.connect(borrower).wrap(
                AssetType.ERC1155,
                await mockERC1155.getAddress(),
                tokenId,
                amount,
                emptyProof
            );

            // 計算 PBM tokenId
            const pbmTokenId = await policyWrapper.computePBMTokenId(
                AssetType.ERC1155,
                await mockERC1155.getAddress(),
                tokenId
            );

            // 驗證
            expect(await pbmToken.balanceOf(borrower.address, pbmTokenId)).to.equal(amount);
        });
    });

    describe("Unwrap", function () {
        const emptyProof = {
            proofType: ethers.encodeBytes32String("KYC"),
            credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
            issuedAt: Math.floor(Date.now() / 1000) - 3600,
            expiresAt: Math.floor(Date.now() / 1000) + 86400,
            issuer: ethers.ZeroAddress,
            signature: "0x"
        };

        it("應該能夠解包 ERC20", async function () {
            await policyWrapper.setComplianceExemption(lender.address, true);
            
            const amount = ethers.parseEther("1000");

            // Approve & Wrap
            await mockERC20.connect(lender).approve(await policyWrapper.getAddress(), amount);
            await policyWrapper.connect(lender).wrap(
                AssetType.ERC20,
                await mockERC20.getAddress(),
                0,
                amount,
                emptyProof
            );

            const pbmTokenId = await policyWrapper.computePBMTokenId(
                AssetType.ERC20,
                await mockERC20.getAddress(),
                0
            );

            const balanceBefore = await mockERC20.balanceOf(lender.address);

            // Unwrap
            await policyWrapper.connect(lender).unwrap(
                pbmTokenId,
                amount,
                lender.address
            );

            // 驗證
            expect(await pbmToken.balanceOf(lender.address, pbmTokenId)).to.equal(0);
            expect(await mockERC20.balanceOf(lender.address)).to.equal(balanceBefore + amount);
        });
    });

    describe("Repo Scenario", function () {
        const emptyProof = {
            proofType: ethers.encodeBytes32String("KYC"),
            credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
            issuedAt: Math.floor(Date.now() / 1000) - 3600,
            expiresAt: Math.floor(Date.now() / 1000) + 86400,
            issuer: ethers.ZeroAddress,
            signature: "0x"
        };

        beforeEach(async function () {
            await policyWrapper.setComplianceExemption(lender.address, true);
            await policyWrapper.setComplianceExemption(borrower.address, true);
        });

        it("應該支援 Repo 場景：Lender 包裝 money, Borrower 包裝 securities", async function () {
            const moneyAmount = ethers.parseEther("1000");
            const securityTokenId = 100;
            const securityAmount = 100;

            // Lender wraps money (ERC20)
            await mockERC20.connect(lender).approve(await policyWrapper.getAddress(), moneyAmount);
            await policyWrapper.connect(lender).wrap(
                AssetType.ERC20,
                await mockERC20.getAddress(),
                0,
                moneyAmount,
                emptyProof
            );

            // Borrower wraps securities (ERC1155)
            await mockERC1155.connect(borrower).setApprovalForAll(await policyWrapper.getAddress(), true);
            await policyWrapper.connect(borrower).wrap(
                AssetType.ERC1155,
                await mockERC1155.getAddress(),
                securityTokenId,
                securityAmount,
                emptyProof
            );

            // 計算 PBM tokenIds
            const moneyPBMId = await policyWrapper.computePBMTokenId(
                AssetType.ERC20,
                await mockERC20.getAddress(),
                0
            );
            const securityPBMId = await policyWrapper.computePBMTokenId(
                AssetType.ERC1155,
                await mockERC1155.getAddress(),
                securityTokenId
            );

            // 驗證雙方都獲得了 PBM
            expect(await pbmToken.balanceOf(lender.address, moneyPBMId)).to.equal(moneyAmount);
            expect(await pbmToken.balanceOf(borrower.address, securityPBMId)).to.equal(securityAmount);

            // 模擬交換：Lender 轉 PBM#money 給 Borrower，Borrower 轉 PBM#security 給 Lender
            await pbmToken.connect(lender).safeTransferFrom(
                lender.address, borrower.address, moneyPBMId, moneyAmount, "0x"
            );
            await pbmToken.connect(borrower).safeTransferFrom(
                borrower.address, lender.address, securityPBMId, securityAmount, "0x"
            );

            // 驗證交換後的狀態
            expect(await pbmToken.balanceOf(borrower.address, moneyPBMId)).to.equal(moneyAmount);
            expect(await pbmToken.balanceOf(lender.address, securityPBMId)).to.equal(securityAmount);

            // Borrower unwraps money
            await policyWrapper.connect(borrower).unwrap(moneyPBMId, moneyAmount, borrower.address);
            expect(await mockERC20.balanceOf(borrower.address)).to.equal(
                ethers.parseEther("10000") + moneyAmount
            );

            // Lender unwraps security
            await policyWrapper.connect(lender).unwrap(securityPBMId, securityAmount, lender.address);
            expect(await mockERC1155.balanceOf(lender.address, securityTokenId)).to.equal(securityAmount);
        });
    });
});
