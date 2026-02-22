// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IClaimTopicsRegistry.sol";

/**
 * @title ClaimTopicsRegistry
 * @notice ERC-3643 Claim 主題註冊表
 * @dev 管理安全代幣要求的 claim 主題列表
 *
 * 預定義 claim 主題：
 * - 1: KYC (Know Your Customer)
 * - 2: AML (Anti-Money Laundering)
 * - 3: 居住地驗證 (Residency)
 * - 4: 合格投資者 (Accredited Investor)
 * - 5: 制裁檢查 (Sanctions)
 */
contract ClaimTopicsRegistry is IClaimTopicsRegistry, AccessControl {
    // 必要的 claim 主題列表
    uint256[] private _claimTopics;

    // 用於快速查詢
    mapping(uint256 => bool) private _claimTopicExists;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice 新增必要的 claim 主題
     * @param _claimTopic claim 主題編號
     */
    function addClaimTopic(
        uint256 _claimTopic
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!_claimTopicExists[_claimTopic], "Topic already exists");

        _claimTopics.push(_claimTopic);
        _claimTopicExists[_claimTopic] = true;

        emit ClaimTopicAdded(_claimTopic);
    }

    /**
     * @notice 移除 claim 主題
     * @param _claimTopic claim 主題編號
     */
    function removeClaimTopic(
        uint256 _claimTopic
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_claimTopicExists[_claimTopic], "Topic does not exist");

        // Swap and pop
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            if (_claimTopics[i] == _claimTopic) {
                _claimTopics[i] = _claimTopics[_claimTopics.length - 1];
                _claimTopics.pop();
                break;
            }
        }
        _claimTopicExists[_claimTopic] = false;

        emit ClaimTopicRemoved(_claimTopic);
    }

    /**
     * @notice 取得所有必要的 claim 主題
     */
    function getClaimTopics()
        external
        view
        override
        returns (uint256[] memory)
    {
        return _claimTopics;
    }
}
