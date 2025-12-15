// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IComplianceRule
 * @notice 合規規則執行器介面
 * @dev 定義單一合規規則的檢查標準
 */
interface IComplianceRule {
    /**
     * @notice 檢查交易是否符合此規則
     * @param from 發送方地址
     * @param to 接收方地址
     * @param amount 交易金額
     * @return passed 是否通過規則檢查
     * @return error 錯誤訊息（如有）
     */
    function checkCompliance(
        address from,
        address to,
        uint256 amount
    ) external returns (bool passed, string memory error);

    /**
     * @notice 獲取規則的唯一標識符
     * @return 規則 ID
     */
    function getRuleId() external view returns (bytes32);

    /**
     * @notice 獲取規則類型
     * @return 規則類型字串（例如 "KYC", "AML", "SANCTIONS"）
     */
    function getRuleType() external view returns (string memory);

    /**
     * @notice 檢查規則是否啟用
     * @return 是否啟用
     */
    function isEnabled() external view returns (bool);
}
