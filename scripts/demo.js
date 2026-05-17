/**
 * ════════════════════════════════════════════════════════════════════════
 * 口試 DEMO
 * ════════════════════════════════════════════════════════════════════════
 *
 * 執行方式：
 *   npx hardhat run scripts/demo.js              （互動模式，每步停下來等 Enter）
 *   DEMO_AUTO=1 npx hardhat run scripts/demo.js  （自動模式，一路跑完）
 *
 * 互動模式下，每完成一個 STEP 會印出「── 按 Enter 繼續 ──」，
 * 按下 Enter 才會跑下一步。
 * ════════════════════════════════════════════════════════════════════════
 */

const { ethers } = require("hardhat");
const readline = require("readline");

// ============================================================
// 終端輸出輔助
// ============================================================
const c = {
  reset: "\x1b[0m",
  bold: "\x1b[1m",
  dim: "\x1b[2m",
  cyan: "\x1b[36m",
  green: "\x1b[32m",
  red: "\x1b[31m",
  yellow: "\x1b[33m",
  magenta: "\x1b[35m",
  blue: "\x1b[34m",
  gray: "\x1b[90m",
};

function banner(stepNum, title) {
  const line = "═".repeat(70);
  console.log(`\n${c.cyan}${c.bold}${line}`);
  console.log(`  STEP ${stepNum}：${title}`);
  console.log(`${line}${c.reset}\n`);
}

function ok(msg) {
  console.log(`  ${c.green}✓${c.reset} ${msg}`);
}
function fail(msg) {
  console.log(`  ${c.red}✗ 預期失敗${c.reset}：${msg}`);
}
function info(msg) {
  console.log(`  ${c.dim}·${c.reset} ${msg}`);
}
function highlight(msg) {
  console.log(`  ${c.yellow}${c.bold}${msg}${c.reset}`);
}

// 印出鏈上交易的證據（tx hash + block）— 讓觀眾看到這是真的鏈上動作
function txEvidence(receipt, label) {
  const hash = receipt.hash.slice(0, 18);
  const block = receipt.blockNumber;
  console.log(
    `  ${c.blue}┃${c.reset} ${c.bold}${label}${c.reset}  ${c.gray}tx=${hash}…  block=${block}${c.reset}`,
  );
}

// 從 receipt 取出指定事件並用 contract interface 解碼
function decodeEvent(receipt, contract, eventName) {
  const iface = contract.interface;
  for (const log of receipt.logs) {
    try {
      const parsed = iface.parseLog(log);
      if (parsed && parsed.name === eventName) return parsed;
    } catch (_) {
      // 不是這個 contract 發出的 log，跳過
    }
  }
  return null;
}

function showEvent(_receipt, _contract, _eventName, _formatter) {
  // Event 顯示已停用。要恢復的話，把這個函式換回 git 歷史的版本即可
  return;
}

// 部署合約並印出合約地址 + 部署 tx hash + block
async function deployAndShow(label, factoryName, args = []) {
  const Factory = await ethers.getContractFactory(factoryName);
  const contract = args.length > 0
    ? await Factory.deploy(...args)
    : await Factory.deploy();
  await contract.waitForDeployment();
  const receipt = await contract.deploymentTransaction().wait();
  const addr = await contract.getAddress();
  console.log(`  ${c.green}✓${c.reset} ${label.padEnd(30)} ${c.bold}addr${c.reset}=${addr}`);
  console.log(
    `  ${c.blue}┃${c.reset} ${c.gray}deployTx=${receipt.hash.slice(0, 18)}…  block=${receipt.blockNumber}${c.reset}`,
  );
  return contract;
}

// ============================================================
// 等待按鍵 — 每步結束停下來
// ============================================================
async function waitForKey() {
  if (process.env.DEMO_AUTO === "1") {
    await new Promise((r) => setTimeout(r, 200));
    return;
  }
  return new Promise((resolve) => {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    rl.question(
      `\n${c.dim}  ── 按 Enter 繼續下一步 ──${c.reset}`,
      () => {
        rl.close();
        console.log("");
        resolve();
      },
    );
  });
}

// 18-decimal BigInt 格式化
function fmt(amount, decimals = 2) {
  const str = ethers.formatEther(amount);
  const [intPart, decPart = ""] = str.split(".");
  const intFormatted = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return decimals === 0
    ? intFormatted
    : `${intFormatted}.${(decPart + "000000").slice(0, decimals)}`;
}

function shortAddr(addr) {
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
}

// ============================================================
// 主流程
// ============================================================
async function main() {
  console.log(`${c.magenta}${c.bold}`);
  console.log("╔══════════════════════════════════════════════════════════════════════╗");
  console.log("║          嵌入式監管架構實作—口試—DEMO                                    ║");
  console.log("║                                                                      ║");
  console.log("╚══════════════════════════════════════════════════════════════════════╝");
  console.log(c.reset);
  if (process.env.DEMO_AUTO !== "1") {
    console.log(`  ${c.dim}互動模式：每步結束會停下，按 Enter 繼續${c.reset}`);
    console.log(`  ${c.dim}（若要一路跑完不停，用 DEMO_AUTO=1 npx hardhat run scripts/demo.js）${c.reset}\n`);
  }

  // ethers.getSigners() 從 Hardhat 內建測試錢包取前 5 個。
  // 每個 signer = (地址 + 對應私鑰) 的容器，後面：
  //   - deployer 預設用於合約部署
  //   - 其他四個用 contract.connect(signer) 切換來模擬不同角色（銀行/商家/遊客）
  const [deployer, bankA, bankB, merchant, tourist] = await ethers.getSigners();

  info(`監管機關 (Deployer): ${deployer.address}`);
  info(`銀行 A   (Sender):   ${bankA.address}`);
  info(`銀行 B   (非白名單): ${bankB.address}`);
  info(`商家 C   (在白名單): ${merchant.address}`);
  info(`遊客     (跨境付款): ${tourist.address}`);

  const JURISDICTION_SG = ethers.encodeBytes32String("SG");
  const TIER_STANDARD = ethers.keccak256(ethers.toUtf8Bytes("TIER_STANDARD"));
  const TIER_INSTITUTIONAL = ethers.keccak256(
    ethers.toUtf8Bytes("TIER_INSTITUTIONAL"),
  );
  const TAG_RESIDENT = ethers.keccak256(ethers.toUtf8Bytes("RESIDENT"));
  const TAG_NON_RESIDENT = ethers.keccak256(ethers.toUtf8Bytes("NON_RESIDENT"));
  const TWD = ethers.keccak256(ethers.toUtf8Bytes("TWD"));
  const SGD = ethers.keccak256(ethers.toUtf8Bytes("SGD"));
  const AssetType = { ERC20: 0, ERC721: 1, ERC1155: 2 };
  const emptyProof = {
    proofType: ethers.encodeBytes32String("KYC"),
    credentialHash: ethers.keccak256(ethers.toUtf8Bytes("credential")),
    issuedAt: Math.floor(Date.now() / 1000) - 3600,
    expiresAt: Math.floor(Date.now() / 1000) + 86400,
    issuer: ethers.ZeroAddress,
    signature: "0x",
  };

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 1：部署所有合約
  // ════════════════════════════════════════════════════════════
  banner(1, "部署系統合約");
  info("每個合約的部署本身也是一筆鏈上交易，下面同時印出合約地址與部署交易雜湊");
  console.log("");

  const ccid = await deployAndShow("CCIDRegistry", "CCIDRegistry");
  const ace = await deployAndShow("MockChainlinkACE", "MockChainlinkACE");
  const policyManager = await deployAndShow(
    "GL1PolicyManager",
    "GL1PolicyManager",
    [await ace.getAddress(), await ccid.getAddress(), deployer.address],
  );
  const pbm = await deployAndShow("PBMToken (ERC-1155+7943)", "PBMToken", [
    deployer.address,
  ]);
  const wrapper = await deployAndShow(
    "GL1PolicyWrapper (SG)",
    "GL1PolicyWrapper",
    [
      JURISDICTION_SG,
      await policyManager.getAddress(),
      await pbm.getAddress(),
      deployer.address,
    ],
  );
  // 把 wrapper 地址回填到 pbm（這不是部署，是設定 tx）
  const updWrapReceipt = await (
    await pbm.updateWrapper(await wrapper.getAddress())
  ).wait();
  console.log(
    `  ${c.dim}·${c.reset} pbm.updateWrapper() — 把 wrapper 地址回填給 PBMToken`,
  );
  console.log(
    `  ${c.blue}┃${c.reset} ${c.gray}tx=${updWrapReceipt.hash.slice(0, 18)}…  block=${updWrapReceipt.blockNumber}${c.reset}`,
  );

  const whitelist = await deployAndShow("WhitelistRule", "WhitelistRule");
  const fxLimit = await deployAndShow("FXLimitRule", "FXLimitRule", [
    await ccid.getAddress(),
  ]);
  const fxProvider = await deployAndShow(
    "MockFXRateProvider",
    "MockFXRateProvider",
  );
  const twd = await deployAndShow("Mock TWD", "MockERC20", [
    "Mock TWDT",
    "MTWDT",
  ]);
  const sgd = await deployAndShow("Mock SGD", "MockERC20", [
    "Mock XSGD",
    "MXSGD",
  ]);
  const str = await deployAndShow("STRRepository", "STRRepository", [
    deployer.address,
  ]);

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 2：CCID 身份註冊
  // ════════════════════════════════════════════════════════════
  banner(2, "CCID 身份註冊（KYC/AML 上鏈）");

  info("【鏈下流程】受信任機構（如銀行合規部門、KYC/AML 服務供應商）先在鏈下");
  info("審核護照、身分證、法人盡職調查等實體文件，並跑制裁名單比對。");
  info("通過後把整份文件雜湊成 identityHash（一個 32-byte 值，不含任何 PII）。");
  console.log("");
  info("【鏈上動作】機構用持有 KYC_PROVIDER_ROLE 的地址呼叫 CCIDRegistry，");
  info("把 identityHash + 等級 (tier) + 標籤 (tag) 寫上鏈。鏈上看不到任何 PII，");
  info("但審計時可用 hash 反查鏈下文件是否未被竄改 — 符合 GDPR 數據最小化原則。");
  console.log("");
  info("【三個函式分工】");
  info("  · registerIdentity(address account, bytes32 identityHash, bytes32 tier)");
  info("      → 在 identities 名冊新增一筆帳戶");
  info("  · approveJurisdiction(address account, bytes32 jurisdiction)");
  info("      → 授權該帳戶可在某管轄區交易（寫入授權清單）");
  info("  · verifyCredential(address account, bytes32 jurisdiction) returns (bool)");
  info("      → view 函式，一次回答「名冊有 + 沒過期 + 授權清單有」");
  console.log("");
  info("本 demo 為求簡化，deployer 同時扮演「受信任 KYC 機構」這個角色，");
  info("實務上應由具備鏈下 KYC 能力的合規機構持有 KYC_PROVIDER_ROLE。");
  console.log("");

  const idHash = (n) => ethers.keccak256(ethers.toUtf8Bytes("identity_" + n));

  // 4 個身份的清單，後面三輪呼叫都用同一個 loop 跑
  const identities = [
    {
      signer: bankA, name: "bankA",
      tier: TIER_INSTITUTIONAL, tierLabel: "TIER_INSTITUTIONAL",
      tag: TAG_RESIDENT, tagLabel: "RESIDENT",
    },
    {
      signer: bankB, name: "bankB",
      tier: TIER_INSTITUTIONAL, tierLabel: "TIER_INSTITUTIONAL",
      tag: TAG_RESIDENT, tagLabel: "RESIDENT",
    },
    {
      signer: merchant, name: "merchant",
      tier: TIER_STANDARD, tierLabel: "TIER_STANDARD",
      tag: TAG_RESIDENT, tagLabel: "RESIDENT",
    },
    {
      signer: tourist, name: "tourist",
      tier: TIER_STANDARD, tierLabel: "TIER_STANDARD",
      tag: TAG_NON_RESIDENT, tagLabel: "NON_RESIDENT",
    },
  ];

  highlight("監管機關呼叫 CCIDRegistry.registerIdentity()  ×4 — 把 4 個帳戶的 KYC 雜湊上鏈");
  for (const id of identities) {
    const r = await (
      await ccid.registerIdentity(id.signer.address, idHash(id.name), id.tier)
    ).wait();
    txEvidence(
      r,
      `registerIdentity(${id.name}, idHash(${id.name}), ${id.tierLabel})`,
    );
    showEvent(r, ccid, "IdentityRegistered", (a) =>
      `account=${shortAddr(a[0])}, tier=${id.tierLabel}`,
    );
  }

  console.log("");
  highlight("監管機關呼叫 CCIDRegistry.approveJurisdiction()  ×4 — 核准 4 個帳戶在 SG 管轄區操作");
  for (const id of identities) {
    const r = await (
      await ccid.approveJurisdiction(id.signer.address, JURISDICTION_SG)
    ).wait();
    txEvidence(r, `approveJurisdiction(${id.name}, SG)`);
    showEvent(r, ccid, "JurisdictionApproved", (a) =>
      `account=${shortAddr(a[0])}, jurisdiction=SG`,
    );
  }

  console.log("");
  highlight("監管機關呼叫 CCIDRegistry.setIdentityTag()  ×4 — 標註居民/非居民身份（影響 FX 規則）");
  for (const id of identities) {
    const r = await (
      await ccid.setIdentityTag(id.signer.address, id.tag)
    ).wait();
    txEvidence(r, `setIdentityTag(${id.name}, ${id.tagLabel})`);
    showEvent(r, ccid, "IdentityTagSet", (a) =>
      `account=${shortAddr(a[0])}, newTag=${id.tagLabel}`,
    );
  }

  console.log("");
  info("驗證：呼叫 verifyCredential(address account, bytes32 jurisdiction)");
  info("（view function，不花 gas、不留 tx 紀錄）");
  for (const id of identities) {
    const v = await ccid.verifyCredential.staticCall(
      id.signer.address,
      JURISDICTION_SG,
    );
    info(`  verifyCredential(${id.name.padEnd(8)}, SG)  →  ${v}`);
  }

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 3：合規規則鏈設定
  // ════════════════════════════════════════════════════════════
  banner(3, "合規規則鏈設定（Whitelist + FXLimit）");

  highlight("把商家 C 加入白名單");
  const r3a = await (
    await whitelist.addToWhitelist(merchant.address, "Singapore Coffee", "F&B")
  ).wait();
  txEvidence(r3a, "WhitelistRule.addToWhitelist()");
  showEvent(r3a, whitelist, "AddedToWhitelist", (a) =>
    `account=${shortAddr(a[0])}, name="${a[1]}", category="${a[2]}"`,
  );

  highlight("設定外匯每日上限 = 1,000 TWD");
  const r3b = await (await fxLimit.setDailyLimit(ethers.parseEther("1000"))).wait();
  txEvidence(r3b, "FXLimitRule.setDailyLimit()");
  showEvent(r3b, fxLimit, "DailyLimitUpdated", (a) =>
    `oldLimit=${fmt(a[0], 0)}, newLimit=${fmt(a[1], 0)} TWD`,
  );

  highlight("把兩條規則註冊到 PolicyManager，並綁到 SG 管轄區");
  const RULE_WL = ethers.keccak256(ethers.toUtf8Bytes("RULE_WHITELIST"));
  const RULE_FX = ethers.keccak256(ethers.toUtf8Bytes("RULE_FX"));
  await policyManager.registerRuleSet(
    RULE_WL, "WHITELIST", true, await whitelist.getAddress(), 1,
  );
  await policyManager.registerRuleSet(
    RULE_FX, "FX_LIMIT", true, await fxLimit.getAddress(), 2,
  );
  const r3c = await (
    await policyManager.setJurisdictionRules(JURISDICTION_SG, [RULE_WL, RULE_FX])
  ).wait();
  txEvidence(r3c, "PolicyManager.setJurisdictionRules()");
  showEvent(r3c, policyManager, "JurisdictionConfigured", (a) =>
    `jurisdiction=${ethers.decodeBytes32String(a[0])}, ruleCount=${a[1]}`,
  );
  await policyManager.setJurisdictionEnabled(JURISDICTION_SG, true);

  await wrapper.setFXRateProvider(await fxProvider.getAddress());
  await wrapper.setFXEnabled(true);
  await wrapper.setAssetCurrency(await twd.getAddress(), TWD);
  await wrapper.setAssetCurrency(await sgd.getAddress(), SGD);
  ok("PolicyWrapper FX 系統已啟用，TWD/SGD 幣種對應已設定");

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 4：銀行 A 包裝 TWD → PBM
  // ════════════════════════════════════════════════════════════
  banner(4, "銀行 A 包裝底層資產：TWD → PBM (ERC-1155)");

  await (await twd.mint(bankA.address, ethers.parseEther("10000"))).wait();
  info(`已鑄造 10,000 TWD 給銀行 A — 餘額：${fmt(await twd.balanceOf(bankA.address))} TWD`);

  await wrapper.setComplianceExemption(bankA.address, true);

  const wrapAmount = ethers.parseEther("5000");
  await (await twd.connect(bankA).approve(await wrapper.getAddress(), wrapAmount)).wait();

  highlight("執行 wrapper.wrap(ERC20, TWD, 0, 5000e18, proof)");
  const wrapReceipt = await (
    await wrapper
      .connect(bankA)
      .wrap(AssetType.ERC20, await twd.getAddress(), 0, wrapAmount, emptyProof)
  ).wait();
  txEvidence(wrapReceipt, "wrapper.wrap()");
  showEvent(wrapReceipt, wrapper, "TokenWrapped", (a) =>
    `user=${shortAddr(a[0])}, tokenId=${a[1].toString().slice(0, 12)}…, asset=ERC20, amount=${fmt(a[5])} TWD`,
  );

  const pbmTokenId = await wrapper.computePBMTokenId(
    AssetType.ERC20, await twd.getAddress(), 0,
  );

  console.log("");
  info(`銀行 A    TWD 餘額：${fmt(await twd.balanceOf(bankA.address))} TWD`);
  info(`銀行 A    PBM 餘額：${fmt(await pbm.balanceOf(bankA.address, pbmTokenId))} PBM`);
  info(`Wrapper   TWD 鎖定：${fmt(await twd.balanceOf(await wrapper.getAddress()))} TWD（這 5000 真的存在合約裡）`);

  await wrapper.setComplianceExemption(bankA.address, false);
  ok("解除豁免，後續轉帳都要過完整規則鏈");

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 5：失敗案例 1 — Whitelist 規則阻擋
  // ════════════════════════════════════════════════════════════
  banner(5, "失敗案例 1：白名單規則即時阻擋");

  highlight("情境：銀行 A → 銀行 B（KYC 過，但未上白名單）");

  // 先 view 預檢，讓觀眾看到規則合約現在就回答 false
  info("預檢：先用 view function 問 WhitelistRule，它會怎麼回答？");
  const [wlPassed, wlReason] = await whitelist.checkCompliance.staticCall(
    bankA.address, bankB.address, ethers.parseEther("100"),
  );
  console.log(
    `  ${c.gray}whitelist.checkCompliance(bankA, bankB, 100e18)  →  (passed=${c.red}${wlPassed}${c.gray}, reason="${c.red}${wlReason}${c.gray}")${c.reset}`,
  );
  console.log("");

  info("實際送 transfer 上鏈，預期會被 PBMToken._update 擋下並 revert...");
  try {
    await pbm
      .connect(bankA)
      .safeTransferFrom(
        bankA.address, bankB.address, pbmTokenId,
        ethers.parseEther("100"), "0x",
      );
    console.log(`  ${c.red}✗ DEMO 失敗：交易理應被擋下${c.reset}`);
  } catch (err) {
    fail("transaction reverted（ERC7943CannotTransfer）");
    info(`外層錯誤：${err.shortMessage || err.reason || "ERC7943CannotTransfer"}`);
    info("內層真實原因（從上面的 view 預檢可以看到）：Recipient not in whitelist");
  }

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 6：失敗案例 2 — FX 額度上限阻擋
  // ════════════════════════════════════════════════════════════
  banner(6, "失敗案例 2：外匯日上限規則即時阻擋");

  highlight("情境：把銀行 A 改成「非居民」，外匯日上限 1,000 TWD，試圖轉 2,000");

  const r6a = await (await ccid.setIdentityTag(bankA.address, TAG_NON_RESIDENT)).wait();
  txEvidence(r6a, "ccid.setIdentityTag(bankA, NON_RESIDENT)");
  showEvent(r6a, ccid, "IdentityTagSet", (a) =>
    `account=${shortAddr(a[0])}, oldTag=RESIDENT, newTag=NON_RESIDENT`,
  );

  console.log("");
  info("預檢：問 FXLimitRule 它現在的判斷");
  const [fxPassed, fxReason] = await fxLimit.checkCompliance.staticCall(
    bankA.address, merchant.address, ethers.parseEther("2000"),
  );
  console.log(
    `  ${c.gray}fxLimit.checkCompliance(bankA, merchant, 2000e18)  →  (passed=${c.red}${fxPassed}${c.gray}, reason="${c.red}${fxReason}${c.gray}")${c.reset}`,
  );
  const [, currentTotal, newTotal, remaining] = await fxLimit.previewTransfer(
    bankA.address, ethers.parseEther("2000"),
  );
  info(`previewTransfer 預測：當日累計 ${fmt(currentTotal)} → ${fmt(newTotal)}（上限 1,000）`);
  console.log("");

  info("實際送 transfer 上鏈，預期會被擋...");
  try {
    await pbm
      .connect(bankA)
      .safeTransferFrom(
        bankA.address, merchant.address, pbmTokenId,
        ethers.parseEther("2000"), "0x",
      );
    console.log(`  ${c.red}✗ DEMO 失敗：交易理應被擋下${c.reset}`);
  } catch (err) {
    fail("transaction reverted（ERC7943CannotTransfer）");
    info(`內層真實原因（從上面的 view 預檢可以看到）：FX_LIMIT_EXCEEDED`);
  }

  await ccid.setIdentityTag(bankA.address, TAG_RESIDENT);
  info("已把銀行 A 標籤改回 RESIDENT，準備下一步");

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 7：成功案例
  // ════════════════════════════════════════════════════════════
  banner(7, "成功案例：通過完整規則鏈");

  highlight("情境：銀行 A → 商家 C（白名單內、KYC 過、額度足夠），轉 500 PBM");

  const aBefore = await pbm.balanceOf(bankA.address, pbmTokenId);
  const mBefore = await pbm.balanceOf(merchant.address, pbmTokenId);

  const okReceipt = await (
    await pbm
      .connect(bankA)
      .safeTransferFrom(
        bankA.address, merchant.address, pbmTokenId,
        ethers.parseEther("500"), "0x",
      )
  ).wait();
  txEvidence(okReceipt, "pbm.safeTransferFrom() ← 觸發完整規則鏈");

  // 解碼鏈上事件
  showEvent(okReceipt, wrapper, "ComplianceCheckInitiated", (a) =>
    `txHash=${a[0].slice(0, 14)}…, from=${shortAddr(a[1])}, to=${shortAddr(a[2])}, amount=${fmt(a[3])}`,
  );
  showEvent(okReceipt, policyManager, "ComplianceRuleExecuted", (a) =>
    `ruleId=${a[0].slice(0, 14)}…, passed=${c.green}${a[1]}${c.reset}, reason="${a[2]}"`,
  );
  showEvent(okReceipt, wrapper, "ComplianceCheckCompleted", (a) =>
    `isCompliant=${c.green}${a[1]}${c.reset}, rules=[${a[2].join(",")}]`,
  );
  showEvent(okReceipt, pbm, "TransferSingle", (a) =>
    `from=${shortAddr(a[1])}, to=${shortAddr(a[2])}, id=…${a[3].toString().slice(-6)}, value=${fmt(a[4])}`,
  );

  console.log("");
  info(`銀行 A 餘額：${fmt(aBefore)} → ${fmt(await pbm.balanceOf(bankA.address, pbmTokenId))} PBM`);
  info(`商家 C 餘額：${fmt(mBefore)} → ${fmt(await pbm.balanceOf(merchant.address, pbmTokenId))} PBM`);

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 8：跨境支付 + FX 匯率
  // ════════════════════════════════════════════════════════════
  banner(8, "跨境支付：遊客用 TWD 付 100 SGD");

  highlight("情境：商家標價 100 SGD，遊客錢包扣 TWD，系統自動轉換並上鏈匯率");

  await wrapper.setComplianceExemption(tourist.address, true);
  await wrapper.setComplianceExemption(merchant.address, true);
  await twd.mint(tourist.address, ethers.parseEther("100000"));
  await sgd.mint(await wrapper.getAddress(), ethers.parseEther("10000"));

  const merchantPrice = ethers.parseEther("100");
  const [expectedTWD, rateUsed] = await fxProvider.convert(SGD, TWD, merchantPrice);
  info(`鏈上查詢匯率：1 SGD = ${fmt(rateUsed, 4)} TWD`);
  info(`商家標價 100 SGD ⇒ 遊客需付 ${fmt(expectedTWD)} TWD`);

  await twd.connect(tourist).approve(await wrapper.getAddress(), expectedTWD);

  const fxReceipt = await (
    await wrapper
      .connect(tourist)
      .payWithFXConversion(
        merchantPrice, SGD, await twd.getAddress(), merchant.address, emptyProof,
      )
  ).wait();
  txEvidence(fxReceipt, "wrapper.payWithFXConversion()");
  showEvent(fxReceipt, wrapper, "CrossBorderPaymentInitiated", (a) =>
    `payer=${shortAddr(a[1])} → payee=${shortAddr(a[2])}, ${fmt(a[5])} TWD = ${fmt(a[6])} SGD @ rate=${fmt(a[7], 4)}`,
  );

  const fxRecord = await wrapper.getFXTransaction(pbmTokenId);
  console.log("");
  info(`鏈上 FX 記錄（永久不可竄改）：`);
  info(`  source: ${fmt(fxRecord.sourceAmount)} TWD`);
  info(`  target: ${fmt(fxRecord.targetAmount)} SGD`);
  info(`  rate:   ${fmt(fxRecord.rateUsed, 4)}`);
  info(`  ts:     ${new Date(Number(fxRecord.timestamp) * 1000).toISOString()}`);

  highlight("商家結算：把 PBM 兌回 SGD");
  const settleReceipt = await (
    await wrapper
      .connect(merchant)
      .settleCrossBorderPayment(
        pbmTokenId, expectedTWD, await sgd.getAddress(), merchant.address,
      )
  ).wait();
  txEvidence(settleReceipt, "wrapper.settleCrossBorderPayment()");
  ok(`商家收到 SGD：${fmt(await sgd.balanceOf(merchant.address))} SGD`);

  await wrapper.setComplianceExemption(tourist.address, false);
  await wrapper.setComplianceExemption(merchant.address, false);

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 9：監管覆寫 — 凍結（ERC-7943）
  // ════════════════════════════════════════════════════════════
  banner(9, "監管覆寫：凍結商家資產（ERC-7943）");

  highlight("情境：監管機關懷疑商家 C 涉及可疑交易，凍結其全部 PBM");

  const merchantBal = await pbm.balanceOf(merchant.address, pbmTokenId);
  info(`商家 C 當前 PBM 餘額：${fmt(merchantBal)} PBM`);

  const freezeReceipt = await (
    await pbm.setFrozenTokens(merchant.address, pbmTokenId, merchantBal)
  ).wait();
  txEvidence(freezeReceipt, "pbm.setFrozenTokens()");
  showEvent(freezeReceipt, pbm, "Frozen", (a) =>
    `account=${shortAddr(a[0])}, tokenId=…${a[1].toString().slice(-6)}, amount=${fmt(a[2])}`,
  );

  console.log("");
  info(`凍結餘額：${fmt(await pbm.getFrozenTokens(merchant.address, pbmTokenId))} PBM`);
  info(`未凍結餘額：${fmt(await pbm.getUnfrozenBalance(merchant.address, pbmTokenId))} PBM`);

  console.log("");
  info("驗證：商家試圖轉移 1 PBM 給銀行 A...");
  try {
    await pbm
      .connect(merchant)
      .safeTransferFrom(
        merchant.address, bankA.address, pbmTokenId,
        ethers.parseEther("1"), "0x",
      );
    console.log(`  ${c.red}✗ DEMO 失敗：凍結未生效${c.reset}`);
  } catch (err) {
    fail("ERC7943InsufficientUnfrozenBalance — 凍結成功阻擋");
  }

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // STEP 10：監管覆寫 — 強制轉移 + STR 審計
  // ════════════════════════════════════════════════════════════
  banner(10, "監管覆寫：強制資產回收 + STR 審計軌跡");

  highlight("情境：監管機關行使 ERC-7943 forcedTransfer，把資產取回");

  const ftReceipt = await (
    await pbm.forcedTransfer(
      merchant.address, deployer.address, pbmTokenId, merchantBal,
    )
  ).wait();
  txEvidence(ftReceipt, "pbm.forcedTransfer() ← 監管權限");
  showEvent(ftReceipt, pbm, "ForcedTransfer", (a) =>
    `from=${shortAddr(a[0])}, to=${shortAddr(a[1])}, tokenId=…${a[2].toString().slice(-6)}, amount=${fmt(a[3])}`,
  );

  console.log("");
  info(`商家     PBM：${fmt(merchantBal)} → ${fmt(await pbm.balanceOf(merchant.address, pbmTokenId))}`);
  info(`監管機關 PBM：${fmt(await pbm.balanceOf(deployer.address, pbmTokenId))}`);

  highlight("把這次監管行動寫入 STR 審計倉儲");
  const strId = ethers.keccak256(ethers.toUtf8Bytes("STR_REGULATOR_FORCED_001"));
  const offchainHash = ethers.keccak256(
    ethers.toUtf8Bytes("Regulator forced recovery — case #001"),
  );
  const strReceipt = await (
    await str.registerSTR(
      strId, offchainHash,
      "ipfs://Qm.../regulator-action-001.json",
      ftReceipt.hash,
      3, // RELEASED
    )
  ).wait();
  txEvidence(strReceipt, "str.registerSTR()");
  showEvent(strReceipt, str, "STRRegistered", (a) =>
    `strId=${a[0].slice(0, 14)}…, registrar=${shortAddr(a[3])}`,
  );
  showEvent(strReceipt, str, "STROnchainLinked", (a) =>
    `strId=${a[0].slice(0, 14)}…, onchainTx=${a[1].slice(0, 14)}…  ← 指向 STEP 10 的 forcedTransfer 交易`,
  );

  await waitForKey();

  // ════════════════════════════════════════════════════════════
  // 結尾
  // ════════════════════════════════════════════════════════════
  console.log(`\n${c.green}${c.bold}`);
  console.log("╔══════════════════════════════════════════════════════════════════════╗");
  console.log("║                        ✓ DEMO 完成                                  ║");
  console.log("╚══════════════════════════════════════════════════════════════════════╝");
  console.log(c.reset);

  console.log(`${c.bold}本次 DEMO 驗證的論文核心論點：${c.reset}`);
  console.log("  1. 嵌入式監管：合規規則在「轉帳當下」即時執行，不靠事後查核");
  console.log("  2. 模組化規則：Whitelist / FXLimit 可分別插拔，並支援多管轄區");
  console.log("  3. 鏈下身份 + 鏈上驗證：CCID 將 PII 留在鏈下，避免 GDPR 衝突");
  console.log("  4. 跨境匯率上鏈：每筆 FX 交易匯率與金額永久可追溯");
  console.log("  5. 監管覆寫權：ERC-7943 freeze / forcedTransfer 提供主權救濟管道");
  console.log("  6. 審計軌跡：STR 倉儲將鏈下證據與鏈上雜湊綁定\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(`\n${c.red}DEMO 執行失敗：${c.reset}`, error);
    process.exit(1);
  });
