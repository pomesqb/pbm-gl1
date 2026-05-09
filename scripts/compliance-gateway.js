/**
 * Compliance Gateway — 模擬鏈下合規閘道（ProofSet 簽發伺服器）
 *
 * 對應論文 §3 ProofSet 機制：
 *   1. User 送 request 給此 server
 *   2. Server 跑 AML 名單比對（O(N)，N = 名單大小）
 *   3. Server 用 ECDSA 簽一張 ProofSet
 *   4. User 拿 ProofSet 上鏈，合約只 _verifyProofSet() 驗章
 *
 * 簽章格式必須對齊 contracts/core/GL1PolicyWrapper.sol::_verifyProofSet：
 *   messageHash = keccak256(abi.encode(proofType, credentialHash, issuedAt, expiresAt, issuer))
 *   ethSignedHash = "\x19Ethereum Signed Message:\n32" || messageHash
 *   signature = sign(ethSignedHash, trustedSignerKey)
 *
 * 使用方式：
 *   程式內：const { createServer } = require("./scripts/compliance-gateway");
 *           const server = createServer(privateKey, amlSize);
 *           await new Promise(r => server.listen(port, r));
 *   獨立執行：PORT=8765 AML_SIZE=1000 node scripts/compliance-gateway.js
 */

const http = require("http");
const { ethers } = require("ethers");

/**
 * 產生模擬 AML 黑名單（確定性，便於重現）
 * @param {number} size 名單大小
 * @returns {Set<string>} 小寫 hex 地址集合
 */
function generateAMLList(size) {
  const list = new Set();
  for (let i = 0; i < size; i++) {
    // 每個條目是 0x000...001 ~ 0x000...N 的偽地址
    const addr = "0x" + i.toString(16).padStart(40, "0");
    list.add(addr.toLowerCase());
  }
  return list;
}

/**
 * 模擬 O(N) AML 比對 — 強制走過整個名單以反映實際比對成本。
 * 即使 Set.has() 是 O(1)，這裡用線性掃描讓 server 端的計算成本與名單大小成正比，
 * 才能讓 M5（小名單）vs M6（大名單）顯現延遲差異。
 */
function lookupAML(blacklist, address) {
  const target = address.toLowerCase();
  let found = false;
  for (const entry of blacklist) {
    if (entry === target) {
      found = true;
      // 不 break — 讓所有 M5/M6 跑同等量級的 worst-case 掃描
    }
  }
  return found;
}

/**
 * 建立 compliance gateway HTTP server
 * @param {string} privateKey 簽章私鑰（須對應合約的 trustedSigner）
 * @param {number} amlSize AML 黑名單大小
 * @returns {http.Server} 尚未 listen 的 server
 */
function createServer(privateKey, amlSize) {
  const wallet = new ethers.Wallet(privateKey);
  const blacklist = generateAMLList(amlSize);
  const abiCoder = ethers.AbiCoder.defaultAbiCoder();
  const proofType = ethers.encodeBytes32String("AML");

  return http.createServer(async (req, res) => {
    if (req.method !== "POST") {
      res.writeHead(405);
      res.end();
      return;
    }

    let body;
    try {
      const chunks = [];
      for await (const chunk of req) chunks.push(chunk);
      body = JSON.parse(Buffer.concat(chunks).toString());
    } catch (err) {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "invalid json" }));
      return;
    }

    if (!body.user || !body.amount) {
      res.writeHead(400, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "missing user/amount" }));
      return;
    }

    if (lookupAML(blacklist, body.user)) {
      res.writeHead(403, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: "blacklisted" }));
      return;
    }

    const now = Math.floor(Date.now() / 1000);
    const credentialHash = ethers.keccak256(
      ethers.toUtf8Bytes(`${body.user}-${body.amount}-${now}-${Math.random()}`),
    );
    const issuedAt = now - 60;
    const expiresAt = now + 3600;
    const issuer = wallet.address;

    const messageHash = ethers.keccak256(
      abiCoder.encode(
        ["bytes32", "bytes32", "uint256", "uint256", "address"],
        [proofType, credentialHash, issuedAt, expiresAt, issuer],
      ),
    );
    const signature = await wallet.signMessage(ethers.getBytes(messageHash));

    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        proofType,
        credentialHash,
        issuedAt,
        expiresAt,
        issuer,
        signature,
      }),
    );
  });
}

module.exports = { createServer, generateAMLList, lookupAML };

if (require.main === module) {
  const PORT = parseInt(process.env.PORT || "8765", 10);
  const AML_SIZE = parseInt(process.env.AML_SIZE || "1000", 10);
  // 預設使用 hardhat account[0] 的私鑰；正式部署應從環境變數注入
  const PRIVATE_KEY =
    process.env.GATEWAY_PRIVATE_KEY ||
    "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";

  const server = createServer(PRIVATE_KEY, AML_SIZE);
  server.listen(PORT, () => {
    const wallet = new ethers.Wallet(PRIVATE_KEY);
    console.log(`[gateway] listening :${PORT} | AML size=${AML_SIZE} | signer=${wallet.address}`);
  });
}
