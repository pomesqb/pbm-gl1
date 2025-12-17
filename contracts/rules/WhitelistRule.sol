// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IComplianceRule.sol";

/**
 * @title WhitelistRule
 * @notice 白名單合規規則 - 只允許轉移給白名單中的接收者
 * @dev 實作 GL1「Whitelisting Selected Receivers」範例
 * 
 * 使用場景：
 * - 外國遊客在本地使用數位支付，只能付款給已驗證的商家
 * - 確保資金只能流向經過 KYC 的合規接收者
 */
contract WhitelistRule is IComplianceRule, AccessControl {
    bytes32 public constant WHITELIST_ADMIN_ROLE = keccak256("WHITELIST_ADMIN_ROLE");
    
    // 規則標識符
    bytes32 public constant RULE_ID = keccak256("WHITELIST_RULE");
    
    // 規則是否啟用
    bool private _enabled = true;
    
    // 全局白名單：address => 是否在白名單中
    mapping(address => bool) public whitelist;
    
    // 按管轄區的白名單：jurisdiction => address => 是否在白名單中
    mapping(bytes32 => mapping(address => bool)) public jurisdictionWhitelist;
    
    // 白名單模式：true = 檢查管轄區白名單，false = 只檢查全局白名單
    bool public useJurisdictionMode;
    
    // 當前檢查的管轄區（由 PolicyManager 設置）
    bytes32 public currentJurisdiction;
    
    // 商家資訊結構
    struct MerchantInfo {
        string name;           // 商家名稱
        string category;       // 商家類別（餐飲、零售等）
        uint256 addedAt;       // 加入時間
        address addedBy;       // 由誰加入
        bool isActive;         // 是否啟用
    }
    
    // 商家詳細資訊
    mapping(address => MerchantInfo) public merchants;
    
    // 白名單地址列表（用於遍歷）
    address[] public whitelistedAddresses;
    mapping(address => uint256) private whitelistIndex;
    
    event AddedToWhitelist(address indexed account, string name, string category, address indexed addedBy);
    event RemovedFromWhitelist(address indexed account, address indexed removedBy);
    event JurisdictionWhitelistUpdated(bytes32 indexed jurisdiction, address indexed account, bool status);
    event RuleEnabledChanged(bool enabled);
    event JurisdictionModeChanged(bool useJurisdictionMode);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(WHITELIST_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice 檢查交易是否符合白名單規則
     * @param from 發送方地址（此規則不檢查發送方）
     * @param to 接收方地址（必須在白名單中）
     * @param amount 交易金額（此規則不檢查金額）
     * @return passed 是否通過規則檢查
     * @return error 錯誤訊息
     */
    function checkCompliance(
        address from,
        address to,
        uint256 amount
    ) external view override returns (bool passed, string memory error) {
        // 抑制未使用參數警告
        from;
        amount;
        
        // 如果規則未啟用，直接通過
        if (!_enabled) {
            return (true, "");
        }
        
        // 檢查接收方是否在白名單中
        bool inWhitelist;
        
        if (useJurisdictionMode && currentJurisdiction != bytes32(0)) {
            // 管轄區模式：檢查特定管轄區的白名單
            inWhitelist = jurisdictionWhitelist[currentJurisdiction][to];
        } else {
            // 全局模式：檢查全局白名單
            inWhitelist = whitelist[to];
        }
        
        if (!inWhitelist) {
            return (false, "Recipient not in whitelist");
        }
        
        // 檢查商家是否仍為啟用狀態
        if (merchants[to].addedAt > 0 && !merchants[to].isActive) {
            return (false, "Merchant is deactivated");
        }
        
        return (true, "");
    }
    
    /**
     * @notice 獲取規則 ID
     */
    function getRuleId() external pure override returns (bytes32) {
        return RULE_ID;
    }
    
    /**
     * @notice 獲取規則類型
     */
    function getRuleType() external pure override returns (string memory) {
        return "WHITELIST";
    }
    
    /**
     * @notice 檢查規則是否啟用
     */
    function isEnabled() external view override returns (bool) {
        return _enabled;
    }
    
    // ============ 白名單管理 ============
    
    /**
     * @notice 將商家加入全局白名單
     * @param merchant 商家地址
     * @param name 商家名稱
     * @param category 商家類別
     */
    function addToWhitelist(
        address merchant,
        string calldata name,
        string calldata category
    ) external onlyRole(WHITELIST_ADMIN_ROLE) {
        require(merchant != address(0), "Invalid address");
        require(!whitelist[merchant], "Already whitelisted");
        
        whitelist[merchant] = true;
        
        // 記錄商家資訊
        merchants[merchant] = MerchantInfo({
            name: name,
            category: category,
            addedAt: block.timestamp,
            addedBy: msg.sender,
            isActive: true
        });
        
        // 加入地址列表
        whitelistIndex[merchant] = whitelistedAddresses.length;
        whitelistedAddresses.push(merchant);
        
        emit AddedToWhitelist(merchant, name, category, msg.sender);
    }
    
    /**
     * @notice 批量加入白名單
     * @param merchantAddresses 商家地址列表
     * @param names 商家名稱列表
     * @param categories 商家類別列表
     */
    function batchAddToWhitelist(
        address[] calldata merchantAddresses,
        string[] calldata names,
        string[] calldata categories
    ) external onlyRole(WHITELIST_ADMIN_ROLE) {
        require(
            merchantAddresses.length == names.length && 
            names.length == categories.length,
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < merchantAddresses.length; i++) {
            address merchant = merchantAddresses[i];
            
            if (merchant == address(0) || whitelist[merchant]) {
                continue; // 跳過無效或已存在的地址
            }
            
            whitelist[merchant] = true;
            
            merchants[merchant] = MerchantInfo({
                name: names[i],
                category: categories[i],
                addedAt: block.timestamp,
                addedBy: msg.sender,
                isActive: true
            });
            
            whitelistIndex[merchant] = whitelistedAddresses.length;
            whitelistedAddresses.push(merchant);
            
            emit AddedToWhitelist(merchant, names[i], categories[i], msg.sender);
        }
    }
    
    /**
     * @notice 從白名單移除
     * @param merchant 商家地址
     */
    function removeFromWhitelist(address merchant) external onlyRole(WHITELIST_ADMIN_ROLE) {
        require(whitelist[merchant], "Not in whitelist");
        
        whitelist[merchant] = false;
        merchants[merchant].isActive = false;
        
        // 從列表中移除（swap and pop）
        uint256 index = whitelistIndex[merchant];
        uint256 lastIndex = whitelistedAddresses.length - 1;
        
        if (index != lastIndex) {
            address lastAddress = whitelistedAddresses[lastIndex];
            whitelistedAddresses[index] = lastAddress;
            whitelistIndex[lastAddress] = index;
        }
        
        whitelistedAddresses.pop();
        delete whitelistIndex[merchant];
        
        emit RemovedFromWhitelist(merchant, msg.sender);
    }
    
    /**
     * @notice 更新管轄區白名單
     * @param jurisdiction 管轄區代碼
     * @param account 地址
     * @param status 是否在白名單中
     */
    function setJurisdictionWhitelist(
        bytes32 jurisdiction,
        address account,
        bool status
    ) external onlyRole(WHITELIST_ADMIN_ROLE) {
        jurisdictionWhitelist[jurisdiction][account] = status;
        emit JurisdictionWhitelistUpdated(jurisdiction, account, status);
    }
    
    /**
     * @notice 批量更新管轄區白名單
     */
    function batchSetJurisdictionWhitelist(
        bytes32 jurisdiction,
        address[] calldata accounts,
        bool status
    ) external onlyRole(WHITELIST_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            jurisdictionWhitelist[jurisdiction][accounts[i]] = status;
            emit JurisdictionWhitelistUpdated(jurisdiction, accounts[i], status);
        }
    }
    
    // ============ 配置函數 ============
    
    /**
     * @notice 設置當前管轄區（由 PolicyManager 調用）
     */
    function setCurrentJurisdiction(bytes32 jurisdiction) external {
        currentJurisdiction = jurisdiction;
    }
    
    /**
     * @notice 啟用/停用規則
     */
    function setEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _enabled = enabled;
        emit RuleEnabledChanged(enabled);
    }
    
    /**
     * @notice 設置是否使用管轄區模式
     */
    function setJurisdictionMode(bool _useJurisdictionMode) external onlyRole(DEFAULT_ADMIN_ROLE) {
        useJurisdictionMode = _useJurisdictionMode;
        emit JurisdictionModeChanged(_useJurisdictionMode);
    }
    
    // ============ 查詢函數 ============
    
    /**
     * @notice 檢查地址是否在白名單中
     */
    function isWhitelisted(address account) external view returns (bool) {
        return whitelist[account] && merchants[account].isActive;
    }
    
    /**
     * @notice 檢查地址是否在特定管轄區的白名單中
     */
    function isWhitelistedInJurisdiction(
        bytes32 jurisdiction,
        address account
    ) external view returns (bool) {
        return jurisdictionWhitelist[jurisdiction][account];
    }
    
    /**
     * @notice 獲取商家資訊
     */
    function getMerchantInfo(address merchant) external view returns (MerchantInfo memory) {
        return merchants[merchant];
    }
    
    /**
     * @notice 獲取白名單地址數量
     */
    function getWhitelistCount() external view returns (uint256) {
        return whitelistedAddresses.length;
    }
    
    /**
     * @notice 獲取白名單地址列表（分頁）
     */
    function getWhitelistedAddresses(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory) {
        uint256 total = whitelistedAddresses.length;
        
        if (offset >= total) {
            return new address[](0);
        }
        
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        
        address[] memory result = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = whitelistedAddresses[i];
        }
        
        return result;
    }
}
