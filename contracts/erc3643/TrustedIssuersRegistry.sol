// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/ITrustedIssuersRegistry.sol";

/**
 * @title TrustedIssuersRegistry
 * @notice ERC-3643 受信任發行者註冊表
 * @dev 管理可以為投資者簽發 claim 的受信任發行者
 *      每個發行者對應其可發行的 claim topic 列表
 */
contract TrustedIssuersRegistry is ITrustedIssuersRegistry, AccessControl {
    // 受信任發行者列表
    address[] private _trustedIssuers;

    // 發行者 => 是否為受信任
    mapping(address => bool) private _isTrusted;

    // 發行者 => claim 主題列表
    mapping(address => uint256[]) private _issuerClaimTopics;

    // 發行者 => claim 主題 => 是否擁有
    mapping(address => mapping(uint256 => bool)) private _hasClaimTopic;

    // claim 主題 => 對應的發行者列表
    mapping(uint256 => address[]) private _claimTopicIssuers;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice 新增受信任發行者
     */
    function addTrustedIssuer(
        address _trustedIssuer,
        uint256[] calldata _claimTopics
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_trustedIssuer != address(0), "Invalid issuer address");
        require(!_isTrusted[_trustedIssuer], "Issuer already trusted");
        require(_claimTopics.length > 0, "No claim topics provided");

        _trustedIssuers.push(_trustedIssuer);
        _isTrusted[_trustedIssuer] = true;

        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _issuerClaimTopics[_trustedIssuer].push(_claimTopics[i]);
            _hasClaimTopic[_trustedIssuer][_claimTopics[i]] = true;
            _claimTopicIssuers[_claimTopics[i]].push(_trustedIssuer);
        }

        emit TrustedIssuerAdded(_trustedIssuer, _claimTopics);
    }

    /**
     * @notice 移除受信任發行者
     */
    function removeTrustedIssuer(
        address _trustedIssuer
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isTrusted[_trustedIssuer], "Issuer not trusted");

        // 移除 claim topics 關聯
        uint256[] memory topics = _issuerClaimTopics[_trustedIssuer];
        for (uint256 i = 0; i < topics.length; i++) {
            _hasClaimTopic[_trustedIssuer][topics[i]] = false;
            _removeIssuerFromTopic(topics[i], _trustedIssuer);
        }
        delete _issuerClaimTopics[_trustedIssuer];

        // Swap and pop from issuers list
        for (uint256 i = 0; i < _trustedIssuers.length; i++) {
            if (_trustedIssuers[i] == _trustedIssuer) {
                _trustedIssuers[i] = _trustedIssuers[_trustedIssuers.length - 1];
                _trustedIssuers.pop();
                break;
            }
        }
        _isTrusted[_trustedIssuer] = false;

        emit TrustedIssuerRemoved(_trustedIssuer);
    }

    /**
     * @notice 更新發行者的 claim 主題列表
     */
    function updateIssuerClaimTopics(
        address _trustedIssuer,
        uint256[] calldata _claimTopics
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_isTrusted[_trustedIssuer], "Issuer not trusted");
        require(_claimTopics.length > 0, "No claim topics provided");

        // 清除舊的 claim topics
        uint256[] memory oldTopics = _issuerClaimTopics[_trustedIssuer];
        for (uint256 i = 0; i < oldTopics.length; i++) {
            _hasClaimTopic[_trustedIssuer][oldTopics[i]] = false;
            _removeIssuerFromTopic(oldTopics[i], _trustedIssuer);
        }
        delete _issuerClaimTopics[_trustedIssuer];

        // 設置新的 claim topics
        for (uint256 i = 0; i < _claimTopics.length; i++) {
            _issuerClaimTopics[_trustedIssuer].push(_claimTopics[i]);
            _hasClaimTopic[_trustedIssuer][_claimTopics[i]] = true;
            _claimTopicIssuers[_claimTopics[i]].push(_trustedIssuer);
        }

        emit ClaimTopicsUpdated(_trustedIssuer, _claimTopics);
    }

    // ============ Getters ============

    function getTrustedIssuers()
        external
        view
        override
        returns (address[] memory)
    {
        return _trustedIssuers;
    }

    function isTrustedIssuer(
        address _issuer
    ) external view override returns (bool) {
        return _isTrusted[_issuer];
    }

    function getTrustedIssuerClaimTopics(
        address _trustedIssuer
    ) external view override returns (uint256[] memory) {
        return _issuerClaimTopics[_trustedIssuer];
    }

    function getTrustedIssuersForClaimTopic(
        uint256 claimTopic
    ) external view override returns (address[] memory) {
        return _claimTopicIssuers[claimTopic];
    }

    function hasClaimTopic(
        address _issuer,
        uint256 _claimTopic
    ) external view override returns (bool) {
        return _hasClaimTopic[_issuer][_claimTopic];
    }

    // ============ Internal ============

    function _removeIssuerFromTopic(uint256 topic, address issuer) internal {
        address[] storage issuers = _claimTopicIssuers[topic];
        for (uint256 i = 0; i < issuers.length; i++) {
            if (issuers[i] == issuer) {
                issuers[i] = issuers[issuers.length - 1];
                issuers.pop();
                break;
            }
        }
    }
}
