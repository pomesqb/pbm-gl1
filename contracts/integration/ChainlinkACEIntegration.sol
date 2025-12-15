// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IChainlinkACEPolicyManager.sol";

/**
 * @title ChainlinkACEIntegration
 * @notice 整合 Chainlink 自動化合規引擎
 * @dev 提供合規策略定義和跨鏈合規驗證功能
 */
contract ChainlinkACEIntegration is AccessControl {
    bytes32 public constant POLICY_CREATOR_ROLE = keccak256("POLICY_CREATOR_ROLE");
    
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
}
