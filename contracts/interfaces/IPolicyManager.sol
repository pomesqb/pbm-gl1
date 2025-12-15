// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IPolicyManager
 * @notice GL1 Policy Manager 介面
 * @dev 定義合規規則驗證的標準介面
 */
interface IPolicyManager {
    /**
     * @notice 驗證跨鏈身份 (CCID)
     * @param from 發送方地址
     * @param to 接收方地址
     * @param jurisdiction 司法管轄區代碼
     * @return isValid 身份是否有效
     * @return errorReason 錯誤原因（如有）
     */
    function verifyIdentity(
        address from,
        address to,
        bytes32 jurisdiction
    ) external returns (bool isValid, string memory errorReason);

    /**
     * @notice 執行合規規則引擎
     * @param from 發送方地址
     * @param to 接收方地址
     * @param amount 轉移金額
     * @param jurisdiction 司法管轄區代碼
     * @return isCompliant 是否合規
     * @return failureReason 失敗原因（如有）
     * @return appliedRules 已套用的規則列表
     */
    function executeComplianceRules(
        address from,
        address to,
        uint256 amount,
        bytes32 jurisdiction
    ) external returns (
        bool isCompliant,
        string memory failureReason,
        string[] memory appliedRules
    );
}
