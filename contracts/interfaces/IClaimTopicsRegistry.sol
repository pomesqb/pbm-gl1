// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IClaimTopicsRegistry
 * @notice ERC-3643 Claim 主題註冊表介面
 * @dev 定義安全代幣要求的 claim 主題列表
 *      例如：KYC (1), AML (2), 居住地驗證 (3), 合格投資者 (4)
 */
interface IClaimTopicsRegistry {
    // ============ Events ============

    event ClaimTopicAdded(uint256 indexed claimTopic);
    event ClaimTopicRemoved(uint256 indexed claimTopic);

    // ============ Setters ============

    /**
     * @notice 新增必要的 claim 主題
     * @param _claimTopic claim 主題編號
     */
    function addClaimTopic(uint256 _claimTopic) external;

    /**
     * @notice 移除 claim 主題
     * @param _claimTopic claim 主題編號
     */
    function removeClaimTopic(uint256 _claimTopic) external;

    // ============ Getters ============

    /**
     * @notice 取得所有必要的 claim 主題
     */
    function getClaimTopics() external view returns (uint256[] memory);
}
