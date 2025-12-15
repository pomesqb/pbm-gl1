// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IPolicyManager.sol";
import "../interfaces/ICCIDProvider.sol";
import "../interfaces/IChainlinkACE.sol";
import "../interfaces/IComplianceRule.sol";

/**
 * @title GL1PolicyManager
 * @notice 協調身份驗證、規則引擎和 Chainlink ACE
 * @dev GL1 架構的核心編排層
 */
contract GL1PolicyManager is IPolicyManager, AccessControl {
    bytes32 public constant RULE_ADMIN_ROLE = keccak256("RULE_ADMIN_ROLE");
    bytes32 public constant JURISDICTION_ADMIN_ROLE = keccak256("JURISDICTION_ADMIN_ROLE");

    // Chainlink ACE 整合
    address public chainlinkACE;
    
    // CCID (Cross-Chain Identity) Provider
    address public ccidProvider;
    
    // 鏈下合規規則引擎 (通過 Chainlink Functions 調用)
    address public offChainRuleEngine;
    
    // 規則集定義
    struct RuleSet {
        bytes32 ruleSetId;
        string ruleType;          // "KYC", "AML", "SANCTIONS", "POSITION_LIMIT"
        bool isOnChain;           // true = 鏈上執行, false = 鏈下執行
        address executorAddress;  // 執行器合約地址或 oracle
        uint256 priority;         // 執行優先級
        bool isActive;            // 是否啟用
    }
    
    mapping(bytes32 => RuleSet) public ruleSets;
    bytes32[] public activeRuleSets;
    
    // 管轄區 → 適用規則集映射
    mapping(bytes32 => bytes32[]) public jurisdictionRules;
    
    // 管轄區是否啟用
    mapping(bytes32 => bool) public jurisdictionEnabled;
    
    event RuleSetRegistered(bytes32 indexed ruleSetId, string ruleType, bool isOnChain);
    event RuleSetUpdated(bytes32 indexed ruleSetId, bool isActive);
    event IdentityVerificationRequested(address indexed account, bytes32 jurisdiction);
    event ComplianceRuleExecuted(bytes32 indexed ruleSetId, bool passed, string reason);
    event JurisdictionConfigured(bytes32 indexed jurisdictionCode, uint256 ruleCount);
    event ProviderUpdated(string providerType, address newAddress);
    
    constructor(
        address _chainlinkACE,
        address _ccidProvider,
        address _offChainRuleEngine
    ) {
        chainlinkACE = _chainlinkACE;
        ccidProvider = _ccidProvider;
        offChainRuleEngine = _offChainRuleEngine;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RULE_ADMIN_ROLE, msg.sender);
        _grantRole(JURISDICTION_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice 驗證跨鏈身份 (CCID)
     * @dev 根據 GL1 CCID 標準驗證參與者身份
     */
    function verifyIdentity(
        address from,
        address to,
        bytes32 jurisdictionCode
    ) external override returns (bool isValid, string memory errorReason) {
        emit IdentityVerificationRequested(from, jurisdictionCode);
        
        // 檢查管轄區是否啟用
        if (!jurisdictionEnabled[jurisdictionCode]) {
            return (false, "Jurisdiction not enabled");
        }
        
        // 調用 CCID Provider (敏感資料存鏈下，鏈上僅驗證證明)
        ICCIDProvider provider = ICCIDProvider(ccidProvider);
        
        // 驗證發送方
        bool fromValid = provider.verifyCredential(from, jurisdictionCode);
        if (!fromValid) {
            return (false, "Sender identity verification failed");
        }
        
        // 驗證接收方
        bool toValid = provider.verifyCredential(to, jurisdictionCode);
        if (!toValid) {
            return (false, "Recipient identity verification failed");
        }
        
        // 檢查制裁名單（透過 Chainlink ACE）
        bool notSanctioned = IChainlinkACE(chainlinkACE).checkSanctionsList(from, to);
        if (!notSanctioned) {
            return (false, "Address on sanctions list");
        }
        
        return (true, "");
    }
    
    /**
     * @notice 執行合規規則引擎
     * @dev 混合鏈上/鏈下執行模式
     */
    function executeComplianceRules(
        address from,
        address to,
        uint256 amount,
        bytes32 jurisdictionCode
    ) external override returns (
        bool isCompliant,
        string memory failureReason,
        string[] memory appliedRules
    ) {
        bytes32[] memory rules = jurisdictionRules[jurisdictionCode];
        
        if (rules.length == 0) {
            // 沒有配置規則，預設通過
            appliedRules = new string[](1);
            appliedRules[0] = "NO_RULES";
            return (true, "", appliedRules);
        }
        
        appliedRules = new string[](rules.length);
        
        for (uint256 i = 0; i < rules.length; i++) {
            RuleSet memory rule = ruleSets[rules[i]];
            
            // 跳過未啟用的規則
            if (!rule.isActive) {
                continue;
            }
            
            appliedRules[i] = rule.ruleType;
            
            bool rulePassed;
            string memory ruleError;
            
            if (rule.isOnChain) {
                // 鏈上規則執行
                (rulePassed, ruleError) = _executeOnChainRule(
                    rule.executorAddress,
                    from,
                    to,
                    amount
                );
            } else {
                // 鏈下規則執行 (通過 Chainlink Functions)
                (rulePassed, ruleError) = _executeOffChainRule(
                    rule.executorAddress,
                    from,
                    to,
                    amount,
                    jurisdictionCode
                );
            }
            
            emit ComplianceRuleExecuted(rules[i], rulePassed, ruleError);
            
            if (!rulePassed) {
                return (false, ruleError, appliedRules);
            }
        }
        
        return (true, "", appliedRules);
    }
    
    /**
     * @notice 鏈上規則執行
     */
    function _executeOnChainRule(
        address ruleExecutor,
        address from,
        address to,
        uint256 amount
    ) internal returns (bool passed, string memory error) {
        // 調用規則執行器合約
        try IComplianceRule(ruleExecutor).checkCompliance(from, to, amount) returns (
            bool _passed,
            string memory _error
        ) {
            return (_passed, _error);
        } catch Error(string memory reason) {
            return (false, reason);
        } catch {
            return (false, "Rule execution failed");
        }
    }
    
    /**
     * @notice 鏈下規則執行 (透過 Chainlink Functions)
     * @dev 成本效益考量：複雜規則在鏈下執行
     */
    function _executeOffChainRule(
        address /* oracle */,
        address /* from */,
        address /* to */,
        uint256 /* amount */,
        bytes32 /* jurisdiction */
    ) internal pure returns (bool passed, string memory error) {
        // 簡化版：實際應使用 Chainlink Functions
        // 發送請求到鏈下規則引擎，接收結果
        
        // 在生產環境中，這會是一個異步調用
        // 使用 Chainlink Request & Receive 模式
        
        return (true, ""); // Placeholder
    }
    
    /**
     * @notice 註冊新的規則集
     */
    function registerRuleSet(
        bytes32 ruleSetId,
        string memory ruleType,
        bool isOnChain,
        address executorAddress,
        uint256 priority
    ) external onlyRole(RULE_ADMIN_ROLE) {
        require(ruleSets[ruleSetId].ruleSetId == bytes32(0), "RuleSet already exists");
        require(executorAddress != address(0), "Invalid executor address");
        
        ruleSets[ruleSetId] = RuleSet({
            ruleSetId: ruleSetId,
            ruleType: ruleType,
            isOnChain: isOnChain,
            executorAddress: executorAddress,
            priority: priority,
            isActive: true
        });
        
        activeRuleSets.push(ruleSetId);
        
        emit RuleSetRegistered(ruleSetId, ruleType, isOnChain);
    }
    
    /**
     * @notice 啟用或停用規則集
     */
    function setRuleSetActive(
        bytes32 ruleSetId,
        bool isActive
    ) external onlyRole(RULE_ADMIN_ROLE) {
        require(ruleSets[ruleSetId].ruleSetId != bytes32(0), "RuleSet does not exist");
        ruleSets[ruleSetId].isActive = isActive;
        emit RuleSetUpdated(ruleSetId, isActive);
    }
    
    /**
     * @notice 為特定司法管轄區配置適用規則
     */
    function setJurisdictionRules(
        bytes32 jurisdictionCode,
        bytes32[] memory ruleSetIds
    ) external onlyRole(JURISDICTION_ADMIN_ROLE) {
        // 驗證所有規則集都存在
        for (uint256 i = 0; i < ruleSetIds.length; i++) {
            require(ruleSets[ruleSetIds[i]].ruleSetId != bytes32(0), "RuleSet does not exist");
        }
        
        jurisdictionRules[jurisdictionCode] = ruleSetIds;
        jurisdictionEnabled[jurisdictionCode] = true;
        
        emit JurisdictionConfigured(jurisdictionCode, ruleSetIds.length);
    }
    
    /**
     * @notice 啟用或停用管轄區
     */
    function setJurisdictionEnabled(
        bytes32 jurisdictionCode,
        bool enabled
    ) external onlyRole(JURISDICTION_ADMIN_ROLE) {
        jurisdictionEnabled[jurisdictionCode] = enabled;
    }
    
    /**
     * @notice 更新 Chainlink ACE 地址
     */
    function updateChainlinkACE(address _chainlinkACE) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_chainlinkACE != address(0), "Invalid address");
        chainlinkACE = _chainlinkACE;
        emit ProviderUpdated("ChainlinkACE", _chainlinkACE);
    }
    
    /**
     * @notice 更新 CCID Provider 地址
     */
    function updateCCIDProvider(address _ccidProvider) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_ccidProvider != address(0), "Invalid address");
        ccidProvider = _ccidProvider;
        emit ProviderUpdated("CCIDProvider", _ccidProvider);
    }
    
    /**
     * @notice 獲取管轄區的規則數量
     */
    function getJurisdictionRuleCount(bytes32 jurisdictionCode) external view returns (uint256) {
        return jurisdictionRules[jurisdictionCode].length;
    }
    
    /**
     * @notice 獲取所有活躍規則集的數量
     */
    function getActiveRuleSetCount() external view returns (uint256) {
        return activeRuleSets.length;
    }
}
