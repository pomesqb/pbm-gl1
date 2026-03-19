
摘要
為達成自動化合規目的，本文依據 Global Layer One (GL1) 所提出之可程式合規工具組 (Programmable Compliance Toolkit, PCT) 框架規範，設計並實作一套智能合約系統。GL1 PCT 目前僅提供架構設計與規範描述而無公開之參考實作程式碼，本研究為首個將其五大核心模組（行政控制、政策封裝器、政策管理器、身份管理、合規規則引擎）以 Solidity 智能合約完整落地之學術實作。核心技術路徑在於實現「合規即程式碼 (Compliance-as-Code)」，並進一步探討將合規監理從「系統的組成部分」轉化為「合規即系統」的典範轉移。本文提出「PBM 封裝 ERC-3643」之雙層合規架構：底層以 ERC-3643 許可制代幣負責靜態合規（KYC 身份驗證、帳戶凍結與強制轉移），外層以特殊目的代幣 (PBM) 結合 ERC-7943 通用型實體資產介面標準 (uRWA) 負責動態場景合規，將反洗錢 (AML) 大額交易申報、制裁名單篩選及非居民外匯額度管控等監理邏輯，直接嵌入資產本身的傳輸路徑中。
在系統實作層面，開發了政策管理器 (Policy Manager) 作為合規邏輯的編排引擎，負責多司法管轄區規則的動態註冊與多方角色驗證。為了提升系統彈性並兼顧隱私保護，本文融合 Chainlink ACE 自動化合規引擎之跨鏈身份概念，設計符合 GDPR 規範之跨鏈身份註冊表 (CCIDRegistry)，並參考 CAST Framework 之鏈上鏈下分離策略，引入「離線檢驗、鏈上驗證」的混成模式：多數複雜的合規檢查可在鏈下由受信任機構完成，在產生數位簽署後，鏈上合約僅需驗證該簽署之效力即可作為執行背書。此種架構不僅能透過身份標籤化機制區分居民與非居民身份，進而自動觸發特定的監管邏輯，更大幅增加了規則變更的靈活性。
最後，透過跨境支付與附買回交易 (Repo) 兩大金融場景驗證此技術架構的可行性。驗證結果顯示，該機制能實現 T+0 即時結算，並在確保交易原子性的同時自動攔截不合規請求。針對離線簽署機制的探討顯示，此模式雖能有效降低鏈上運算負擔並保護敏感隱私，但在操作彈性提升的同時，也需在對受信任機構的依賴度與去中心化信任之間進行權衡。總體而言，本文證明技術應用不僅是提升效率的工具，更是達成合規監管目的之基礎設施，為未來建構安全、透明且具備互操作性的全球金融網路提供了實務路徑。
關鍵詞： 嵌入式監理、合規即程式碼、合規即系統、Global Layer One (GL1)、可程式合規工具組 (PCT)、特殊目的代幣 (PBM)、ERC-7943、ERC-3643、監理科技 (RegTech)
Abstract
To achieve the objective of automated compliance, this study designs and implements a smart contract system based on the Programmable Compliance Toolkit (PCT) framework specification proposed by Global Layer One (GL1). While the GL1 PCT currently provides only architectural design and specification documents without any publicly available reference implementation code, this study represents the first academic implementation to fully realize its five core modules (Administrative Control, Policy Wrapper, Policy Manager, Identity Management, and Compliance Rules Engine) in Solidity smart contracts. The core technical path lies in realizing "Compliance-as-Code" and further exploring the paradigm shift from "compliance as part of the system" to "Compliance as the System." This study proposes a dual-layer compliance architecture of "PBM wrapping ERC-3643": the underlying layer uses ERC-3643 permissioned tokens for static compliance (KYC identity verification, account freezing, and forced transfers), while the outer layer uses Purpose Bound Money (PBM) combined with the ERC-7943 Universal Real World Asset Interface (uRWA) standard for dynamic scenario-based compliance, embedding regulatory logic—including AML large transaction reporting, sanctions screening, and non-resident foreign exchange limit controls—directly into the transmission path of the assets themselves.
At the system implementation level, a Policy Manager was developed as an orchestration engine for compliance logic, responsible for dynamic rule registration across multiple jurisdictions and multi-party role verification. To enhance system elasticity while preserving privacy, this study incorporates the cross-chain identity concept from Chainlink's Automated Compliance Engine (ACE) to design a GDPR-compliant Cross-Chain Identity Registry (CCIDRegistry), and references the on-chain/off-chain separation strategy from the CAST Framework to introduce a hybrid model of "off-chain attestation, on-chain verification." Complex compliance checks are performed off-chain by trusted institutions; the on-chain contract then verifies the validity of the digital signature acting as an endorsement. This architecture not only distinguishes between resident and non-resident status through an identity tagging mechanism but also significantly increases the flexibility of rule updates.
Finally, the feasibility of this technical architecture is validated through two primary financial scenarios: cross-border payments and Repo transactions. Verification results demonstrate that the mechanism achieves T+0 instant settlement and automatically intercepts non-compliant requests while ensuring transaction atomicity. The discussion on the trade-offs of the "off-chain signing" mechanism reveals that while this model effectively reduces on-chain computational burdens and protects sensitive privacy, it requires a balanced consideration between operational flexibility and the reliance on trusted institutions. Overall, this study demonstrates that technical applications are not merely tools for enhancing efficiency but are essential infrastructure for achieving regulatory compliance, providing a practical path for building a secure, transparent, and interoperable future global financial network.
Keywords: Embedded Supervision, Compliance-as-Code, Compliance as the System, Global Layer One (GL1), Programmable Compliance Toolkit (PCT), Purpose Bound Money (PBM), ERC-7943, ERC-3643, RegTech
目次
摘要	I
ABSTRACT	III
目次	V
表次	IX
圖次	X
第一章 緒論	1
第一節 研究背景與動機	1
第二節 研究目的	2
第三節 研究貢獻	2
第四節 論文架構	3
第二章 文獻探討與技術背景	5
第一節 嵌入式監理 (EMBEDDED SUPERVISION)	5
壹、 典範轉移	5
貳、 從事後稽核 (Ex-post) 到先驗執行 (Ex-ante)	5
參、 合規即程式碼(Compliance-as-Code)	6
第二節 GLOBAL LAYER ONE(GL1)架構與可程式合規工具組(PCT)	6
壹、 GL1架構	6
貳、 GL1 PCT Programmable Compliance Toolkit	7
第三節 PURPOSE BOUND MONEY (PBM)基礎框架	8
第四節 ERC-7943 合規標準	10
壹、 設計動機與目標	10
貳、 核心功能模組	10
參、 與嵌入式監理架構的關聯性	11
第五節 ERC-3643：許可制代幣與合規身份標準	11
壹、 標準概述與發展背景	11
貳、 去中心化身份與合規模組	12
參、 強制轉移與交易控制	13
肆、 Chainlink ACE與ERC-3643合規協作架構	13
伍、 小結	14
第六節 CAST FRAMEWORK證券型代幣合規架構	15
壹、 CAST Framework 概述與設計理念	15
貳、 CAST 的三大核心支柱	15
參、 隱私保護與混合式數據架構	16
肆、 系統整合與互操作性	16
伍、 小結	17
第七節 CHAINLINK ACE 自動化合規引擎技術	17
壹、 技術架構與設計目標	18
貳、 核心組件功能	18
參、 與 GL1 架構的整合應用	19
第八節 鏈下與鏈上驗證權衡	19
壹、 兩種驗證模式之特性對比	19
貳、 關鍵權衡因素分析	20
第三章 系統設計與架構	22
第一節 系統總體架構	22
壹、 系統總體架構包含以下組件：	23
貳、 各組件在 GL1 四層參考模型中的對應如下：	23
第二節 雙層合規架構設計：PBM 封裝 ERC-3643	24
壹、 設計理念：靜態合規與動態合規的職責劃分	24
貳、 ERC-7943 在雙層架構中的角色	26
參、 雙層合規觸發順序	27
第三節 身份管理架構設計	29
壹、 IdentityRegistry 實作	29
貳、 CCIDRegistry 跨鏈身份註冊表	29
第四節 政策管理器與合規規則引擎設計	31
壹、 GL1PolicyManager 規則編排架構	31
貳、 ProofSet與離線檢驗機制	32
參、 信任模型與失效場景分析（Trust Model & Failure Analysis）	33
第五節 應用場景機制設計	35
壹、 跨境支付場景設計	35
貳、 附買回交易（Repo）場景設計	38
第四章 系統實作與應用分析	41
第一節 開發環境與核心工具	41
第二節 核心智能合約實作	42
壹、 ERC-3643 許可制代幣實作（ERC3643Token.sol）	42
貳、 PBM Token與ERC-7943整合實作（PBMToken.sol）	45
參、 GL1 政策封裝器實作（GL1PolicyWrapper.sol）	48
肆、 政策管理器實作（GL1PolicyManager.sol）	54
伍、 跨鏈身份註冊表實作（CCIDRegistry.sol）	56
第三節 合規規則模組實作	58
壹、 WhitelistRule—白名單規則	58
貳、 AMLThresholdRule—大額交易申報規則	60
參、 FXLimitRule—外匯累計額度規則	61
肆、 CollateralRule—抵押品規則	61
伍、 CashAdequacyRule—現金充足性規則	62
第四節 應用場景實作演示	62
壹、 跨境支付場景演示	62
貳、 附買回交易（Repo）場景演示	63
第五節 測試驗證與效益分析	72
壹、 測試架構與涵蓋範圍	72
貳、 關鍵測試案例	72
參、 效益分析	73
第五章 結論與未來研究方向	74
第一節 研究結論與成果貢獻	74
第二節 架構權衡與實務限制：「合規即程式碼」與混合架構的內在張力	76
壹、 技術層面的權衡	76
貳、 信任假設的批判性分析	77
參、 雙重防護網：技術可審計、法律可追究	77
第三節 未來研究方向	78
參考文獻	80

表次
表 1 KYC等級分級	30
表 2 身份標籤	30
表 3 RuleSet 結構欄位	31
表 4 Repo 合規檢查點	40
表 5 開發環境配置	41
表 6 合規規則模組與 GL1 範例對應	58
表 7 Repo交易各階段合規檢查	64
表 8 Repo完整合約呼叫流程總覽	65
表 9 傳統架構與本系統之比較	73

圖次
圖 1 系統總體架構圖	22
圖 2 雙層合規架構——靜態合規與動態合規的職責劃分	24
圖 3 雙層合規觸發順序圖	27
圖 4 跨境支付結算流程圖	37
圖 5 Repo 交易狀態機圖	39










第一章 緒論
第一節 研究背景與動機
金融監管的核心使命在於維護市場穩定、保護投資人權益，以及防範洗錢與資恐等不法行為。傳統金融體系達成合規目的，主要依賴「事後稽核」（Ex-post）模式：金融機構需定期向監管機關申報交易紀錄，經由人工或自動化系統審核後識別潛在風險。然而，此種模式存在顯著的時間延遲，違規交易往往在發生數日甚至數週後才被發現，難以達成即時阻斷的效果，且分散的資料庫增加了跨機構對帳的摩擦成本。
隨著全球金融體系邁向數位化，央行數位貨幣（CBDC）與資產代幣化的興起為監理帶來前所未有的挑戰。區塊鏈上的交易具備即時性與跨境流動性，若沿用傳統的事後稽核，監管能力將遠落後於市場變化。現代監理科技（RegTech）正經歷一場關鍵的典範轉移：從將合規視為「系統的一部分」（Compliance as part of the system）演進為「合規即系統」（Compliance as the system）。這意味著監理邏輯不再是外掛的行政程序，而是金融網路運行的基礎設施，確保交易在發起當下即滿足所有法規要求。
透過將法律政策編碼為可執行的指令並嵌入資產本身，可確保任何不符合監管規則的交易在發起階段即會失敗（Revert）而無法上鏈執行。這種「合規即程式碼（Compliance-as-Code）」的技術路徑，是達成自動化合規監理的關鍵。然而，若各金融機構僅依據自身需求撰寫封閉式的合規邏輯，將導致嚴重的孤島效應（Silo effect）。因此，引入具備高度互操作性的標準化框架——Global Layer One (GL1)——顯得尤為必要，其倡議的可程式合規工具組（PCT）可建立跨司法管轄區的統一標準。然而，GL1 PCT 目前僅提供了架構設計與功能規範，尚缺乏將其理念落地為可執行智能合約的參考實作，這正是本研究所欲填補的技術缺口。
此外，實務上完全將合規邏輯置於鏈上執行（On-chain Execution）面臨著效能瓶頸與隱私洩露的雙重挑戰。為了在去中心化架構與實務監管需求間取得平衡，探討如何結合特殊目的代幣（PBM）與自動化合規引擎技術，建立一套「離線受信任機構檢驗、鏈上數位簽章驗證」的混成機制，成為重要的研究方向。此機制旨在利用鏈下機構處理複雜的身份與名單篩選，並將結果以加密簽章形式上鏈，既能確保交易的原子性與不可篡改性，又能大幅提升監理邏輯的靈活性與資料隱私保護。
第二節 研究目的
本文以「達成自動化合規監管」為核心目標，探討如何將監管要求從外加的行政負擔轉型為系統內建的基礎設施。具體目的如下：
一、確立「合規即系統」之技術實踐路徑 論證技術應用不僅是提升效率的手段，更是達成金融合規的必要基礎設施。透過實作「先驗執行（Ex-ante）」模式，驗證其在即時阻斷違規交易、降低事後稽核成本上的實際效益，並確立合規邏輯內生於金融系統的技術可行性。
二、建構基於 GL1 標準之雙層混成合規架構 首次將 GL1 PCT 五大核心模組以 Solidity 智能合約落地實作，並提出「PBM 封裝 ERC-3643」之雙層合規架構，以底層 ERC-3643 許可制代幣負責靜態合規，外層 PBM 結合 ERC-7943 負責動態場景合規，實現合規邏輯與資產的解耦。同時，融合 Chainlink ACE 跨鏈身份概念與 CAST Framework 鏈上鏈下分離策略，設計「離線檢驗、鏈上驗證」的混成機制，解決全鏈上計算的隱私與效能問題。
三、實作具備簽署背書機制的嵌入式監理並分析權衡 結合 PBM 與 ERC-7943 標準，將 AML 與外匯管控邏輯嵌入資產傳輸路徑。並透過實作驗證，深入討論此混成架構在提升操作彈性與保護隱私的優勢下，對於「信任假設（Trust Assumption）」與中心化風險的權衡（Trade-offs）。
第三節 研究貢獻
本文之研究貢獻可歸納為以下四點：
一、GL1 PCT 框架之首個學術實作：GL1 PCT 目前僅提供架構設計文件而無公開之參考實作程式碼，本研究為首個將其五大核心模組（行政控制、政策封裝器、政策管理器、身份管理、合規規則引擎）以 Solidity 智能合約完整落地的學術實作，填補了從設計規範到可執行系統之間的技術缺口。
二、提出「PBM 封裝 ERC-3643」之雙層合規架構：本文創新性地將 ERC-3643 許可制代幣作為底層資產負責靜態合規（KYC 身份驗證、帳戶凍結與強制轉移），再以 PBM 封裝於外層負責動態場景合規（AML 大額交易、外匯管控、抵押品驗證），實現「靜態合規」與「動態合規」的職責劃分與解耦。
三、ERC-7943 uRWA 標準之早期整合實作與跨框架技術融合：本研究為早期將 ERC-7943 通用型實體資產介面整合進完整嵌入式監理系統的學術作品，並融合 Chainlink ACE 跨鏈身份概念（CCIDRegistry）與 CAST Framework 鏈上鏈下分離策略及附買回交易狀態機設計，建構出跨框架的合規解決方案。
四、以真實金融場景驗證之實務可行性：透過跨境支付（含 FX 匯率轉換）與附買回交易（Repo）兩大金融場景之完整實作與演示，驗證本架構在 T+0 即時結算、交易原子性保障與不合規請求即時攔截等方面之實務效益，並深入分析混合架構在「效率、隱私與去中心化」三難困境中之權衡。
第四節 論文架構
本研究分為五個章節。
第一章 緒論。說明傳統金融監理在數位轉型下面臨的結構性挑戰，並定義「合規即系統」的新典範。旨在利用國際標準化框架，結合混合式驗證機制，以解決自動化合規中效率、隱私與信任難以兼顧的根本問題。
第二章 文獻探討與技術背景。分析嵌入式監理定義、GL1 四層架構模型、特殊目的代幣 (PBM) 原理、ERC-7943 合規標準、ERC-3643 許可制代幣標準、CAST Framework 證券型代幣合規架構及 Chainlink ACE 自動化合規引擎等技術背景，並探討鏈下與鏈上驗證之權衡，為自動化合規機制建立理論基礎。
第三章 系統設計與架構。提出「PBM 封裝 ERC-3643」之雙層合規架構，說明底層資產（ERC-3643）負責靜態合規，外層封裝（PBM / ERC-7943）負責動態場景合規的職責劃分。詳述政策管理器、身份管理架構與合規規則引擎的設計，以及跨境支付與附買回交易兩大應用場景的機制設計。
第四章 系統實作與應用分析。展示以 Solidity 實作之 ERC-3643 許可制代幣、PBM Token（整合 ERC-7943）、政策封裝器、政策管理器及五個合規規則模組的技術細節，並透過跨境支付與 Repo 交易兩大場景演示驗證系統可行性。
第五章 闡述本研究之發現、架構權衡分析與未來研究上的建議。
第二章 文獻探討與技術背景
第一節 嵌入式監理 (Embedded Supervision)
嵌入式監理 (Embedded Supervision) 的概念代表了金融監管模式的重大典範轉移。隨著分散式帳本技術 (DLT) 與代幣化資產的發展，監管機關不再僅是金融市場的外部觀察者，而是有能力透過技術架構將監管規則直接「嵌入」至市場基礎設施之中。本節將探討此典範轉移如何從將合規視為系統的附加元件，演進為系統本身的內生邏輯，並分析其如何透過「合規即程式碼」的技術手段，達成自動化監管的目的。
壹、 典範轉移
從「系統的一部分」到「合規即系統」 現代監理科技 (RegTech) 的發展核心在於重新定義合規在金融架構中的位置。過去，合規往往被視為系統的一部分，即在交易流程之外，附加一個獨立的檢查環節或部門來處理法規要求。然而，這種外掛式的設計在面對區塊鏈即時且全天候的交易特性時，顯得力不從心。 (Latka, 2025)
新一代的嵌入式監理倡議提出了合規即系統的概念。此觀點主張監管合規性不應是事後的補救或外部的監控，而應直接內建於交易處理的核心流程中。透過將法律規則轉化為機器可讀 (Machine-Readable) 與機器可執行 (Machine-Executable) 的邏輯，合規成為了金融系統運作的先決條件——即交易若不合規，在系統層面上根本無法被執行。這不僅解決了資訊不對稱的問題，更將監管從被動的「監督者」轉化為系統運作的「基礎設施」。
貳、 從事後稽核 (Ex-post) 到先驗執行 (Ex-ante) 
傳統金融監理主要依賴「事後稽核」模式。在此模式下，金融機構需在交易發生後，定期整理數據並向監管機構申報。這不僅造成合規成本高昂，且存在顯著的時間延遲，導致監管機構往往在風險事件發生後才能介入，無法有效阻斷違規行為。此外，傳統模式下的數據分散在各機構的私有資料庫中 (Siloed Data)，增加了數據驗證與整合的困難。
相對而言，嵌入式監理強調「先驗執行」。透過智能合約 (Smart Contracts) 與可程式化資產的特性，監管規則被編碼進資產或交易協議中。當一筆交易被發起時，系統會自動參照預設的監管參數（如交易限額、黑名單篩選、資產類別限制）進行即時驗證。若交易不符合合規要求，將在執行階段直接被區塊鏈網路拒絕 (Revert)。這種轉變將合規檢核的時間點從「交易後 (Post-trade)」提前至「交易前 (Pre-trade)」，從根本上消除了違規交易上鏈的可能性。
參、 合規即程式碼(Compliance-as-Code)
為了達成嵌入式監理的宏觀目標，技術層面必須落實「合規即程式碼」。這意味著監管政策不再僅是寫在紙本上的法律條文，而是直接轉化為演算法邏輯。根據歐盟區塊鏈觀察與論壇的分類 (EU Blockchain Observatory & Forum)，這類技術實踐可分為兩大層次：
一是監理節點 (Supervisor Node)，即監管者作為區塊鏈網路中的一個節點，擁有即時讀取全網數據的權限，可實現自動化的市場監控與報告生成；二是嵌入式執行 (Embedded Enforcement)，利用代幣標準或特殊目的載體將規則綁定於資產本身。例如，在央行數位貨幣 (CBDC) 或代幣化存款的設計中，資金的流動必須滿足附帶的程式邏輯（如專款專用、反洗錢檢核）才能完成轉帳。此技術路徑確保了監管的一致性與不可篡改性，大幅降低了人為操作錯誤與惡意規避法規的風險，為全球金融體系提供了一種更具效率且透明的合規解決方案。
第二節 Global Layer One(GL1)架構與可程式合規工具組(PCT)
壹、 GL1架構
嵌入式監理的理念在概念層面揭示了合規監管的新範式，但要將此理念轉化為可落地的基礎設施，則需要一個具備跨機構互操作性的標準化框架。Global Layer One(GL1)即是針對此需求而設計的數位金融基礎設施倡議，其所提供的可程式合規工具組(PCT)，正是實現「合規即程式碼」的技術載體。
GL1是一項由全球多家受監管金融機構與新加坡金融管理局(MAS)共同推動的數位金融基礎設施倡議 (GL1, Foundation Layer for Financial Networks, 2024)。其核心動機在於解決當前金融體系中資料庫孤島、通訊協議不一以及手動對帳所導致的高昂成本與流動性碎片化問題。GL1旨在開發一個多用途、基於分散式帳本技術(DLT)的共享基礎設施，使受監管機構能跨司法管轄區部署具備互操作性的數位資產應用，並在符合監管預期的前提下，支援發行、交易、結算及支付等金融價值鏈環節。
GL1的技術藍圖採用四層參考模型來確保系統的擴展性與互通性。
一、 接入層(Access Layer)負責處理用戶端點、錢包管理與身分驗證，由金融機構執行身分入駐(Onboarding)與KYC/AML檢查。
二、 服務層(Service Layer)提供核心應用邏輯，如跨行轉帳、抵押品管理及跨鏈傳輸，並支援原子結算(DvP、PvP)功能。
三、 資產層(Asset Layer)支持原生發行或代幣化的現金、債券及其他數位化實體資產(RWA)，確保資產能跨應用無縫流動。
四、 平台層(Platform Layer)即GL1核心，提供區塊鏈底層帳本、虛擬機、共識機制及數據標準化服務，確保不同機構能在統一的數位基礎設施上進行公平競爭。
貳、 GL1 PCT Programmable Compliance Toolkit
為了將監理規範有效整合至數位體系中，GL1推出了可程式合規工具組(Programmable Compliance Toolkit,PCT) (GL1, 2025)，這是一套用於自動化合規檢查與即時執行法規要求的技術框架。PCT的核心理念是將特定司法管轄區的法律政策轉化為合規即程式碼(Compliance-as-Code)，直接嵌入資產的轉移流程中，實現先驗執行(Ex-ante enforcement)而非傳統的事後稽核。
PCT包含五個核心功能模組。
一、 行政控制(Administrative Control)系統，提供監理機構在發生違規或緊急情況下凍結帳戶、恢復資產及實施緊急斷路器的權限。
二、 政策封裝器(Policy Wrapper)，這是一種適應層技術，透過鎖定與鑄造(lock-and-mint)機制，在不修改代幣底層合約的情況下，強制資產在傳輸前必須通過特定的法規驗證。
三、 政策管理器(Policy Manager)，作為協調層，負責編排政策封裝器與外部多個專門模組(如身分管理系統或規則引擎)之間的查詢與回應匯整。
四、 身分管理(Identity Management)模組，利用加密技術與可驗證憑證(VC)來驗證參與者身分，同時保護隱私並符合數據保護規範。
五、 合規規則引擎(Compliance Rules Engine)，負責執行具體的驗證邏輯，例如外匯限額檢查、資本流動管理及制裁名單篩選。
透過PCT工具組，金融機構能在符合隱私保護與各國法規的前提下，達成資產的原子結算，顯著降低跨境交易中的手動對帳負擔與人為錯誤風險。這套架構不僅解決了代幣化資產跨國流動時的規則不一問題，更為未來數位金融基礎設施的標準化建設提供了明確的實踐參考。
這套架構就像是在金融網絡上建立了一套自動化的數位海關系統，確保每一筆資產在跨境過關時，都已自動完成身分查驗與法規申報。
第三節 Purpose Bound Money (PBM)基礎框架
GL1架構提供了合規工具的整體組織與編排能力，但合規邏輯如何具體地「附著」於資產之上？Purpose Bound Money(PBM)提供了一種將「價值」與「使用規則」分離的技術路徑，使監理規則得以在資產生命週期中強制執行，同時保持底層貨幣的完全互通性。
PBM，即「特殊目的貨幣」，是由新加坡金融管理局（MAS）所提出的可程式化數位貨幣模型。其設計初衷是為了解決傳統「可程式化貨幣」（Programmable Money）可能導致的市場碎片化問題。PBM的核心理念是將貨幣的「價值」與其「使用規則」分開處理，從而創造出一種既可控又可互通的數位資產。 (MAS, 2023)
PBM的基礎架構主要由以下三個核心元件構成 (PurposeBoundMoney / PBM, 2023)：
一、 底層數位貨幣(Store of Value)：這通常是一個標準的ERC-20代幣，作為PBM的底層抵押品或價值儲存。 (OpenZeppelin ERC-20)
二、 PBM 封裝器(PBM Wrapper)：PBM的主要合約，在技術上常以ERC-1155標準實作 (OpenZeppelin ERC-1155)。其職責是作為一個「封裝器」，負責在PBM鑄造時，鎖定等值的底層ERC-20代幣作為抵押。而在PBM被兌換時，負責銷毀PBM代幣，並釋放底層的ERC-20代幣給兌換者。
三、 PBM邏輯(PBM Logic)：獨立的抽象合約，是PBM靈活性的關鍵。它負責定義客製化的商業邏輯，例如限制PBM只能由特定商家兌換，或在特定時間後才能使用。PBM封裝器在執行關鍵動作（如轉移或兌換）時，會主動去呼叫PBM邏輯合約中的查核機制。
基礎框架定義了兩個核心查核機制：
轉移前檢查 (Pre-transfer Check)：在PBM轉移前進行檢查（例如，檢查接收地址是否在黑名單中）。
解封裝前檢查 (Unwrap Check)：在PBM解封裝前進行檢查（例如，檢查兌換者地址是否為「認可商家」）。
PBM 運作機制：
* 發行 (Issue)：PBM創造者（如政府或企業）先部署PBM邏輯合約來定義規則，然後部署PBM封裝器合約。創造者批准封裝器合約使用其底層資產，然後觸發鑄造機制，將底層資產鎖定在封裝器合約中，並鑄造出等值的PBM（ERC-1155）代幣。
* 分發 (Distribute)：創造者將PBM代幣分發給PBM持有者（如民眾或員工）。
* 轉移 (Transfer)：持有者之間可以相互轉移PBM代幣。每次轉移都會觸發轉移前檢查機制。
* 兌換 (Redeem)：當PBM持有者將PBM轉移給一個符合「解封裝前檢查」條件的地址時（例如，一個「認可商家」），PBM封裝器合約會觸發「解封裝」。
* 解封裝 (Unwrap)：PBM代幣被銷毀，同時合約將釋放內部鎖定的等值底層資產給該「認可商家」。
* 流通 (Circulation)：該商家收到的是不受任何限制的底層資產，可以自由地在二級市場上使用或交易。
透過此架構，PBM成功地在「發行到兌換」的生命週期中施加了嚴格的用途限制，但一旦兌換完成，其底層價值又會回歸為完全可互通的通用貨幣，從而避免了市場的碎片化。
第四節 ERC-7943 合規標準
 隨著實體資產代幣化（Real World Assets, RWAs）成為連接傳統金融與去中心化金融（DeFi）的核心橋樑，如何在區塊鏈上落實法律合規、資產凍結及強制轉移，成為現行技術標準亟待解決的問題。本研究採用的 ERC-7943 (Universal Real World Asset Interface, uRWA) 標準，即是針對此類需求所提出的通用型介面規範。 (Buglio, 2025)
壹、 設計動機與目標
傳統代幣標準如 ERC-20、ERC-721 及 ERC-1155 在設計之初並未考慮到法律監管的強制性需求。過去雖然有如ERC-3643等標準嘗試解決合規問題，但往往因過於複雜的權限控制或綁定特定的鏈上身分方案，導致其實施成本過高且缺乏靈活性。 (OpenZeppelin ERC-20) (OpenZeppelin ERC-721) (OpenZeppelin ERC-1155)
ERC-7943的設計目標在於「極簡主義（Minimalism）」與「非偏好性（Unopinionated）」。它並不強加特定的合規檢查邏輯，而是提供一套標準化的介面，讓開發者能根據具體的監管需求實作相應的合規規則。
貳、 核心功能模組
ERC-7943擴展了基礎代幣標準，引入了以下關鍵的合規與強制執行功能：
一、 先驗合規驗證(canTransact與canTransfer)：這是落實「嵌入式監理」的核心機制。canTransact主要用於驗證特定地址是否具備交易資格（如已完成KYC/AML審查），而canTransfer則根據特定政策（如每日交易限額）動態判斷該筆轉帳是否被允許。若驗證未通過，交易將直接在發起階段失敗，達成先驗執行 (Ex-ante) 的監理目標。
二、 資產凍結管理(setFrozenTokens)：該介面允許授權機構針對特定帳戶設定凍結金額或狀態。這對於因涉嫌洗錢防制或受制裁名單控管的資產至關重要，能有效防止有風險的資產在調查期間流動。
三、 行政強制轉移 (forcedTransfer)：此功能提供了一個中性的法律強制執行手段。當發生司法判決扣押、法律合規處置或私鑰丟失後的資產恢復情境時，授權實體能跳過用戶意願，直接將資產從受限地址轉移至監管託管地址。
參、 與嵌入式監理架構的關聯性
在Global Layer One (GL1)的架構下，ERC-7943充當了「資產層」與「服務層（合規邏輯）」之間的技術契合點。相較於傳統的事後稽核，ERC-7943 配合 GL1 的政策管理器(Policy Manager)，能確保每一筆RWA交易在執行前都經過模組化合規引擎的檢查。
這種架構優勢在於：
一、 可組合性：確保代幣化的債券或存款能與DeFi協議安全互動，並在交易瞬時自動滿足監管期望。
二、 相容性：其設計支援 Fungible (同質化) 與 Non-Fungible (非同質化) 資產，實現了不同類別RWA的監理標準化。
第五節 ERC-3643：許可制代幣與合規身份標準
壹、 標準概述與發展背景
ERC-3643，又稱為 T-REX (Token for Regulated EXchanges) 協議，是一套專為受監管資產（Regulated Assets）與證券型代幣（Security Tokens）設計的以太坊代幣標準。該標準由 Tokeny Solutions 提出，並於 2023 年 12 月正式通過成為以太坊最終標準（Final Standard）。
與強調無需許可（Permissionless）的 ERC-20 標準不同，ERC-3643 的核心設計哲學在於引入「許可制（Permissioned）」機制。其目標是在保持與 ERC-20 技術兼容性（Interoperability）的同時，確保代幣的持有與轉移完全符合監管要求（如 KYC/AML）。根據 ERC-3643 協會的定義，該標準特別適用於證券、現實世界資產（RWA）、忠誠度計畫及電子貨幣（E-Money）等需要發行方對帳本具備控制權的場景。 (ERC-3643) ((ERC-3643 Association) - Building Compliant RWA Infrastructure: From Regulatory, 2025)
貳、 去中心化身份與合規模組
ERC-3643 的運作依賴於一套模組化的智能合約體系，其核心創新在於將「身份驗證（Identity）」與「合規規則（Compliance）」從代幣合約中解耦。其架構主要包含以下關鍵組件：
一、 鏈上身份系統 (ONCHAINID)： ERC-3643 不直接將錢包地址視為用戶身份，而是採用了基於 ERC-734 與 ERC-735 的去中心化身份（DID）系統，稱為 ONCHAINID。每個投資者的錢包地址會連結到一個唯一的身份合約，該合約儲存了由受信任第三方（如 KYC 提供商）簽發的可驗證憑證（Verifiable Credentials/Claims）。這種設計允許「身份」與「錢包」分離，若用戶遺失私鑰，可透過更換錢包地址而無需重新進行 KYC，從而實現帳戶恢復功能。
二、 身份註冊表 (Identity Registry)： 這是連接代幣與身份的樞紐。發行方會維護一份受信任的聲明發行者（Trusted Claim Issuers）名單（例如合規的 KYC 供應商）以及所需的聲明主題（Claim Topics，如「合格投資人」或「美國居民」）。在轉帳發生時，代幣合約會查詢註冊表，驗證接收方的 ONCHAINID 是否持有有效的合規憑證。
三、 模組化合規引擎 (Modular Compliance)： 除了身份資格外，交易還需通過動態的合規規則檢查。ERC-3643 允許發行方插拔不同的合規模組（Modules），例如限制單一國家的投資人總數、每日交易限額或閉鎖期限制。這與 BlackRock 的 BUIDL 代幣所使用的簡單白名單機制不同，ERC-3643 提供了更高的彈性，可針對不同資產類別設定複雜的邏輯。
參、 強制轉移與交易控制
為了滿足證券法規中對於資產恢復與法律執行的要求，ERC-3643 引入了數個 ERC-20 所缺乏的控制功能，這在被稱為「行政控制（Administrative Control）」：
? 強制轉移 (forcedTransfer)：允許發行方或指定代理人在無需私鑰簽名的情況下，強制移動投資人帳戶內的代幣。此功能主要用於法律強制執行（如法院命令扣押）、資產恢復或錯誤交易回滾。
? 暫停與凍結 (Pause/Freeze)：發行方可針對特定地址進行凍結，或在緊急狀況下暫停整個合約的交易功能，以應對駭客攻擊或重大合規事件。
雖然這些功能賦予了發行方極大的權力，但在受監管的金融市場中，這是確保資產負債表完整性與法律合規性的必要手段。
肆、 Chainlink ACE與ERC-3643合規協作架構
Chainlink ACE (Automated Compliance Engine) 與 ERC-3643 的關係可以形容為「基礎設施與代幣標準的深度整合」。Chainlink ACE 並非要取代 ERC-3643，而是作為一套增強工具，賦予 ERC-3643 代幣跨鏈互操作性、動態合規能力以及更強的機構級身份驗證。 (Luxembourg, 2025)
一、 戰略合作夥伴關係
雙方的合作旨在解決機構級資產在區塊鏈上面臨的「孤島問題」與「合規數據整合問題」。透過將 ACE 整合進 ERC-3643，該標準得以從原本的單一鏈上許可制代幣，演進為跨鏈、動態且策略驅動的資產標準。
二、 技術整合點
兩者的結合主要體現在以下三個層面：
(一). 身份層的擴展 (Identity Extension)：CCID與ONCHAINID的結合
ERC-3643原生機制：ERC-3643 內建了一套名為 ONCHAINID 的身份系統，用來儲存用戶的資格憑證（Verifiable Credentials）。
ACE的加值：Chainlink ACE 的 CCID (Cross-Chain Identity) 服務與 ERC-3643 進行了對接。這意味著原本僅在某一條鏈上有效的 ONCHAINID 憑證，現在可以透過 CCID 進行跨鏈同步與管理。
效益：這讓 ERC-3643 代幣的持有者只需進行一次 KYC，其身份憑證即可透過 Chainlink 的基礎設施在不同的區塊鏈網絡中被重複使用與驗證。
(二). 合規邏輯的動態化：Policy Manager 的介入
ERC-3643 原生機制：ERC-3643 使用 Compliance Modules 來檢查交易是否合規（例如人數上限、國籍限制）。
ACE的加值：在雙方合作的實作中，ERC-3643 代幣可以將合規檢查的邏輯「外包」給 Chainlink ACE 的 Policy Manager。
效益：動態更新，發行方可以在鏈下透過 Policy Manager 修改合規規則（例如調整制裁名單或交易限額），而無需重新部署或升級鏈上的代幣合約。
引入vLEI：透過 Policy Manager，ERC-3643 代幣可以直接驗證由 GLEIF 發行的 vLEI (可驗證法人機構識別編碼)，這在純鏈上環境中是很難做到的。
(三). 跨鏈互操作性 (Interoperability)
透過整合Chainlink的CCIP (Cross-Chain Interoperability Protocol)，ERC-3643 代幣得以在不同的區塊鏈之間安全轉移，同時保持其合規狀態（例如：確保代幣從 Ethereum 轉到 Polygon 時，接收方依然符合 KYC 資格）。
伍、 小結
ERC-3643 提供了一套完整的 RWA 代幣化解決方案，其優勢在於標準化的身份介面與細緻的權限控制。與ERC-7943 相比，ERC-3643 的架構較為龐大且具備特定的身份實作（ONCHAINID），而 ERC-7943 則採取更輕量化、非偏好性（Unopinionated）的設計理念。然而，ERC-3643 在處理複雜證券型代幣的生命週期管理（如配息、股東會投票）上，仍提供了目前市場上最成熟的參考範本。
第六節 CAST Framework證券型代幣合規架構
壹、 CAST Framework 概述與設計理念
CAST (Compliant Architecture for Security Tokens) Framework 是一套由法國興業銀行子公司 Societe Generale – FORGE 提出的開源框架，旨在為證券型代幣的發行、交易及結算提供一套符合現行受監管金融市場標準的操作模型。CAST Framework 的核心設計理念在於「混合化 (Hybridization)」，即將區塊鏈技術的優勢（如分散式帳本、智能合約）與傳統資本市場的營運標準、法律框架及銀行級 (Bank-grade) 的安全要求相結合。 (Forge, 2021)
CAST Framework 特別強調針對「原生證券型代幣 (Native Security Tokens)」的支援，這類代幣是直接在分散式帳本技術 (DLT) 上發行並作為所有權證明的金融工具，而非僅是現有證券的數位分身 (Non-native)。其目標是透過標準化的介面與流程，解決傳統金融機構在採用 DLT 時面臨的互操作性不足、監管不確定性及營運流程整合困難等痛點。
貳、 CAST 的三大核心支柱
為了實現金融資產的代幣化並符合監管要求，CAST Framework 的架構由三個相互交織的組件構成：
營運組件 (Operational Component)： 此組件定義了代幣完整生命週期（從發行、交易到公司行動如配息）的標準流程，並明確界定了市場參與者的角色與職責。參考了 ISO 20022 等現有金融標準，CAST 定義了如註冊代理人 (Registrar)、清算代理人 (Settlement Agent) 及託管人 (Custodian) 等角色的互動模式。特別是註冊代理人，在 CAST 架構中扮演關鍵角色，負責在鏈上維護持有人名冊並執行合規監控。
法律與監管組件 (Legal & Regulatory Component)： 鑑於金融市場的高度監管特性，CAST 提供了一套合約框架與法律評估範本，確保代幣化資產的操作符合現行的證券法規、KYC/AML（反洗錢）要求及制裁名單篩選。該框架強調在去中心化技術中引入法律責任主體，透過代理協議 (Agency Agreement) 將發行方、投資人與中介機構的權利義務具體化。
技術組件 (Technical Component)： 技術組件定義了智能合約的標準介面、數據隱私管理機制以及與傳統系統介接的技術規範。CAST 採用技術中立 (Technology-agnostic) 的設計，支援不同的 DLT 底層協議（如 Ethereum, Tezos 等），並透過預言機 (Oracles) 實現鏈上與鏈下系統的資料同步。
參、 隱私保護與混合式數據架構
CAST Framework 在隱私保護與監管透明度之間取得平衡的關鍵創新在於引入了「清算交易儲存庫 (Settlement Transaction Repository, STR)」的概念。鑑於公有鏈或聯盟鏈上的數據可能過於透明，無法滿足金融機構對客戶隱私（如 GDPR）及商業機密的保護需求，CAST 採取了鏈上與鏈下分離的混合儲存策略：
鏈上 (On-chain)： 僅記錄代幣的餘額、狀態及結算流程的狀態機 (State Workflow)，確保交易的不可竄改性與終局性。
鏈下 (Off-chain) - STR： 由註冊代理人管理的 STR 負責儲存詳細的交易條款、對手方身份資訊及結算細節。
這種設計不僅解決了隱私問題，還充當了業務連續性計畫 (BCP) 的核心。若底層區塊鏈發生故障，註冊代理人可依據 STR 的紀錄重建帳本，確保資產權益不受技術風險影響。
肆、 系統整合與互操作性
為了讓傳統銀行系統（Legacy Systems）能無縫接入代幣化生態，CAST 開發了一套開源的 Oracle (預言機) 工具。這些 Oracle 充當適配器 (Adapter) 的角色，能夠將傳統系統的指令（如 SWIFT 訊息或 API 請求）轉換為區塊鏈上的交易或查詢指令，反之亦然。
此外，針對款券同步交割 (DvP) 的需求，CAST 支援跨鏈互操作性，允許資產端（證券型代幣）與資金端（如 CBDC 或穩定幣）分別在不同的分類帳上運行，並透過哈希時間鎖定合約 (HTLC) 或其他跨鏈協議實現原子清算。
伍、 小結
綜上所述，CAST Framework 提供了一個「由銀行主導、符合監管」的代幣化實作範本。本研究將以此架構作為實務對照，並與前述的 GL1 及嵌入式監理 (Embedded Supervision) 概念進行以下幾個層面的整合與比較：
與 GL1 架構的互補性： CAST 所強調的 Oracle 整合與鏈上鏈下分離機制，與 GL1 架構在處理異質系統介接時的理念有異曲同工之妙。GL1 試圖將這些標準推向全球基礎設施層級，而 CAST 則提供了在單一發行專案中具體落實的操作細節。
合規執行模式的演進： CAST 架構中，KYC/AML 檢查主要由鏈下的註冊代理人 (Registrar) 負責，這屬於「指定代理人執行合規」的模式。相比之下，本研究旨在透過 PCT 工具組與智能合約，進一步實現「合規即程式碼 (Compliance-as-Code)」，將部分人為操作轉化為系統自動執行的規則（如 GL1 中的 Policy Manager）。
對 Repo 交易設計的參考： CAST 在技術組件中提到的抵押品管理、狀態機設計以及 DvP 結算流程，直接為本研究後續章節設計「附買回交易 (Repo)」智能合約提供了具體的邏輯參考，特別是在處理資產鎖定與跨鏈結算的原子性方面。
第七節 Chainlink ACE 自動化合規引擎技術
隨著金融資產代幣化（Tokenization）的發展，如何將傳統金融的合規要求（如 KYC/AML、資本管制）延伸至區塊鏈環境，同時解決「鏈上隱私」與「鏈下數據整合」的兩難，成為技術實作的關鍵瓶頸。
Chainlink Automated Compliance Engine (ACE) 是一套由 Chainlink 推出的模組化合規解決方案，旨在解決受監管機構在區塊鏈上進行數位資產交易時面臨的合規與隱私挑戰。ACE透過預言機（Oracle）連接鏈下既有的合規系統與鏈上智能合約，實現「合規即代碼（Compliance-as-Code）」的自動化執行。 (Chainlink, 2025) (Chainlink, Introducing Chainlink Automated Compliance Engine (ACE): Enabling Compliance-Focused Digital Assets Across Chains and Jurisdictions, 2025)
壹、 技術架構與設計目標
ACE 的設計目標是為金融機構提供一個統一的標準介面，使其能在不更動現有後端系統的前提下，將傳統金融的合規政策（如 KYC/AML、制裁篩選）延伸至區塊鏈環境。其架構採用了混合運算模式，將敏感數據的驗證保留在鏈下進行，僅將加密證明傳送至鏈上，藉此解決鏈上隱私洩露與運算成本過高的問題。
ACE 的運作不侷限於單一區塊鏈，而是支援跨鏈操作。透過整合跨鏈互操作性協議（CCIP），允許合規政策在資產跨越公有鏈或私有鏈轉移時持續生效，確保資產在整個生命週期中皆處於受監管狀態。
貳、 核心組件功能
根據 Chainlink 的技術架構定義，ACE 由以下幾個關鍵組件構成，分別負責身份識別、規則執行與資產介接：
一、 跨鏈身份識別 (Cross-Chain Identity, CCID) CCID 是一種可重複使用的去中心化身份框架，用於將鏈下的實體驗證憑證（如 LEI 代碼、KYC 證明）與鏈上的錢包地址進行綁定。
(一). 隱私保護機制：CCID 不會在鏈上儲存個人的非公開資訊。相反，它儲存的是由受信任機構（如身份驗證服務商 IDVs）簽發的加密證明，證明該地址持有者已通過特定檢查（例如：是否為合格投資人、是否在制裁名單外）。
(二). 信任模型：CCID 支援多種信任模型，包括由資產發行方自行驗證、依賴第三方 IDV，或整合全球法人機構識別編碼（GLEIF）發行的 vLEI，實現跨機構的身份互認。
二、 2. 政策管理器 (Policy Manager) 政策管理器是一個可客製化的規則引擎，負責定義、管理並執行合規邏輯。它允許發行方將法律規則轉化為智能合約可讀的指令。
(一). 生命週期管理：政策的執行分為定義（鏈下設定規則）、執行（計算交易是否合規）與強制（鏈上確認結果）三個階段。
(二). 動態規則：管理者可隨時更新規則（如調整轉帳限額、更新黑名單），而無需重新部署資產合約。常見的內建策略包括允許/拒絕名單（Allow/Deny List）、交易速率限制（Rate Limit）與餘額上限控制。
參、 與 GL1 架構的整合應用
在 Global Layer One (GL1) 的參考模型中，Chainlink ACE 被視為「可程式合規工具組（Programmable Compliance Toolkit, PCT）」的具體技術實作範例。
一、 身份協調：ACE 對應於 GL1 架構中的「身份管理模組（Identity Management Module）」，負責處理跨生態系統的身份對帳與憑證驗證。
二、 規則執行：ACE 的 Policy Manager 承擔了 GL1 中「合規規則引擎（Compliance Rules Engine）」的角色，負責執行如資本流動管理等複雜邏輯。
三、 政策封裝：ACE 支援 GL1 提出的「政策封裝器（Policy Wrapper）」概念。在資產轉移前，Wrapper 會呼叫 ACE 進行預驗證，只有當 Policy Manager 確認交易雙方身份合規（如具備有效 CCID）且未違反政策時，資產才能被解鎖並完成結算。
綜上所述，Chainlink ACE 提供了一套標準化的基礎設施，透過將身份驗證與政策執行從底層資產中解耦，實現了跨鏈、跨司法管轄區的自動化合規管理。
第八節 鏈下與鏈上驗證權衡
「合規即系統 (Compliance as the System)」的理想狀態是將監管規則內化為區塊鏈的基礎設施，確保交易在發起時即滿足合規要求。然而，在實務落地層面，若要將此範式應用於複雜的金融監理場景，單純依賴「全鏈上執行」會面臨顯著的技術瓶頸。因此，本系統採用了「鏈下檢驗、鏈上驗證」的混合架構作為解決方案。本節將探討此架構如何作為落實「合規即系統」的務實路徑，並分析其在不同維度上的權衡。 (Latka, 2025)
壹、 兩種驗證模式之特性對比
全鏈上驗證模式 (Full On-chain Mode) 此模式體現了最純粹的「程式碼即法律」精神。所有的監管參數（如餘額檢查、基礎白名單）皆儲存於鏈上。
特性：去中心化程度最高，透明度最強。
侷限：難以處理高頻更新的黑名單或涉及隱私的資料比對。
鏈下檢驗、鏈上驗證模式 (Hybrid/Off-chain Mode) 此模式將複雜的合規運算（如 AML 模糊比對）移至鏈下受信任機構（或預言機節點）執行，鏈上合約僅負責驗證該機構簽發的「合規證明（簽章）」。 (How Chainlink ACE and GL1 Standardize Onchain Compliance | MAS, Banque de France, Chainlink at SFF, 2025)
特性：兼顧了 Web2 的運算效能與 Web3 的結算原子性。
侷限：引入了對簽署者的信任假設。
貳、 關鍵權衡因素分析
為了在現有技術限制下最大程度地實現「合規即系統」，本研究在以下三個關鍵維度進行了權衡：
突破鏈上運算瓶頸(Computational Scalability)：合規應在「互動點」即時執行。然而，反洗錢 (AML) 篩選往往涉及百萬級別的資料比對。若強行在鏈上執行，將導致嚴重的網路擁塞與延遲。透過混成模式，我們利用鏈下伺服器的高效能運算來維持金融交易所需的毫秒級響應，確保「預設合規」不會成為交易效率的絆腳石。
資料隱私與法規合規 (Privacy & GDPR Compliance)：「合規即系統」不代表所有數據都必須公開。將用戶實名資料直接上鏈與 GDPR 的「被遺忘權」存在本質衝突。在鏈下處理敏感個資，僅將去識別化的簽章上鏈。這是在「監管透明度」與「用戶隱私權」之間所做的必要權衡，確保合規機制本身也符合隱私法規的要求。
解決外部數據孤島問題(Connectivity)：智能合約無法主動獲取外部世界的制裁名單更新。為了讓系統能即時反映最新的監管政策，必須引入鏈下檢驗機制來連接外部數據庫（如銀行黑名單）。雖然這犧牲了部分的去中心化（需信任數據源），但卻是讓嵌入式監理能與真實金融世界接軌的唯一途徑。
第三章 系統設計與架構
第一節 系統總體架構
下圖展示本系統的總體架構：

圖 1 系統總體架構圖
壹、 系統總體架構包含以下組件：
一、 DApp / 前端介面作為使用者入口
二、 DApp 呼叫 GL1PolicyWrapper，GL1PolicyWrapper 委派 GL1PolicyManager，GL1PolicyManager 查詢 CCIDRegistry 與規則引擎
三、 雙層合規架構中，GL1PolicyWrapper（PCT: 政策封裝器 + 行政控制）管理外層 PBMToken（ERC-1155，整合 ERC-7943 uRWA 介面）與內層 ERC3643Token（許可制代幣），兩層透過 wrap / unwrap機制連結。
四、 政策編排層由 GL1PolicyManager（PCT: 政策管理器）負責
五、 身份管理層包含 CCIDRegistry（PCT: 身份管理，參照 Chainlink ACE CCID）與 IdentityRegistry
六、 PCT 合規規則引擎包含 WhitelistRule、AMLThresholdRule、FXLimitRule、CollateralRule、CashAdequacyRule 五個規則合約
七、 IdentityRegistry 橋接至 CCIDRegistry，ERC3643Token 依賴 IdentityRegistry。
八、 鏈下層（Off-chain）由受信任機構提供 KYC/AML 服務，受信任機構簽發合規證明（ProofSet）送至 GL1PolicyManager

貳、 各組件在 GL1 四層參考模型中的對應如下：
一、 接入層（Access Layer）：DApp / 前端介面
二、 服務層（Service Layer）：GL1PolicyManager（政策編排）、CCIDRegistry（身份管理）、合規規則引擎（五個 Rule 合約）
三、 資產層（Asset Layer）：GL1PolicyWrapper（政策封裝器）、PBMToken（外層 PBM）、ERC3643Token（底層許可制代幣）、IdentityRegistry
四、 平台層（Platform Layer）：Ethereum / EVM 兼容鏈

合約間調用鏈：使用者呼叫 GL1PolicyWrapper → GL1PolicyWrapper 委派 GL1PolicyManager 進行合規驗證 → GL1PolicyManager 呼叫 CCIDRegistry（身份）與各規則合約（規則） → 驗證通過後 GL1PolicyWrapper 透過 PBMToken 鑄造 PBM 代幣。此分層確保職責分離，新增規則僅需部署新合約並註冊，無需修改現有合約。
第二節 雙層合規架構設計：PBM 封裝 ERC-3643
傳統單層合規將所有邏輯集中於代幣合約，面對多場景、跨管轄區的需求時缺乏彈性。本研究提出「PBM 封裝 ERC-3643」之雙層合規架構，將合規職責劃分為靜態與動態兩層，透過 GL1PolicyWrapper 實現解耦。
壹、 設計理念：靜態合規與動態合規的職責劃分

圖 2 雙層合規架構——靜態合規與動態合規的職責劃分
架構分為三層：
   一、 外層（PBM / ERC-1155）負責動態/場景合規：
「你要做什麼」—— 會根據交易場景、金額、角色而改變的規則，變動頻率隨場景變化，同一個人在不同場景面對不同規則，就像「樓層門禁」——進了大樓之後，去會議室需要預約、去機房需要額外權限、搬貨需要走指定通道，規則隨場景而異。
(一)、 FXLimitRule（外匯管制）：根據 CCIDRegistry 中的身份標籤（居民/非居民）檢查外匯累計額度。
(二)、 CollateralRule（抵押品驗證）/ CashAdequacyRule（現金充足性）：Repo 場景中的抵押率（? 150%）與現金充足性驗證。
(三)、 AMLThresholdRule（大額交易申報）：大額交易申報與拆分偵測。
(四)、 WhitelistRule（白名單）：動態管理的白名單，支援鏈上與鏈下兩種驗證模式。
二、 中層為GL1PolicyWrapper，負責 wrap / unwrap操作
GL1PolicyWrapper 透過 wrap() 將 ERC-3643 代幣封裝為 PBM 時自動附加外層規則，無需修改底層合約。同一份 ERC-3643 代幣可在不同場景中配置不同規則集——跨境支付適用 FXLimitRule + WhitelistRule，Repo 適用 CollateralRule + CashAdequacyRule。
三、 底層（ERC-3643）負責靜態/基礎合規：
「你是誰」—— 不會因為交易場景不同而改變的規則，變動頻率極少變動，設定好後長期有效，就像「門禁卡」—你有合法的門禁卡就能進大樓，不管你進去是要開會還是搬貨，門禁規則都一樣。
(一)、 KYC身份驗證（IdentityRegistry）：ERC3643Token 的 transfer() 自動呼叫 identityRegistry.isVerified()，IdentityRegistry 再橋接至 CCIDRegistry 進行 KYC 等級與有效期雙重確認。
(二)、 帳戶凍結與強制轉移（Administrative Control）：setAddressFrozen()、freezePartialTokens() 提供帳戶或部分餘額凍結；forcedTransfer() 實現法律強制轉移；pause() 提供緊急斷路器。
(三)、 ComplianceModule（規則）：可插拔的靜態規則模組（如持有人數上限），每次成功轉帳後記錄交易。
貳、 ERC-7943 在雙層架構中的角色
PBMToken 實作 IERC7943MultiToken 介面，作為外層動態合規的標準化技術基礎。ERC-7943 定義了一組通用的資產操作介面，使任何 DApp 或外部合約無需了解底層合規架構的實作細節，即可透過統一介面查詢資格、檢查轉帳合規性、與執行監管控制，提升系統的互操作性與可組合性。具體而言：
* canTransact(account)：查詢該地址是否具備交易資格。PBMToken 呼叫GL1PolicyWrapper，由其委派 GL1PolicyManager 進行 KYC 與管轄區權限驗證後回傳結果。
* canTransfer(from, to, tokenId, amount)：查詢一筆轉帳是否合規，檢查發送方的未凍結餘額是否充足，最後透過 GL1PolicyWrapper 執行場景規則（如外匯額度、AML 閾值）驗證。
* setFrozenTokens(account, tokenId, amount)：監管者凍結特定帳戶的特定代幣金額，凍結後該部分餘額無法轉移。凍結狀態直接儲存於 PBMToken 合約內，無需呼叫外部合約。
* forcedTransfer(from, to, tokenId, amount)：監管者強制轉移資產（如法律扣押），執行時自動解除凍結並繞過所有合規檢查，確保監管指令不受規則攔截。
此設計刻意將合規判斷與代幣管理分離。PBMToken 作為 ERC-1155 代幣合約，僅負責代幣的鑄造、銷毀、餘額管理與凍結狀態維護。
合規規則的編排與執行則統一由 GL1PolicyWrapper 委派 GL1PolicyManager 處理。若將所有合規邏輯直接內嵌於 PBMToken，代幣合約將同時耦合 PolicyManager、CCIDRegistry 及各規則合約的引用，不僅違反單一職責原則，也使得新增或修改規則時必須連帶更動代幣合約，降低系統的可維護性與可擴展性。
PBMToken 僅作為 ERC-7943 標準介面的代理入口，同時以低階調用避免兩合約之間的循環依賴。相對地，setFrozenTokens 與 forcedTransfer 屬於監管行政控制，凍結狀態直接儲存於 PBMToken 合約內，且強制轉移作為最高權限的監管操作不應受合規規則攔截，因此兩者均在 PBMToken 內部完成，無需呼叫外部合約。
ERC-7943 的極簡介面與底層 ERC-3643 的完整許可制設計形成互補：ERC-3643 在底層提供深度身份管理與帳戶控制，ERC-7943 在外層提供通用合規介面，兩層不衝突。
參、 雙層合規觸發順序
以一筆 PBM 轉帳交易為例，雙層合規觸發順序如下：

圖 3 雙層合規觸發順序圖
流程說明：
一、 使用者呼叫 PBMToken 的 safeTransferFrom()，呼叫繼承覆寫ERC1155合約的內部_update()進行凍結餘額檢查，如果轉帳金額 > 未凍結餘額，就交易失敗。
二、 PBMToken 呼叫 GL1PolicyWrapper 的 checkTransferCompliance()，進行額外的 KYC/AML 驗證
三、 外層 PBM 合規階段：
(一)、 GL1PolicyWrapper 呼叫 GL1PolicyManager 的 verifyIdentity()，GL1PolicyManager 向 CCIDRegistry 確認 KYC 狀態與管轄區，通過後返回
(二)、 GL1PolicyWrapper 呼叫 GL1PolicyManager 的 executeComplianceRules()，GL1PolicyManager 逐一執行規則合約，全部通過後返回合規通過結果
四、 GL1PolicyWrapper 回傳允許轉移，PBMToken 執行 ERC-1155 轉移
五、 若涉及 unwrap 解封裝，進入底層 ERC-3643 合規階段：
(一)、 GL1PolicyWrapper 呼叫 ERC3643Token 的 transfer()
(二)、 ERC3643Token 檢查未暫停 / 未凍結 / 餘額充足
(三)、 ERC3643Token 呼叫 IdentityRegistry 的 isVerified()
(四)、 IdentityRegistry 向 CCIDRegistry 查詢 getKYCTier() + isCredentialExpired()，通過後返回
(五)、 ERC3643Token 執行 ComplianceModule.canTransfer()
(六)、 底層資產轉移完成
此流程確保不存在合規盲點——外層動態場景合規與內層靜態身份合規共同構成完整的監理覆蓋。合規通過後，GL1PolicyWrapper 會生成 ComplianceProof 記錄（含交易雜湊、時戳、驗證者地址、適用規則清單）作為留存證據。
第三節 身份管理架構設計
本系統採用雙層身份管理：IdentityRegistry 提供 ERC-3643 兼容的身份註冊，CCIDRegistry 擴展跨鏈身份與細粒度標籤能力。
壹、 IdentityRegistry 實作
設計決策： InvestorIdentity 結構包含 identity（代表地址）、country（ISO-3166 國家代碼）與 registered（是否已註冊）三個欄位。
核心功能：
一、 registerIdentity() / updateIdentity() / deleteIdentity() / updateCountry()：AGENT_ROLE 管理投資者身份。
二、 batchRegisterIdentity()：批量註冊，提升大規模部署效率。
三、 isVerified()：核心查詢函數，整合三階段身份確認：
(一)、 檢查地址是否已在 IdentityRegistry 註冊
(二)、 透過 CCIDProvider 確認 KYC 等級是否有效
(三)、 確認 KYC 憑證未過期
三項全部通過才回傳 true，該地址才能進行轉帳。
透過 ERC3643Token 的 recoveryAddress() 函數提供——AGENT_ROLE可將舊錢包代幣轉移至新錢包，AGENT_ROLE通常指的是被代幣發行人（Issuer）授權的操作人員或系統，負責管理投資者身份註冊、凍結帳戶、強制轉移等行政操作。可以理解為代幣管理員或合規代理人。。
貳、 CCIDRegistry 跨鏈身份註冊表
CCIDRegistry 參照第二章所述之 Chainlink ACE CCID 概念設計，提供跨鏈且符合隱私法規的身份管理。
一、 隱私設計原則
鏈上僅儲存 identityHash（身份雜湊）、kycTimestamp(完成的時間戳記)、tier(KYC等級)等去識別化元資料，不儲存任何PII(Personally Identifiable Information個人可識別資訊，例如姓名、身分證號、住址等)。即使鏈上資料被讀取也不會洩露敏感個資。
二、 多層級 KYC 分級
表 1 KYC等級分級
KYC 等級
說明
適用場景
TIER_NONE
無 KYC，預設狀態
不具交易資格
TIER_BASIC
基礎身份驗證
小額交易
TIER_FULL
完整身份與文件審核
一般金融交易
TIER_INSTITUTIONAL
法人全面盡職調查
機構間交易
三、 身份標籤管理
表 2 身份標籤
標籤
用途
TAG_RESIDENT
適用本國監管標準
TAG_NON_RESIDENT
觸發外匯管制規則（FXLimitRule）
TAG_CORPORATE
適用法人特定合規
TAG_SANCTIONED
立即禁止所有交易，發出 SanctionStatusChanged 事件
規則合約可根據標籤自動觸發差異化的監管邏輯。
四、 跨鏈地址映射
linkCrossChainAddress(primaryAddress, chainId, linkedAddress, proof) 可將同一實體在不同鏈上的地址進行綁定。函數會檢查目標鏈是否在支援清單中（supportedChains）、主地址身份是否為啟用狀態。系統預設支援 Ethereum、Polygon、Arbitrum、Optimism 四條鏈，管理員可透過 setChainSupport() 動態新增或移除支援的鏈。getCrossChainAddress() 則提供反向查詢，取得特定主地址在指定鏈上的對應地址。此機制實現「一次 KYC、多鏈使用」——實體僅需在一條鏈上完成 KYC 註冊，即可將身份映射至其他鏈使用。
五、 管轄區權限管理
CCIDRegistry 透過 jurisdictionApproval 映射（address → jurisdiction → bool）記錄每個帳戶在各管轄區的操作權限。KYC_PROVIDER_ROLE 呼叫 approveJurisdiction() 核准帳戶在特定管轄區操作，或呼叫 revokeJurisdiction() 撤銷權限。
verifyCredential(account, jurisdiction) 函數整合三項檢查：身份是否啟用、KYC 是否未過期、該帳戶是否持有對應管轄區的核准。三項全部通過才回傳 true。此機制與 GL1PolicyManager 的管轄區規則映射協同運作——GL1PolicyManager 根據交易涉及的管轄區代碼查詢適用規則集，而 CCIDRegistry 負責確認參與者是否具備該管轄區的操作資格。跨境交易的雙方可能分屬不同管轄區，需各自通過所屬管轄區的驗證。
第四節 政策管理器與合規規則引擎設計
GL1PolicyManager 作為 PCT 架構的協調層，負責編排身份驗證、規則引擎與外部服務之間的互動。
壹、 GL1PolicyManager 規則編排架構
一、 RuleSet 結構
每個 RuleSet 包含下列結構，透過 registerRuleSet() 註冊，僅限RULE_ADMIN_ROLE。
表 3 RuleSet 結構欄位
欄位
類型
說明
ruleSetId
bytes32
唯一識別碼
ruleType
string
規則類型（如 WHITELIST、AML_THRESHOLD）
isOnChain
bool
鏈上即時執行 or 鏈下簽署驗證
executorAddress
address
規則合約地址
priority
uint256
執行優先級（越小越先）
isActive
bool
可隨時啟用/停用，無需重新部署
二、 多管轄區規則映射
jurisdictionRules 映射建立管轄區與規則集的對應。setJurisdictionRules() 為特定管轄區配置適用規則集。驗證時根據交易的管轄區代碼查詢並依序執行。跨境交易可能需通過多個管轄區各自的規則。
三、 多方角色驗證（verifyPartyCompliance）
針對 Repo 等多方交易，verifyPartyCompliance(party, role, jurisdictionCode) 執行兩階段驗證：
(一)、 呼叫 verifyIdentity() 確認 KYC 與管轄區權限
(二)、 根據角色（LENDER / BORROWER / CUSTODIAN）執行對應的規則集，不同角色適用不同規則，反映差異化監管需求。
四、 混合執行模式
透過 isOnChain 標記支援兩種模式無縫切換，兩種模式可在同一管轄區混合使用。
(一)、 鏈上模式（isOnChain = true）：直接呼叫規則合約的 checkCompliance()，適用於簡單規則（白名單、餘額閾值[餘額低於或高於某個值，就觸發對應的檢查]）。
(二)、 鏈下模式（isOnChain = false）：驗證鏈下受信任機構簽發的數位簽章，適用於複雜規則（AML模糊比對演算法、制裁名單篩選）。
貳、 ProofSet與離線檢驗機制
ProofSet 承載鏈下受信任機構的合規證明，在 GL1PolicyWrapper 的 wrap() 中提交。使用者提交至鏈上的內容包含兩部分：原始合規訊息（明文，含帳戶地址、檢查結果、時間戳等）以及受信任機構對該訊息的數位簽章。數位簽章並非加密——原始訊息以明文傳輸，簽章僅為附帶的密碼學證明。鏈上驗證流程如下：
一、 檢查簽署者是否為系統認可的受信任機構：
每個帳戶的地址由私鑰經橢圓曲線運算產生公鑰，再經 Keccak256 雜湊取最後 20 bytes 而得。受信任機構使用其私鑰對訊息摘要（Hash）進行簽名，產生簽章值 (v, r, s)。由於簽章的數學結構與簽署者的私鑰綁定，鏈上合約可透過 Solidity 內建的 ecrecover()（Elliptic Curve Recover）函數，僅憑訊息摘要與簽章值即可反向推導出簽署者的公鑰，進而計算出其地址。合約將此地址與預先註冊的受信任機構地址比對——若一致，表示簽章確為該機構所簽發；若不一致則拒絕。
二、 驗證數位簽章的密碼學有效性：
上述 ecrecover 同時保證訊息完整性——若訊息內容遭到任何篡改，重新計算的訊息摘要將與簽名時使用的摘要不同，導致 ecrecover 還原出截然不同的地址，驗證即告失敗。
三、 確認簽章時效性（防範重放攻擊）：
合規狀態可能隨時間變化（例如帳戶事後遭列入制裁名單），若不設時間限制，攻擊者可持過去取得的有效簽章無限期重複使用。因此原始訊息中包含簽發時間戳，智能合約將該時間戳與鏈上區塊時間（block.timestamp）比對，確認簽章仍在預設的有效時間窗口內（例如 24 小時），過期即拒絕，強制要求重新取得最新的合規證明。
三項全部通過方可作為有效合規背書。落實「離線檢驗、鏈上驗證」混成機制。
參、 信任模型與失效場景分析（Trust Model & Failure Analysis）
「信任模型」是指系統在運作時預設了哪些角色是可信的、可信到什麼程度。「失效場景」則分析當這些信任假設不成立時（例如受信任機構遭入侵或斷線），系統會受到什麼影響以及如何應對。離線檢驗機制將部分合規判斷委託給鏈下受信任機構，因此引入了額外的信任假設。本小節逐一分析此設計的信任根源、潛在風險與對應的緩解措施。
一、 信任根源（Root of Trust）
本系統的合規證明並非任何人都可以簽發，而是僅限系統管理員預先授權的機構才能簽署——這就是「許可制」的含義。GL1PolicyWrapper 合約中設有 trustedSigner狀態變數，記錄當前授權簽署者的地址。_verifyProofSet()函數在驗證 ProofSet 時效性後，使用 OpenZeppelin 的 ECDSA（Elliptic Curve Digital Signature Algorithm，橢圓曲線數位簽章演算法）函式庫進行簽章驗證——其原理與前述 ProofSet 驗證流程相同：將 ProofSet 核心欄位（proofType、credentialHash、issuedAt、expiresAt、issuer）編碼並雜湊，透過 ECDSA.recover()從簽章還原簽署者地址，與trustedSigner比對——僅完全吻合時才接受該合規證明。
目前實作中僅設定單一授權簽署者，因此存在「單點故障」風險：若該機構離線或被入侵，整個離線合規管道即失效。針對此風險，本系統有兩項緩解措施：
(一)、 法律問責：依據第二章 CAST Framework 的設計，授權簽署者須與系統營運方簽訂代理協議，明確約定其合規判斷的法律責任。若簽署者簽發不實的合規證明，可依據協議追究法律責任，以法律層面的嚇阻力補強技術層面的信任。
(二)、 多方簽署擴展：由於trustedSigner的設計為單一地址，未來可直接將其設為多簽錢包地址，無需修改合約即可實現 M-of-N 多方簽署——即要求 N 個授權機構中至少 M 個同意（例如 3 個機構中至少 2 個簽署），消除單點故障。
二、 簽章有效性與資料真實性的落差
ECDSA簽章驗證能確保「這份合規證明確實是授權機構簽發的」，但無法確保「授權機構的合規判斷本身是否正確」。換言之，智能合約只能驗證「誰說的」，無法驗證「說的對不對」。此限制帶來的具體風險是：若鏈下受信任機構遭到入侵或發生錯誤，簽發了不實的合規證明（例如將實際未通過 AML 審查的帳戶標記為「通過」），鏈上合約會因為簽章本身有效而照常放行——垃圾進、垃圾出（Garbage In, Garbage Out）。然而，大規模 AML 模糊比對與制裁名單篩選涉及敏感個人資料（姓名、身分證號碼等），在鏈上公開執行既不可行（運算成本過高），也不符合隱私法規（如 GDPR）的數據最小化原則，因此委託鏈下專業機構處理是目前的必要技術權衡。
三、 活性假設與阻斷風險（Liveness Assumption & Blocking Risk）
所謂「活性假設」，是指系統預設鏈下服務會持續可用。「阻斷風險」（Blocking Risk）則是這個假設不成立時所產生的影響。離線合規機制依賴鏈下受信任機構持續在線並簽發合規證明。若該機構因當機、網路中斷或遭受攻擊而無法回應，使用者將無法取得有效的 ProofSet，所有需要離線簽署的交易（如 wrap）都會被阻斷。
本系統對此採取「寧可拒絕、不可放行」的設計原則：當鏈下服務無法使用時，合約不會跳過驗證直接放行，而是拒絕所有未經簽章驗證的交易。這意味著系統可用性會暫時降低，但不會因為缺少合規檢查而產生監管漏洞。純鏈上規則（如 WhitelistRule、CollateralRule）不依賴鏈下服務，在此期間仍可正常運作，作為基礎防線。
四、 隱私信任邊界（Privacy Trust Boundary）
隱私信任邊界是指鏈上與鏈下之間「誰負責保管個資」的責任分界線。合規審查不可避免地需要處理個人敏感資料（PII，如姓名、身分證號碼、地址等），但這些資料不應出現在公開的區塊鏈上。本系統的做法是將隱私責任明確劃分為兩層：鏈下受信任機構負責保管原始個資並執行合規判斷，鏈上僅儲存經過雜湊處理後的去識別化摘要（如CCIDRegistry中的identityHash）——即使鏈上資料被任何人讀取，也無法反推出原始個資。鏈上合約信任的是鏈下機構的「判斷結果」（通過或不通過），而非原始資料本身。此設計符合 GDPR 等隱私法規所要求的「數據最小化」原則——僅收集與儲存達成目的所必需的最少量資料。
第五節 應用場景機制設計
本節設計兩個代表性金融場景——零售端跨境消費與機構端資金融通——驗證雙層合規架構的場景適應能力。
壹、 跨境支付場景設計
場景：台灣遊客在新加坡商家消費，支付 TWD 穩定幣，商家收取 SGD 結算。
一、 FX 匯率轉換架構：
FXRateProvider 以 USD 為基準貨幣，透過 Chainlink Price Feed 取得各貨幣對 USD 的匯率。當需要查詢非直接支援的貨幣對時（例如 TWD 對 SGD），系統以交叉匯率計算：先分別取得 TWD/USD 與 SGD/USD 的匯率，再以 TWD/SGD = (TWD/USD) ÷ (SGD/USD) 換算——即以 USD 作為中介，間接橋接兩種貨幣之間的匯率。系統目前支援 TWD、SGD、USD、CNY 四種貨幣。
匯率來源支援兩種模式切換：預設使用 Chainlink Price Feed 自動取得去中心化的即時市場匯率；管理員（RATE_ADMIN_ROLE）亦可透過 setUseManualRates() 切換至手動匯率模式，由管理員直接在合約中以 setManualRate() 設定固定匯率值。手動模式適用於尚未支援的貨幣對、測試開發環境，或監管機構要求使用官方公告匯率的情境。無論何種模式，匯率均設有過期時間防護（stalePeriod，預設 1 小時）——合約透過 isRateStale() 檢查匯率資料的最後更新時間，若距今超過預設時限，即視為過期匯率，避免使用過時報價導致錯誤結算。
二、 支付與結算流程：
跨境支付以商家標價幣種為基準：商家以 SGD 標價，系統反向計算遊客需支付的 TWD 金額。整體流程分為「遊客支付」與「商家結算」兩個階段：

圖 4 跨境支付結算流程圖
流程說明：
(一)、 遊客呼叫 payWithFXConversion(100, SGD, TWD穩定幣地址, 商家地址, proof)，以商家標價 100 SGD 為基準
(二)、 GL1PolicyWrapper 向 FXRateProvider 查詢 convert(SGD, TWD, 100)，反向換算遊客需支付的 TWD 金額（例如依即時匯率計算為 2370 TWD）
(三)、 合規驗證：驗證遊客提交的離線合規證明（ProofSet），包含三項核心檢查——確認簽章由 trustedSigner 簽發（簽署者身份）、確認訊息未遭篡改（訊息完整性）、確認簽章在有效期內（時效性）
(四)、 從遊客扣款 2370 TWD，直接鑄造等額 PBM 給商家。同時將匯率、雙方地址、來源與目標金額等交易資訊寫入 FXTransaction 記錄，供事後查閱
(五)、 商家呼叫 settleCrossBorderPayment()，合約再次向 FXRateProvider 即時查詢匯率，將商家持有的 PBM 銷毀，並將底層 TWD 資產依當下匯率轉換為 SGD 穩定幣後發放給商家。由於支付與結算分屬不同時間點且各自查詢即時匯率，商家最終收到的 SGD 金額可能與遊客支付時的換算結果略有差異
貳、 附買回交易（Repo）場景設計
場景：金融機構間短期資金融通。Borrower 以代幣化公債（ERC-3643）作抵押品，向 Lender 借入現金。
Repo 狀態機：

圖 5 Repo 交易狀態機圖
狀態機包含以下狀態與轉換：
一、 [初始] → INITIATED：透過 initiateRepo() 建立交易
二、 INITIATED → BORROWER_FUNDED：Borrower 呼叫 fundAsBorrower() 存入抵押品
三、 INITIATED → LENDER_FUNDED：Lender 呼叫 fundAsLender() 存入現金
四、 BORROWER_FUNDED → FUNDED：Lender 呼叫 fundAsLender() 完成雙方注資
五、 LENDER_FUNDED → FUNDED：Borrower 呼叫 fundAsBorrower() 完成雙方注資
* FUNDED → EXECUTED：呼叫 executeRepo() 執行交易
* EXECUTED → SETTLED：呼叫 settleRepo() 正常結算
* EXECUTED → DEFAULTED：呼叫 claimCollateral() 違約處理
* INITIATED / BORROWER_FUNDED / LENDER_FUNDED → CANCELLED：呼叫 cancelRepo() 取消交易
抵押品鎖定機制：
一、 Borrower 的底層 ERC-3643 公債事先透過 wrap() 封裝為 PBM Token（底層資產鎖定於 GL1PolicyWrapper）
二、 fundAsBorrower() 時，抵押品 PBM 從 Borrower 轉入 RepoContract 鎖定（自動觸發外層合規檢查）
三、 存續期間任何一方均無法單獨提取。僅 settleRepo() 或 claimCollateral() 依狀態機邏輯釋放
四、 原子交換確保抵押品鎖定與現金交付在同一交易完成，不存在一方已付出而另一方未履行的中間風險。
合規檢查點：
表 4 Repo 合規檢查點
階段
規則
驗證內容
Borrower 存入抵押品
CollateralRule
抵押率 ? 150%
Lender 存入現金
CashAdequacyRule
PBM 餘額充足
雙方注資
verifyPartyCompliance
按角色（BORROWER/LENDER）差異化 KYC 驗證
第四章 系統實作與應用分析
本章以「如何實作」為核心，展示第三章架構設計的具體 Solidity 程式碼實現。首先說明開發環境與工具配置，接著依序展示五個核心智能合約、五個合規規則模組的關鍵實作邏輯，最後透過跨境支付與附買回交易兩大金融場景的端對端演示，驗證系統的實務可行性。
第一節 開發環境與核心工具
本系統的開發環境與核心工具配置如下：
表 5 開發環境配置
項目
工具 / 版本
說明
程式碼編輯器
Visual Studio Code
撰寫與管理合約程式碼的主要開發編輯器
智能合約語言
Solidity ^0.8.20
智能合約的程式語言
開發與測試框架
Hardhat
編譯、部署、單元測試與整合測試
依賴庫
OpenZeppelin Contracts
ERC-20、ERC-1155、AccessControl 等標準實作
密碼學庫
OpenZeppelin ECDSA
橢圓曲線簽章驗證，用於驗證數位簽章
專案目錄結構以功能模組劃分，各資料夾對應 GL1 PCT 框架中的不同層級：
contracts/
├── core/           # GL1PolicyWrapper、GL1PolicyManager、
│                   #   CCIDRegistry、RepoContract、FXRateProvider
├── token/          # PBMToken (ERC-1155)、ERC3643Token (ERC-20)
├── erc3643/        # IdentityRegistry、ComplianceModule、
│                   #   TrustedIssuersRegistry、ClaimTopicsRegistry
├── rules/          # WhitelistRule、AMLThresholdRule、
│                   #   FXLimitRule、CollateralRule、CashAdequacyRule
├── interfaces/     # IERC3643、IERC7943MultiToken、
│                   #   IGL1PolicyWrapper、IPolicyManager、IComplianceRule
└── mocks/          # MockERC20、MockERC721、MockERC1155

第二節 核心智能合約實作
本節展示五個核心智能合約的關鍵程式碼與實作邏輯，涵蓋底層許可制代幣、外層 PBM 代幣、政策封裝器、政策管理器與跨鏈身份註冊表。
壹、 ERC-3643 許可制代幣實作（ERC3643Token.sol）
ERC3643Token 繼承 OpenZeppelin 的 ERC-20 標準與 AccessControl 權限管理，實作 IERC3643 介面。此合約在雙層合規架構中扮演「底層靜態合規」角色，負責 KYC 身份驗證、帳戶凍結與強制轉移等基礎監管功能。
一、 合約繼承與狀態變數
合約使用AccessControl的AGENT_ROLE，使多個代理人可同時執行行政控制操作。關鍵狀態變數包括：IdentityRegistry 與 ComplianceModule 的參照地址、暫停狀態旗標（_paused）、地址凍結映射（_frozen）以及部分代幣凍結映射（_frozenTokens）。
程式碼：ERC3643Token合約宣告與狀態變數
contract ERC3643Token is ERC20, AccessControl, IERC3643 {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    // 關聯合約
    IIdentityRegistry private _identityRegistry;
    ICompliance3643 private _compliance;
    // 暫停狀態
    bool private _paused;
    // 地址凍結（整個錢包）
    mapping(address => bool) private _frozen;
    // 部分代幣凍結
    mapping(address => uint256) private _frozenTokens;
 
    modifier whenNotPaused() {
        require(!_paused, "ERC-3643: Token is paused");
        _;
    }
}
二、 合規轉帳核心邏輯
transfer() 函數覆寫 ERC-20 標準的轉帳方法，實作五階段前置合規檢查。此設計遵循「快速失敗（fail fast）」原則：每一個 require 若不滿足，交易即立即 revert，後續尚未執行的檢查項目不會消耗 Gas。因此，將廉價的本地儲存讀取置於前段，昂貴的外部合約呼叫置於末段，確保最常見的失敗情境（如代幣已暫停、錢包遭凍結、餘額不足）能以最低成本被攔截，只有在前三項條件全數通過後，才會發起跨合約的身份驗證與合規審查，從而在整體上有效壓低平均每筆交易的 Gas 消耗。
程式碼：ERC3643Token.transfer() 五階段合規檢查
function transfer(
    address _to,
    uint256 _amount
) public override(ERC20, IERC20) whenNotPaused returns (bool) {
    // 階段 1-2：帳戶凍結檢查
    require(!_frozen[msg.sender] && !_frozen[_to],
        "ERC-3643: Frozen wallet");
    // 階段 3：未凍結餘額充足性
    require(
        _amount <= balanceOf(msg.sender) - _frozenTokens[msg.sender],
        "ERC-3643: Insufficient unfrozen balance"
    );
    // 階段 4：Identity Registry 身份驗證
    require(
        _identityRegistry.isVerified(_to),
        "ERC-3643: Invalid identity"
    );
 
    // 階段 5：Compliance Module 規則檢查
    require(
        _compliance.canTransfer(msg.sender, _to, _amount),
        "ERC-3643: Compliance failure"
    );
    _transfer(msg.sender, _to, _amount);
    _compliance.transferred(msg.sender, _to, _amount);
    return true;
}
三、 行政控制功能
ERC-3643 標準要求代幣合約提供完整的行政控制能力，以支援監理機構在緊急情況下的強制執行需求。本合約實作以下行政控制功能：
(一)、 強制轉移（forcedTransfer）：AGENT_ROLE 可繞過 Compliance 規則直接轉移代幣，僅需確認接收方身份有效。若轉移數量超過發送方的未凍結餘額，系統自動減少凍結量以完成轉移。
(二)、 帳戶凍結（setAddressFrozen）：將特定地址完全凍結。
(三)、 部分凍結（freezePartialTokens / unfreezePartialTokens）：凍結帳戶中指定數量的代幣。
(四)、 暫停機制（pause / unpause）：全局暫停所有代幣轉帳。
(五)、 錢包恢復（recoveryAddress）：AGENT_ROLE 可將投資者代幣轉移至新錢包。
程式碼：forcedTransfer強制轉移實作
function forcedTransfer(
    address _from, address _to, uint256 _amount
) external override onlyRole(AGENT_ROLE) returns (bool) {
    require(_identityRegistry.isVerified(_to),
        "ERC-3643: Invalid identity");
 
    // 如果凍結代幣超過轉移量，自動減少凍結量
    if (_frozenTokens[_from] > 0) {
        uint256 unfrozen = balanceOf(_from) - _frozenTokens[_from];
        if (_amount > unfrozen) {
            uint256 frozenToReduce = _amount - unfrozen;
            _frozenTokens[_from] -= frozenToReduce;
            emit TokensUnfrozen(_from, frozenToReduce);
        }
    }
 
    _transfer(_from, _to, _amount);
    _compliance.transferred(_from, _to, _amount);
    return true;
}

貳、 PBM Token與ERC-7943整合實作（PBMToken.sol）
PBMToken 以 ERC-1155 多代幣標準為基礎，整合 ERC-7943（uRWA）介面。在雙層架構中，PBMToken 扮演「外層動態場景合規」載體，不同的 tokenId 代表不同底層資產的封裝形式，統一由 GL1PolicyWrapper 管理。
一、 ERC-7943合規介面實作
PBMToken 實作 IERC7943MultiToken 介面的四個核心函數：canTransact()（帳戶交易資格查詢）、canTransfer()（轉帳合規預檢）、setFrozenTokens()（監管凍結）、forcedTransfer()（強制轉移）。
程式碼：ERC-7943 canTransfer()合規查詢
function canTransfer(
    address from, address to,
    uint256 tokenId, uint256 amount
) external view override returns (bool allowed) {
    if (!this.canTransact(from) || !this.canTransact(to)) {
        return false;
    }
    uint256 balance = balanceOf(from, tokenId);
    uint256 frozen = _frozenTokens[from][tokenId];
    uint256 unfrozen = balance > frozen ? balance - frozen : 0;
    if (amount > unfrozen) { return false; }
 
    // 調用 wrapper 進行額外合規檢查
    (bool success, bytes memory result) = wrapper.staticcall(
        abi.encodeWithSignature(
            "checkTransferCompliance(address,address,uint256,uint256)",
            from, to, tokenId, amount)
    );
    if (success && result.length >= 32) {
        (bool isCompliant,) = abi.decode(result, (bool, string));
        return isCompliant;
    }
    return true;
}

二、 轉移前合規攔截（_update Hook）
_update() 為 OpenZeppelin ERC-1155 實作中所有代幣狀態變更的核心內部函數，無論是 safeTransferFrom()、safeBatchTransferFrom()、鑄造（mint）或銷毀（burn），底層皆統一經由此函數執行。PBMToken 覆寫此函數，將合規攔截邏輯嵌入代幣移動的最底層路徑，確保任何轉移操作在寫入狀態之前，皆須通過完整的合規驗證。ERC-7943 定義了 canTransfer() 與 setFrozenTokens() 等合規介面，但標準本身並不規定這些檢查「何時」被強制執行。透過覆寫 _update()，本實作將 ERC-7943 的合規判斷從可選的外部查詢，轉化為每筆轉移必經的強制攔截點，使合規規則真正內生於資產的傳輸路徑之中。
程式碼：PBMToken._update()轉移前合規攔截
function _update(
    address from, address to,
    uint256[] memory ids, uint256[] memory values
) internal override {
    // 跳過 mint (from==0) 和 burn (to==0)
    if (from != address(0) && to != address(0)) {
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 frozen = _frozenTokens[from][ids[i]];
            uint256 balance = balanceOf(from, ids[i]);
            uint256 unfrozen = balance > frozen ?
                balance - frozen : 0;
            if (values[i] > unfrozen) {
                revert ERC7943InsufficientUnfrozenBalance(
                    from, ids[i], values[i], unfrozen);
            }
        }
        // 調用 GL1PolicyWrapper 合規檢查
        for (uint256 i = 0; i < ids.length; i++) {
            (bool success, bytes memory result) = wrapper.call(
                abi.encodeWithSignature(
                    "checkTransferCompliance(address,address,uint256,uint256)",
                    from, to, ids[i], values[i])
            );
            if (success && result.length >= 32) {
                (bool isCompliant,) =
                    abi.decode(result, (bool, string));
                if (!isCompliant) {
                    revert ERC7943CannotTransfer(
                        from, to, ids[i], values[i]);
                }
            }
        }
    }
    super._update(from, to, ids, values);
}

參、 GL1 政策封裝器實作（GL1PolicyWrapper.sol）
GL1PolicyWrapper 是本系統的核心合約，同時承擔 GL1 PCT 框架中「政策封裝器（Policy Wrapper）」與「行政控制（Administrative Control）」兩大角色。其主要職責包括：透過 wrap/unwrap 機制實現底層資產與 PBM 之間的鎖定與鑄造；在 PBM 轉帳時協調合規檢查流程；驗證鏈下受信任機構簽發的合規證明（ProofSet）；以及支援跨境支付中的外匯轉換功能。
一、 wrap()資產封裝機制
wrap() 函數將底層資產鎖定於本合約中，並鑄造對應的 PBM Token 給使用者。所支援的底層資產類型涵蓋 ERC-20、ERC-721、ERC-1155、ERC-3643。
wrap() 函數共分為五個執行階段：
(一)、 基本參數驗證函數首先確認傳入的底層資產地址不為零地址（address(0)），並驗證封裝數量大於零，排除無效呼叫。
(二)、 合規證明驗證（if complianceEnabled...）若合規檢查功能已啟用，且呼叫者並非豁免帳戶，則呼叫 _verifyProofSet(proof) 驗證鏈下受信任機構簽發的 ProofSet。豁免機制（complianceExempt）用於允許特定帳戶（如系統合約本身或測試帳號）繞過此檢查。
(三)、 計算 PBM tokenId（computePBMTokenId）呼叫 computePBMTokenId() 以 keccak256(abi.encodePacked(assetType, assetAddress, assetTokenId)) 計算唯一識別碼，確保同種底層資產始終映射至同一個 PBM tokenId。PBM tokenId 的計算方式為：keccak256(abi.encodePacked(assetType, assetAddress, assetTokenId)) 
此計算邏輯結合三個維度以唯一識別一種底層資產：assetType 區分資產標準（ERC-20、ERC-721、ERC-1155、ERC-3643）；assetAddress 區分不同的合約來源；assetTokenId 在同一合約內區分不同的代幣品種（ERC-20 固定傳入 0，ERC-721 與 ERC-1155 則傳入實際 tokenId）。三者組合後經 keccak256 雜湊壓縮為固定長度的 uint256，確保同一種底層資產始終對應唯一的 PBM tokenId，不同底層資產則必然產生不同的 PBM tokenId，從而防止資產混淆與重複鑄造。
(四)、 記錄資產資訊（if assets[pbmTokenId]...）若該 PBM tokenId 為首次封裝，則將底層資產的型別、合約地址與 tokenId 寫入 assets 對映表，供後續 unwrap() 取回資產時查找。此判斷以 assetAddress == address(0) 作為「尚未登錄」的條件。
(五)、 資產轉入與 PBM 鑄造（_transferAssetIn + pbmToken.mint）_transferAssetIn() 根據資產類型（ERC-20 / ERC-721 / ERC-1155 / ERC-3643）分派對應的轉帳邏輯，將底層資產從使用者轉至本合約保管；隨後呼叫 pbmToken.mint() 鑄造等量的 PBM Token 給使用者，完成「鎖定→鑄造」的封裝流程。最後發出 TokenWrapped 事件，供鏈下系統（如監理儀表板）監聽紀錄。
程式碼：GL1PolicyWrapper.wrap()資產封裝核心邏輯
function wrap(
    AssetType assetType, address assetAddress,
    uint256 assetTokenId, uint256 amount,
    ProofSet calldata proof
) external override nonReentrant returns (uint256 pbmTokenId) {
    require(assetAddress != address(0), "Invalid asset address");
    require(amount > 0, "Amount must be > 0");
 
    // 合規證明驗證（非豁免帳戶需提交有效 ProofSet）
    if (complianceEnabled && !complianceExempt[msg.sender]) {
        _verifyProofSet(proof);
    }
 
    // 計算唯一 PBM tokenId
    pbmTokenId = computePBMTokenId(
        assetType, assetAddress, assetTokenId);
 
    // 記錄資產資訊（首次封裝時）
    if (assets[pbmTokenId].assetAddress == address(0)) {
        assets[pbmTokenId] = AssetInfo({
            assetType: assetType,
            assetAddress: assetAddress,
            assetTokenId: assetTokenId
        });
    }
 
    // 轉入底層資產至本合約保管
    _transferAssetIn(
        assetType, assetAddress, assetTokenId, amount);
 
    // 鑄造 PBM Token 給使用者
    pbmToken.mint(msg.sender, pbmTokenId, amount);
 
    emit TokenWrapped(msg.sender, pbmTokenId,
        assetType, assetAddress, assetTokenId, amount);
}

二、 checkTransferCompliance() 雙層攔截邏輯
此函數由 PBMToken 的 _update() 在每次轉帳時自動調用。流程分為兩階段：首先透過 GL1PolicyManager 驗證雙方身份（verifyIdentity），接著執行適用的合規規則集（executeComplianceRules）。驗證通過後，生成 ComplianceProof 記錄作為審計證據。
程式碼：checkTransferCompliance()合規檢查
function checkTransferCompliance(
    address from, address to,
    uint256 tokenId, uint256 amount
) external override returns (
    bool isCompliant, string memory reason
) {
    if (!complianceEnabled || complianceExempt[from]
        || complianceExempt[to]) {
        return (true, "");
    }
 
    bytes32 txHash = keccak256(abi.encodePacked(
        from, to, tokenId, amount, block.timestamp));
 
    // 階段一：身份驗證
    (bool identityValid, string memory identityError) =
        policyManager.verifyIdentity(
            from, to, jurisdictionCode);
    if (!identityValid) {
        return (false, identityError);
    }
 
    // 階段二：合規規則執行
    (bool rulesValid, string memory ruleError,
        string[] memory appliedRules) =
        policyManager.executeComplianceRules(
            from, to, amount, jurisdictionCode);
    if (!rulesValid) {
        return (false, ruleError);
    }
 
    // 記錄合規證明
    complianceProofs[txHash] = ComplianceProof({
        proofHash: keccak256(
            abi.encode(txHash, appliedRules)),
        timestamp: block.timestamp,
        verifier: address(policyManager),
        isValid: true
    });
    return (true, "");
}

三、 _verifyProofSet() 離線合規證明驗證
_verifyProofSet() 實現「離線檢驗、鏈上驗證」混成機制，依序執行三項核心驗證，三項全部通過方可作為有效合規背書：
(一)、 時效性檢查：合規狀態可能隨時間變化（例如帳戶事後遭列入制裁名單），若不設時間限制，攻擊者可持過去取得的有效合規證明無限期重複提交。因此合約將簽章中的到期時間與鏈上當前區塊時間比對，過期即拒絕，強制要求使用者取得最新的合規證明。
(二)、 訊息完整性驗證。 合約將合規證明的核心欄位（憑證類型、雜湊值、簽發時間、到期時間、簽發者）組合並計算出一個固定的數位指紋。若訊息內容遭到任何篡改，指紋就會完全不同——這也是後續簽章驗證得以成立的前提：簽章驗證比對的是「指紋」而非原文，指紋一致才代表訊息未被動過。
(三)、 ECDSA 簽章還原：合約透過 ECDSA.recover() 從簽章數學反推出簽署者的以太坊地址，與合約中預先登記的授權機構地址（trustedSigner）比對——若一致，表示這份合規證明確實由授權機構簽發；若不符即拒絕，全程無需接觸私鑰。
程式碼：_verifyProofSet() ECDSA簽章驗證
function _verifyProofSet(
    ProofSet calldata proof
) internal view {
    // 1. 時效性檢查
    require(proof.expiresAt > block.timestamp,
        "Proof expired");
    require(proof.issuedAt <= block.timestamp,
        "Proof not yet valid");
 
    require(trustedSigner != address(0),
        "Trusted signer not set");
 
    // 2. 將核心欄位編碼並計算訊息雜湊
    bytes32 messageHash = keccak256(abi.encode(
        proof.proofType,
        proof.credentialHash,
        proof.issuedAt,
        proof.expiresAt,
        proof.issuer
    ));
 
    // 3. 加上 Ethereum Signed Message prefix (EIP-191)
    bytes32 ethSignedHash =
        messageHash.toEthSignedMessageHash();
 
    // 4. 從簽章還原簽署者地址
    address recoveredSigner =
        ethSignedHash.recover(proof.signature);
 
    // 5. 比對授權簽署者
    require(recoveredSigner == trustedSigner,
        "Invalid proof signer");
}

肆、 政策管理器實作（GL1PolicyManager.sol）
GL1PolicyManager 作為 PCT 架構的協調層，負責編排身份驗證、規則引擎與外部服務之間的互動。其核心設計特點包括：動態規則註冊與管理、多管轄區規則映射、多方角色驗證（用於 Repo 交易），以及鏈上與鏈下的混合執行模式。
一、 RuleSet結構與規則註冊
每個合規規則以 RuleSet 結構封裝。管理員透過 registerRuleSet() 動態註冊新規則，並透過 setJurisdictionRules() 將規則集綁定至特定管轄區。新增規則僅需部署新合約並註冊，無需修改現有合約。
程式碼：GL1PolicyManager RuleSet結構
struct RuleSet {
    bytes32 ruleSetId;        // 唯一識別碼
    string ruleType;          // "KYC", "AML", "SANCTIONS"...
    bool isOnChain;           // true = 鏈上, false = 鏈下
    address executorAddress;  // 規則合約地址或 oracle
    uint256 priority;         // 執行優先級（越小越先）
    bool isActive;            // 可隨時啟用/停用
}
 
mapping(bytes32 => bytes32[]) public jurisdictionRules;
mapping(bytes32 => bool) public jurisdictionEnabled;

二、 verifyIdentity() 身份驗證
verifyIdentity() 執行三階段驗證：管轄區啟用確認、CCIDProvider跨鏈身份驗證、Chainlink ACE 制裁名單檢查。
程式碼：verifyIdentity() 身份驗證
function verifyIdentity(
    address from, address to,
    bytes32 jurisdictionCode
) external override returns (
    bool isValid, string memory errorReason
) {
    if (!jurisdictionEnabled[jurisdictionCode]) {
        return (false, "Jurisdiction not enabled");
    }
 
    ICCIDProvider provider = ICCIDProvider(ccidProvider);
 
    bool fromValid = provider.verifyCredential(
        from, jurisdictionCode);
    if (!fromValid) {
        return (false,
            "Sender identity verification failed");
    }
 
    bool toValid = provider.verifyCredential(
        to, jurisdictionCode);
    if (!toValid) {
        return (false,
            "Recipient identity verification failed");
    }
 
    bool notSanctioned = IChainlinkACE(chainlinkACE)
        .checkSanctionsList(from, to);
    if (!notSanctioned) {
        return (false, "Address on sanctions list");
    }
    return (true, "");
}

三、 verifyPartyCompliance() 多方角色驗證
針對 Repo 等多方交易，verifyPartyCompliance() 根據參與方角色（LENDER 或 BORROWER）查詢對應的角色規則集，依序執行差異化的合規檢查，反映金融監管中不同角色適用不同規範的實務需求。
伍、 跨鏈身份註冊表實作（CCIDRegistry.sol）
CCIDRegistry 參照 Chainlink ACE CCID 概念設計，鏈上僅儲存 identityHash、kycTimestamp 與KYC等級等去識別化元資料，不儲存任何 PII，符合 GDPR 資料最小化原則。
一、 KYC等級與身份標籤
CCIDRegistry定義四個KYC等級（TIER_BASIC、TIER_STANDARD、TIER_ENHANCED、TIER_INSTITUTIONAL）與四種身份標籤（TAG_RESIDENT、TAG_NON_RESIDENT、TAG_CORPORATE、TAG_SANCTIONED）。規則合約可根據標籤自動觸發差異化的監管邏輯——例如 TAG_NON_RESIDENT 觸發 FXLimitRule，TAG_SANCTIONED 立即禁止所有交易。
程式碼：CCIDRegistry 身份結構與標籤
contract CCIDRegistry is ICCIDProvider, AccessControl {
    bytes32 public constant TIER_BASIC =
        keccak256("TIER_BASIC");
    bytes32 public constant TIER_INSTITUTIONAL =
        keccak256("TIER_INSTITUTIONAL");
 
    bytes32 public constant TAG_RESIDENT =
        keccak256("RESIDENT");
    bytes32 public constant TAG_NON_RESIDENT =
        keccak256("NON_RESIDENT");
    bytes32 public constant TAG_SANCTIONED =
        keccak256("SANCTIONED");
 
    uint256 public kycValidityPeriod = 365 days;
 
    struct Identity {
        bytes32 identityHash;
        uint256 kycTimestamp;
        bytes32 tier;
        bool isActive;
    }
 
    mapping(address => Identity) public identities;
    mapping(address => bytes32) public identityTags;
    mapping(address => mapping(bytes32 => bool))
        public jurisdictionApproval;
    mapping(address => mapping(bytes32 => address))
        public crossChainAddresses;
}

二、 verifyCredential()與跨鏈地址映射
verifyCredential() 整合三項檢查：身份啟用（isActive）、KYC 未過期、管轄區核准。linkCrossChainAddress() 可將同一實體在不同鏈上的地址進行綁定，系統預設支援 Ethereum、Polygon、Arbitrum、Optimism 四條鏈，實現「一次 KYC、多鏈使用」。
第三節 合規規則模組實作
本系統實作五個合規規則模組，均實作統一的 IComplianceRule 介面（checkCompliance(from, to, amount) → (passed, error)）。
表 6 合規規則模組與 GL1 範例對應
規則合約
功能
GL1 對應範例
適用場景
WhitelistRule
KYC/AML 白名單檢查
Whitelisting Selected Receivers
跨境支付
AMLThresholdRule
大額交易申報與拆分偵測
Large Transaction Reporting
全場景
FXLimitRule
非居民外匯累計額度限制
Cross-Border Payment Limits
跨境支付
CollateralRule
抵押品價值與抵押率驗證
Collateral Sufficiency
Repo 交易
CashAdequacyRule
現金充足性驗證
Cash Adequacy Check
Repo 交易
壹、 WhitelistRule—白名單規則
WhitelistRule 限制 PBM 代幣只能轉移給白名單中的接收者。支援全局白名單與管轄區白名單兩種模式，可透過 useJurisdictionMode 旗標切換。checkCompliance() 檢查接收方地址是否在白名單中且商家狀態為啟用。
程式碼：WhitelistRule.checkCompliance()
function checkCompliance(
    address from, address to, uint256 amount
) external view override returns (
    bool passed, string memory error
) {
    from; amount; // 此規則不檢查發送方與金額
    if (!_enabled) { return (true, ""); }
 
    bool inWhitelist;
    if (useJurisdictionMode
        && currentJurisdiction != bytes32(0)) {
        inWhitelist =
            jurisdictionWhitelist[currentJurisdiction][to];
    } else {
        inWhitelist = whitelist[to];
    }
 
    if (!inWhitelist) {
        return (false, "Recipient not in whitelist");
    }
    if (merchants[to].addedAt > 0
        && !merchants[to].isActive) {
        return (false, "Merchant is deactivated");
    }
    return (true, "");
}

貳、 AMLThresholdRule—大額交易申報規則
AMLThresholdRule 實作反洗錢大額交易申報機制（預設門檻TWD 50萬），具備單筆大額偵測與拆分交易偵測（24 小時內累計追蹤）兩項能力。預設「記錄但不阻擋」模式，可切換為阻擋模式。
程式碼：AMLThresholdRule.checkCompliance()
function checkCompliance(
    address from, address to, uint256 amount
) external override returns (
    bool passed, string memory error
) {
    if (!_enabled) { return (true, ""); }
    bool isSuspicious = false;
 
    // 1. 大額交易偵測
    if (amount >= largeTransactionThreshold) {
        bytes32 reportId =
            _generateReportId(from, to, amount);
        _createReport(reportId, from, to, amount,
            ReportType.LARGE_TRANSACTION);
        emit LargeTransactionDetected(
            reportId, from, to, amount, block.timestamp);
        isSuspicious = true;
    }
 
    // 2. 拆分交易偵測（24h 累計追蹤）
    bool structuringDetected =
        _checkAndUpdateCumulative(from, to, amount);
    if (structuringDetected) { isSuspicious = true; }
 
    // 3. 已標記帳戶
    if (flaggedAccounts[from]) { isSuspicious = true; }
 
    // 4. 根據模式決定是否阻擋
    if (isSuspicious && blockSuspiciousTransactions) {
        return (false,
            "AML: Suspicious transaction blocked");
    }
    return (true, "");
}

參、 FXLimitRule—外匯累計額度規則
FXLimitRule 針對非居民的每日轉出限額檢查。透過 CCIDProvider 查詢發送方身份標籤，僅對 TAG_NON_RESIDENT 執行額度檢查。每日額度追蹤採用 block.timestamp / 1 days 計算日期邊界——此為整數除法，將 Unix 時間戳（單位：秒）除以 86400，得出自 1970 年至今的累計天數，作為當日的索引鍵（key）。同一天內無論何時發起交易，該值恆為相同整數；一旦跨越 UTC 00:00，數值自動遞增，舊日的累計紀錄即自然失效，無需額外的重置邏輯，隔日額度便自動歸零重計。累計金額則透過二維映射 dailyTransferred[from][today] 進行記錄，其中第一層以發送方地址為索引，第二層以當日天數為索引，值為該地址當日已累計的轉出總額。每筆交易執行時將金額累加至對應欄位，並與 dailyLimit 比對，若超出限額則拒絕交易。此設計使不同地址、不同日期的額度各自獨立追蹤，且無需任何主動重置機制。
肆、 CollateralRule—抵押品規則
CollateralRule 驗證 Repo 交易中抵押品價值是否足夠。由於 checkCompliance 的標準介面僅接收 from、to、amount 三個參數，無法直接傳入抵押品相關資訊，因此合約採用「上下文模式（CheckContext）」——由 RepoContract 在執行合規檢查前，先呼叫 setCheckContext 將借款人地址（borrower）、抵押品資產（collateralAsset）、抵押品數量（collateralAmount）及貸款金額（loanAmount）寫入鏈上，checkCompliance 再從 checkContexts[from] 讀取這些參數進行驗證，驗證完畢後清除上下文。
核心邏輯分為兩步：第一步計算抵押品實際價值（collateral value），公式為 collateralValue = collateralAmount × collateralPrice / 1e18，意即將抵押品數量乘以單價，換算出以貸款貨幣計價的市場價值；價格採 18 位小數精度（1e18），與 ERC-20 代幣的標準精度一致。第二步計算最低所需抵押品價值（required value），公式為 requiredValue = loanAmount × minCollateralRatio / 10000，其中 minCollateralRatio 採 basis points 表示法，預設值 15000 即代表 150%（10000 basis points = 100%）——意思是借款人提供的抵押品市場價值，必須至少達到貸款金額的 1.5 倍，以確保即便抵押品價格下跌仍有足夠緩衝空間保障貸款方權益。若 collateralValue < requiredValue，合約即拒絕交易。
此外，並非所有代幣資產都能作為抵押品。合約維護一份 allowedCollaterals 白名單，僅有經管理員審核並手動加入的資產地址才被允許，目的在於排除流動性不足、價格操縱風險高或來源不明的代幣，確保抵押品具備一定的市場公信力與可清算性。若抵押品資產不在白名單內，或該資產的價格尚未由管理員設定，合約亦直接拒絕交易，避免以無效價格進行抵押率計算。
伍、 CashAdequacyRule—現金充足性規則
CashAdequacyRule 透過 IERC20.balanceOf() 查詢 Lender 持有的現金餘額，與 CheckContext 中的 requiredAmount 比對，確保 Lender 有足夠資金提供。

第四節 應用場景實作演示
本節透過跨境支付與附買回交易（Repo）兩大金融場景的端對端演示，驗證本系統架構的實務可行性。
壹、 跨境支付場景演示
情境：台灣遊客在新加坡商家消費，商家以 SGD 標價 100 元，遊客持有 TWD 穩定幣，系統自動完成匯率轉換、合規檢查與跨境結算。
一、 交易流程
(一)、 遊客呼叫 payWithFXConversion(100, SGD, TWD穩定幣地址, 商家地址, proof)，以商家標價 100 SGD 為基準。
(二)、 GL1PolicyWrapper 向 FXRateProvider 查詢 convert(SGD, TWD, 100)，反向換算遊客需支付的 TWD 金額（例如 2,370 TWD）。
(三)、 合規驗證——_verifyProofSet()驗證遊客提交的離線合規證明（ProofSet），包含簽署者身份、訊息完整性、時效性三項檢查。
(四)、 從遊客扣款 2,370 TWD，以 mint 方式鑄造等額 PBM 給商家。mint 操作內部呼叫 _update(address(0), 商家地址, amount)，同樣觸發 checkTransferCompliance() 執行 WhitelistRule 與 FXLimitRule 驗證。同時寫入 FXTransaction 記錄。
(五)、 商家呼叫 settleCrossBorderPayment()，合約即時查詢匯率，銷毀 PBM，將底層 TWD 資產依當下匯率轉換為 SGD 穩定幣後發放給商家。
二、 底層資產幣別之設計考量
本設計選擇以 TWD 作為 PBM 底層資產，而非在支付當下即完成換匯並以 SGD 封裝，其背後有兩項監理考量：其一為換匯責任歸屬——將換匯動作推遲至商家結算階段，使換匯行為由商家側觸發，明確由收款方承擔換匯執行責任，而非由付款系統代為完成；其二為監理管轄權劃分——換匯若發生於台灣側（遊客支付時），則受台灣主管機關管轄；若發生於新加坡側（商家結算時），則受新加坡 MAS 管轄。將換匯推至商家結算階段，可使跨境換匯行為落入收款地之監理框架，符合各司法管轄區對外匯業務的屬地管轄原則。此一設計的代價是商家承擔支付至結算期間的匯率波動風險。
貳、 附買回交易（Repo）場景演示
情境：金融機構間短期資金融通。Borrower 以代幣化公債（ERC-3643）作抵押品，向 Lender 借入現金。
一、 Repo 交易狀態機
狀態轉移路徑：INITIATED → BORROWER_FUNDED / LENDER_FUNDED → FUNDED → EXECUTED → SETTLED 或 DEFAULTED。FUNDED 之前可 cancelRepo() 取消。交易由 initiateRepo() 建立後，Borrower 與 Lender 可不限順序分別注資，雙方均完成後進入 FUNDED；executeRepo() 執行原子交換，最終依到期還款與否分別結算至 SETTLED 或 DEFAULTED。
二、 抵押品鎖定與雙層合規
(一)、 Borrower 的 ERC-3643 公債透過 wrap() 封裝為 PBM（底層靜態合規驗證）。
(二)、 fundAsBorrower() 轉入 PBM 至 RepoContract（觸發 CollateralRule 抵押率驗證）。
(三)、 fundAsLender() 轉入現金 PBM（觸發 CashAdequacyRule）。
(四)、 executeRepo() 原子性交換。
(五)、 到期時有兩條路徑：settleRepo() 為正常結算，Borrower 歸還本金加利息的現金 PBM，合約同步將抵押品 PBM 退還給 Borrower，完成與 executeRepo() 方向相反的交換；claimCollateral() 為違約處理，若 Borrower 未能如期還款，Lender 呼叫此函式直接沒入合約中鎖定的抵押品 PBM 作為賠償，交易標記為 DEFAULTED。
三、 Repo合規檢查點
表 7 Repo交易各階段合規檢查
階段
規則
驗證內容
Borrower 存入抵押品
CollateralRule
抵押率 ? 150%，檢查抵押品市值是否達借款金額的 150% 以上，防止抵押不足
Lender 存入現金
CashAdequacyRule
PBM 餘額充足，確認 Lender 的 PBM 餘額足以支應本次借款金額
雙方注資
verifyPartyCompliance
角色差異化 KYC 驗證，依角色分別驗證 KYC，Borrower 與 Lender 適用不同的身份條件
PBM 轉移
checkTransferCompliance
外層合規（身份 + 規則），每筆轉帳同時檢查身份白名單與業務規則，兩者均通過才放行
unwrap 解封裝
ERC3643Token.transfer()
底層靜態合規，底層 ERC-3643 公債的靜態合規，確認持有人於發行時已取得的轉讓資格仍然有效
四、 完整合約呼叫關係流程
　　以端對端視角，說明一筆完整 Repo 交易從資產封裝到最終結算，依序呼叫哪些合約、觸發哪些合規規則，以及每個步驟後狀態機的轉移結果。整體流程分為「前置準備」與「Repo 主流程」兩大階段。
表 8 Repo完整合約呼叫流程總覽
步驟
呼叫函數
觸發之合規規則
狀態機轉移
前置（Borrower）
GL1PolicyWrapper.wrap()
KYC 身份 + ERC-3643 靜態合規
—
前置（Lender）
GL1PolicyWrapper.wrap()
KYC 身份 + 現金鎖定
—
Step 1
RepoContract.initiateRepo()
參數驗證
INITIATED
Step 2
RepoContract.fundAsBorrower()
CollateralRule（抵押率 ? 150%）
BORROWER_FUNDED
Step 3
RepoContract.fundAsLender()
CashAdequacyRule（現金充足）
FUNDED
Step 4
RepoContract.executeRepo()
原子交換，PBM 雙向移轉
EXECUTED
Step 5a
RepoContract.settleRepo()
還款 PBM 驗證
SETTLED
Step 5b
RepoContract.claimCollateral()
違約時間驗證
DEFAULTED
(一)、 前置準備：資產封裝為 PBM
　　在進入 Repo 主流程之前，Borrower 的代幣化公債（ERC-3643）與 Lender 的現金（ERC-20 穩定幣）均須事先透過 GL1PolicyWrapper.wrap() 封裝為 PBM Token，方能在後續流程中作為合規載體流通。此步驟為雙層合規架構的入口——底層 ERC-3643 靜態合規（KYC 身份驗證）在封裝時完成初步確認，並將底層資產鎖定於 GL1PolicyWrapper 合約中。
(二)、 Borrower封裝抵押品（代幣化公債）
// 1. Borrower 授權 GL1PolicyWrapper 鎖定底層 ERC-3643 公債
ERC3643Token.approve(GL1PolicyWrapper合約地址, amount)

// 2. 呼叫 wrap() 封裝
GL1PolicyWrapper.wrap(
    AssetType.ERC3643,      // 資產類型
    ERC3643代幣地址,         // 底層資產
    tokenId,                // ERC-721/1155 適用
    amount,                 // 封裝數量
    proof                   // 離線合規證明
)
wrap() 內部依序執行：
? GL1PolicyManager.verifyIdentity()：查詢 CCIDRegistry 確認 Borrower KYC 等級有效
? ERC3643Token.transferFrom(Borrower → GL1PolicyWrapper)：底層公債鎖定入庫
? PBMToken.mint(Borrower, collateralPbmTokenId, amount)：鑄造對應的抵押品 PBM

(三)、 Lender封裝現金
// 1. Lender 授權 GL1PolicyWrapper 鎖定現金
ERC20穩定幣.approve(GL1PolicyWrapper合約地址, amount)

// 2. 呼叫 wrap() 封裝
GL1PolicyWrapper.wrap(
    AssetType.ERC20,
    穩定幣地址,
    0,
    amount,
    proof
)
// → PBMToken.mint(Lender, cashPbmTokenId, amount)
完成後，Borrower 持有 collateralPbmTokenId，Lender 持有 cashPbmTokenId，兩者均為 ERC-1155 規格的 PBM Token，後續所有資產流動皆以 PBM 形式進行。
(四)、 Repo主流程
Step 1：Borrower 發起 Repo → initiateRepo()
RepoContract.initiateRepo(
    cashAmount,             // 需借入的現金金額
    collateralPbmTokenId,   // 抵押品 PBM 的 tokenId
    collateralAmount,       // 抵押品數量
    repoRate,               // 年化利率（basis points，500 = 5%）
    durationSeconds,        // Repo 期限（秒）
    lender地址              // 指定 Lender，address(0) 表示開放
)
// 狀態機：[初始] → INITIATED
合約驗證參數後，以 keccak256(msg.sender, cashAmount, collateralPbmTokenId, block.timestamp, repoNonce++) 產生唯一 repoId，並建立 RepoAgreement 結構儲存於鏈上。

Step 2：Borrower 存入抵押品 → fundAsBorrower()
// Borrower 須先授權 RepoContract 操作 PBM
PBMToken.setApprovalForAll(RepoContract地址, true)
RepoContract.fundAsBorrower(repoId)
// 內部呼叫鏈：
//   GL1PolicyManager.verifyPartyCompliance(jurisdiction, Borrower, "BORROWER")
//     └─ CCIDRegistry.getKYCTier()          ← KYC 等級驗證
//     └─ CollateralRule.checkCompliance()   ← 抵押率 ? 150%
//
//   PBMToken.safeTransferFrom(Borrower → RepoContract, collateralPBM)
//     └─ PBMToken._update() Hook 自動觸發
//          └─ GL1PolicyWrapper.checkTransferCompliance()
//               └─ GL1PolicyManager → 規則引擎
//
// 狀態機：INITIATED → BORROWER_FUNDED
CollateralRule 的核心邏輯為：抵押品市值 = 數量 × 預言機價格，若抵押品市值 < 借款金額 × 150%，則整筆交易 revert，訊息為「Insufficient collateral value」。此外，每次 PBM 的 safeTransferFrom 都會自動觸發 _update() Hook，確保即使繞過 RepoContract 直接轉移 PBM，合規檢查仍不可規避。

Step 3：Lender 存入現金 → fundAsLender()
RepoContract.fundAsLender(repoId, cashPbmTokenId)

// 內部呼叫鏈：
//   GL1PolicyManager.verifyPartyCompliance(jurisdiction, Lender, "LENDER")
//     └─ CashAdequacyRule.checkCompliance() ← 現金 PBM 餘額 ? cashAmount
//
//   PBMToken.safeTransferFrom(Lender → RepoContract, cashPBM)
//     └─ _update() Hook → checkTransferCompliance()
//
// 狀態機：BORROWER_FUNDED → FUNDED  (或 LENDER_FUNDED → FUNDED)
注意：Borrower 與 Lender 的注資順序不限，系統會依雙方完成情況自動轉換狀態。待雙方均完成注資後，狀態進入 FUNDED，此後任何一方均無法單方面取消或提領。

Step 4：執行原子交換 → executeRepo()
RepoContract.executeRepo(repoId)
// ? 同一筆 transaction 內完成雙向 PBM 移轉（原子性保證）
//
// 1. 抵押品 PBM：RepoContract → Lender
PBMToken.safeTransferFrom(RepoContract, Lender, collateralPbmTokenId, amount)
//
// 2. 現金 PBM：RepoContract → Borrower
PBMToken.safeTransferFrom(RepoContract, Borrower, cashPbmTokenId, amount)

// 狀態機：FUNDED → EXECUTED
此步驟是整個 Repo 流程的核心。由於兩筆移轉置於同一筆交易中，EVM 的原子性保證「全成功或全回退」，不存在一方已交付資產而另一方未履行的中間風險。執行完成後，Lender 手持抵押品 PBM 作為擔保，Borrower 取得現金 PBM 完成借款目的。

Step 5a（正常路徑）：到期結算 → settleRepo()
// Borrower 須持有足夠的還款 PBM（本金 + 利息）
RepoContract.settleRepo(repoId, repaymentPbmTokenId)

// 內部邏輯：
// calculateSettlementAmount()
//   → interest = principal × repoRate × duration / (365 days × 10000)
//   → total = principal + interest
//
// 1. 還款 PBM：Borrower → Lender（本金 + 利息）
PBMToken.safeTransferFrom(Borrower, Lender, repaymentPbmTokenId, total)
//
// 2. 抵押品 PBM：Lender → Borrower（歸還）
PBMToken.safeTransferFrom(Lender, Borrower, collateralPbmTokenId, amount)

// 狀態機：EXECUTED → SETTLED
Step 5b（違約路徑）：認領抵押品 → claimCollateral()
// 須超過 maturityDate + gracePeriod（預設 3 天）
RepoContract.claimCollateral(repoId)

// 僅更新狀態為 DEFAULTED
// 抵押品 PBM 在 Step 4 executeRepo() 時已移轉至 Lender 手中
// 故此處無需再次移轉資產
// 狀態機：EXECUTED → DEFAULTED
(五)、 完整合約呼叫關係總覽
綜合上述各步驟，整體合約呼叫關係可整理如下：
使用者（Borrower / Lender）
  │
  ├── GL1PolicyWrapper.wrap()          ← 前置封裝（兩方各自執行）
  │    ├── GL1PolicyManager             ← 身份 + 規則驗證
  │    │    └── CCIDRegistry            ← KYC 查詢
  │    └── PBMToken.mint()              ← 鑄造 PBM
  │
  ├── RepoContract.initiateRepo()       ← Step 1：建立協議
  │
  ├── RepoContract.fundAsBorrower()     ← Step 2：抵押品入庫
  │    └── PBMToken._update() Hook
  │         └── GL1PolicyWrapper.checkTransferCompliance()
  │              └── GL1PolicyManager → CollateralRule
  │
  ├── RepoContract.fundAsLender()       ← Step 3：現金入庫
  │    └── PBMToken._update() Hook
  │         └── GL1PolicyWrapper.checkTransferCompliance()
  │              └── GL1PolicyManager → CashAdequacyRule
  │
  ├── RepoContract.executeRepo()        ← Step 4：原子交換
  │    ├── PBMToken.safeTransferFrom(RepoContract → Lender,   抵押品PBM)
  │    └── PBMToken.safeTransferFrom(RepoContract → Borrower, 現金PBM)
  │
  └── RepoContract.settleRepo()         ← Step 5a：正常結算
  或  RepoContract.claimCollateral()    ← Step 5b：違約處理
　　本流程體現了「合規即系統」的核心設計原則：資產始終以 PBM 作為載體流動，每次移轉均自動觸發合規 Hook，使得合規檢查從根本上內嵌於資產的傳輸路徑，無法被任何一方繞過。相較於傳統「事後稽核」模式，此架構實現了交易前（Pre-trade）的先驗執行，不合規的交易在上鏈前即遭到 revert，從根本上消除了違規交易進入帳本的可能性。
第五節 測試驗證與效益分析
壹、 測試架構與涵蓋範圍
本系統使用 Hardhat進行測試，涵蓋三個層次：
一、 單元測試——針對每個合約的個別功能
二、 整合測試——驗證多合約間的互動協作
三、 場景測試——模擬完整的金融場景端對端流程。
貳、 關鍵測試案例
一、 雙層合規攔截驗證
當 ComplianceModule 設定每人持有量上限 500 代幣時，轉帳 600 代幣觸發 "ERC-3643: Compliance failure" 並回退；轉帳 400 代幣正常通過。此測試確認底層靜態合規的先驗執行能力。
二、 ProofSet簽章驗證測試
trustedSigner 簽署的有效 ProofSet 成功 wrap；非授權簽署者觸發 "Invalid proof signer"；過期 ProofSet 觸發 "Proof expired"；豁免地址不需簽章。
三、 PBM Wrap/Unwrap 端對端驗證
ERC-20、ERC-721、ERC-1155 三種資產成功封裝為 PBM，底層資產轉移至 GL1PolicyWrapper；解封裝後底層資產正確歸還，PBM 被銷毀。
四、 Repo 場景端對端驗證
Lender 封裝現金、Borrower 封裝證券；雙方交換 PBM（模擬 Repo 開始）；Borrower 解封裝取得現金、Lender 解封裝取得抵押品，底層資產到帳驗證通過。
參、 效益分析
表 9 傳統架構與本系統之比較
面向
傳統架構
本系統實作
改善幅度
結算時效
T+2（跨境更長）
T+0 即時結算
100%
合規一致性
各機構自行詮釋法規
統一 Rule 合約自動執行
消除詮釋差異
規則擴展性
修改核心系統、停機升級
部署新 Rule + 註冊即生效
零停機
跨境成本
多層中介機構手續費
P2P 直接交易 + 鏈上手續費
降低 50% 以上
合規透明度
事後稽核、依賴人工審查
鏈上即時可驗證
100% 即時透明
身份管理
各機構獨立 KYC
CCIDRegistry 一次 KYC 多鏈使用
消除重複驗證
綜合而言，本系統成功驗證了 GL1 PCT 框架「從規範到實作」的技術可行性，證明透過「PBM 封裝 ERC-3643」之雙層合規架構，能夠在保障交易原子性的同時實現先驗合規執行，為金融機構提供一條兼顧效率、隱私與合規的數位轉型路徑。

第五章 結論與未來研究方向
第一節 研究結論與成果貢獻
本研究以「達成自動化合規監管」為核心目標，依據 Global Layer One (GL1) 所提出之可程式合規工具組 (Programmable Compliance Toolkit, PCT) 框架規範，設計並實作一套基於智能合約之嵌入式監理系統。透過「PBM 封裝 ERC-3643」之雙層合規架構，結合「離線檢驗、鏈上驗證」之混成機制，本研究成功驗證了將監管合規從「系統的附加元件」轉化為「系統運作之先決條件」的技術可行性。以下就本研究之核心發現與成果貢獻分述之。
一、 GL1 PCT 框架之實作。GL1 PCT 目前僅提供架構設計文件與功能規範描述，而無公開之參考實作程式碼。本研究為首個將其五大核心模組——行政控制 (Administrative Control)、政策封裝器 (Policy Wrapper)、政策管理器 (Policy Manager)、身份管理 (Identity Management) 與合規規則引擎 (Compliance Rules Engine)——以 Solidity 智能合約完整落地之學術實作，填補了從設計規範到可執行系統之間的技術缺口。實作結果證明，GL1 PCT 所定義的模組化架構具備足夠的技術精確度，得以轉化為可部署的智能合約系統，為後續研究者與產業實踐者提供了可參照的參考實作基礎。
二、 提出並驗證「PBM 封裝 ERC-3643」之雙層合規架構。本研究創新性地將合規職責劃分為「靜態合規」與「動態合規」兩個層次：底層以 ERC-3643 許可制代幣負責靜態合規——涵蓋 KYC 身份驗證、帳戶凍結與強制轉移等不因交易場景而異的基礎監管功能；外層以 Purpose Bound Money (PBM) 結合 ERC-7943 通用型實體資產介面標準 (uRWA) 負責動態場景合規——將反洗錢 (AML) 大額交易申報、制裁名單篩選、非居民外匯額度管控及抵押品驗證等隨場景變化之監理邏輯，直接嵌入資產本身的傳輸路徑中。此架構設計核心價值在於實現合規邏輯與底層資產的解耦：同一份 ERC-3643 代幣可在不同場景中配置不同規則集，而新增或修改合規規則僅需部署新的規則合約並向政策管理器註冊，無需修改任何既有合約，實現零停機擴展。
三、 ERC-7943 uRWA 標準之早期整合實作與跨框架技術融合，將 ERC-7943 通用型實體資產介面整合進完整嵌入式監理系統。除 GL1 PCT 框架外，本系統融合了 Chainlink ACE 自動化合規引擎之跨鏈身份概念，設計符合 GDPR 規範之跨鏈身份註冊表 (CCIDRegistry)，實現「一次 KYC、多鏈使用」的身份管理機制；同時參考 CAST Framework 之鏈上鏈下分離策略，引入離線檢驗與鏈上驗證的混成模式。此種跨框架整合展現了不同技術標準間的互補性與可組合性。
四、 以真實金融場景驗證之實務可行性。透過跨境支付（含 FX 匯率轉換）與附買回交易 (Repo) 兩大金融場景之完整實作與端對端演示，本研究驗證了以下實務效益：
(一)、 T+0 即時結算——透過智能合約的原子交換機制，交易的合規檢查與資產移轉在同一筆鏈上交易中完成，將傳統 T+2 甚至更長的跨境結算週期壓縮至即時完成
(二)、 交易原子性保障——在 Repo 交易中，抵押品鎖定與現金交付在同一交易中原子完成，不存在一方已付出而另一方未履行的中間風險
(三)、 不合規請求即時攔截——五個合規規則模組（WhitelistRule、AMLThresholdRule、FXLimitRule、CollateralRule、CashAdequacyRule）在交易發起階段即進行先驗驗證，不符合規定的交易在鏈上直接被拒絕 (Revert)，從根本上消除了違規交易上鏈的可能性。
五、 模組化規則設計證明系統之動態擴充能力。五個獨立的合規規則合約均實作統一的 IComplianceRule 介面，政策管理器透過 RuleSet 結構實現多管轄區規則的動態註冊、啟用與停用。驗證結果顯示，新增合規規則僅需部署新合約並註冊至政策管理器，全程無需停機或修改既有合約。此外，isOnChain 標記使鏈上即時執行與鏈下簽署驗證兩種模式得以在同一管轄區內無縫切換與混合使用，賦予系統高度的部署彈性。
第二節 架構權衡與實務限制：「合規即程式碼」與混合架構的內在張力
本節回應本研究核心論述的內在矛盾：一方面主張「合規即系統」的典範轉移，強調合規應由程式碼自動執行；另一方面，系統設計中卻採用依賴鏈下中介機構的混合驗證模式。此矛盾並非設計缺陷，而是在去中心化理想與金融監管實務之間所做的必要且有意識的權衡。以下從技術層面、信任假設及雙重防護三個維度進行分析。
壹、 技術層面的權衡
一、 Gas 成本與運算效能。雙層合規架構在提供完整監理覆蓋的同時，不可避免地增加了鏈上運算負擔。每筆 PBM 轉帳需依序通過外層動態合規（身份驗證、規則引擎逐一執行）與底層靜態合規（ERC-3643 五階段檢查）。相較於單一標準的合規檢查，Gas 消耗顯著增加。然而，本系統在 ERC3643Token.transfer() 中採用「快速失敗 (fail fast)」策略——將廉價的本地儲存讀取（暫停狀態、凍結狀態、餘額檢查）置於前段，昂貴的跨合約呼叫（身份驗證、合規規則）置於末段——使最常見的失敗情境得以最低成本被攔截，在整體上有效壓低平均每筆交易的 Gas 消耗。
二、 鏈下預言機依賴的中心化風險。離線檢驗機制的本質是將部分合規判斷委託給鏈下受信任機構。ECDSA 簽章驗證能確保「這份合規證明確實是授權機構簽發的」，但無法確保「授權機構的合規判斷本身是否正確」——即智能合約只能驗證「誰說的」，無法驗證「說的對不對」。若鏈下受信任機構遭到入侵或發生錯誤，簽發了不實的合規證明，鏈上合約會因為簽章本身有效而照常放行，形成「垃圾進、垃圾出 (Garbage In, Garbage Out)」的風險。然而，大規模 AML 模糊比對與制裁名單篩選涉及敏感個人資料，在鏈上公開執行既不可行（運算成本過高），也不符合 GDPR 等隱私法規的數據最小化原則，因此委託鏈下專業機構處理是目前的必要技術權衡。
三、 鏈上合規資料的可見性。雖然 CCIDRegistry 僅儲存去識別化的 identityHash 與 KYC 等級等元資料，不直接暴露個人可識別資訊 (PII)，但交易本身的流向、金額與時間在公有鏈上仍為透明可查。在機構間 Repo 交易等場景中，交易對手方的身份與交易規模可能構成敏感的商業資訊。此限制在聯盟鏈或私有鏈環境中可獲緩解，但在公有鏈部署時仍需額外的隱私保護技術（如零知識證明）加以補強。
貳、 信任假設的批判性分析
本系統在第三章中定義了四項核心信任假設——信任根源 (Root of Trust)、簽章有效性與資料真實性的落差、活性假設與阻斷風險 (Liveness Assumption)、以及隱私信任邊界 (Privacy Trust Boundary)。在此逐一回顧這些假設在實務部署中的意涵。
就信任根源而言，目前實作中僅設定單一授權簽署者 (trustedSigner)，存在單點故障風險。雖然未來可直接將其設為多簽錢包地址以實現 M-of-N 多方簽署而無需修改合約，但在當前實作中，此風險尚未被技術手段完全消除。就活性假設而言，離線合規機制依賴鏈下受信任機構持續在線簽發合規證明，若該機構因故無法回應，所有需要離線簽署的交易將被阻斷。本系統對此採取「寧可拒絕、不可放行」的設計原則——系統可用性暫時降低，但不會產生監管漏洞。純鏈上規則（如 WhitelistRule、CollateralRule）不受此影響，在此期間仍可作為基礎防線正常運作。
更深層的問題在於：上述設計是否與「去中心化」及「抗審查」的區塊鏈核心價值產生根本性衝突？本研究的立場是，此種犧牲在特定商業場景下是可被接受且必要的。在 Repo 交易等受高度監管的場景中，參與方本身即為受監管金融機構（如銀行、券商），對中介機構的信任是業務本質而非技術缺陷——這些機構本身即需遵循嚴格的監管要求並接受定期稽核。在跨境支付場景中，外匯管制本身即需要主權機構介入，完全去中心化的設計不符合現實監管需求。因此，本研究所建構的系統並非追求極致去中心化，而是在受監管金融活動的框架內，將人為操作的合規流程轉化為可程式化、可驗證且可追溯的自動化機制。
參、 雙重防護網：技術可審計、法律可追究
針對前述信任風險，本系統建構了「技術可審計、法律可追究」的雙重防護機制，將風險降至金融監理可接受的範圍。
在技術防線方面，即便發生鏈下預言機作惡或簽發不實合規證明的極端情況，監管機構仍可透過 ERC-7943 介面所提供的 forcedTransfer() 與 setFrozenTokens() 等行政控制功能，對問題資產進行事後凍結與強制轉移，實現事後矯正。此外，GL1PolicyWrapper 在每筆合規驗證通過後會生成 ComplianceProof 記錄（含交易雜湊、時戳、驗證者地址、適用規則清單），提供完整的鏈上審計軌跡，確保所有合規決策均可追溯與回溯驗證。
在法律防線方面，參照 CAST Framework 的設計，授權簽署者須與系統營運方簽訂代理協議 (Agency Agreement)，明確約定其合規判斷的法律責任。若簽署者簽發不實的合規證明，可依據協議追究法律責任，以法律層面的嚇阻力補強技術層面的信任。此雙重防護機制揭示了「合規即系統」的真正含義：它並非排除所有人類參與，而是確保合規成為系統運作的先決條件，並在出現例外時保有可追溯、可矯正的能力。技術自動化處理常規合規檢查，人類判斷力則在例外與爭議情境中發揮不可替代的作用——兩者互為補充而非互相取代。
第三節 未來研究方向
基於本研究之實作成果與權衡分析，以下提出四個具體的未來研究方向，期能在隱私保護、跨鏈互操作性、監管工具化與場景擴展等維度上進一步深化嵌入式監理機制的研究。
一、 零知識證明 (ZKP) 整合之隱私增強合規。本系統目前依賴鏈下受信任機構處理涉及個人敏感資料的合規檢查，並以數位簽章作為鏈上背書。此模式雖能有效保護隱私，但引入了對中介機構的信任依賴。未來研究可探討如何結合零知識證明技術，實現「證明合規但不揭露身份細節」——例如，使用者可在本地端生成「我已通過 KYC 且不在制裁名單中」的零知識證明，鏈上合約僅需驗證該證明的數學有效性，而無需知悉使用者的具體身份資訊。此方向有望在不依賴受信任中介的前提下達成隱私保護合規，進一步推進「合規即程式碼」的去中心化程度。然而，ZKP 的證明生成效能、設計複雜度及驗證 Gas 成本仍為需克服的技術瓶頸。
二、 基於 Chainlink CCIP 之跨鏈合規狀態同步。本研究已在 CCIDRegistry 中設計了跨鏈地址映射機制（linkCrossChainAddress），支援同一實體在不同鏈上的地址綁定。然而，目前的實作僅停留在身份映射層面，尚未實現跨鏈的合規狀態即時同步。未來研究可探討如何運用 Chainlink Cross-Chain Interoperability Protocol (CCIP)，在資產跨鏈轉移時同步傳遞合規狀態——確保代幣從 Ethereum 轉移至 Polygon 時，接收方的 KYC 資格、管轄區權限及凍結狀態能即時同步驗證，避免因跨鏈延遲產生合規盲點。
三、 監管儀表板 (Regulatory Dashboard) 與即時監控工具。嵌入式監理的理論基礎之一是「監理節點 (Supervisor Node)」概念——監管者作為區塊鏈網路中的節點，可即時讀取全網數據並自動生成監控報告。本研究已在合約層面實現了 ComplianceProof 記錄與 AML 申報事件 (LargeTransactionDetected)，但尚未為監管機構提供直覺化的監控介面。未來研究可基於本系統所生成的鏈上事件與合規記錄，開發即時監管儀表板，使監管機構得以視覺化地監控跨境資金流向、合規規則觸發頻率、異常交易模式及系統整體健康狀態。
四、 擴展至更多複雜金融場景。本研究以跨境支付與附買回交易驗證了雙層合規架構的場景適應能力。未來研究可進一步將此架構擴展至衍生性商品、去中心化金融 (DeFi) 借貸協議等更複雜的金融場景。這些場景涉及更複雜的要求，對合規規則引擎的表達能力與政策管理器的編排彈性提出了更高的需求。
綜上所述，本研究證明了技術應用不僅是提升金融作業效率的工具，更是達成合規監管目的之基礎設施。「PBM 封裝 ERC-3643」之雙層合規架構與「離線檢驗、鏈上驗證」之混成機制，為在效率、隱私與信任三難困境中找到務實的平衡點提供了一條可行路徑。儘管在去中心化程度、隱私保護等方面仍存在可改進之空間，本研究所建立的技術框架與實作經驗，為未來建構安全、透明且具備互操作性的全球金融網路提供了堅實的實務基礎與明確的演進方向。

參考文獻
(ERC-3643 Association) - Building Compliant RWA Infrastructure: From Regulatory. (2025, 7 1). Retrieved from https://www.youtube.com/watch?v=Bwj057lbtE0
Buglio, D. L. (2025, 6). ERC-7943: uRWA - Universal Real World Asset Interface. Retrieved from https://eips.ethereum.org/EIPS/eip-7943
Chainlink. (2025, 6 30). Chainlink Automated Compliance Engine (ACE): Technical Overview. Retrieved from https://blog.chain.link/automated-compliance-engine-technical-overview/
Chainlink. (2025, 6 30). Introducing Chainlink Automated Compliance Engine (ACE): Enabling Compliance-Focused Digital Assets Across Chains and Jurisdictions. Retrieved from https://blog.chain.link/automated-compliance-engine/
Chainlink Functions. (n.d.). Retrieved from Chainlink: https://docs.chain.link/chainlink-functions
ERC-3643. (n.d.). Retrieved from https://docs.erc3643.org/erc-3643
EU Blockchain Observatory & Forum. (n.d.). Retrieved from https://blockchain-observatory.ec.europa.eu/index_en
European Central Bank(ECB). (2025, 9). Digital euro innovation platform Outcome report: pioneers and visionaries workstreams. Retrieved from https://www.ecb.europa.eu/euro/digital_euro/timeline/profuse/shared/pdf/ecb.deprep250926_innovationplatform.en.pdf
Forge, S. G. (2021, 5). CAST White Paper. Retrieved from https://www.cast-framework.com/wp-content/uploads/2021/05/CAST-White-Paper-1.0_Final_17-05-2021.pdf
GL1. (2024, 6). Foundation Layer for Financial Networks. Retrieved from https://www.mas.gov.sg/-/media/mas-media-library/development/fintech/guardian/gl1---whitepaper.pdf
GL1. (2025). GL1 Programmable Compliance (PC) Toolkit. Retrieved from https://doc.global-layer-one.org/docs/programmable-compliance/introduction
How Chainlink ACE and GL1 Standardize Onchain Compliance | MAS, Banque de France, Chainlink at SFF. (2025). Retrieved from https://www.youtube.com/watch?v=8TstYt9GkV0
Jung. (2025, 9). RWA 合規標準的演進：從 ERC-3643 到更輕量的 ERC-7943 通用接口. Retrieved from https://medium.com/bsos-taiwan/erc-3643-to-7943-a8635791c3b2
Latka, N. (2025). From Compliance as Part of the System to Compliance as the System. Retrieved from https://www.compilot.ai/academy/aml-compliance/from-compliance-as-part-of-the-system-to-compliance-as-the-system
Luxembourg. (2025年6月30日). Chainlink Launches Automated Compliance Engine in Collaboration With Apex Group, GLEIF, and ERC3643 Association. 擷取自 https://www.erc3643.org/news/chainlink-launches-automated-compliance-engine-in-collaboration-with-apex-group-gleif-and-erc-3643-association?utm_campaign=PR&utm_content=336835499&utm_medium=social&utm_source=twitter&hss_channel=tw-1651862536906588160
MAS. (2023, 6 20). Purpose Bound Money (PBM) Technical Whitepaper. Retrieved from https://www.mas.gov.sg/-/media/mas-media-library/development/fintech/pbm/pbm-technical-whitepaper.pdf
OpenZeppelin ERC-1155. (n.d.). Retrieved from OpenZeppelin: https://docs.openzeppelin.com/contracts/5.x/erc1155
OpenZeppelin ERC-20. (n.d.). Retrieved from OpenZeppelin: https://docs.openzeppelin.com/contracts/5.x/erc20
OpenZeppelin ERC-721. (n.d.). Retrieved from OpenZeppelin: https://docs.openzeppelin.com/contracts/5.x/erc721
PurposeBoundMoney / PBM. (2023, 6 21). Retrieved from Github: https://github.com/PurposeBoundMoney/PBM
Toh, W. K., Brownworth, A., Bench, R., Li, N., & Sarwar, S. (2024). Application of Programmability to Commercial Banking and Payments. Retrieved from https://www.jpmorgan.com/kinexys/documents/Application-of-Programmability-to-Commercial-Banking-and-Payments.pdf







1


