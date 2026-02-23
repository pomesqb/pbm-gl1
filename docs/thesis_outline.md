基於智能合約之嵌入式監理機制設計與實作
Design and Implementation of Smart Contract-Based Embedded Supervision Mechanism

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
摘要 I
ABSTRACT II
目次 IV
表次 VI
圖次 VII
第一章 緒論 1
第一節 研究背景與動機 1
第二節 研究目的 2
第三節 研究貢獻 2
第四節 論文架構 3
第二章 文獻探討與技術背景 4
第一節 嵌入式監理 (EMBEDDED SUPERVISION) 4
壹、 典範轉移 4
貳、 從事後稽核 (Ex-post) 到先驗執行 (Ex-ante) 4
參、 合規即程式碼(Compliance-as-Code) 5
第二節 GLOBAL LAYER ONE(GL1)架構與可程式合規工具組(PCT) 5
壹、 GL1架構 5
貳、 GL1 PCT Programmable Compliance Toolkit 6
第三節 PURPOSE BOUND MONEY (PBM)基礎框架 7
第四節 ERC-7943 合規標準 9
壹、 設計動機與目標 9
貳、 核心功能模組 9
參、 與嵌入式監理架構的關聯性 10
第五節 ERC-3643：許可制代幣與合規身份標準 10
壹、 標準概述與發展背景 10
貳、 去中心化身份與合規模組 11
參、 強制轉移與交易控制 12
肆、 Chainlink ACE與ERC-3643合規協作架構 12
伍、 小結 13
第六節 CAST FRAMEWORK證券型代幣合規架構 14
壹、 CAST Framework 概述與設計理念 14
貳、 CAST 的三大核心支柱 14
參、 隱私保護與混合式數據架構 15
肆、 系統整合與互操作性 15
伍、 小結 16
第七節 CHAINLINK ACE 自動化合規引擎技術 16
壹、 技術架構與設計目標 17
貳、 核心組件功能 17
參、 與 GL1 架構的整合應用 18
第八節 鏈下與鏈上驗證權衡 18
壹、 兩種驗證模式之特性對比 19
貳、 關鍵權衡因素分析 19
第三章 系統設計與架構 21
第一節 系統總體架構 21
第二節 雙層合規架構設計：PBM 封裝 ERC-3643 22
壹、 設計理念：靜態合規與動態合規的職責劃分 22
貳、 ERC-7943 在雙層架構中的角色 23
參、 雙層合規觸發順序 23
第三節 身份管理架構設計 24
壹、 IdentityRegistry 簡化實作 24
貳、 CCIDRegistry 跨鏈身份註冊表 25
第四節 政策管理器與合規規則引擎設計 26
壹、 GL1PolicyManager 規則編排架構 26
貳、 ProofSet 與離線檢驗機制 27
參、 信任模型與失效場景分析 27
第五節 應用場景機制設計 28
壹、 跨境支付場景設計 28
貳、 附買回交易（Repo）場景設計 29
第四章 系統實作與應用分析 29
第一節 開發環境與核心工具 29
第二節 核心智能合約實作 30
壹、 ERC-3643 許可制代幣實作（ERC3643Token.sol） 30
貳、 PBM Token 與 ERC-7943 整合實作（PBMToken.sol） 31
參、 GL1 政策封裝器實作（GL1PolicyWrapper.sol） 32
肆、 政策管理器實作（GL1PolicyManager.sol） 33
伍、 跨鏈身份註冊表實作（CCIDRegistry.sol） 34
第三節 合規規則模組實作 35
第四節 應用場景實作演示 36
壹、 跨境支付場景演示 36
貳、 附買回交易（Repo）場景演示 37
第五節 測試結果與效益評估 38
第五章 結論與未來研究方向 39
第一節 研究結論與成果貢獻 39
第二節 架構權衡與實務限制：「合規即程式碼」與混合架構的內在張力 40
第三節 未來研究方向 41
參考文獻 24

表次
找不到圖表目錄。
圖次
找不到圖表目錄。

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
二、提出「PBM 封裝 ERC-3643」之雙層合規架構：本文創新性地將 ERC-3643 許可制代幣作為底層資產負責靜態合規（KYC 身份驗證、帳戶凍結與強制轉移），再以 PBM 封裝於外層負責動態場景合規（AML 大額交易、外匯管控、抵押品驗證），實現「靜態合規」與「動態合規」的職責劃分與解耦，此架構設計在現有文獻中未見先例。
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
(1) 接入層(Access Layer)負責處理用戶端點、錢包管理與身分驗證，由金融機構執行身分入駐(Onboarding)與KYC/AML檢查。
(2) 服務層(Service Layer)提供核心應用邏輯，如跨行轉帳、抵押品管理及跨鏈傳輸，並支援原子結算(DvP、PvP)功能。
(3) 資產層(Asset Layer)支持原生發行或代幣化的現金、債券及其他數位化實體資產(RWA)，確保資產能跨應用無縫流動。
(4) 平台層(Platform Layer)即GL1核心，提供區塊鏈底層帳本、虛擬機、共識機制及數據標準化服務，確保不同機構能在統一的數位基礎設施上進行公平競爭。
貳、 GL1 PCT Programmable Compliance Toolkit
為了將監理規範有效整合至數位體系中，GL1推出了可程式合規工具組(Programmable Compliance Toolkit,PCT) (GL1, 2025)，這是一套用於自動化合規檢查與即時執行法規要求的技術框架。PCT的核心理念是將特定司法管轄區的法律政策轉化為合規即程式碼(Compliance-as-Code)，直接嵌入資產的轉移流程中，實現先驗執行(Ex-ante enforcement)而非傳統的事後稽核。
PCT包含五個核心功能模組。
(1) 行政控制(Administrative Control)系統，提供監理機構在發生違規或緊急情況下凍結帳戶、恢復資產及實施緊急斷路器的權限。
(2) 政策封裝器(Policy Wrapper)，這是一種適應層技術，透過鎖定與鑄造(lock-and-mint)機制，在不修改代幣底層合約的情況下，強制資產在傳輸前必須通過特定的法規驗證。
(3) 政策管理器(Policy Manager)，作為協調層，負責編排政策封裝器與外部多個專門模組(如身分管理系統或規則引擎)之間的查詢與回應匯整。
(4) 身分管理(Identity Management)模組，利用加密技術與可驗證憑證(VC)來驗證參與者身分，同時保護隱私並符合數據保護規範。
(5) 合規規則引擎(Compliance Rules Engine)，負責執行具體的驗證邏輯，例如外匯限額檢查、資本流動管理及制裁名單篩選。
透過PCT工具組，金融機構能在符合隱私保護與各國法規的前提下，達成資產的原子結算，顯著降低跨境交易中的手動對帳負擔與人為錯誤風險。這套架構不僅解決了代幣化資產跨國流動時的規則不一問題，更為未來數位金融基礎設施的標準化建設提供了明確的實踐參考。
這套架構就像是在金融網絡上建立了一套自動化的數位海關系統，確保每一筆資產在跨境過關時，都已自動完成身分查驗與法規申報。
第三節 Purpose Bound Money (PBM)基礎框架
GL1架構提供了合規工具的整體組織與編排能力，但合規邏輯如何具體地「附著」於資產之上？Purpose Bound Money(PBM)提供了一種將「價值」與「使用規則」分離的技術路徑，使監理規則得以在資產生命週期中強制執行，同時保持底層貨幣的完全互通性。
PBM，即「特殊目的貨幣」，是由新加坡金融管理局（MAS）所提出的可程式化數位貨幣模型。其設計初衷是為了解決傳統「可程式化貨幣」（Programmable Money）可能導致的市場碎片化問題。PBM的核心理念是將貨幣的「價值」與其「使用規則」分開處理，從而創造出一種既可控又可互通的數位資產。 (MAS, 2023)
PBM的基礎架構主要由以下三個核心元件構成 (PurposeBoundMoney / PBM, 2023)：
(1) 底層數位貨幣(Store of Value)：這通常是一個標準的ERC-20代幣，作為PBM的底層抵押品或價值儲存。 (OpenZeppelin ERC-20)
(2) PBM 封裝器(PBM Wrapper)：PBM的主要合約，在技術上常以ERC-1155標準實作 (OpenZeppelin ERC-1155)。其職責是作為一個「封裝器」，負責在PBM鑄造時，鎖定等值的底層ERC-20代幣作為抵押。而在PBM被兌換時，負責銷毀PBM代幣，並釋放底層的ERC-20代幣給兌換者。
(3) PBM邏輯(PBM Logic)：獨立的抽象合約，是PBM靈活性的關鍵。它負責定義客製化的商業邏輯，例如限制PBM只能由特定商家兌換，或在特定時間後才能使用。PBM封裝器在執行關鍵動作（如轉移或兌換）時，會主動去呼叫PBM邏輯合約中的查核機制。
基礎框架定義了兩個核心查核機制：
轉移前檢查 (Pre-transfer Check)：在PBM轉移前進行檢查（例如，檢查接收地址是否在黑名單中）。
解封裝前檢查 (Unwrap Check)：在PBM解封裝前進行檢查（例如，檢查兌換者地址是否為「認可商家」）。
PBM 運作機制：

- 發行 (Issue)：PBM創造者（如政府或企業）先部署PBM邏輯合約來定義規則，然後部署PBM封裝器合約。創造者批准封裝器合約使用其底層資產，然後觸發鑄造機制，將底層資產鎖定在封裝器合約中，並鑄造出等值的PBM（ERC-1155）代幣。
- 分發 (Distribute)：創造者將PBM代幣分發給PBM持有者（如民眾或員工）。
- 轉移 (Transfer)：持有者之間可以相互轉移PBM代幣。每次轉移都會觸發轉移前檢查機制。
- 兌換 (Redeem)：當PBM持有者將PBM轉移給一個符合「解封裝前檢查」條件的地址時（例如，一個「認可商家」），PBM封裝器合約會觸發「解封裝」。
- 解封裝 (Unwrap)：PBM代幣被銷毀，同時合約將釋放內部鎖定的等值底層資產給該「認可商家」。
- 流通 (Circulation)：該商家收到的是不受任何限制的底層資產，可以自由地在二級市場上使用或交易。
  透過此架構，PBM成功地在「發行到兌換」的生命週期中施加了嚴格的用途限制，但一旦兌換完成，其底層價值又會回歸為完全可互通的通用貨幣，從而避免了市場的碎片化。
  第四節 ERC-7943 合規標準
  隨著實體資產代幣化（Real World Assets, RWAs）成為連接傳統金融與去中心化金融（DeFi）的核心橋樑，如何在區塊鏈上落實法律合規、資產凍結及強制轉移，成為現行技術標準亟待解決的問題。本研究採用的 ERC-7943 (Universal Real World Asset Interface, uRWA) 標準，即是針對此類需求所提出的通用型介面規範。 (Buglio, 2025)
  壹、 設計動機與目標
  傳統代幣標準如 ERC-20、ERC-721 及 ERC-1155 在設計之初並未考慮到法律監管的強制性需求。過去雖然有如ERC-3643等標準嘗試解決合規問題，但往往因過於複雜的權限控制或綁定特定的鏈上身分方案，導致其實施成本過高且缺乏靈活性。 (OpenZeppelin ERC-20) (OpenZeppelin ERC-721) (OpenZeppelin ERC-1155)
  ERC-7943的設計目標在於「極簡主義（Minimalism）」與「非偏好性（Unopinionated）」。它並不強加特定的合規檢查邏輯，而是提供一套標準化的介面，讓開發者能根據具體的監管需求實作相應的合規規則。
  貳、 核心功能模組
  ERC-7943擴展了基礎代幣標準，引入了以下關鍵的合規與強制執行功能：
- 先驗合規驗證(canTransact與canTransfer)：這是落實「嵌入式監理」的核心機制。canTransact主要用於驗證特定地址是否具備交易資格（如已完成KYC/AML審查），而canTransfer則根據特定政策（如每日交易限額）動態判斷該筆轉帳是否被允許。若驗證未通過，交易將直接在發起階段失敗，達成先驗執行 (Ex-ante) 的監理目標。
- ·資產凍結管理(setFrozenTokens)：該介面允許授權機構針對特定帳戶設定凍結金額或狀態。這對於因涉嫌洗錢防制或受制裁名單控管的資產至關重要，能有效防止有風險的資產在調查期間流動。
- 行政強制轉移 (forcedTransfer)：此功能提供了一個中性的法律強制執行手段。當發生司法判決扣押、法律合規處置或私鑰丟失後的資產恢復情境時，授權實體能跳過用戶意願，直接將資產從受限地址轉移至監管託管地址。
  參、 與嵌入式監理架構的關聯性
  在Global Layer One (GL1)的架構下，ERC-7943充當了「資產層」與「服務層（合規邏輯）」之間的技術契合點。相較於傳統的事後稽核，ERC-7943 配合 GL1 的政策管理器(Policy Manager)，能確保每一筆RWA交易在執行前都經過模組化合規引擎的檢查。
  這種架構優勢在於：
- 可組合性：確保代幣化的債券或存款能與DeFi協議安全互動，並在交易瞬時自動滿足監管期望。
- 相容性：其設計支援 Fungible (同質化) 與 Non-Fungible (非同質化) 資產，實現了不同類別RWA的監理標準化。
  第五節 ERC-3643：許可制代幣與合規身份標準
  壹、 標準概述與發展背景
  ERC-3643，又稱為 T-REX (Token for Regulated EXchanges) 協議，是一套專為受監管資產（Regulated Assets）與證券型代幣（Security Tokens）設計的以太坊代幣標準。該標準由 Tokeny Solutions 提出，並於 2023 年 12 月正式通過成為以太坊最終標準（Final Standard）。
  與強調無需許可（Permissionless）的 ERC-20 標準不同，ERC-3643 的核心設計哲學在於引入「許可制（Permissioned）」機制。其目標是在保持與 ERC-20 技術兼容性（Interoperability）的同時，確保代幣的持有與轉移完全符合監管要求（如 KYC/AML）。根據 ERC-3643 協會的定義，該標準特別適用於證券、現實世界資產（RWA）、忠誠度計畫及電子貨幣（E-Money）等需要發行方對帳本具備控制權的場景。 (ERC-3643) ((ERC-3643 Association) - Building Compliant RWA Infrastructure: From Regulatory, 2025)
  貳、 去中心化身份與合規模組
  ERC-3643 的運作依賴於一套模組化的智能合約體系，其核心創新在於將「身份驗證（Identity）」與「合規規則（Compliance）」從代幣合約中解耦。其架構主要包含以下關鍵組件：
  (1) 鏈上身份系統 (ONCHAINID)： ERC-3643 不直接將錢包地址視為用戶身份，而是採用了基於 ERC-734 與 ERC-735 的去中心化身份（DID）系統，稱為 ONCHAINID。每個投資者的錢包地址會連結到一個唯一的身份合約，該合約儲存了由受信任第三方（如 KYC 提供商）簽發的可驗證憑證（Verifiable Credentials/Claims）。這種設計允許「身份」與「錢包」分離，若用戶遺失私鑰，可透過更換錢包地址而無需重新進行 KYC，從而實現帳戶恢復功能。
  (2) 身份註冊表 (Identity Registry)： 這是連接代幣與身份的樞紐。發行方會維護一份受信任的聲明發行者（Trusted Claim Issuers）名單（例如合規的 KYC 供應商）以及所需的聲明主題（Claim Topics，如「合格投資人」或「美國居民」）。在轉帳發生時，代幣合約會查詢註冊表，驗證接收方的 ONCHAINID 是否持有有效的合規憑證。
  (3) 模組化合規引擎 (Modular Compliance)： 除了身份資格外，交易還需通過動態的合規規則檢查。ERC-3643 允許發行方插拔不同的合規模組（Modules），例如限制單一國家的投資人總數、每日交易限額或閉鎖期限制。這與 BlackRock 的 BUIDL 代幣所使用的簡單白名單機制不同，ERC-3643 提供了更高的彈性，可針對不同資產類別設定複雜的邏輯。
  參、 強制轉移與交易控制
  為了滿足證券法規中對於資產恢復與法律執行的要求，ERC-3643 引入了數個 ERC-20 所缺乏的控制功能，這在被稱為「行政控制（Administrative Control）」：
  · 強制轉移 (forcedTransfer)：允許發行方或指定代理人在無需私鑰簽名的情況下，強制移動投資人帳戶內的代幣。此功能主要用於法律強制執行（如法院命令扣押）、資產恢復或錯誤交易回滾。
  · 暫停與凍結 (Pause/Freeze)：發行方可針對特定地址進行凍結，或在緊急狀況下暫停整個合約的交易功能，以應對駭客攻擊或重大合規事件。
  雖然這些功能賦予了發行方極大的權力，但在受監管的金融市場中，這是確保資產負債表完整性與法律合規性的必要手段。
  肆、 Chainlink ACE與ERC-3643合規協作架構
  Chainlink ACE (Automated Compliance Engine) 與 ERC-3643 的關係可以形容為「基礎設施與代幣標準的深度整合」。Chainlink ACE 並非要取代 ERC-3643，而是作為一套增強工具，賦予 ERC-3643 代幣跨鏈互操作性、動態合規能力以及更強的機構級身份驗證。 (Luxembourg, 2025)
  (1) 戰略合作夥伴關係
  雙方的合作旨在解決機構級資產在區塊鏈上面臨的「孤島問題」與「合規數據整合問題」。透過將 ACE 整合進 ERC-3643，該標準得以從原本的單一鏈上許可制代幣，演進為跨鏈、動態且策略驅動的資產標準。
  (2) 技術整合點
  兩者的結合主要體現在以下三個層面：
  A. 身份層的擴展 (Identity Extension)：CCID與ONCHAINID的結合
  ERC-3643原生機制：ERC-3643 內建了一套名為 ONCHAINID 的身份系統，用來儲存用戶的資格憑證（Verifiable Credentials）。
  ACE的加值：Chainlink ACE 的 CCID (Cross-Chain Identity) 服務與 ERC-3643 進行了對接。這意味著原本僅在某一條鏈上有效的 ONCHAINID 憑證，現在可以透過 CCID 進行跨鏈同步與管理。
  效益：這讓 ERC-3643 代幣的持有者只需進行一次 KYC，其身份憑證即可透過 Chainlink 的基礎設施在不同的區塊鏈網絡中被重複使用與驗證。
  B. 合規邏輯的動態化：Policy Manager 的介入
  ERC-3643 原生機制：ERC-3643 使用 Compliance Modules 來檢查交易是否合規（例如人數上限、國籍限制）。
  ACE的加值：在雙方合作的實作中，ERC-3643 代幣可以將合規檢查的邏輯「外包」給 Chainlink ACE 的 Policy Manager。
  效益：動態更新，發行方可以在鏈下透過 Policy Manager 修改合規規則（例如調整制裁名單或交易限額），而無需重新部署或升級鏈上的代幣合約。
  引入vLEI：透過 Policy Manager，ERC-3643 代幣可以直接驗證由 GLEIF 發行的 vLEI (可驗證法人機構識別編碼)，這在純鏈上環境中是很難做到的。
  C. 跨鏈互操作性 (Interoperability)
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

1. 跨鏈身份識別 (Cross-Chain Identity, CCID) CCID 是一種可重複使用的去中心化身份框架，用於將鏈下的實體驗證憑證（如 LEI 代碼、KYC 證明）與鏈上的錢包地址進行綁定。
   · 隱私保護機制：CCID 不會在鏈上儲存個人的非公開資訊。相反，它儲存的是由受信任機構（如身份驗證服務商 IDVs）簽發的加密證明，證明該地址持有者已通過特定檢查（例如：是否為合格投資人、是否在制裁名單外）。
   · 信任模型：CCID 支援多種信任模型，包括由資產發行方自行驗證、依賴第三方 IDV，或整合全球法人機構識別編碼（GLEIF）發行的 vLEI，實現跨機構的身份互認。
2. 政策管理器 (Policy Manager) 政策管理器是一個可客製化的規則引擎，負責定義、管理並執行合規邏輯。它允許發行方將法律規則轉化為智能合約可讀的指令。
   · 生命週期管理：政策的執行分為定義（鏈下設定規則）、執行（計算交易是否合規）與強制（鏈上確認結果）三個階段。
   · 動態規則：管理者可隨時更新規則（如調整轉帳限額、更新黑名單），而無需重新部署資產合約。常見的內建策略包括允許/拒絕名單（Allow/Deny List）、交易速率限制（Rate Limit）與餘額上限控制。
   參、 與 GL1 架構的整合應用
   在 Global Layer One (GL1) 的參考模型中，Chainlink ACE 被視為「可程式合規工具組（Programmable Compliance Toolkit, PCT）」的具體技術實作範例。
   · 身份協調：ACE 對應於 GL1 架構中的「身份管理模組（Identity Management Module）」，負責處理跨生態系統的身份對帳與憑證驗證。
   · 規則執行：ACE 的 Policy Manager 承擔了 GL1 中「合規規則引擎（Compliance Rules Engine）」的角色，負責執行如資本流動管理等複雜邏輯。
   · 政策封裝：ACE 支援 GL1 提出的「政策封裝器（Policy Wrapper）」概念。在資產轉移前，Wrapper 會呼叫 ACE 進行預驗證，只有當 Policy Manager 確認交易雙方身份合規（如具備有效 CCID）且未違反政策時，資產才能被解鎖並完成結算。
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
   本章以「如何設計」為核心，說明系統各組件的架構決策與互動方式。

第一節 系統總體架構
依據 GL1 四層參考模型（接入層、服務層、資產層、平台層），說明本系統各合約在四層架構中的定位與互動關係，並附上系統總體架構圖。

- 接入層（Access Layer）：DApp / 前端介面
- 服務層（Service Layer）：GL1PolicyManager（政策編排引擎）、CCIDRegistry（跨鏈身份註冊）、合規規則模組（WhitelistRule、CashAdequacyRule、CollateralRule、AMLThresholdRule、FXLimitRule）
- 資產層（Asset Layer）：GL1PolicyWrapper（政策封裝器 + FX 轉換）、PBMToken（ERC-1155）、ERC3643Token（許可制代幣）、RepoContract（Repo 交易管理）
- 平台層（Platform Layer）：Ethereum / EVM 兼容鏈

第二節 雙層合規架構設計：PBM 封裝 ERC-3643
本節為本研究的核心架構創新，闡述為何需要雙層架構，以及兩層各自的職責。

壹、 設計理念：靜態合規與動態合規的職責劃分

- 底層資產（ERC-3643）負責「靜態/基礎合規」：KYC 身份驗證（透過 IdentityRegistry）、合格投資人資格審查、帳戶凍結與強制轉移（Administrative Control）、模組化合規引擎（ComplianceModule）
- 外層封裝（PBM / ERC-1155）負責「動態/場景合規」：跨管轄區外匯管制（FXLimitRule）、Repo 交易特定條件（CollateralRule、CashAdequacyRule）、AML 大額交易申報（AMLThresholdRule）、白名單動態管理（WhitelistRule）
- 解耦與互操作性：透過 GL1PolicyWrapper 將底層資產封裝，使監管規則可動態附加與更新，而不必修改底層 ERC-3643 合約

貳、 ERC-7943 在雙層架構中的角色

- ERC-7943（uRWA）提供標準化的合規介面（canTransact、canTransfer、setFrozenTokens、forcedTransfer），作為 PBM Token 實作合規功能的技術基礎
- 說明 PBMToken 如何整合 ERC-7943 介面，使其具備先驗合規驗證與行政控制能力
- ERC-7943 的極簡設計與 ERC-3643 的完整許可制設計形成互補：前者提供通用介面，後者提供深度身份管理

參、 雙層合規觸發順序
以一筆 PBM 轉帳交易為例，說明雙層合規的觸發順序圖：

1. 用戶發起 PBM 轉帳
2. PBMToken.\_update() 呼叫 GL1PolicyWrapper.checkTransferCompliance()
3. GL1PolicyWrapper 透過 GL1PolicyManager 檢查外層 PBM 規則（WhitelistRule、FXLimitRule、AMLThresholdRule 等）
4. 若交易涉及 unwrap（解封裝），底層 ERC3643Token.transfer() 再執行內層合規檢查（暫停狀態 → 帳戶凍結 → 餘額充足 → IdentityRegistry 身份驗證 → ComplianceModule 規則檢查）

第三節 身份管理架構設計
說明本系統的身份管理如何參照 ERC-3643 的 ONCHAINID 概念進行簡化實作，並透過 CCIDRegistry 擴展跨鏈身份能力。

壹、 IdentityRegistry 簡化實作

- 說明本系統參照 ERC-3643 的 ONCHAINID 概念，採用簡化的地址型態（address）取代完整的 ONCHAINID 身份合約，降低實作複雜度
- IdentityRegistry 負責管理投資者地址與身份、國家代碼的映射
- isVerified() 整合 CCIDRegistry 的 KYC 驗證，實現雙重身份確認
- 說明此簡化設計的取捨：降低了部署成本與複雜度，但犧牲了 ONCHAINID 的錢包恢復便利性

貳、 CCIDRegistry 跨鏈身份註冊表

- 設計理念：敏感資料存鏈下（符合 GDPR），可驗證性證明存鏈上
- 多層級 KYC 分級（TIER_NONE → TIER_BASIC → TIER_FULL → TIER_INSTITUTIONAL）
- 身份標籤管理（居民/非居民/法人/制裁名單），用於自動觸發特定監管邏輯
- 跨鏈地址映射與同步
- 管轄區權限管理

第四節 政策管理器與合規規則引擎設計

壹、 GL1PolicyManager 規則編排架構

- RuleSet 結構設計：如何按管轄區、資產類型動態註冊規則集
- 多管轄區規則映射：同一筆交易可能需通過多個管轄區的不同規則
- 多方角色驗證（verifyPartyCompliance）：支援 Lender/Borrower 等不同角色的差異化合規要求
- 混合執行模式（鏈上/鏈下）：說明如何支援純鏈上規則與離線簽署兩種模式

貳、 ProofSet 與離線檢驗機制

- 說明 ProofSet 結構如何承載鏈下受信任機構的合規簽署
- 鏈上合約僅需驗證簽署效力，即可作為合規背書
- 此設計如何落實第二章所探討的「離線檢驗、鏈上驗證」混成機制

參、 信任模型與失效場景分析（Trust Model & Failure Scenarios）
本小節正面回應「合規即程式碼」理念與「離線檢驗」混合模式之間的內在張力，明確定義本系統的信任假設與其邊界。

（一）信任根源的定義（Root of Trust）

- 明確界定本系統採取的信任模式：本系統的信任假設為「許可制聯邦（Permissioned Federation）」，即合規證明需獲得授權簽署者的簽章方可視為有效驗證
- 對比三種信任模型：單一發行方驗證（Issuer Self-verification）、第三方 IDV（Identity Verification Provider）、聯盟共識（Consortium/Federated，M-of-N 多方簽署）
- 若本系統採單一機構簽署，則承認存在「單點故障（Single Point of Failure）」風險，並說明如何透過 CAST Framework 中的法律代理協議（Agency Agreement）來緩解此技術風險

（二）簽章有效性與資料真實性的落差（The Oracle Problem）

- 核心挑戰：智能合約只能驗證「簽章是不是真的」，無法驗證「這個人是不是真的合規」
- 信任假設定義：「本系統假設鏈下預言機（Oracle）所輸入的數據真實反映了現實世界的法律狀態」
- GIGO 風險（Garbage In, Garbage Out）：若鏈下機構被入侵並對不合規地址簽發「合規」憑證，鏈上合約將無條件執行
- 為何仍採此設計：引用第二章文獻，說明這是處理「百萬級別 AML 模糊比對」與「高頻黑名單更新」所必須的技術權衡

（三）活性假設與阻斷風險（Liveness Assumption）

- 隱藏的信任假設：鏈下驗證服務必須保持高可用性（High Availability）
- 失效模式選擇：本系統採「安全失效（Fail-safe）」模式——若鏈下驗證服務失效，系統暫停所有交易，而非採「開放失效（Fail-open）」模式放行未驗證交易
- 參考 CAST Framework 中「業務連續性計畫（BCP）」的描述，說明如何依據鏈上狀態機重建帳本

（四）隱私與合規的法律信任邊界（Privacy Trust Boundary）

- 信任假設：「本架構建立在『數據最小化（Data Minimization）』原則之上，鏈下機構承擔保管個資（PII）的法律責任，鏈上驗證者不需要也不應接觸原始個資」
- CCIDRegistry 僅儲存加密證明（Encrypted Proofs）而非個資本身
- 信任邊界：鏈上信任鏈下的「判斷結果（Yes/No）」，但不信任鏈下環境能永久保護「原始資料」，因此原始資料根本不應上鏈

第五節 應用場景機制設計

壹、 跨境支付場景設計

- 場景描述：台灣遊客在新加坡商家消費，支付 TWD 穩定幣、商家收取 SGD 結算
- FX 匯率轉換架構：FXRateProvider 提供多幣種匯率（TWD、SGD、USD、CNY）
- 跨境支付結算流程設計：payWithFXConversion → 匯率查詢 → 合規檢查 → 鑄造 PBM → settleCrossBorderPayment
- 涉及的合規檢查：WhitelistRule（商家身份驗證）、FXLimitRule（非居民外匯額度）

貳、 附買回交易（Repo）場景設計

- 場景描述：金融機構間的短期資金融通
- Repo 交易狀態機設計（INITIATED → FUNDED → EXECUTED → SETTLED / DEFAULTED），附狀態轉移圖
- 抵押品鎖定機制：代幣化公債（ERC-3643）如何透過 GL1PolicyWrapper 封裝為 PBM 並存入 RepoContract
- 涉及的合規檢查：CollateralRule（抵押率 ≥ 150%）、CashAdequacyRule（現金充足性）、雙方 KYC 透過 CCID 驗證

第四章 系統實作與應用分析
本章以「如何實作」為核心，展示具體的 Solidity 程式碼，特別是雙層合規的觸發機制與各模組的技術細節。

第一節 開發環境與核心工具

- 智能合約語言：Solidity ^0.8.20
- 開發框架：Hardhat
- 依賴庫：OpenZeppelin Contracts
- 測試框架：Hardhat + Chai

第二節 核心智能合約實作

壹、 ERC-3643 許可制代幣實作（ERC3643Token.sol）

- 實作 IERC3643 介面，繼承 ERC-20 標準
- 使用 AccessControl 的 AGENT_ROLE 取代 ERC-173 Owner 機制（說明設計考量）
- transfer() 中的合規檢查順序：代幣未暫停 → 帳戶未凍結 → 未凍結餘額充足 → IdentityRegistry 驗證雙方身份 → ComplianceModule 規則檢查
- 行政控制功能：強制轉移（forcedTransfer）、帳戶凍結（setAddressFrozen）、部分凍結（freezePartialTokens）、暫停（pause）
- 錢包恢復功能（recoveryAddress）
- 搭配的 ERC-3643 元件：IdentityRegistry、TrustedIssuersRegistry、ClaimTopicsRegistry、ComplianceModule

貳、 PBM Token 與 ERC-7943 整合實作（PBMToken.sol）

- ERC-1155 標準實作
- 整合 ERC-7943 uRWA 介面：canTransact()、canTransfer()、setFrozenTokens()、forcedTransfer()
- 轉移前合規檢查 Hook（\_update）：每次轉移自動呼叫 GL1PolicyWrapper.checkTransferCompliance()
- Wrapper 專屬鑄造/銷毀權限設計

參、 GL1 政策封裝器實作（GL1PolicyWrapper.sol）

- wrap 函數解析：如何將底層資產（ERC-20/ERC-721/ERC-1155，包含 ERC-3643）鎖定入庫，並鑄造對應的 PBM Token
- unwrap 函數解析：銷毀 PBM Token 並歸還底層資產
- checkTransferCompliance 雙層攔截邏輯：先通過 PBM 外層規則審查（透過 GL1PolicyManager），再滿足底層 ERC-3643 的轉帳合規要求
- 合規證明結構（ComplianceProof）：記錄每筆交易的合規驗證結果
- FX 轉換功能：wrapWithFXConversion、payWithFXConversion、settleCrossBorderPayment

肆、 政策管理器實作（GL1PolicyManager.sol）

- RuleSet 結構實作與規則動態註冊
- 管轄區規則映射（jurisdictionRuleSets）
- 多方角色驗證（verifyPartyCompliance）實作
- 混合執行模式：鏈上即時驗證與鏈下簽署驗證的切換機制

伍、 跨鏈身份註冊表實作（CCIDRegistry.sol）

- KYC 等級結構與驗證邏輯
- 身份標籤管理（居民/非居民/法人/制裁）
- 跨鏈地址映射（Ethereum ↔ Polygon ↔ BSC）
- 管轄區權限審批機制
- GDPR 合規：僅儲存身份雜湊，不儲存 PII

第三節 合規規則模組實作（contracts/rules/）
以統一格式（觸發條件 → 檢查邏輯 → 輸出結果）說明五個 Rule 合約：

| 規則合約             | 功能                   | GL1 對應範例                    |
| -------------------- | ---------------------- | ------------------------------- |
| WhitelistRule.sol    | KYC/AML 白名單檢查     | Whitelisting Selected Receivers |
| CashAdequacyRule.sol | 現金充足性驗證         | Cash Adequacy Check             |
| CollateralRule.sol   | 抵押品價值與 LTV 驗證  | Collateral Sufficiency          |
| AMLThresholdRule.sol | 大額交易申報與拆分偵測 | Large Transaction Reporting     |
| FXLimitRule.sol      | 非居民外匯額度限制     | Cross-Border Payment Limits     |

第四節 應用場景實作演示

壹、 跨境支付場景演示

- 情境：台灣遊客在新加坡商家消費
- 參與方：遊客（持有 TWD 穩定幣）、商家（接收 SGD 結算）、合規驗證節點
- 交易流程：商家標價 100 SGD → 遊客調用 payWithFXConversion() → 查詢 SGD/TWD 匯率 → WhitelistRule 驗證商家 → FXLimitRule 檢查外匯額度 → 扣款 TWD 鑄造 PBM → 商家調用 settleCrossBorderPayment() 收取 SGD
- 合規檢查點分析

貳、 附買回交易（Repo）場景演示

- 情境：金融機構間的短期資金融通
- 參與方：Borrower（提供代幣化公債作為抵押品）、Lender（提供現金）
- 交易流程：Borrower 發起 Repo（initiateRepo）→ Borrower 存入抵押品（fundAsBorrower）→ CollateralRule 驗證抵押率 → Lender 存入現金（fundAsLender）→ CashAdequacyRule 驗證 → 執行原子交換（executeRepo）→ 到期結算（settleRepo）或違約處理（claimCollateral）
- 合規檢查點分析

第五節 測試結果與效益評估

- 測試覆蓋範圍概述（單元測試、整合測試）
- 與傳統模式的效益比較：

| 評估維度   | 傳統模式       | 本研究實作             | 改善幅度  |
| ---------- | -------------- | ---------------------- | --------- |
| 結算時效   | T+2            | T+0（即時）            | 100%      |
| 合規一致性 | 各機構自行解讀 | 統一 Rule 合約         | 消除差異  |
| 擴充性     | 升級核心系統   | 部署新 Rule 合約並註冊 | 無需停機  |
| 跨境成本   | 多層中介費用   | 直接 P2P + 鏈上手續費  | 降低 50%+ |
| 透明度     | 事後稽核       | 即時可驗證             | 100%      |

第五章 結論與未來研究方向

第一節 研究結論與成果貢獻

- 證明「PBM + ERC-3643」的雙層架構，能有效解決單一標準無法兼顧「資產級別控制」與「動態交易場景限制」的痛點
- 成功落實 GL1 PCT 框架與「合規即系統」的先驗執行（Ex-ante）
- 透過跨境支付與 Repo 交易兩大場景驗證架構的通用性與可擴展性
- 模組化規則設計（五個獨立 Rule 合約）證明系統具備動態擴充能力

第二節 架構權衡與實務限制：「合規即程式碼」與混合架構的內在張力
本節回應本研究核心論述的內在矛盾：一方面主張「合規即系統」的典範轉移，另一方面採用依賴鏈下中介機構的混合驗證模式。此矛盾並非設計缺陷，而是在去中心化理想與金融監管實務之間所做的必要且有意識的權衡。

壹、 技術層面的權衡

- 雙層合規檢查帶來的 Gas Fee 與運算成本增加
- 鏈下預言機依賴的中心化風險：本質上仍依賴「人/機構」而非純粹的「程式碼」
- ERC-3643 生態系統成熟度問題（目前主要在歐洲監管框架下使用）
- 智能合約升級限制（本系統未採用 Proxy 機制）
- 隱私問題：鏈上合規相關資料的可見性

貳、 信任假設的批判性分析

- 回顧第三章定義的四項信任假設（信任根源、Oracle Problem、活性假設、隱私邊界），討論其在實務部署中的風險
- 討論「去中心化」與「抗審查」核心價值的犧牲：在 Repo 交易等受高度監管的場景中，參與方本身即為受監管金融機構，對中介信任的依賴是業務本質而非技術缺陷；在跨境支付場景中，外匯管制本身即需要主權機構介入，完全去中心化不符實務需求
- 明確界定在何種商業場景下，此種犧牲是可被接受的

參、 雙重防護網：技術可審計、法律可追究

- 「即便發生鏈下預言機作惡，監管機構仍可透過 ERC-7943 的 forcedTransfer 進行事後矯正」——這構成了技術層面的最後防線
- CAST Framework 的法律代理協議（Agency Agreement）為鏈下機構的行為提供法律約束與追責機制
- 此雙重防護將技術層面的信任風險降至金融監理可接受的範圍
- 論述「合規即系統」的真正含義不是排除所有人類參與，而是確保合規成為系統運作的先決條件，並在出現例外時保有可追溯、可矯正的能力

第三節 未來研究方向

- 零知識證明（ZKP）：探討如何結合 ZKP 保護合規驗證中的敏感資訊，實現「證明合規但不揭露身份細節」
- 跨鏈互操作性：使用 Chainlink CCIP 實現跨鏈資產轉移時的合規狀態同步
- 監管儀表板：為監管機構提供即時合規狀態視圖
- 更多金融場景：擴展至衍生性商品、結構型產品等複雜金融工具

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
