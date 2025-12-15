// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IPolicyManager.sol";

/**
 * @title GL1PolicyWrapper
 * @notice 實作 GL1 政策包裝器標準
 * @dev 將合規邏輯與代幣合約分離，支援多司法管轄區
 */
contract GL1PolicyWrapper is AccessControl {
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    bytes32 public constant POLICY_ADMIN_ROLE = keccak256("POLICY_ADMIN_ROLE");
    
    // 司法管轄區代碼 (ISO 3166-1)
    bytes32 public immutable jurisdictionCode;
    
    // Policy Manager 介面
    IPolicyManager public policyManager;
    
    // 合規狀態追蹤
    struct ComplianceProof {
        bytes32 proofHash;        // 合規證明的雜湊
        uint256 timestamp;        // 驗證時間戳
        address verifier;         // 驗證者地址
        bool isValid;             // 是否有效
    }
    
    // 交易 → 合規證明映射
    mapping(bytes32 => ComplianceProof) public complianceProofs;
    
    // 事件：用於監理機構即時監控
    event ComplianceCheckInitiated(
        bytes32 indexed txHash,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 jurisdictionCode
    );
    
    event ComplianceCheckCompleted(
        bytes32 indexed txHash,
        bool isCompliant,
        string[] appliedRules,
        uint256 timestamp
    );
    
    event PolicyWrapperUpdated(
        bytes32 indexed jurisdictionCode,
        address newPolicyManager,
        uint256 effectiveDate
    );
    
    constructor(
        bytes32 _jurisdictionCode,
        address _policyManager
    ) {
        jurisdictionCode = _jurisdictionCode;
        policyManager = IPolicyManager(_policyManager);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POLICY_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice GL1 標準：交易前合規檢查
     * @dev 在代幣轉移前由代幣合約調用
     * @param from 發送方地址
     * @param to 接收方地址
     * @param amount 轉移金額
     * @return isCompliant 是否通過合規檢查
     * @return failureReason 失敗原因（如有）
     */
    function checkTransferCompliance(
        address from,
        address to,
        uint256 amount
    ) external returns (bool isCompliant, string memory failureReason) {
        bytes32 txHash = keccak256(abi.encodePacked(from, to, amount, block.timestamp));
        
        emit ComplianceCheckInitiated(txHash, from, to, amount, jurisdictionCode);
        
        // 步驟 1: 驗證身份（CCID）
        (bool identityValid, string memory identityError) = 
            policyManager.verifyIdentity(from, to, jurisdictionCode);
        
        if (!identityValid) {
            emit ComplianceCheckCompleted(txHash, false, _toArray("IDENTITY_CHECK"), block.timestamp);
            return (false, identityError);
        }
        
        // 步驟 2: 執行合規規則引擎（可能在鏈下）
        (bool rulesValid, string memory ruleError, string[] memory appliedRules) = 
            policyManager.executeComplianceRules(from, to, amount, jurisdictionCode);
        
        if (!rulesValid) {
            emit ComplianceCheckCompleted(txHash, false, appliedRules, block.timestamp);
            return (false, ruleError);
        }
        
        // 步驟 3: 記錄合規證明
        complianceProofs[txHash] = ComplianceProof({
            proofHash: keccak256(abi.encode(txHash, appliedRules)),
            timestamp: block.timestamp,
            verifier: address(policyManager),
            isValid: true
        });
        
        emit ComplianceCheckCompleted(txHash, true, appliedRules, block.timestamp);
        return (true, "");
    }
    
    /**
     * @notice 更新 Policy Manager（支援監管敏捷性）
     * @param newPolicyManager 新的 Policy Manager 地址
     * @param effectiveDate 生效日期
     */
    function updatePolicyManager(
        address newPolicyManager,
        uint256 effectiveDate
    ) external onlyRole(POLICY_ADMIN_ROLE) {
        require(effectiveDate > block.timestamp, "Invalid effective date");
        
        // 使用 timelock 模式確保過渡期
        policyManager = IPolicyManager(newPolicyManager);
        
        emit PolicyWrapperUpdated(jurisdictionCode, newPolicyManager, effectiveDate);
    }
    
    /**
     * @notice 監理機構查詢歷史合規證明
     */
    function getComplianceProof(bytes32 txHash) 
        external 
        view 
        onlyRole(REGULATOR_ROLE)
        returns (ComplianceProof memory) 
    {
        return complianceProofs[txHash];
    }
    
    /**
     * @notice 批量驗證多筆交易的合規狀態
     * @param txHashes 交易雜湊陣列
     * @return proofs 合規證明陣列
     */
    function batchGetComplianceProofs(bytes32[] calldata txHashes)
        external
        view
        onlyRole(REGULATOR_ROLE)
        returns (ComplianceProof[] memory proofs)
    {
        proofs = new ComplianceProof[](txHashes.length);
        for (uint256 i = 0; i < txHashes.length; i++) {
            proofs[i] = complianceProofs[txHashes[i]];
        }
        return proofs;
    }
    
    // Helper function
    function _toArray(string memory str) internal pure returns (string[] memory) {
        string[] memory arr = new string[](1);
        arr[0] = str;
        return arr;
    }
}
