# GL1 Programmable Compliance Toolkit

基於 GL1 標準的嵌入式監理架構智能合約實作。

## 功能特色

- 🔒 **可程式合規**：將 KYC/AML、資本管制等合規邏輯模組化
- 🌍 **跨境支付**：支援 FX 即時匯率轉換（TWD, SGD, USD, CNY）
- 📜 **Repo 交易**：原子交換確保抵押品與現金安全交換
- 🔗 **跨鏈整合**：Chainlink ACE 跨鏈合規驗證
- 🆔 **身份管理**：CCID 跨鏈身份註冊與 KYC 驗證

## 專案結構

```
contracts/
├── interfaces/
│   ├── IGL1PolicyWrapper.sol         # Policy Wrapper 介面，定義 wrap/unwrap 方法
│   ├── IPolicyManager.sol            # Policy Manager 介面，定義身份驗證與規則執行
│   ├── IRepoContract.sol             # Repo 合約介面，定義回購協議生命週期
│   ├── IFXRateProvider.sol           # FX 匯率提供者介面，定義匯率查詢方法
│   ├── ICCIDProvider.sol             # 跨鏈身份提供者介面
│   ├── IChainlinkACE.sol             # Chainlink ACE 整合介面
│   ├── IChainlinkACEPolicyManager.sol # Chainlink ACE 政策管理介面
│   └── IComplianceRule.sol           # 合規規則介面，所有規則須實作此介面
│
├── core/
│   ├── GL1PolicyWrapper.sol          # 核心包裝器，處理資產 wrap/unwrap 與 FX 轉換
│   ├── GL1PolicyManager.sol          # 政策編排引擎，協調身份驗證與多方合規檢查
│   ├── RepoContract.sol              # 回購協議合約，實作原子交換與清算流程
│   ├── FXRateProvider.sol            # 外匯匯率提供者，支援多幣種即時匯率
│   └── CCIDRegistry.sol              # 跨鏈身份註冊表，管理用戶 KYC 憑證與標籤
│
├── rules/
│   ├── WhitelistRule.sol             # 白名單規則，限制收款人為預先驗證的商家
│   ├── CollateralRule.sol            # 抵押品規則，驗證 LTV 與抵押品價值
│   ├── CashAdequacyRule.sol          # 現金充足性規則，驗證 Lender 餘額
│   ├── FXLimitRule.sol               # 外匯限額規則，檢查單筆/每日交易限額
│   └── AMLThresholdRule.sol          # AML 門檻規則，大額交易申報與風險評估
│
├── token/
│   └── PBMToken.sol                  # Purpose Bound Money 代幣 (ERC1155)
│
├── mocks/
│   ├── MockERC20.sol                 # ERC20 Mock，用於測試
│   ├── MockERC721.sol                # ERC721 Mock，用於測試
│   ├── MockERC1155.sol               # ERC1155 Mock，用於測試
│   └── MockFXRateProvider.sol        # FX 匯率 Mock，用於測試
│
└── integration/
    └── ChainlinkACEIntegration.sol   # Chainlink ACE 整合合約
```

## 快速開始

### 安裝依賴

```bash
npm install
```

### 編譯合約

```bash
npx hardhat compile
```

### 執行測試

```bash
npx hardhat test
```

## GL1 合規規則對應

| 規則合約           | 功能                   | GL1 對應範例                    |
| ------------------ | ---------------------- | ------------------------------- |
| `WhitelistRule`    | KYC/AML 白名單檢查     | Whitelisting Selected Receivers |
| `CashAdequacyRule` | 現金充足性驗證         | Cash Adequacy Check             |
| `CollateralRule`   | 抵押品價值與 LTV 驗證  | Collateral Sufficiency          |
| `FXLimitRule`      | 外匯交易限額管控       | FX Control Limits               |
| `AMLThresholdRule` | 大額交易申報與風險評估 | AML Large Transaction Reporting |

## 授權

MIT License
