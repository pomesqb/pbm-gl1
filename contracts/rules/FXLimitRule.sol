// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IComplianceRule.sol";
import "../interfaces/ICCIDProvider.sol";

/**
 * @title FXLimitRule
 * @notice 外匯累計額度規則 - 針對非居民的每日轉出限額檢查
 * @dev 實作「外國人外匯額度檢查」功能
 * 
 * ═══════════════════════════════════════════════════════════════════
 * 使用場景：
 * ═══════════════════════════════════════════════════════════════════
 * 當智能合約偵測到發送方帶有 Non-Resident 標籤時，
 * 自動觸發外匯額度檢查邏輯，確保今日累計轉出不超過央行設定的門檻。
 * 
 * 錯誤代碼：FX_LIMIT_EXCEEDED
 * ═══════════════════════════════════════════════════════════════════
 */
contract FXLimitRule is IComplianceRule, AccessControl {
    bytes32 public constant FX_ADMIN_ROLE = keccak256("FX_ADMIN_ROLE");
    
    // 規則標識符
    bytes32 public constant RULE_ID = keccak256("FX_LIMIT_RULE");
    
    // 規則是否啟用
    bool private _enabled = true;
    
    // CCID Provider - 用於查詢身份標籤
    ICCIDProvider public ccidProvider;
    
    // 每日累計額度上限 (18 decimals)
    // 預設：等值 TWD 50 億 (可由央行動態調整)
    uint256 public dailyLimit = 5_000_000_000 * 1e18;
    
    // 地址 → 日期 → 累計轉出金額
    // 日期使用 block.timestamp / 1 days 計算
    mapping(address => mapping(uint256 => uint256)) public dailyTransferAmounts;
    
    // 豁免額度檢查的地址（如銀行、合規機構）
    mapping(address => bool) public exemptAddresses;
    
    // 限額變更歷史記錄（用於審計）
    struct LimitChange {
        uint256 oldLimit;
        uint256 newLimit;
        uint256 timestamp;
        address changedBy;
    }
    LimitChange[] public limitHistory;
    
    event DailyLimitUpdated(uint256 oldLimit, uint256 newLimit, address indexed changedBy);
    event TransferRecorded(address indexed from, uint256 amount, uint256 dailyTotal, uint256 day);
    event FXLimitExceeded(address indexed from, uint256 attemptedAmount, uint256 dailyTotal, uint256 limit);
    event ExemptAddressSet(address indexed account, bool exempt);
    event CCIDProviderUpdated(address indexed oldProvider, address indexed newProvider);
    event RuleEnabledChanged(bool enabled);
    
    constructor(address _ccidProvider) {
        require(_ccidProvider != address(0), "Invalid CCID provider");
        ccidProvider = ICCIDProvider(_ccidProvider);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(FX_ADMIN_ROLE, msg.sender);
        
        // 記錄初始限額
        limitHistory.push(LimitChange({
            oldLimit: 0,
            newLimit: dailyLimit,
            timestamp: block.timestamp,
            changedBy: msg.sender
        }));
    }
    
    /**
     * @notice 檢查交易是否符合外匯額度規則
     * @dev 僅檢查 Non-Resident 的轉出額度
     * @param from 發送方地址
     * @param to 接收方地址（不使用）
     * @param amount 交易金額
     * @return passed 是否通過規則檢查
     * @return error 錯誤訊息
     */
    function checkCompliance(
        address from,
        address to,
        uint256 amount
    ) external view override returns (bool passed, string memory error) {
        // 抑制未使用參數警告
        to;
        
        // 如果規則未啟用，直接通過
        if (!_enabled) {
            return (true, "");
        }
        
        // 檢查是否為豁免地址
        if (exemptAddresses[from]) {
            return (true, "");
        }
        
        // 檢查發送方是否為非居民
        // 只有非居民需要受到外匯額度限制
        if (!ccidProvider.isNonResident(from)) {
            return (true, "");
        }
        
        // 計算今日累計
        uint256 today = block.timestamp / 1 days;
        uint256 currentDailyTotal = dailyTransferAmounts[from][today];
        uint256 newTotal = currentDailyTotal + amount;
        
        // 檢查是否超過限額
        if (newTotal > dailyLimit) {
            return (false, "FX_LIMIT_EXCEEDED");
        }
        
        return (true, "");
    }
    
    /**
     * @notice 記錄轉帳金額（由 PolicyWrapper 或 PolicyManager 調用）
     * @dev 在交易通過後調用，更新累計額度
     * @param from 發送方地址
     * @param amount 交易金額
     */
    function recordTransfer(
        address from,
        uint256 amount
    ) external {
        // 只記錄非居民的轉帳
        if (!ccidProvider.isNonResident(from)) {
            return;
        }
        
        if (exemptAddresses[from]) {
            return;
        }
        
        uint256 today = block.timestamp / 1 days;
        dailyTransferAmounts[from][today] += amount;
        
        emit TransferRecorded(from, amount, dailyTransferAmounts[from][today], today);
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
        return "FX_LIMIT";
    }
    
    /**
     * @notice 檢查規則是否啟用
     */
    function isEnabled() external view override returns (bool) {
        return _enabled;
    }
    
    // ============ 查詢函數 ============
    
    /**
     * @notice 獲取帳戶今日累計轉出金額
     */
    function getDailyTransferAmount(address account) external view returns (uint256) {
        uint256 today = block.timestamp / 1 days;
        return dailyTransferAmounts[account][today];
    }
    
    /**
     * @notice 獲取帳戶今日剩餘額度
     */
    function getRemainingLimit(address account) external view returns (uint256) {
        // 如果不是非居民，返回無限額度
        if (!ccidProvider.isNonResident(account)) {
            return type(uint256).max;
        }
        
        if (exemptAddresses[account]) {
            return type(uint256).max;
        }
        
        uint256 today = block.timestamp / 1 days;
        uint256 used = dailyTransferAmounts[account][today];
        
        if (used >= dailyLimit) {
            return 0;
        }
        
        return dailyLimit - used;
    }
    
    /**
     * @notice 預覽交易是否會超過限額
     */
    function previewTransfer(
        address from,
        uint256 amount
    ) external view returns (
        bool wouldPass,
        uint256 currentDailyTotal,
        uint256 newTotal,
        uint256 remainingAfter
    ) {
        uint256 today = block.timestamp / 1 days;
        currentDailyTotal = dailyTransferAmounts[from][today];
        newTotal = currentDailyTotal + amount;
        
        // 非 Non-Resident 或豁免地址直接通過
        if (!ccidProvider.isNonResident(from) || exemptAddresses[from]) {
            return (true, currentDailyTotal, newTotal, type(uint256).max);
        }
        
        wouldPass = newTotal <= dailyLimit;
        remainingAfter = wouldPass ? dailyLimit - newTotal : 0;
    }
    
    /**
     * @notice 獲取限額變更歷史記錄數量
     */
    function getLimitHistoryCount() external view returns (uint256) {
        return limitHistory.length;
    }
    
    // ============ 管理函數 ============
    
    /**
     * @notice 設定每日額度上限
     * @dev 僅限 FX_ADMIN_ROLE（央行或授權機構）
     */
    function setDailyLimit(uint256 newLimit) external onlyRole(FX_ADMIN_ROLE) {
        require(newLimit > 0, "Limit must be > 0");
        
        uint256 oldLimit = dailyLimit;
        dailyLimit = newLimit;
        
        // 記錄變更歷史
        limitHistory.push(LimitChange({
            oldLimit: oldLimit,
            newLimit: newLimit,
            timestamp: block.timestamp,
            changedBy: msg.sender
        }));
        
        emit DailyLimitUpdated(oldLimit, newLimit, msg.sender);
    }
    
    /**
     * @notice 設定豁免地址
     */
    function setExemptAddress(
        address account,
        bool exempt
    ) external onlyRole(FX_ADMIN_ROLE) {
        exemptAddresses[account] = exempt;
        emit ExemptAddressSet(account, exempt);
    }
    
    /**
     * @notice 批量設定豁免地址
     */
    function batchSetExemptAddresses(
        address[] calldata accounts,
        bool exempt
    ) external onlyRole(FX_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            exemptAddresses[accounts[i]] = exempt;
            emit ExemptAddressSet(accounts[i], exempt);
        }
    }
    
    /**
     * @notice 更新 CCID Provider
     */
    function updateCCIDProvider(address newProvider) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newProvider != address(0), "Invalid provider");
        address oldProvider = address(ccidProvider);
        ccidProvider = ICCIDProvider(newProvider);
        emit CCIDProviderUpdated(oldProvider, newProvider);
    }
    
    /**
     * @notice 啟用/停用規則
     */
    function setEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _enabled = enabled;
        emit RuleEnabledChanged(enabled);
    }
    
    /**
     * @notice 重置帳戶的每日累計（緊急使用）
     * @dev 僅限 DEFAULT_ADMIN_ROLE，用於異常情況
     */
    function resetDailyAmount(
        address account,
        uint256 day
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        dailyTransferAmounts[account][day] = 0;
    }
}
