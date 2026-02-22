// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IIdentityRegistry.sol";
import "../interfaces/ITrustedIssuersRegistry.sol";
import "../interfaces/IClaimTopicsRegistry.sol";
import "../interfaces/ICCIDProvider.sol";

/**
 * @title IdentityRegistry
 * @notice ERC-3643 身份註冊表 - 橋接至 CCIDRegistry
 * @dev 管理投資者地址與身份、國家代碼的映射
 *      isVerified() 整合 CCIDRegistry 的 KYC 驗證
 *      簡化 IIdentity 為地址型態以對接現有架構
 */
contract IdentityRegistry is IIdentityRegistry, AccessControl {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    // 投資者身份資訊
    struct InvestorIdentity {
        address identity;     // 身份合約地址（簡化為地址）
        uint16 country;       // ISO-3166 數字國家代碼
        bool registered;      // 是否已註冊
    }

    // 地址 → 投資者身份
    mapping(address => InvestorIdentity) private _identities;

    // 已註冊地址列表
    address[] private _registeredAddresses;

    // 關聯的註冊表
    address private _issuersRegistry;
    address private _topicsRegistry;

    // 橋接至 CCIDRegistry
    ICCIDProvider public ccidProvider;

    constructor(
        address _trustedIssuersRegistry,
        address _claimTopicsRegistry,
        address _ccidProvider
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AGENT_ROLE, msg.sender);

        _issuersRegistry = _trustedIssuersRegistry;
        _topicsRegistry = _claimTopicsRegistry;
        ccidProvider = ICCIDProvider(_ccidProvider);
    }

    // ============ Registry Getters ============

    function issuersRegistry() external view override returns (address) {
        return _issuersRegistry;
    }

    function topicsRegistry() external view override returns (address) {
        return _topicsRegistry;
    }

    // ============ Registry Setters ============

    function setClaimTopicsRegistry(
        address _claimTopicsRegistry
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_claimTopicsRegistry != address(0), "Invalid address");
        _topicsRegistry = _claimTopicsRegistry;
        emit ClaimTopicsRegistrySet(_claimTopicsRegistry);
    }

    function setTrustedIssuersRegistry(
        address _trustedIssuersRegistry
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_trustedIssuersRegistry != address(0), "Invalid address");
        _issuersRegistry = _trustedIssuersRegistry;
        emit TrustedIssuersRegistrySet(_trustedIssuersRegistry);
    }

    /**
     * @notice 設定 CCIDProvider 地址
     */
    function setCCIDProvider(
        address _ccidProvider
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_ccidProvider != address(0), "Invalid address");
        ccidProvider = ICCIDProvider(_ccidProvider);
    }

    // ============ Registry Actions ============

    function registerIdentity(
        address _userAddress,
        address _identity,
        uint16 _country
    ) external override onlyRole(AGENT_ROLE) {
        require(_userAddress != address(0), "Invalid user address");
        require(!_identities[_userAddress].registered, "Already registered");

        _identities[_userAddress] = InvestorIdentity({
            identity: _identity,
            country: _country,
            registered: true
        });

        _registeredAddresses.push(_userAddress);

        emit IdentityRegistered(_userAddress, _identity);
        emit CountryUpdated(_userAddress, _country);
    }

    function deleteIdentity(
        address _userAddress
    ) external override onlyRole(AGENT_ROLE) {
        require(_identities[_userAddress].registered, "Not registered");

        address oldIdentity = _identities[_userAddress].identity;
        delete _identities[_userAddress];

        // 從列表移除 (swap and pop)
        for (uint256 i = 0; i < _registeredAddresses.length; i++) {
            if (_registeredAddresses[i] == _userAddress) {
                _registeredAddresses[i] = _registeredAddresses[
                    _registeredAddresses.length - 1
                ];
                _registeredAddresses.pop();
                break;
            }
        }

        emit IdentityRemoved(_userAddress, oldIdentity);
    }

    function updateCountry(
        address _userAddress,
        uint16 _country
    ) external override onlyRole(AGENT_ROLE) {
        require(_identities[_userAddress].registered, "Not registered");
        _identities[_userAddress].country = _country;
        emit CountryUpdated(_userAddress, _country);
    }

    function updateIdentity(
        address _userAddress,
        address _identity
    ) external override onlyRole(AGENT_ROLE) {
        require(_identities[_userAddress].registered, "Not registered");
        address oldIdentity = _identities[_userAddress].identity;
        _identities[_userAddress].identity = _identity;
        emit IdentityUpdated(oldIdentity, _identity);
    }

    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        address[] calldata _identitiesArr,
        uint16[] calldata _countries
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _userAddresses.length == _identitiesArr.length &&
                _userAddresses.length == _countries.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < _userAddresses.length; i++) {
            if (
                _userAddresses[i] != address(0) &&
                !_identities[_userAddresses[i]].registered
            ) {
                _identities[_userAddresses[i]] = InvestorIdentity({
                    identity: _identitiesArr[i],
                    country: _countries[i],
                    registered: true
                });
                _registeredAddresses.push(_userAddresses[i]);
                emit IdentityRegistered(_userAddresses[i], _identitiesArr[i]);
            }
        }
    }

    // ============ Registry Consultation ============

    function contains(
        address _userAddress
    ) external view override returns (bool) {
        return _identities[_userAddress].registered;
    }

    /**
     * @notice 驗證地址是否通過所有身份驗證
     * @dev 整合 CCIDRegistry 的 KYC 驗證：
     *      1. 檢查是否已在 Identity Registry 註冊
     *      2. 透過 CCIDProvider 驗證 KYC 狀態
     *      3. 檢查 KYC 是否未過期
     */
    function isVerified(
        address _userAddress
    ) external view override returns (bool) {
        // 1. 必須在 Identity Registry 中註冊
        if (!_identities[_userAddress].registered) {
            return false;
        }

        // 2. 透過 CCIDProvider 橋接驗證
        if (address(ccidProvider) != address(0)) {
            // 檢查 KYC 是否有效
            bytes32 kycTier = ccidProvider.getKYCTier(_userAddress);
            if (kycTier == bytes32(0)) {
                return false; // 無 KYC 等級
            }

            // 檢查 KYC 是否過期
            if (ccidProvider.isCredentialExpired(_userAddress)) {
                return false;
            }
        }

        return true;
    }

    function identity(
        address _userAddress
    ) external view override returns (address) {
        return _identities[_userAddress].identity;
    }

    function investorCountry(
        address _userAddress
    ) external view override returns (uint16) {
        return _identities[_userAddress].country;
    }

    /**
     * @notice 取得已註冊的投資者數量
     */
    function getRegisteredCount() external view returns (uint256) {
        return _registeredAddresses.length;
    }
}
