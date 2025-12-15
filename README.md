# GL1 Programmable Compliance Toolkit

基於 GL1 標準的嵌入式監理架構智能合約實作。

## 專案結構

```
contracts/
├── interfaces/           # 介面定義
│   ├── IPolicyManager.sol
│   ├── ICCIDProvider.sol
│   ├── IChainlinkACE.sol
│   ├── IComplianceRule.sol
│   └── IChainlinkACEPolicyManager.sol
├── core/                  # 核心合約
│   ├── GL1PolicyWrapper.sol    # 政策包裝器
│   ├── GL1PolicyManager.sol    # 政策編排引擎
│   └── CCIDRegistry.sol        # 跨鏈身份註冊表
├── token/                 # 代幣合約
│   └── GL1CompliantToken.sol   # 合規代幣
└── integration/           # 整合合約
    └── ChainlinkACEIntegration.sol

scripts/
└── deploy.js              # 部署腳本

test/
└── GL1PolicyWrapper.test.js  # 測試用例
```

## 安裝

```bash
npm install
```

## 編譯

```bash
npx hardhat compile
```

## 測試

```bash
npx hardhat test
```

## 部署

### 本地部署（Hardhat Network）
```bash
npx hardhat run scripts/deploy.js
```

### 測試網部署（Sepolia）
```bash
# 設置環境變數
export SEPOLIA_RPC_URL="your_sepolia_rpc_url"
export PRIVATE_KEY="your_private_key"

npx hardhat run scripts/deploy.js --network sepolia
```

## 核心功能

### 1. Policy Wrapper (GL1PolicyWrapper)
- 將合規邏輯與代幣合約分離
- 支援多司法管轄區
- 記錄合規證明供監理機構查詢

### 2. Policy Manager (GL1PolicyManager)
- 協調身份驗證和規則引擎
- 支援混合鏈上/鏈下規則執行
- 整合 Chainlink ACE

### 3. CCID Registry (CCIDRegistry)
- 跨鏈身份管理
- GDPR 合規設計（敏感資料存鏈下）
- 支援跨鏈地址映射

### 4. Compliant Token (GL1CompliantToken)
- 自動合規檢查的 ERC-20 代幣
- 多管轄區支援
- 緊急暫停功能

### 5. Chainlink ACE Integration
- 合規策略定義
- 跨鏈合規驗證

## 管轄區代碼

| 代碼 | 說明 |
|------|------|
| TW   | 台灣 |
| SG   | 新加坡 |
| EU   | 歐盟 |

## 授權

MIT License
