// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITrustedIssuersRegistry
 * @notice ERC-3643 受信任發行者註冊表介面
 * @dev 管理可以為投資者簽發 claim 的受信任發行者
 *      每個發行者對應其可發行的 claim topic 列表
 */
interface ITrustedIssuersRegistry {
    // ============ Events ============

    event TrustedIssuerAdded(address indexed trustedIssuer, uint256[] claimTopics);
    event TrustedIssuerRemoved(address indexed trustedIssuer);
    event ClaimTopicsUpdated(address indexed trustedIssuer, uint256[] claimTopics);

    // ============ Setters ============

    /**
     * @notice 新增受信任發行者
     * @param _trustedIssuer 發行者地址
     * @param _claimTopics 該發行者可發行的 claim 主題列表
     */
    function addTrustedIssuer(
        address _trustedIssuer,
        uint256[] calldata _claimTopics
    ) external;

    /**
     * @notice 移除受信任發行者
     * @param _trustedIssuer 發行者地址
     */
    function removeTrustedIssuer(address _trustedIssuer) external;

    /**
     * @notice 更新發行者的 claim 主題列表
     * @param _trustedIssuer 發行者地址
     * @param _claimTopics 新的 claim 主題列表
     */
    function updateIssuerClaimTopics(
        address _trustedIssuer,
        uint256[] calldata _claimTopics
    ) external;

    // ============ Getters ============

    /**
     * @notice 取得所有受信任發行者
     */
    function getTrustedIssuers() external view returns (address[] memory);

    /**
     * @notice 檢查地址是否為受信任發行者
     */
    function isTrustedIssuer(address _issuer) external view returns (bool);

    /**
     * @notice 取得發行者的 claim 主題列表
     */
    function getTrustedIssuerClaimTopics(
        address _trustedIssuer
    ) external view returns (uint256[] memory);

    /**
     * @notice 取得特定 claim 主題的受信任發行者
     */
    function getTrustedIssuersForClaimTopic(
        uint256 claimTopic
    ) external view returns (address[] memory);

    /**
     * @notice 檢查發行者是否擁有特定 claim 主題
     */
    function hasClaimTopic(
        address _issuer,
        uint256 _claimTopic
    ) external view returns (bool);
}
