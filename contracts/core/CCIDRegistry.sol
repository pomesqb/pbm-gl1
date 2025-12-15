// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/ICCIDProvider.sol";

/**
 * @title CCIDRegistry
 * @notice GL1 跨鏈身份註冊表
 * @dev 敏感資料存鏈下（符合 GDPR），可驗證性證明存鏈上
 */
contract CCIDRegistry is ICCIDProvider, AccessControl {
    bytes32 public constant KYC_PROVIDER_ROLE = keccak256("KYC_PROVIDER_ROLE");
    bytes32 public constant CROSS_CHAIN_BRIDGE_ROLE = keccak256("CROSS_CHAIN_BRIDGE_ROLE");
    
    // KYC 等級定義
    bytes32 public constant TIER_NONE = keccak256("TIER_NONE");
    bytes32 public constant TIER_BASIC = keccak256("TIER_BASIC");
    bytes32 public constant TIER_STANDARD = keccak256("TIER_STANDARD");
    bytes32 public constant TIER_ENHANCED = keccak256("TIER_ENHANCED");
    bytes32 public constant TIER_INSTITUTIONAL = keccak256("TIER_INSTITUTIONAL");
    
    // KYC 有效期限（預設 365 天）
    uint256 public kycValidityPeriod = 365 days;
    
    struct Identity {
        bytes32 identityHash;      // 鏈下身份資料的雜湊
        uint256 kycTimestamp;      // KYC 驗證時間
        bytes32 tier;              // 風險等級
        bool isActive;             // 是否啟用
    }
    
    // 地址 → 身份映射
    mapping(address => Identity) public identities;
    
    // 地址 → 適用管轄區
    mapping(address => mapping(bytes32 => bool)) public jurisdictionApproval;
    
    // 跨鏈地址映射（例如：以太坊地址 → Polygon 地址）
    mapping(address => mapping(bytes32 => address)) public crossChainAddresses;
    
    // 鏈 ID → 是否支援
    mapping(bytes32 => bool) public supportedChains;
    
    event IdentityRegistered(address indexed account, bytes32 tier, uint256 timestamp);
    event IdentityUpdated(address indexed account, bytes32 newTier);
    event IdentityRevoked(address indexed account);
    event JurisdictionApproved(address indexed account, bytes32 indexed jurisdiction);
    event JurisdictionRevoked(address indexed account, bytes32 indexed jurisdiction);
    event CrossChainAddressLinked(
        address indexed primaryAddress,
        bytes32 indexed chainId,
        address linkedAddress
    );
    event ChainSupportUpdated(bytes32 indexed chainId, bool supported);
    event KYCValidityPeriodUpdated(uint256 newPeriod);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(KYC_PROVIDER_ROLE, msg.sender);
        
        // 預設支援的鏈
        supportedChains[keccak256("ETHEREUM")] = true;
        supportedChains[keccak256("POLYGON")] = true;
        supportedChains[keccak256("ARBITRUM")] = true;
        supportedChains[keccak256("OPTIMISM")] = true;
    }
    
    /**
     * @notice 註冊新身份
     * @param account 帳戶地址
     * @param identityHash 鏈下身份資料的雜湊
     * @param tier KYC 等級
     */
    function registerIdentity(
        address account,
        bytes32 identityHash,
        bytes32 tier
    ) external onlyRole(KYC_PROVIDER_ROLE) {
        require(account != address(0), "Invalid account");
        require(identityHash != bytes32(0), "Invalid identity hash");
        require(
            tier == TIER_BASIC || tier == TIER_STANDARD || 
            tier == TIER_ENHANCED || tier == TIER_INSTITUTIONAL,
            "Invalid tier"
        );
        
        identities[account] = Identity({
            identityHash: identityHash,
            kycTimestamp: block.timestamp,
            tier: tier,
            isActive: true
        });
        
        emit IdentityRegistered(account, tier, block.timestamp);
    }
    
    /**
     * @notice 更新身份的 KYC 等級
     */
    function updateIdentityTier(
        address account,
        bytes32 newTier
    ) external onlyRole(KYC_PROVIDER_ROLE) {
        require(identities[account].isActive, "Identity not active");
        
        identities[account].tier = newTier;
        identities[account].kycTimestamp = block.timestamp;
        
        emit IdentityUpdated(account, newTier);
    }
    
    /**
     * @notice 撤銷身份
     */
    function revokeIdentity(address account) external onlyRole(KYC_PROVIDER_ROLE) {
        require(identities[account].isActive, "Identity not active");
        
        identities[account].isActive = false;
        
        emit IdentityRevoked(account);
    }
    
    /**
     * @notice 核准帳戶在特定管轄區操作
     */
    function approveJurisdiction(
        address account,
        bytes32 jurisdiction
    ) external onlyRole(KYC_PROVIDER_ROLE) {
        require(identities[account].isActive, "Identity not active");
        
        jurisdictionApproval[account][jurisdiction] = true;
        
        emit JurisdictionApproved(account, jurisdiction);
    }
    
    /**
     * @notice 撤銷帳戶在特定管轄區的操作權限
     */
    function revokeJurisdiction(
        address account,
        bytes32 jurisdiction
    ) external onlyRole(KYC_PROVIDER_ROLE) {
        jurisdictionApproval[account][jurisdiction] = false;
        
        emit JurisdictionRevoked(account, jurisdiction);
    }
    
    /**
     * @notice 驗證憑證（不暴露 PII）
     * @dev 實作 ICCIDProvider 介面
     */
    function verifyCredential(
        address account,
        bytes32 jurisdiction
    ) external view override returns (bool) {
        Identity memory identity = identities[account];
        
        // 檢查身份是否啟用
        if (!identity.isActive) {
            return false;
        }
        
        // 檢查 KYC 是否有效（未過期）
        if (block.timestamp > identity.kycTimestamp + kycValidityPeriod) {
            return false;
        }
        
        // 檢查是否有管轄區核准
        if (!jurisdictionApproval[account][jurisdiction]) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @notice 獲取帳戶的 KYC 等級
     * @dev 實作 ICCIDProvider 介面
     */
    function getKYCTier(address account) external view override returns (bytes32) {
        return identities[account].tier;
    }
    
    /**
     * @notice 檢查帳戶的憑證是否過期
     * @dev 實作 ICCIDProvider 介面
     */
    function isCredentialExpired(address account) external view override returns (bool) {
        Identity memory identity = identities[account];
        
        if (!identity.isActive || identity.kycTimestamp == 0) {
            return true;
        }
        
        return block.timestamp > identity.kycTimestamp + kycValidityPeriod;
    }
    
    /**
     * @notice 連結跨鏈地址
     * @param primaryAddress 主鏈地址
     * @param chainId 目標鏈 ID
     * @param linkedAddress 目標鏈上的地址
     * @param proof ZK 證明或多簽證明（未來擴展）
     */
    function linkCrossChainAddress(
        address primaryAddress,
        bytes32 chainId,
        address linkedAddress,
        bytes memory proof
    ) external onlyRole(CROSS_CHAIN_BRIDGE_ROLE) {
        require(supportedChains[chainId], "Chain not supported");
        require(identities[primaryAddress].isActive, "Primary identity not active");
        require(linkedAddress != address(0), "Invalid linked address");
        
        // TODO: 驗證 proof（使用 ZK 證明或多簽）
        // 目前簡化處理，僅由授權角色執行
        require(proof.length > 0, "Proof required");
        
        crossChainAddresses[primaryAddress][chainId] = linkedAddress;
        
        emit CrossChainAddressLinked(primaryAddress, chainId, linkedAddress);
    }
    
    /**
     * @notice 獲取跨鏈地址
     */
    function getCrossChainAddress(
        address primaryAddress,
        bytes32 chainId
    ) external view returns (address) {
        return crossChainAddresses[primaryAddress][chainId];
    }
    
    /**
     * @notice 更新支援的鏈
     */
    function setChainSupport(
        bytes32 chainId,
        bool supported
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        supportedChains[chainId] = supported;
        emit ChainSupportUpdated(chainId, supported);
    }
    
    /**
     * @notice 更新 KYC 有效期限
     */
    function setKYCValidityPeriod(
        uint256 newPeriod
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newPeriod >= 30 days, "Period too short");
        require(newPeriod <= 730 days, "Period too long");
        
        kycValidityPeriod = newPeriod;
        emit KYCValidityPeriodUpdated(newPeriod);
    }
    
    /**
     * @notice 批量註冊身份（用於遷移）
     */
    function batchRegisterIdentities(
        address[] calldata accounts,
        bytes32[] calldata identityHashes,
        bytes32[] calldata tiers
    ) external onlyRole(KYC_PROVIDER_ROLE) {
        require(
            accounts.length == identityHashes.length && 
            accounts.length == tiers.length,
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < accounts.length; i++) {
            if (accounts[i] != address(0) && identityHashes[i] != bytes32(0)) {
                identities[accounts[i]] = Identity({
                    identityHash: identityHashes[i],
                    kycTimestamp: block.timestamp,
                    tier: tiers[i],
                    isActive: true
                });
                
                emit IdentityRegistered(accounts[i], tiers[i], block.timestamp);
            }
        }
    }
    
    /**
     * @notice 獲取身份詳細資訊
     */
    function getIdentity(address account) external view returns (
        bytes32 identityHash,
        uint256 kycTimestamp,
        bytes32 tier,
        bool isActive,
        bool isExpired
    ) {
        Identity memory identity = identities[account];
        return (
            identity.identityHash,
            identity.kycTimestamp,
            identity.tier,
            identity.isActive,
            block.timestamp > identity.kycTimestamp + kycValidityPeriod
        );
    }
}
