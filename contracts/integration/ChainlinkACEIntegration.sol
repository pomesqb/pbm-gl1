// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IChainlinkACEPolicyManager.sol";

/**
 * @title ChainlinkACEIntegration
 * @notice 整合 Chainlink 自動化合規引擎 + CAST Framework Oracle 管理
 * @dev 提供合規策略定義、跨鏈合規驗證、以及 Oracle 中間件管理功能
 * 
 * ═══════════════════════════════════════════════════════════════════════════════
 * CAST Framework Oracle 說明
 * ═══════════════════════════════════════════════════════════════════════════════
 * 
 * 在 CAST (Capital markets Architecture for Security Tokens) 架構中，
 * Oracle 是連接區塊鏈與傳統金融系統的橋樑。
 * 
 * 問題背景：
 * - 區塊鏈上發生的代幣轉移是即時的
 * - 但傳統銀行轉帳可能需要 T+1 或 T+2 才能到帳
 * - 智能合約無法直接知道「銀行款項是否已收到」
 * 
 * 解決方案：
 * - 授權特定的 Oracle 地址代表傳統金融機構
 * - 當銀行確認收款後，Oracle 調用合約更新狀態
 * - 合約收到 Oracle 確認後，才執行代幣轉移
 * 
 * 三種 Oracle 角色：
 * 
 * 1. FRO (Financial Registrar Oracle) - 註冊代理人 Oracle
 *    服務對象：Registrar（註冊代理人，如證券登記機構）
 *    職責：
 *    - 註冊新的金融工具（如新發行的證券型代幣）
 *    - 維護持有人名冊
 *    - 更新工具的靜態資料（ISIN、利率等）
 * 
 * 2. FSO (Financial Settlement Oracle) - 清算代理人 Oracle
 *    服務對象：Settlement Agent（清算代理人，如銀行、清算所）
 *    職責：
 *    - 監控銀行系統的付款狀態
 *    - 當確認收到款項時，調用合約的 confirmPaymentReceived()
 *    - 將鏈上事件轉換為 SWIFT 報文發送給銀行
 *    這是最關鍵的 Oracle，負責「鏈下付款 → 鏈上清算」的橋接
 * 
 * 3. FIO (Financial Investor Oracle) - 投資人 Oracle
 *    服務對象：Investor/Dealer（投資人、券商）
 *    職責：
 *    - 代表投資人發起交易請求
 *    - 查詢持倉與交易狀態
 *    - 發起認購/贖回請求
 * 
 * ═══════════════════════════════════════════════════════════════════════════════
 */
contract ChainlinkACEIntegration is AccessControl {
    
    // ═══════════════════════════════════════════════════════════════════════════
    // 角色定義
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice 政策創建者角色 - 可以定義合規政策
    bytes32 public constant POLICY_CREATOR_ROLE = keccak256("POLICY_CREATOR_ROLE");
    
    /// @notice Oracle 管理員角色 - 可以註冊/停用 Oracle
    bytes32 public constant ORACLE_ADMIN_ROLE = keccak256("ORACLE_ADMIN_ROLE");
    
    /// @notice FRO 角色 - 註冊代理人 Oracle
    /// @dev 只有擁有此角色的地址才能調用 registerInstrument() 等方法
    bytes32 public constant FRO_ROLE = keccak256("FRO_ROLE");
    
    /// @notice FSO 角色 - 清算代理人 Oracle
    /// @dev 只有擁有此角色的地址才能調用 confirmPaymentReceived() 等方法
    bytes32 public constant FSO_ROLE = keccak256("FSO_ROLE");
    
    /// @notice FIO 角色 - 投資人 Oracle
    /// @dev 只有擁有此角色的地址才能調用 initiateTradeRequest() 等方法
    bytes32 public constant FIO_ROLE = keccak256("FIO_ROLE");
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Oracle 類型與結構
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice Oracle 類型枚舉
     * @dev 對應 CAST Framework 定義的三種 Oracle 角色
     */
    enum OracleType {
        FRO,    // Financial Registrar Oracle - 註冊代理人
        FSO,    // Financial Settlement Oracle - 清算代理人
        FIO     // Financial Investor Oracle - 投資人/券商
    }
    
    /**
     * @notice Oracle 註冊資訊
     * @dev 記錄每個 Oracle 的詳細資訊，用於審計和權限管理
     */
    struct OracleInfo {
        address oracleAddress;      // Oracle 的鏈上地址
        OracleType oracleType;      // Oracle 類型 (FRO/FSO/FIO)
        bytes32 institutionId;      // 機構識別碼（如 LEI 的 hash）
        string institutionName;     // 機構名稱（如 "ABC Bank"）
        bool isActive;              // 是否啟用
        uint256 registeredAt;       // 註冊時間
        uint256 lastActionAt;       // 最後操作時間
    }
    
    /**
     * @notice 清算確認記錄
     * @dev 記錄 FSO 確認付款的詳細資訊
     */
    struct PaymentConfirmation {
        bytes32 settlementId;       // 清算 ID
        bytes32 paymentReference;   // 銀行付款參考號
        address confirmedBy;        // 確認的 Oracle 地址
        uint256 confirmedAmount;    // 確認金額
        uint256 confirmedAt;        // 確認時間
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Oracle 相關狀態變數
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Oracle 地址 → Oracle 資訊
    mapping(address => OracleInfo) public registeredOracles;
    
    /// @notice 所有已註冊的 Oracle 地址列表
    address[] public oracleAddresses;
    
    /// @notice 清算 ID → 付款確認記錄
    mapping(bytes32 => PaymentConfirmation) public paymentConfirmations;
    
    /// @notice Oracle 操作計數（用於統計）
    mapping(address => uint256) public oracleActionCount;
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Oracle 相關事件
    // ═══════════════════════════════════════════════════════════════════════════
    
    /// @notice Oracle 註冊事件
    event OracleRegistered(
        address indexed oracleAddress,
        OracleType indexed oracleType,
        bytes32 institutionId,
        string institutionName,
        uint256 timestamp
    );
    
    /// @notice Oracle 停用事件
    event OracleDeactivated(
        address indexed oracleAddress,
        uint256 timestamp
    );
    
    /// @notice Oracle 重新啟用事件
    event OracleReactivated(
        address indexed oracleAddress,
        uint256 timestamp
    );
    
    /// @notice FSO 確認付款事件（供鏈下系統監聽）
    /// @dev 當 Settlement Agent 確認銀行款項已收到時發出此事件
    event PaymentConfirmed(
        bytes32 indexed settlementId,
        bytes32 indexed paymentReference,
        address indexed oracle,
        uint256 confirmedAmount,
        uint256 timestamp
    );
    
    /// @notice FRO 註冊工具事件
    event InstrumentRegistered(
        bytes32 indexed isin,
        address indexed tokenContract,
        address indexed registrar,
        uint256 timestamp
    );
    
    /// @notice FIO 發起交易請求事件
    event TradeRequestInitiated(
        bytes32 indexed requestId,
        address indexed investor,
        bytes32 isin,
        uint256 amount,
        uint256 timestamp
    );
    
    /// @notice Oracle 操作執行事件（用於審計）
    event OracleActionExecuted(
        address indexed oracle,
        OracleType oracleType,
        string actionType,
        bytes32 indexed referenceId,
        bool success,
        uint256 timestamp
    );
    
    // Chainlink ACE Policy Manager
    address public chainlinkACEPolicyManager;
    
    // 政策結構
    struct Policy {
        bytes32 policyId;
        string policyName;
        address[] eligibleAddresses;
        uint256 volumeLimit;
        bytes32[] jurisdictions;
        bool isActive;
        uint256 createdAt;
        uint256 updatedAt;
    }
    
    // 政策 ID → 政策詳情
    mapping(bytes32 => Policy) public policies;
    
    // 所有政策 ID 列表
    bytes32[] public policyIds;
    
    // 地址 → 適用政策 ID 列表
    mapping(address => bytes32[]) public addressPolicies;
    
    event PolicyCreated(bytes32 indexed policyId, string policyName, uint256 timestamp);
    event PolicyUpdated(bytes32 indexed policyId, uint256 timestamp);
    event PolicyDeactivated(bytes32 indexed policyId, uint256 timestamp);
    event AddressAddedToPolicy(bytes32 indexed policyId, address indexed account);
    event CrossChainComplianceVerified(
        address indexed participant,
        bytes32 sourceChain,
        bytes32 targetChain,
        bool isCompliant
    );
    
    constructor(address _chainlinkACEPolicyManager) {
        chainlinkACEPolicyManager = _chainlinkACEPolicyManager;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POLICY_CREATOR_ROLE, msg.sender);
        _grantRole(ORACLE_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice 使用 Chainlink ACE 定義合規策略
     * @param policyName 政策名稱
     * @param eligibleAddresses 符合條件的地址列表
     * @param volumeLimit 交易量限制
     * @param jurisdictions 適用的司法管轄區列表
     */
    function definePolicy(
        string memory policyName,
        address[] memory eligibleAddresses,
        uint256 volumeLimit,
        bytes32[] memory jurisdictions
    ) external onlyRole(POLICY_CREATOR_ROLE) returns (bytes32 policyId) {
        policyId = keccak256(abi.encodePacked(policyName, block.timestamp, msg.sender));
        
        require(policies[policyId].policyId == bytes32(0), "Policy already exists");
        
        // 建立本地政策記錄
        policies[policyId] = Policy({
            policyId: policyId,
            policyName: policyName,
            eligibleAddresses: eligibleAddresses,
            volumeLimit: volumeLimit,
            jurisdictions: jurisdictions,
            isActive: true,
            createdAt: block.timestamp,
            updatedAt: block.timestamp
        });
        
        policyIds.push(policyId);
        
        // 更新地址 → 政策映射
        for (uint256 i = 0; i < eligibleAddresses.length; i++) {
            addressPolicies[eligibleAddresses[i]].push(policyId);
            emit AddressAddedToPolicy(policyId, eligibleAddresses[i]);
        }
        
        // 調用 Chainlink ACE Policy Manager（如果已配置）
        if (chainlinkACEPolicyManager != address(0)) {
            bytes memory parameters = abi.encode(
                eligibleAddresses,
                volumeLimit,
                jurisdictions
            );
            
            try IChainlinkACEPolicyManager(chainlinkACEPolicyManager).createPolicy(
                policyId,
                parameters
            ) {} catch {
                // 記錄失敗但不回滾
            }
        }
        
        emit PolicyCreated(policyId, policyName, block.timestamp);
        return policyId;
    }
    
    /**
     * @notice 更新政策參數
     */
    function updatePolicy(
        bytes32 policyId,
        address[] memory newEligibleAddresses,
        uint256 newVolumeLimit,
        bytes32[] memory newJurisdictions
    ) external onlyRole(POLICY_CREATOR_ROLE) {
        require(policies[policyId].policyId != bytes32(0), "Policy does not exist");
        require(policies[policyId].isActive, "Policy is not active");
        
        Policy storage policy = policies[policyId];
        policy.eligibleAddresses = newEligibleAddresses;
        policy.volumeLimit = newVolumeLimit;
        policy.jurisdictions = newJurisdictions;
        policy.updatedAt = block.timestamp;
        
        // 更新 Chainlink ACE
        if (chainlinkACEPolicyManager != address(0)) {
            bytes memory parameters = abi.encode(
                newEligibleAddresses,
                newVolumeLimit,
                newJurisdictions
            );
            
            try IChainlinkACEPolicyManager(chainlinkACEPolicyManager).updatePolicy(
                policyId,
                parameters
            ) {} catch {
                // 記錄失敗但不回滾
            }
        }
        
        emit PolicyUpdated(policyId, block.timestamp);
    }
    
    /**
     * @notice 停用政策
     */
    function deactivatePolicy(bytes32 policyId) 
        external 
        onlyRole(POLICY_CREATOR_ROLE) 
    {
        require(policies[policyId].policyId != bytes32(0), "Policy does not exist");
        require(policies[policyId].isActive, "Policy already inactive");
        
        policies[policyId].isActive = false;
        policies[policyId].updatedAt = block.timestamp;
        
        // 通知 Chainlink ACE
        if (chainlinkACEPolicyManager != address(0)) {
            try IChainlinkACEPolicyManager(chainlinkACEPolicyManager).deactivatePolicy(
                policyId
            ) {} catch {}
        }
        
        emit PolicyDeactivated(policyId, block.timestamp);
    }
    
    /**
     * @notice 即時合規驗證（跨鏈支援）
     * @dev Chainlink ACE 的 CCID 支援跨鏈身份驗證，無需在每條鏈上重複 KYC 流程
     */
    function verifyComplianceAcrossChains(
        address participant,
        bytes32 sourceChain,
        bytes32 targetChain
    ) external returns (bool isCompliant) {
        // 檢查參與者是否有適用的政策
        bytes32[] memory applicablePolicies = addressPolicies[participant];
        
        if (applicablePolicies.length == 0) {
            emit CrossChainComplianceVerified(participant, sourceChain, targetChain, false);
            return false;
        }
        
        // 檢查是否有任何活躍政策覆蓋目標鏈
        for (uint256 i = 0; i < applicablePolicies.length; i++) {
            Policy memory policy = policies[applicablePolicies[i]];
            
            if (!policy.isActive) {
                continue;
            }
            
            // 檢查目標鏈是否在政策的管轄區中
            for (uint256 j = 0; j < policy.jurisdictions.length; j++) {
                if (policy.jurisdictions[j] == targetChain) {
                    emit CrossChainComplianceVerified(participant, sourceChain, targetChain, true);
                    return true;
                }
            }
        }
        
        emit CrossChainComplianceVerified(participant, sourceChain, targetChain, false);
        return false;
    }
    
    /**
     * @notice 添加地址到政策
     */
    function addAddressToPolicy(
        bytes32 policyId,
        address account
    ) external onlyRole(POLICY_CREATOR_ROLE) {
        require(policies[policyId].policyId != bytes32(0), "Policy does not exist");
        require(policies[policyId].isActive, "Policy is not active");
        
        policies[policyId].eligibleAddresses.push(account);
        addressPolicies[account].push(policyId);
        
        emit AddressAddedToPolicy(policyId, account);
    }
    
    /**
     * @notice 檢查地址是否符合特定政策
     */
    function isAddressEligible(
        bytes32 policyId,
        address account
    ) external view returns (bool) {
        Policy memory policy = policies[policyId];
        
        if (!policy.isActive) {
            return false;
        }
        
        for (uint256 i = 0; i < policy.eligibleAddresses.length; i++) {
            if (policy.eligibleAddresses[i] == account) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @notice 獲取政策詳情
     */
    function getPolicyDetails(bytes32 policyId) 
        external 
        view 
        returns (
            string memory policyName,
            uint256 volumeLimit,
            uint256 eligibleAddressCount,
            uint256 jurisdictionCount,
            bool isActive,
            uint256 createdAt,
            uint256 updatedAt
        ) 
    {
        Policy memory policy = policies[policyId];
        return (
            policy.policyName,
            policy.volumeLimit,
            policy.eligibleAddresses.length,
            policy.jurisdictions.length,
            policy.isActive,
            policy.createdAt,
            policy.updatedAt
        );
    }
    
    /**
     * @notice 獲取地址適用的政策數量
     */
    function getAddressPolicyCount(address account) external view returns (uint256) {
        return addressPolicies[account].length;
    }
    
    /**
     * @notice 獲取所有政策數量
     */
    function getTotalPolicyCount() external view returns (uint256) {
        return policyIds.length;
    }
    
    /**
     * @notice 更新 Chainlink ACE Policy Manager 地址
     */
    function setChainlinkACEPolicyManager(address newManager) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        chainlinkACEPolicyManager = newManager;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Oracle 管理方法
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice 註冊新的 Oracle
     * @dev 僅限 ORACLE_ADMIN_ROLE 調用
     * 
     * 使用場景：
     * - 當一個新的銀行或金融機構要加入系統時，管理員調用此方法註冊其 Oracle
     * - 例如：新加坡 DBS 銀行要作為清算代理人，就註冊一個 FSO 類型的 Oracle
     * 
     * @param oracleAddress Oracle 的鏈上地址（通常是該機構控制的 EOA 或多簽）
     * @param oracleType Oracle 類型（FRO=0, FSO=1, FIO=2）
     * @param institutionId 機構識別碼（建議使用 LEI 的 keccak256 hash）
     * @param institutionName 機構名稱（方便人類閱讀）
     */
    function registerOracle(
        address oracleAddress,
        OracleType oracleType,
        bytes32 institutionId,
        string calldata institutionName
    ) external onlyRole(ORACLE_ADMIN_ROLE) {
        require(oracleAddress != address(0), "Invalid oracle address");
        require(
            registeredOracles[oracleAddress].oracleAddress == address(0),
            "Oracle already registered"
        );
        
        // 儲存 Oracle 資訊
        registeredOracles[oracleAddress] = OracleInfo({
            oracleAddress: oracleAddress,
            oracleType: oracleType,
            institutionId: institutionId,
            institutionName: institutionName,
            isActive: true,
            registeredAt: block.timestamp,
            lastActionAt: 0
        });
        
        oracleAddresses.push(oracleAddress);
        
        // 根據 Oracle 類型授予對應角色
        // 這樣該地址就能調用受限的方法
        if (oracleType == OracleType.FRO) {
            _grantRole(FRO_ROLE, oracleAddress);
        } else if (oracleType == OracleType.FSO) {
            _grantRole(FSO_ROLE, oracleAddress);
        } else if (oracleType == OracleType.FIO) {
            _grantRole(FIO_ROLE, oracleAddress);
        }
        
        emit OracleRegistered(
            oracleAddress,
            oracleType,
            institutionId,
            institutionName,
            block.timestamp
        );
    }
    
    /**
     * @notice 停用 Oracle
     * @dev 當某機構不再參與系統時，調用此方法停用其 Oracle
     * 
     * 使用場景：
     * - 機構退出市場
     * - Oracle 私鑰可能洩露，需要緊急停用
     * - 更換為新的 Oracle 地址
     * 
     * @param oracleAddress 要停用的 Oracle 地址
     */
    function deactivateOracle(address oracleAddress) 
        external 
        onlyRole(ORACLE_ADMIN_ROLE) 
    {
        OracleInfo storage oracle = registeredOracles[oracleAddress];
        require(oracle.oracleAddress != address(0), "Oracle not found");
        require(oracle.isActive, "Oracle already inactive");
        
        oracle.isActive = false;
        
        // 撤銷對應角色，防止繼續調用受限方法
        if (oracle.oracleType == OracleType.FRO) {
            _revokeRole(FRO_ROLE, oracleAddress);
        } else if (oracle.oracleType == OracleType.FSO) {
            _revokeRole(FSO_ROLE, oracleAddress);
        } else if (oracle.oracleType == OracleType.FIO) {
            _revokeRole(FIO_ROLE, oracleAddress);
        }
        
        emit OracleDeactivated(oracleAddress, block.timestamp);
    }
    
    /**
     * @notice 重新啟用 Oracle
     * @param oracleAddress 要重新啟用的 Oracle 地址
     */
    function reactivateOracle(address oracleAddress) 
        external 
        onlyRole(ORACLE_ADMIN_ROLE) 
    {
        OracleInfo storage oracle = registeredOracles[oracleAddress];
        require(oracle.oracleAddress != address(0), "Oracle not found");
        require(!oracle.isActive, "Oracle already active");
        
        oracle.isActive = true;
        
        // 重新授予對應角色
        if (oracle.oracleType == OracleType.FRO) {
            _grantRole(FRO_ROLE, oracleAddress);
        } else if (oracle.oracleType == OracleType.FSO) {
            _grantRole(FSO_ROLE, oracleAddress);
        } else if (oracle.oracleType == OracleType.FIO) {
            _grantRole(FIO_ROLE, oracleAddress);
        }
        
        emit OracleReactivated(oracleAddress, block.timestamp);
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // FSO 專用方法 - 清算代理人 Oracle
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice 確認付款已收到
     * @dev 僅限 FSO_ROLE 調用
     * 
     * 這是 CAST Framework 最核心的 Oracle 功能！
     * 
     * 流程說明：
     * 1. 投資人在鏈下透過銀行轉帳付款
     * 2. 銀行確認收到款項後，通知 Settlement Agent
     * 3. Settlement Agent 的 Oracle 調用此方法
     * 4. 合約記錄確認資訊，並可觸發後續的代幣轉移
     * 
     * @param settlementId 清算 ID（對應鏈上的交易或 Repo ID）
     * @param paymentReference 銀行付款參考號（如 SWIFT 交易號）
     * @param confirmedAmount 確認的金額
     */
    function confirmPaymentReceived(
        bytes32 settlementId,
        bytes32 paymentReference,
        uint256 confirmedAmount
    ) external onlyRole(FSO_ROLE) {
        require(settlementId != bytes32(0), "Invalid settlement ID");
        require(confirmedAmount > 0, "Amount must be > 0");
        require(
            paymentConfirmations[settlementId].settlementId == bytes32(0),
            "Payment already confirmed"
        );
        
        // 更新 Oracle 最後操作時間
        registeredOracles[msg.sender].lastActionAt = block.timestamp;
        oracleActionCount[msg.sender]++;
        
        // 記錄付款確認
        paymentConfirmations[settlementId] = PaymentConfirmation({
            settlementId: settlementId,
            paymentReference: paymentReference,
            confirmedBy: msg.sender,
            confirmedAmount: confirmedAmount,
            confirmedAt: block.timestamp
        });
        
        emit PaymentConfirmed(
            settlementId,
            paymentReference,
            msg.sender,
            confirmedAmount,
            block.timestamp
        );
        
        emit OracleActionExecuted(
            msg.sender,
            OracleType.FSO,
            "CONFIRM_PAYMENT",
            settlementId,
            true,
            block.timestamp
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // FRO 專用方法 - 註冊代理人 Oracle
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice 註冊金融工具
     * @dev 僅限 FRO_ROLE 調用
     * 
     * 使用場景：
     * - 發行新的證券型代幣時，Registrar 需要在系統中註冊該工具
     * - 記錄 ISIN 與代幣合約地址的映射關係
     * 
     * @param isin 國際證券識別碼（ISIN）的 hash
     * @param tokenContract 對應的代幣合約地址
     */
    function registerInstrument(
        bytes32 isin,
        address tokenContract,
        bytes32 /* metadata */
    ) external onlyRole(FRO_ROLE) {
        require(isin != bytes32(0), "Invalid ISIN");
        require(tokenContract != address(0), "Invalid token contract");
        
        // 更新 Oracle 最後操作時間
        registeredOracles[msg.sender].lastActionAt = block.timestamp;
        oracleActionCount[msg.sender]++;
        
        emit InstrumentRegistered(
            isin,
            tokenContract,
            msg.sender,
            block.timestamp
        );
        
        emit OracleActionExecuted(
            msg.sender,
            OracleType.FRO,
            "REGISTER_INSTRUMENT",
            isin,
            true,
            block.timestamp
        );
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // FIO 專用方法 - 投資人 Oracle
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice 發起交易請求
     * @dev 僅限 FIO_ROLE 調用
     * 
     * 使用場景：
     * - 券商代表投資人發起買賣請求
     * - 此方法僅記錄請求，實際撮合由其他機制處理
     * 
     * @param isin 欲交易的證券 ISIN（hash）
     * @param investor 投資人地址
     * @param amount 交易數量
     * @param isBuy 是否為買入（true=買入, false=賣出）
     * @return requestId 產生的請求 ID
     */
    function initiateTradeRequest(
        bytes32 isin,
        address investor,
        uint256 amount,
        bool isBuy
    ) external onlyRole(FIO_ROLE) returns (bytes32 requestId) {
        require(isin != bytes32(0), "Invalid ISIN");
        require(investor != address(0), "Invalid investor");
        require(amount > 0, "Amount must be > 0");
        
        // 更新 Oracle 最後操作時間
        registeredOracles[msg.sender].lastActionAt = block.timestamp;
        oracleActionCount[msg.sender]++;
        
        // 產生請求 ID
        requestId = keccak256(abi.encodePacked(
            isin,
            investor,
            amount,
            isBuy,
            block.timestamp,
            msg.sender
        ));
        
        emit TradeRequestInitiated(
            requestId,
            investor,
            isin,
            amount,
            block.timestamp
        );
        
        emit OracleActionExecuted(
            msg.sender,
            OracleType.FIO,
            isBuy ? "BUY_REQUEST" : "SELL_REQUEST",
            requestId,
            true,
            block.timestamp
        );
        
        return requestId;
    }
    
    // ═══════════════════════════════════════════════════════════════════════════
    // Oracle 查詢方法
    // ═══════════════════════════════════════════════════════════════════════════
    
    /**
     * @notice 查詢 Oracle 資訊
     * @param oracleAddress Oracle 地址
     * @return info Oracle 詳細資訊
     */
    function getOracleInfo(address oracleAddress) 
        external 
        view 
        returns (OracleInfo memory info) 
    {
        return registeredOracles[oracleAddress];
    }
    
    /**
     * @notice 檢查地址是否為特定類型的有效 Oracle
     * @param oracleAddress 要檢查的地址
     * @param oracleType 預期的 Oracle 類型
     * @return isValid 是否為有效的 Oracle
     */
    function isValidOracle(
        address oracleAddress,
        OracleType oracleType
    ) external view returns (bool isValid) {
        OracleInfo memory oracle = registeredOracles[oracleAddress];
        return oracle.isActive && oracle.oracleType == oracleType;
    }
    
    /**
     * @notice 查詢付款確認記錄
     * @param settlementId 清算 ID
     * @return confirmation 付款確認詳情
     */
    function getPaymentConfirmation(bytes32 settlementId)
        external
        view
        returns (PaymentConfirmation memory confirmation)
    {
        return paymentConfirmations[settlementId];
    }
    
    /**
     * @notice 檢查付款是否已確認
     * @param settlementId 清算 ID
     * @return isConfirmed 是否已確認
     */
    function isPaymentConfirmed(bytes32 settlementId)
        external
        view
        returns (bool isConfirmed)
    {
        return paymentConfirmations[settlementId].settlementId != bytes32(0);
    }
    
    /**
     * @notice 獲取已註冊的 Oracle 數量
     * @return count Oracle 總數
     */
    function getOracleCount() external view returns (uint256 count) {
        return oracleAddresses.length;
    }
    
    /**
     * @notice 獲取特定 Oracle 的操作統計
     * @param oracleAddress Oracle 地址
     * @return actionCount 操作次數
     * @return lastAction 最後操作時間
     */
    function getOracleStats(address oracleAddress)
        external
        view
        returns (uint256 actionCount, uint256 lastAction)
    {
        return (
            oracleActionCount[oracleAddress],
            registeredOracles[oracleAddress].lastActionAt
        );
    }
}
