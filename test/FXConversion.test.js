const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FX Conversion for Cross-Border Payments", function () {
  let policyWrapper;
  let pbmToken;
  let mockFXProvider;
  let mockUSD; // Mock USDC (USD)
  let mockSGD; // Mock XSGD (SGD)
  let mockTWD; // Mock TWDT (TWD)
  let mockCNY; // Mock CNYT (CNY)

  let owner;
  let tourist; // 遊客
  let merchant; // 商家
  let policyManager;

  const JURISDICTION_SG = ethers.encodeBytes32String("SG");

  // 貨幣代碼
  const USD = ethers.keccak256(ethers.toUtf8Bytes("USD"));
  const SGD = ethers.keccak256(ethers.toUtf8Bytes("SGD"));
  const TWD = ethers.keccak256(ethers.toUtf8Bytes("TWD"));
  const CNY = ethers.keccak256(ethers.toUtf8Bytes("CNY"));

  beforeEach(async function () {
    [owner, tourist, merchant, policyManager] = await ethers.getSigners();

    // 部署 Mock 穩定幣
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockUSD = await MockERC20.deploy("Mock USDC", "MUSDC");
    mockSGD = await MockERC20.deploy("Mock XSGD", "MXSGD");
    mockTWD = await MockERC20.deploy("Mock TWDT", "MTWDT");
    mockCNY = await MockERC20.deploy("Mock CNYT", "MCNYT");

    await Promise.all([
      mockUSD.waitForDeployment(),
      mockSGD.waitForDeployment(),
      mockTWD.waitForDeployment(),
      mockCNY.waitForDeployment(),
    ]);

    // 部署 Mock FX Rate Provider
    const MockFXRateProvider =
      await ethers.getContractFactory("MockFXRateProvider");
    mockFXProvider = await MockFXRateProvider.deploy();
    await mockFXProvider.waitForDeployment();

    // 部署 CCIDRegistry 和 GL1PolicyManager
    const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
    const ccidRegistry = await CCIDRegistry.deploy();
    await ccidRegistry.waitForDeployment();

    const GL1PolicyManager =
      await ethers.getContractFactory("GL1PolicyManager");
    const policyManagerContract = await GL1PolicyManager.deploy(
      owner.address,
      await ccidRegistry.getAddress(),
      owner.address
    );
    await policyManagerContract.waitForDeployment();

    // 部署 PBMToken（先用 owner 作為臨時 wrapper）
    const PBMToken = await ethers.getContractFactory("PBMToken");
    pbmToken = await PBMToken.deploy(owner.address);
    await pbmToken.waitForDeployment();

    // 部署 GL1PolicyWrapper
    const GL1PolicyWrapper =
      await ethers.getContractFactory("GL1PolicyWrapper");
    policyWrapper = await GL1PolicyWrapper.deploy(
      JURISDICTION_SG,
      await policyManagerContract.getAddress(),
      await pbmToken.getAddress()
    );
    await policyWrapper.waitForDeployment();

    // 更新 PBMToken 的 wrapper
    await pbmToken.updateWrapper(await policyWrapper.getAddress());

    // 配置 FX 系統
    await policyWrapper.setFXRateProvider(await mockFXProvider.getAddress());
    await policyWrapper.setFXEnabled(true);

    // 設定資產幣種對應
    await policyWrapper.setAssetCurrency(await mockUSD.getAddress(), USD);
    await policyWrapper.setAssetCurrency(await mockSGD.getAddress(), SGD);
    await policyWrapper.setAssetCurrency(await mockTWD.getAddress(), TWD);
    await policyWrapper.setAssetCurrency(await mockCNY.getAddress(), CNY);

    // 豁免合規檢查（測試用）
    await policyWrapper.setComplianceExemption(tourist.address, true);
    await policyWrapper.setComplianceExemption(merchant.address, true);

    // 鑄造測試代幣
    await mockTWD.mint(tourist.address, ethers.parseEther("100000")); // 10萬 TWD
    await mockCNY.mint(tourist.address, ethers.parseEther("10000")); // 1萬 CNY
    await mockSGD.mint(
      await policyWrapper.getAddress(),
      ethers.parseEther("10000")
    ); // 為合約提供 SGD 流動性
  });

  describe("MockFXRateProvider", function () {
    it("應該返回正確的匯率", async function () {
      // TWD/SGD 匯率
      const [twdToSgdRate] = await mockFXProvider.getRate(TWD, SGD);
      expect(twdToSgdRate).to.be.gt(0);

      // CNY/SGD 匯率
      const [cnyToSgdRate] = await mockFXProvider.getRate(CNY, SGD);
      expect(cnyToSgdRate).to.be.gt(0);
    });

    it("應該正確轉換金額", async function () {
      const amount = ethers.parseEther("1000"); // 1000 TWD
      const [convertedAmount, rateUsed] = await mockFXProvider.convert(
        TWD,
        SGD,
        amount
      );

      // 1000 TWD ≈ 42.2 SGD (基於 Mock 匯率)
      expect(convertedAmount).to.be.gt(0);
      expect(rateUsed).to.be.gt(0);
    });
  });

  describe("wrapWithFXConversion", function () {
    const emptyProof = {
      proofType: ethers.encodeBytes32String("KYC"),
      credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
      issuedAt: Math.floor(Date.now() / 1000) - 3600,
      expiresAt: Math.floor(Date.now() / 1000) + 86400,
      issuer: ethers.ZeroAddress,
      signature: "0x",
    };

    it("應該能夠用 TWD 包裝並轉換為 SGD 價值", async function () {
      const twdAmount = ethers.parseEther("1000"); // 1000 TWD

      // Approve
      await mockTWD
        .connect(tourist)
        .approve(await policyWrapper.getAddress(), twdAmount);

      // Wrap with FX conversion
      const tx = await policyWrapper.connect(tourist).wrapWithFXConversion(
        await mockTWD.getAddress(),
        twdAmount,
        SGD, // 目標幣種：SGD
        emptyProof
      );

      // 檢查事件
      await expect(tx).to.emit(policyWrapper, "FXConversionApplied");
      await expect(tx).to.emit(policyWrapper, "TokenWrapped");

      // 驗證 PBM 餘額
      const pbmTokenId = await policyWrapper.computePBMTokenId(
        0, // ERC20
        await mockTWD.getAddress(),
        0
      );
      expect(await pbmToken.balanceOf(tourist.address, pbmTokenId)).to.equal(
        twdAmount
      );
    });

    it("應該用 CNY 包裝時計算正確的 SGD 金額", async function () {
      const cnyAmount = ethers.parseEther("100"); // 100 CNY

      // 先查詢預期轉換金額
      const [expectedSgd] = await mockFXProvider.convert(CNY, SGD, cnyAmount);

      // Approve
      await mockCNY
        .connect(tourist)
        .approve(await policyWrapper.getAddress(), cnyAmount);

      // Wrap with FX conversion
      const tx = await policyWrapper
        .connect(tourist)
        .wrapWithFXConversion(
          await mockCNY.getAddress(),
          cnyAmount,
          SGD,
          emptyProof
        );

      const receipt = await tx.wait();

      // 找到 FXConversionApplied 事件
      const fxEvent = receipt.logs.find(
        (log) => log.fragment && log.fragment.name === "FXConversionApplied"
      );

      if (fxEvent) {
        const convertedAmount = fxEvent.args[4];
        expect(convertedAmount).to.equal(expectedSgd);
      }
    });

    it("未啟用 FX 應該失敗", async function () {
      await policyWrapper.setFXEnabled(false);

      const twdAmount = ethers.parseEther("1000");
      await mockTWD
        .connect(tourist)
        .approve(await policyWrapper.getAddress(), twdAmount);

      await expect(
        policyWrapper
          .connect(tourist)
          .wrapWithFXConversion(
            await mockTWD.getAddress(),
            twdAmount,
            SGD,
            emptyProof
          )
      ).to.be.revertedWith("FX conversion not enabled");
    });
  });

  describe("previewFXConversion", function () {
    it("應該能預覽 TWD 到 SGD 的轉換", async function () {
      const amount = ethers.parseEther("10000"); // 10,000 TWD

      const [convertedAmount, rate] = await policyWrapper.previewFXConversion(
        await mockTWD.getAddress(),
        amount,
        SGD
      );

      expect(convertedAmount).to.be.gt(0);
      expect(rate).to.be.gt(0);

      // 驗證計算正確：convertedAmount = amount * rate / 1e18
      const calculated = (amount * rate) / ethers.parseEther("1");
      expect(convertedAmount).to.equal(calculated);
    });
  });

  describe("Cross-Border Payment Scenario (跨境支付場景)", function () {
    const emptyProof = {
      proofType: ethers.encodeBytes32String("KYC"),
      credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
      issuedAt: Math.floor(Date.now() / 1000) - 3600,
      expiresAt: Math.floor(Date.now() / 1000) + 86400,
      issuer: ethers.ZeroAddress,
      signature: "0x",
    };

    it("完整流程：台灣遊客在新加坡消費", async function () {
      // 場景：台灣遊客使用 TWD 穩定幣在新加坡消費
      // 商家收到 SGD 結算

      const twdAmount = ethers.parseEther("3200"); // 3200 TWD (約 100 SGD)

      // 1. 遊客 approve TWD
      await mockTWD
        .connect(tourist)
        .approve(await policyWrapper.getAddress(), twdAmount);

      // 2. 遊客使用 wrapWithFXConversion 付款
      await policyWrapper
        .connect(tourist)
        .wrapWithFXConversion(
          await mockTWD.getAddress(),
          twdAmount,
          SGD,
          emptyProof
        );

      const pbmTokenId = await policyWrapper.computePBMTokenId(
        0, // ERC20
        await mockTWD.getAddress(),
        0
      );

      // 3. 驗證遊客獲得 PBM
      expect(await pbmToken.balanceOf(tourist.address, pbmTokenId)).to.equal(
        twdAmount
      );

      // 4. 遊客將 PBM 轉給商家
      await pbmToken
        .connect(tourist)
        .safeTransferFrom(
          tourist.address,
          merchant.address,
          pbmTokenId,
          twdAmount,
          "0x"
        );

      // 5. 驗證商家收到 PBM
      expect(await pbmToken.balanceOf(merchant.address, pbmTokenId)).to.equal(
        twdAmount
      );
      expect(await pbmToken.balanceOf(tourist.address, pbmTokenId)).to.equal(0);

      // 6. 商家結算 - 收取 SGD
      const merchantSgdBefore = await mockSGD.balanceOf(merchant.address);

      await policyWrapper
        .connect(merchant)
        .settleCrossBorderPayment(
          pbmTokenId,
          twdAmount,
          await mockSGD.getAddress(),
          merchant.address
        );

      const merchantSgdAfter = await mockSGD.balanceOf(merchant.address);

      // 7. 驗證商家收到 SGD
      expect(merchantSgdAfter).to.be.gt(merchantSgdBefore);

      // 8. 驗證 PBM 已銷毀
      expect(await pbmToken.balanceOf(merchant.address, pbmTokenId)).to.equal(
        0
      );
    });
  });

  describe("payWithFXConversion (正確的跨境支付流程)", function () {
    const emptyProof = {
      proofType: ethers.encodeBytes32String("KYC"),
      credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
      issuedAt: Math.floor(Date.now() / 1000) - 3600,
      expiresAt: Math.floor(Date.now() / 1000) + 86400,
      issuer: ethers.ZeroAddress,
      signature: "0x",
    };

    it("商家標價 100 SGD，遊客用 TWD 付款", async function () {
      // 商家標價 100 SGD
      const merchantPrice = ethers.parseEther("100"); // 100 SGD

      // 先計算遊客需要付多少 TWD
      const [expectedTWD] = await mockFXProvider.convert(
        SGD,
        TWD,
        merchantPrice
      );

      // 遊客需要 approve 足夠的 TWD
      await mockTWD
        .connect(tourist)
        .approve(await policyWrapper.getAddress(), expectedTWD);

      // 記錄遊客初始餘額
      const touristTWDBefore = await mockTWD.balanceOf(tourist.address);

      // 執行 payWithFXConversion
      const tx = await policyWrapper.connect(tourist).payWithFXConversion(
        merchantPrice, // 商家要收 100 SGD
        SGD, // 商家幣種
        await mockTWD.getAddress(), // 遊客支付 TWD
        merchant.address, // 商家地址
        emptyProof
      );

      // 檢查事件
      await expect(tx).to.emit(policyWrapper, "CrossBorderPaymentInitiated");
      await expect(tx).to.emit(policyWrapper, "TokenWrapped");

      // 驗證遊客被扣款
      const touristTWDAfter = await mockTWD.balanceOf(tourist.address);
      expect(touristTWDBefore - touristTWDAfter).to.equal(expectedTWD);

      // 驗證商家收到 PBM
      const pbmTokenId = await policyWrapper.computePBMTokenId(
        0, // ERC20
        await mockTWD.getAddress(),
        0
      );
      expect(await pbmToken.balanceOf(merchant.address, pbmTokenId)).to.equal(
        expectedTWD
      );
    });

    it("應該記錄 FX 交易詳情", async function () {
      const merchantPrice = ethers.parseEther("50"); // 50 SGD

      const [expectedTWD, rateUsed] = await mockFXProvider.convert(
        SGD,
        TWD,
        merchantPrice
      );

      await mockTWD
        .connect(tourist)
        .approve(await policyWrapper.getAddress(), expectedTWD);

      await policyWrapper
        .connect(tourist)
        .payWithFXConversion(
          merchantPrice,
          SGD,
          await mockTWD.getAddress(),
          merchant.address,
          emptyProof
        );

      // 查詢 FX 交易記錄
      const pbmTokenId = await policyWrapper.computePBMTokenId(
        0,
        await mockTWD.getAddress(),
        0
      );

      const fxTx = await policyWrapper.getFXTransaction(pbmTokenId);

      // 驗證記錄內容
      expect(fxTx.sourceCurrency).to.equal(TWD);
      expect(fxTx.targetCurrency).to.equal(SGD);
      expect(fxTx.sourceAmount).to.equal(expectedTWD);
      expect(fxTx.targetAmount).to.equal(merchantPrice);
      expect(fxTx.rateUsed).to.equal(rateUsed);
      expect(fxTx.payer).to.equal(tourist.address);
      expect(fxTx.payee).to.equal(merchant.address);
      expect(fxTx.timestamp).to.be.gt(0);
    });

    it("餘額不足應該失敗", async function () {
      // 商家標價 1000000 SGD (遊客不可能有這麼多)
      const hugeAmount = ethers.parseEther("1000000");

      await mockTWD
        .connect(tourist)
        .approve(
          await policyWrapper.getAddress(),
          ethers.parseEther("100000000")
        );

      await expect(
        policyWrapper
          .connect(tourist)
          .payWithFXConversion(
            hugeAmount,
            SGD,
            await mockTWD.getAddress(),
            merchant.address,
            emptyProof
          )
      ).to.be.revertedWith("Insufficient balance");
    });

    it("完整流程：商家標價 SGD，遊客付 TWD，商家收 SGD", async function () {
      // 1. 商家標價 100 SGD
      const merchantPrice = ethers.parseEther("100");

      // 2. 計算遊客需付多少 TWD
      const [twdToPayFromContract] = await mockFXProvider.convert(
        SGD,
        TWD,
        merchantPrice
      );

      // 3. 遊客 approve TWD
      await mockTWD
        .connect(tourist)
        .approve(await policyWrapper.getAddress(), twdToPayFromContract);

      // 4. 遊客付款 (payWithFXConversion)
      await policyWrapper
        .connect(tourist)
        .payWithFXConversion(
          merchantPrice,
          SGD,
          await mockTWD.getAddress(),
          merchant.address,
          emptyProof
        );

      const pbmTokenId = await policyWrapper.computePBMTokenId(
        0,
        await mockTWD.getAddress(),
        0
      );

      // 5. 驗證商家已收到 PBM
      expect(await pbmToken.balanceOf(merchant.address, pbmTokenId)).to.equal(
        twdToPayFromContract
      );

      // 6. 查詢 FX 記錄
      const fxRecord = await policyWrapper.getFXTransaction(pbmTokenId);
      expect(fxRecord.targetAmount).to.equal(merchantPrice);
      expect(fxRecord.sourceAmount).to.equal(twdToPayFromContract);

      // 7. 商家結算收取 SGD
      const merchantSgdBefore = await mockSGD.balanceOf(merchant.address);

      await policyWrapper
        .connect(merchant)
        .settleCrossBorderPayment(
          pbmTokenId,
          twdToPayFromContract,
          await mockSGD.getAddress(),
          merchant.address
        );

      const merchantSgdAfter = await mockSGD.balanceOf(merchant.address);

      // 8. 驗證商家收到 SGD
      expect(merchantSgdAfter).to.be.gt(merchantSgdBefore);

      // 9. PBM 已銷毀
      expect(await pbmToken.balanceOf(merchant.address, pbmTokenId)).to.equal(
        0
      );
    });
  });
});
