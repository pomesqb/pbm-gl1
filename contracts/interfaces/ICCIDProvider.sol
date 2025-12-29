// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICCIDProvider
 * @notice GL1 跨鏈身份提供者介面
 * @dev 符合 GL1 CCID 標準的身份驗證介面，包含台灣監管要求的身份標籤功能
 */
interface ICCIDProvider {
    /**
     * @notice 驗證帳戶在特定管轄區的憑證
     * @param account 待驗證的帳戶地址
     * @param jurisdiction 司法管轄區代碼
     * @return 憑證是否有效
     */
    function verifyCredential(
        address account,
        bytes32 jurisdiction
    ) external view returns (bool);

    /**
     * @notice 獲取帳戶的 KYC 等級
     * @param account 帳戶地址
     * @return tier KYC 等級
     */
    function getKYCTier(address account) external view returns (bytes32 tier);

    /**
     * @notice 檢查帳戶的憑證是否過期
     * @param account 帳戶地址
     * @return 是否已過期
     */
    function isCredentialExpired(address account) external view returns (bool);
    
    /**
     * @notice 獲取帳戶的身份標籤
     * @param account 帳戶地址
     * @return 身份標籤 (RESIDENT, NON_RESIDENT, CORPORATE, SANCTIONED)
     */
    function getIdentityTag(address account) external view returns (bytes32);
    
    /**
     * @notice 檢查帳戶是否為非居民（外國人）
     * @dev 用於外匯額度檢查
     * @param account 帳戶地址
     * @return 是否為非居民
     */
    function isNonResident(address account) external view returns (bool);
    
    /**
     * @notice 檢查帳戶是否在制裁名單（黑名單）
     * @dev 用於 AML/制裁檢查
     * @param account 帳戶地址
     * @return 是否在制裁名單中
     */
    function isSanctioned(address account) external view returns (bool);
}
