const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 開始部署 GL1 Programmable Compliance Toolkit...\n");

  const [deployer] = await ethers.getSigners();
  console.log("部署者地址:", deployer.address);
  console.log(
    "帳戶餘額:",
    ethers.formatEther(await ethers.provider.getBalance(deployer.address)),
    "ETH\n",
  );

  // 定義管轄區代碼
  const JURISDICTION_TW = ethers.encodeBytes32String("TW"); // 台灣
  const JURISDICTION_SG = ethers.encodeBytes32String("SG"); // 新加坡
  const JURISDICTION_EU = ethers.encodeBytes32String("EU"); // 歐盟

  // ========================================
  // 步驟 1: 部署 CCID Registry（身份註冊表）
  // ========================================
  console.log("📝 步驟 1: 部署 CCIDRegistry...");
  const CCIDRegistry = await ethers.getContractFactory("CCIDRegistry");
  const ccidRegistry = await CCIDRegistry.deploy();
  await ccidRegistry.waitForDeployment();
  const ccidRegistryAddress = await ccidRegistry.getAddress();
  console.log("   CCIDRegistry 部署於:", ccidRegistryAddress);

  // ========================================
  // 步驟 2: 部署模擬的 Chainlink ACE（測試用）
  // ========================================
  console.log("\n📝 步驟 2: 部署 MockChainlinkACE（測試用）...");
  // 注意：在生產環境中，這應該是真正的 Chainlink ACE 地址
  // 這裡我們使用部署者地址作為佔位符
  const mockChainlinkACE = deployer.address;
  console.log("   使用模擬 ChainlinkACE 地址:", mockChainlinkACE);

  // ========================================
  // 步驟 3: 部署 Policy Manager
  // ========================================
  console.log("\n📝 步驟 3: 部署 GL1PolicyManager...");
  const GL1PolicyManager = await ethers.getContractFactory("GL1PolicyManager");
  const policyManager = await GL1PolicyManager.deploy(
    mockChainlinkACE, // Chainlink ACE
    ccidRegistryAddress, // CCID Provider
    deployer.address, // 鏈下規則引擎（佔位符）
  );
  await policyManager.waitForDeployment();
  const policyManagerAddress = await policyManager.getAddress();
  console.log("   GL1PolicyManager 部署於:", policyManagerAddress);

  // ========================================
  // 步驟 4: 部署 Policy Wrapper（台灣管轄區）
  // ========================================
  console.log("\n📝 步驟 4: 部署台灣管轄區的 GL1PolicyWrapper...");
  const GL1PolicyWrapper = await ethers.getContractFactory("GL1PolicyWrapper");
  // 注意：生產環境應先部署 PBMToken 再傳入地址
  // 此處使用 deployer.address 作為佔位符
  const policyWrapperTW = await GL1PolicyWrapper.deploy(
    JURISDICTION_TW,
    policyManagerAddress,
    deployer.address, // PBMToken 地址（佔位符）
    deployer.address, // trustedSigner
  );
  await policyWrapperTW.waitForDeployment();
  const policyWrapperTWAddress = await policyWrapperTW.getAddress();
  console.log("   GL1PolicyWrapper (TW) 部署於:", policyWrapperTWAddress);

  // ========================================
  // 步驟 5: 部署 GL1 Compliant Token
  // ========================================
  console.log("\n📝 步驟 5: 部署 GL1CompliantToken...");
  const GL1CompliantToken =
    await ethers.getContractFactory("GL1CompliantToken");
  const token = await GL1CompliantToken.deploy(
    "GL1 Security Token",
    "GL1ST",
    JURISDICTION_TW,
  );
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log("   GL1CompliantToken 部署於:", tokenAddress);

  // ========================================
  // 步驟 6: 部署 Chainlink ACE Integration
  // ========================================
  console.log("\n📝 步驟 6: 部署 ChainlinkACEIntegration...");
  const ChainlinkACEIntegration = await ethers.getContractFactory(
    "ChainlinkACEIntegration",
  );
  const aceIntegration = await ChainlinkACEIntegration.deploy(deployer.address);
  await aceIntegration.waitForDeployment();
  const aceIntegrationAddress = await aceIntegration.getAddress();
  console.log("   ChainlinkACEIntegration 部署於:", aceIntegrationAddress);

  // ========================================
  // 步驟 7: 配置合約關係
  // ========================================
  console.log("\n⚙️  步驟 7: 配置合約關係...");

  // 為代幣設置政策包裝器
  await token.setPolicyWrapper(JURISDICTION_TW, policyWrapperTWAddress);
  console.log("   ✓ 設置台灣管轄區的 Policy Wrapper");

  // 啟用管轄區
  await policyManager.setJurisdictionEnabled(JURISDICTION_TW, true);
  console.log("   ✓ 啟用台灣管轄區");

  // ========================================
  // 部署摘要
  // ========================================
  console.log("\n" + "=".repeat(60));
  console.log("📋 GL1 Programmable Compliance Toolkit 部署完成！");
  console.log("=".repeat(60));
  console.log("\n部署的合約地址：");
  console.log("┌─────────────────────────────────────────────────────────┐");
  console.log(`│ CCIDRegistry:            ${ccidRegistryAddress} │`);
  console.log(`│ GL1PolicyManager:        ${policyManagerAddress} │`);
  console.log(`│ GL1PolicyWrapper (TW):   ${policyWrapperTWAddress} │`);
  console.log(`│ GL1CompliantToken:       ${tokenAddress} │`);
  console.log(`│ ChainlinkACEIntegration: ${aceIntegrationAddress} │`);
  console.log("└─────────────────────────────────────────────────────────┘");

  console.log("\n管轄區代碼：");
  console.log(`  TW (台灣): ${JURISDICTION_TW}`);
  console.log(`  SG (新加坡): ${JURISDICTION_SG}`);
  console.log(`  EU (歐盟): ${JURISDICTION_EU}`);

  console.log("\n下一步：");
  console.log("  1. 在 CCIDRegistry 中註冊用戶身份");
  console.log("  2. 在 PolicyManager 中配置合規規則");
  console.log("  3. 使用 GL1CompliantToken 進行合規轉帳測試");
  console.log("  4. 整合真實的 Chainlink ACE 服務（生產環境）");

  // 返回部署的合約地址（供測試使用）
  return {
    ccidRegistry: ccidRegistryAddress,
    policyManager: policyManagerAddress,
    policyWrapperTW: policyWrapperTWAddress,
    token: tokenAddress,
    aceIntegration: aceIntegrationAddress,
    jurisdictions: {
      TW: JURISDICTION_TW,
      SG: JURISDICTION_SG,
      EU: JURISDICTION_EU,
    },
  };
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("部署失敗:", error);
    process.exit(1);
  });
