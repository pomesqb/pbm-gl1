// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IChainlinkACEPolicyManager
 * @notice Chainlink ACE 政策管理介面
 * @dev 用於建立和管理合規政策
 */
interface IChainlinkACEPolicyManager {
    /**
     * @notice 建立新的合規政策
     * @param policyId 政策唯一標識符
     * @param parameters 政策參數（編碼後）
     */
    function createPolicy(
        bytes32 policyId,
        bytes memory parameters
    ) external;

    /**
     * @notice 更新現有政策
     * @param policyId 政策唯一標識符
     * @param parameters 新的政策參數
     */
    function updatePolicy(
        bytes32 policyId,
        bytes memory parameters
    ) external;

    /**
     * @notice 停用政策
     * @param policyId 政策唯一標識符
     */
    function deactivatePolicy(bytes32 policyId) external;

    /**
     * @notice 檢查政策是否啟用
     * @param policyId 政策唯一標識符
     * @return 是否啟用
     */
    function isPolicyActive(bytes32 policyId) external view returns (bool);

    /**
     * @notice 獲取政策參數
     * @param policyId 政策唯一標識符
     * @return 編碼後的政策參數
     */
    function getPolicyParameters(bytes32 policyId) external view returns (bytes memory);
}
