// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IIdentityRegistry
 * @notice ERC-3643 身份註冊表介面
 * @dev 管理投資者地址與身份合約、國家代碼的映射
 *      在本專案中橋接至 CCIDRegistry，簡化 IIdentity 為地址型態
 */
interface IIdentityRegistry {
    // ============ Events ============

    event ClaimTopicsRegistrySet(address indexed claimTopicsRegistry);
    event IdentityStorageSet(address indexed identityStorage);
    event TrustedIssuersRegistrySet(address indexed trustedIssuersRegistry);
    event IdentityRegistered(
        address indexed investorAddress,
        address indexed identity
    );
    event IdentityRemoved(
        address indexed investorAddress,
        address indexed identity
    );
    event IdentityUpdated(
        address indexed oldIdentity,
        address indexed newIdentity
    );
    event CountryUpdated(
        address indexed investorAddress,
        uint16 indexed country
    );

    // ============ Registry Getters ============

    /**
     * @notice 取得 Trusted Issuers Registry 地址
     */
    function issuersRegistry() external view returns (address);

    /**
     * @notice 取得 Claim Topics Registry 地址
     */
    function topicsRegistry() external view returns (address);

    // ============ Registry Setters ============

    /**
     * @notice 設定 Claim Topics Registry
     */
    function setClaimTopicsRegistry(address _claimTopicsRegistry) external;

    /**
     * @notice 設定 Trusted Issuers Registry
     */
    function setTrustedIssuersRegistry(address _trustedIssuersRegistry) external;

    // ============ Registry Actions ============

    /**
     * @notice 註冊投資者身份
     * @param _userAddress 投資者地址
     * @param _identity 身份合約地址（簡化為地址）
     * @param _country 國家代碼 (ISO-3166 數字代碼)
     */
    function registerIdentity(
        address _userAddress,
        address _identity,
        uint16 _country
    ) external;

    /**
     * @notice 刪除投資者身份
     * @param _userAddress 投資者地址
     */
    function deleteIdentity(address _userAddress) external;

    /**
     * @notice 更新投資者國家代碼
     * @param _userAddress 投資者地址
     * @param _country 新國家代碼
     */
    function updateCountry(address _userAddress, uint16 _country) external;

    /**
     * @notice 更新投資者身份合約
     * @param _userAddress 投資者地址
     * @param _identity 新身份合約地址
     */
    function updateIdentity(address _userAddress, address _identity) external;

    /**
     * @notice 批量註冊身份
     */
    function batchRegisterIdentity(
        address[] calldata _userAddresses,
        address[] calldata _identities,
        uint16[] calldata _countries
    ) external;

    // ============ Registry Consultation ============

    /**
     * @notice 檢查地址是否已註冊
     */
    function contains(address _userAddress) external view returns (bool);

    /**
     * @notice 驗證地址是否通過所有身份驗證
     * @dev 檢查 KYC 狀態 + claim 驗證
     * @param _userAddress 投資者地址
     * @return 是否已驗證
     */
    function isVerified(address _userAddress) external view returns (bool);

    /**
     * @notice 取得投資者的身份合約地址
     */
    function identity(address _userAddress) external view returns (address);

    /**
     * @notice 取得投資者的國家代碼
     */
    function investorCountry(address _userAddress) external view returns (uint16);
}
