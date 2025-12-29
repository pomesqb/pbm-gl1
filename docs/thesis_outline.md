# 碩士論文大綱（修訂版）

**題目**：基於智能合約之嵌入式監理機制設計與實作

**英文題目**：Design and Implementation of Smart Contract-Based Embedded Supervision Mechanism

---

## 第一章 緒論 (Introduction)

### 1.1 研究背景：監理科技的典範轉移

- 從「事後監管（Ex-post）」到「嵌入式監理（Embedded / Ex-ante）」
- 傳統合規痛點：規則分散、跨境標準不一、無法即時阻斷違規交易
- 央行數位貨幣（CBDC）與代幣化資產的興起帶來監理新挑戰

### 1.2 研究動機：為什麼需要標準化框架？

- 單純撰寫 Smart Contract 容易導致「孤島效應」
- 引入 GL1 (Global Layer One) 架構的必要性
- 可程式合規工具組（PCT, Programmable Compliance Toolkit）的價值：跨司法轄區、跨機構的統一合規標準

### 1.3 研究目的

- 將 GL1 可程式合規工具組（PCT）的設計指引轉化為可執行的智能合約程式碼
  > GL1 官方的 PCT 標準目前僅提供架構指引與範例說明，尚無完整的實作程式碼
- 實作 PBM（Purpose Bound Money）與 GL1 政策管理器的整合
- 驗證「合規即程式碼（Compliance-as-Code）」於跨境支付與 Repo 交易的可行性

---

## 第二章 文獻探討與技術背景 (Literature Review)

### 2.1 嵌入式監理 (Embedded Supervision)

- 定義：將監管規則直接寫入交易系統的技術
- BIS（國際清算銀行）相關報告回顧
- 與傳統監管模式的比較

### 2.2 GL1 架構與可程式合規工具組 (PCT)

- GL1 的四層架構：
  - **Platform Layer**：底層區塊鏈基礎設施
  - **Asset Layer**：代幣化資產（PBM、證券型代幣）
  - **Service Layer**：合規服務、身份驗證
  - **Access Layer**：用戶介面與應用程式
- PCT 的核心概念：將合規邏輯（KYC/AML、資本管制）模組化
- GL1 Illustrative Examples 回顧

### 2.3 PBM (Purpose Bound Money)

- PBM 的定義與特性
- 新加坡金管局（MAS）的 PBM 試驗計畫
- PBM 在跨境支付中的應用（StraitsX/Alipay+ 案例）
- PBM 作為「資產層」載體的角色

### 2.4 跨境支付合規挑戰

- 外匯管制與即時匯率轉換需求
- 跨司法管轄區的 KYC 互認問題
- 跨鏈身份驗證（CCID）概念

### 2.5 Repo 交易與合規自動化

- Repo（附買回交易）的基本機制
- 傳統 Repo 交易的合規痛點
- 區塊鏈 Repo 的優勢：原子交換、即時結算

---

## 第三章 系統架構設計 (System Architecture)

### 3.1 總體架構圖 (High-Level Architecture)

```
┌────────────────────────────────────────────────────────────────────┐
│                        Access Layer                                │
│                   (DApp / 前端介面)                                 │
├────────────────────────────────────────────────────────────────────┤
│                       Service Layer                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ │
│  │ GL1PolicyManager│  │ChainlinkACE     │  │ FXRateProvider      │ │
│  │ (政策編排引擎)   │  │(跨鏈合規驗證)   │  │ (外匯匯率提供者)    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ │
│  │ CCIDRegistry    │  │ WhitelistRule   │  │ CashAdequacyRule    │ │
│  │ (跨鏈身份註冊)  │  │ (KYC/AML 白名單)│  │ (現金充足性)        │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ │
│  │ CollateralRule  │  │ AMLThresholdRule│  │ FXLimitRule         │ │
│  │ (抵押品驗證)    │  │ (大額交易申報)  │  │ (外匯額度限制)      │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────────┘ │
├────────────────────────────────────────────────────────────────────┤
│                        Asset Layer                                 │
│  ┌─────────────────────────────────┐  ┌───────────────────────────┐│
│  │ GL1PolicyWrapper                │  │ RepoContract              ││
│  │ (資產封裝器 + FX 轉換)          │  │ (Repo 交易管理)           ││
│  └─────────────────────────────────┘  └───────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────────┐│
│  │                    PBMToken (ERC1155)                           ││
│  │                    (Purpose Bound Money)                        ││
│  └─────────────────────────────────────────────────────────────────┘│
├────────────────────────────────────────────────────────────────────┤
│                       Platform Layer                               │
│                  (Ethereum / EVM 兼容鏈)                            │
└────────────────────────────────────────────────────────────────────┘
```

### 3.2 合規層設計 (GL1PolicyManager)

- **設計理念**：邏輯與資產分離
- **核心功能**：
  - 規則集動態註冊與管理
  - 多管轄區規則映射
  - 混合執行模式（鏈上/鏈下）
  - 多方角色驗證（Lender/Borrower）
- **對應程式碼**：`GL1PolicyManager.sol`

### 3.3 資產封裝與跨境支付設計 (GL1PolicyWrapper)

- **設計理念**：透過 Wrapper 模式讓任何資產「無縫繼承」合規能力
- **核心功能**：
  - 多資產類型支援（ERC20/ERC721/ERC1155）
  - wrap/unwrap 生命週期管理
  - 跨境支付 FX 轉換（StraitsX/Alipay+ 模式）
  - 合規證明記錄
- **對應程式碼**：`GL1PolicyWrapper.sol`

### 3.4 Repo 交易機制設計 (RepoContract)

- **設計理念**：原子交換確保交易安全
- **Repo 生命週期**：
  1. 發起 (Initiate)
  2. Borrower 存入抵押品 (fundAsBorrower)
  3. Lender 存入現金 (fundAsLender)
  4. 執行原子交換 (executeRepo)
  5. 到期結算 (settleRepo) 或違約處理 (claimCollateral)
- **對應程式碼**：`RepoContract.sol`

### 3.5 外部數據整合 (Oracle Integration)

- **Chainlink ACE 整合**：跨鏈合規驗證、制裁名單檢查
- **FX 匯率提供者**：即時匯率查詢與轉換
- **對應程式碼**：`ChainlinkACEIntegration.sol`, `FXRateProvider.sol`

### 3.6 跨鏈身份管理設計 (CCIDRegistry)

- **設計理念**：敏感資料存鏈下（符合 GDPR），可驗證性證明存鏈上
- **核心功能**：
  - 多層級 KYC 分級（TIER_NONE → TIER_BASIC → TIER_FULL → TIER_INSTITUTIONAL）
  - 身份標籤管理（居民/非居民/法人/制裁名單）
  - 跨鏈地址映射與同步
  - 管轄區權限管理
- **對應程式碼**：`CCIDRegistry.sol`

---

## 第四章 系統實作 (Implementation)

### 4.1 開發環境與工具

- **智能合約語言**：Solidity ^0.8.20
- **開發框架**：Hardhat
- **依賴庫**：OpenZeppelin Contracts
- **預言機**：Chainlink（設計階段）

### 4.2 核心合約實作詳解

#### 4.2.1 PBM Token 實作 (`PBMToken.sol`)

- ERC1155 標準實作
- 轉移前合規檢查 Hook (`_update`)
- Wrapper 專屬鑄造/銷毀權限

#### 4.2.2 政策管理器實作 (`GL1PolicyManager.sol`)

- RuleSet 結構設計
- 管轄區規則映射
- 多方角色驗證（`verifyPartyCompliance`）
- 混合執行模式（鏈上/鏈下）

#### 4.2.3 合規規則實作 (`contracts/rules/`)

| 規則合約               | 功能                   | GL1 對應範例                    |
| ---------------------- | ---------------------- | ------------------------------- |
| `WhitelistRule.sol`    | KYC/AML 白名單檢查     | Whitelisting Selected Receivers |
| `CashAdequacyRule.sol` | 現金充足性驗證         | Cash Adequacy Check             |
| `CollateralRule.sol`   | 抵押品價值與 LTV 驗證  | Collateral Sufficiency          |
| `AMLThresholdRule.sol` | 大額交易申報與拆分偵測 | Large Transaction Reporting     |
| `FXLimitRule.sol`      | 非居民外匯額度限制     | Cross-Border Payment Limits     |

#### 4.2.4 Policy Wrapper 實作 (`GL1PolicyWrapper.sol`)

- 資產類型抽象化處理
- 合規證明結構 (`ProofSet`, `ComplianceProof`)
- FX 轉換功能 (`wrapWithFXConversion`, `payWithFXConversion`)
- 跨境支付結算 (`settleCrossBorderPayment`)

#### 4.2.5 Repo 合約實作 (`RepoContract.sol`)

- 狀態機設計（INITIATED → FUNDED → EXECUTED → SETTLED/DEFAULTED）
- 原子交換邏輯
- 利息計算與結算金額

#### 4.2.6 跨鏈身份註冊表實作 (`CCIDRegistry.sol`)

- KYC 等級結構與驗證邏輯
- 身份標籤（居民/非居民/法人/制裁）管理
- 跨鏈地址映射（Ethereum ↔ Polygon ↔ BSC）
- 管轄區權限審批機制
- GDPR 合規：僅儲存身份雜湊，不儲存 PII

#### 4.2.7 AML 大額交易規則實作 (`AMLThresholdRule.sol`)

- 大額交易門檻檢測（預設 50,000）
- 拆分交易偵測（時間窗口累計追蹤）
- 自動申報記錄生成
- AML 審查員工作流程（審查/標記/手動建立申報）

#### 4.2.8 外匯額度規則實作 (`FXLimitRule.sol`)

- 非居民每日外匯額度限制
- 與 CCIDRegistry 整合判斷居民身份
- 豁免地址管理（機構/交易所）
- 額度變更歷史追溯

### 4.3 外部數據串接

#### 4.3.1 Chainlink ACE 整合 (`ChainlinkACEIntegration.sol`)

- 政策定義與管理
- 跨鏈合規驗證 (`verifyComplianceAcrossChains`)
- 地址政策映射

#### 4.3.2 FX 匯率整合 (`FXRateProvider.sol`)

- 多幣種匯率支援（TWD, SGD, USD, CNY）
- 即時匯率查詢與轉換

---

## 第五章 案例驗證與效益分析 (Case Study & Evaluation)

### 5.1 案例一：跨境支付場景

#### 5.1.1 實驗場景描述

- **情境**：台灣遊客在新加坡商家消費
- **參與方**：
  - 遊客（持有 TWD 穩定幣）
  - 商家（接收 SGD 結算）
  - 合規驗證節點

#### 5.1.2 交易流程演示

```
步驟 1：商家標價 100 SGD
步驟 2：遊客發起支付，調用 payWithFXConversion()
步驟 3：系統查詢 SGD/TWD 匯率（假設 1 SGD = 23.70 TWD）
步驟 4：WhitelistRule 驗證商家為已認證接收者
步驟 5：扣款 2370 TWD，鑄造 PBM 給商家
步驟 6：商家調用 settleCrossBorderPayment() 收取 SGD
```

#### 5.1.3 合規檢查點

- KYC/AML：WhitelistRule 確認商家身份
- 外匯管制：FXRateProvider 即時匯率轉換

---

### 5.2 案例二：Repo 交易場景

#### 5.2.1 實驗場景描述

- **情境**：金融機構間的短期資金融通
- **參與方**：
  - Borrower（提供代幣化公債作為抵押品）
  - Lender（提供現金）

#### 5.2.2 交易流程演示

```
步驟 1：Borrower 發起 Repo（initiateRepo）
        - 抵押品：代幣化公債 PBM
        - 借款金額：100 萬
        - Repo 利率：5% APY
        - 期限：7 天

步驟 2：Borrower 存入抵押品（fundAsBorrower）
        - CollateralRule 驗證抵押率 ≥ 150%
        - PolicyManager 驗證 Borrower 身份

步驟 3：Lender 存入現金（fundAsLender）
        - CashAdequacyRule 驗證餘額充足
        - PolicyManager 驗證 Lender 身份

步驟 4：執行原子交換（executeRepo）
        - 抵押品 → Lender
        - 現金 → Borrower

步驟 5：到期結算（settleRepo）
        - 計算利息：100 萬 × 5% × 7/365 = 958.9
        - Borrower 還款 1,000,959
        - Lender 歸還抵押品
```

#### 5.2.3 合規檢查點

- 身份驗證：雙方 KYC 通過 CCID 驗證
- 抵押品：CollateralRule 驗證 LTV
- 現金充足：CashAdequacyRule 驗證餘額

---

### 5.3 效益分析（與傳統模式對比）

| 評估維度       | 傳統模式       | 本研究實作             | 改善幅度  |
| -------------- | -------------- | ---------------------- | --------- |
| **結算時效**   | T+2            | T+0（即時）            | 100%      |
| **合規一致性** | 各機構自行解讀 | 統一 Rule 合約         | 消除差異  |
| **擴充性**     | 升級核心系統   | 部署新 Rule 合約並註冊 | 無需停機  |
| **跨境成本**   | 多層中介費用   | 直接 P2P + 鏈上手續費  | 降低 50%+ |
| **透明度**     | 事後稽核       | 即時可驗證             | 100%      |

---

## 第六章 結論與未來展望 (Conclusion)

### 6.1 研究結論

- 成功驗證基於 GL1 架構的嵌入式監理可行性
- 實作完整的可程式合規工具組（PCT）
- 證明「合規即程式碼」能有效解決傳統合規痛點

### 6.2 研究貢獻

1. 提出 GL1 標準的完整實作框架
2. 設計模組化合規規則系統，支援動態擴充
3. 實作跨境支付與 Repo 交易的嵌入式監理機制

### 6.3 未來研究方向

| 方向             | 說明                                                  |
| ---------------- | ----------------------------------------------------- |
| **隱私保護**     | ZK-Proof 在合規檢查的應用（證明合規但不揭露敏感資訊） |
| **跨鏈互操作**   | 使用 Chainlink CCIP 實現跨鏈資產轉移與合規驗證        |
| **監管儀表板**   | 為監管機構提供即時合規狀態視圖                        |
| **更多金融場景** | 擴展至衍生性商品、結構型產品等複雜金融工具            |

---

## 附錄

### 附錄 A：專案結構與程式碼對照表

| 合約檔案                      | 論文章節     | 功能說明                    |
| ----------------------------- | ------------ | --------------------------- |
| `PBMToken.sol`                | 3.1, 4.2.1   | ERC1155 Purpose Bound Money |
| `GL1PolicyManager.sol`        | 3.2, 4.2.2   | 政策編排引擎                |
| `GL1PolicyWrapper.sol`        | 3.3, 4.2.4   | 資產封裝與跨境支付          |
| `RepoContract.sol`            | 3.4, 4.2.5   | Repo 交易管理               |
| `CCIDRegistry.sol`            | 3.6, 4.2.6   | 跨鏈身份註冊表              |
| `WhitelistRule.sol`           | 4.2.3        | KYC/AML 白名單              |
| `CashAdequacyRule.sol`        | 4.2.3        | 現金充足性驗證              |
| `CollateralRule.sol`          | 4.2.3        | 抵押品驗證                  |
| `AMLThresholdRule.sol`        | 4.2.3, 4.2.7 | 大額交易申報與拆分偵測      |
| `FXLimitRule.sol`             | 4.2.3, 4.2.8 | 非居民外匯額度限制          |
| `ChainlinkACEIntegration.sol` | 3.5, 4.3.1   | 跨鏈合規驗證                |
| `FXRateProvider.sol`          | 3.5, 4.3.2   | FX 匯率提供                 |

### 附錄 B：智能合約接口規格

（可附上主要介面定義）

### 附錄 C：測試報告

（可附上 Hardhat 測試結果）
