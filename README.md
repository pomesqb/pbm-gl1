# GL1 Programmable Compliance Toolkit

基於GL1標準的嵌入式監理架構智能合約實作。

## 專案結構

```
contracts/
├── interfaces/
│   ├── IGL1PolicyWrapper.sol         # Policy Wrapper介面，定義wrap/unwrap方法
│   ├── IPolicyManager.sol            # Policy Manager介面，定義身份驗證與規則執行
│   ├── IRepoContract.sol             # Repo合約介面，定義回購協議生命週期
│   ├── IFXRateProvider.sol           # FX匯率提供者介面，定義匯率查詢方法
│   ├── ICCIDProvider.sol             # 跨鏈身份提供者介面
│   ├── IChainlinkACE.sol             # Chainlink ACE整合介面
│   └── IComplianceRule.sol           # 合規規則介面，所有規則須實作此介面
│
├── core/
│   ├── GL1PolicyWrapper.sol          # 核心包裝器，處理資產wrap/unwrap與FX轉換
│   ├── GL1PolicyManager.sol          # 政策編排引擎，協調身份驗證與多方合規檢查
│   ├── RepoContract.sol              # 回購協議合約，實作原子交換與清算流程
│   ├── FXRateProvider.sol            # 外匯匯率提供者，支援多幣種即時匯率
│   └── CCIDRegistry.sol              # 跨鏈身份註冊表，管理用戶KYC憑證
│
├── rules/
│   ├── WhitelistRule.sol             # 白名單規則，限制收款人為預先驗證的商家
│   ├── CollateralRule.sol            # 抵押品規則，驗證LTV與抵押品價值
│   └── CashAdequacyRule.sol          # 現金充足性規則，驗證Lender餘額
│
├── token/
│   └── PBMToken.sol                  # Purpose Bound Money代幣(ERC1155)
│
├── mocks/
│   └── MockFXRateProvider.sol        # FX匯率Mock，用於測試
│
└── integration/
    └── ChainlinkACEIntegration.sol   # Chainlink ACE整合合約
```
