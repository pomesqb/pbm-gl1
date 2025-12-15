// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IChainlinkACE
 * @notice Chainlink 自動化合規引擎介面
 * @dev 整合 Chainlink ACE 進行制裁名單檢查和合規驗證
 */
interface IChainlinkACE {
    /**
     * @notice 檢查地址是否在制裁名單上
     * @param from 發送方地址
     * @param to 接收方地址
     * @return 如果兩個地址都不在制裁名單上，返回 true
     */
    function checkSanctionsList(
        address from,
        address to
    ) external view returns (bool);

    /**
     * @notice 驗證交易的合規狀態
     * @param from 發送方地址
     * @param to 接收方地址
     * @param amount 交易金額
     * @param jurisdiction 司法管轄區
     * @return isCompliant 是否合規
     * @return reason 原因說明
     */
    function verifyTransactionCompliance(
        address from,
        address to,
        uint256 amount,
        bytes32 jurisdiction
    ) external returns (bool isCompliant, string memory reason);

    /**
     * @notice 獲取地址的風險評分
     * @param account 帳戶地址
     * @return riskScore 風險評分 (0-100)
     */
    function getRiskScore(address account) external view returns (uint256 riskScore);
}
