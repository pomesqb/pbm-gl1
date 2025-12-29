// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IComplianceRule.sol";

/**
 * @title AMLThresholdRule
 * @notice AML 大額交易申報規則 - 偵測並記錄需申報的大額交易
 * @dev 實作「檢查 C：該筆交易是否符合洗錢防制（AML）的大額申報標準」
 * 
 * ═══════════════════════════════════════════════════════════════════
 * 使用場景：
 * ═══════════════════════════════════════════════════════════════════
 * 1. 單筆交易超過大額門檻 → 產生申報記錄事件
 * 2. 24 小時內累計小額交易超過門檻 → 偵測「拆分交易 (Structuring)」
 * 
 * 注意：此規則「不阻擋」交易，而是記錄並發送事件供鏈下監管系統處理。
 * 如需阻擋可疑交易，應搭配額外的審核流程。
 * ═══════════════════════════════════════════════════════════════════
 */
contract AMLThresholdRule is IComplianceRule, AccessControl {
    bytes32 public constant AML_OFFICER_ROLE = keccak256("AML_OFFICER_ROLE");
    
    // 規則標識符
    bytes32 public constant RULE_ID = keccak256("AML_THRESHOLD_RULE");
    
    // 規則是否啟用
    bool private _enabled = true;
    
    // 大額交易門檻 (18 decimals)
    // 預設：等值 TWD 50 萬 (符合台灣洗錢防制法規)
    uint256 public largeTransactionThreshold = 500_000 * 1e18;
    
    // 累計交易門檻（用於偵測拆分交易）
    uint256 public structuringThreshold = 500_000 * 1e18;
    
    // 累計計算時間窗口（預設 24 小時）
    uint256 public structuringWindow = 24 hours;
    
    // 累計交易次數門檻（多次小額可能是拆分）
    uint256 public structuringTxCountThreshold = 5;
    
    // 是否阻擋可疑交易（預設為 false，僅記錄不阻擋）
    bool public blockSuspiciousTransactions = false;
    
    // 申報記錄結構
    struct AMLReport {
        bytes32 reportId;
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
        ReportType reportType;
        bool reviewed;
        bool flagged;
        string notes;
    }
    
    enum ReportType {
        LARGE_TRANSACTION,      // 大額交易
        STRUCTURING_SUSPECTED,  // 疑似拆分交易
        MANUAL_FLAG            // 手動標記
    }
    
    // 申報記錄儲存
    mapping(bytes32 => AMLReport) public reports;
    bytes32[] public reportIds;
    
    // 累計交易追蹤
    struct CumulativeTracker {
        uint256 totalAmount;           // 時間窗口內累計金額
        uint256 transactionCount;      // 時間窗口內交易次數
        uint256 windowStart;           // 時間窗口開始時間
    }
    mapping(address => CumulativeTracker) public cumulativeTrackers;
    
    // 帳戶標記（被標記的帳戶需要額外審查）
    mapping(address => bool) public flaggedAccounts;
    
    // 事件
    event LargeTransactionDetected(
        bytes32 indexed reportId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    
    event StructuringDetected(
        bytes32 indexed reportId,
        address indexed from,
        uint256 cumulativeAmount,
        uint256 transactionCount,
        uint256 windowStart,
        uint256 windowEnd
    );
    
    event ReportReviewed(
        bytes32 indexed reportId,
        address indexed reviewer,
        bool flagged,
        string notes
    );
    
    event AccountFlagged(address indexed account, bool flagged, address indexed flaggedBy);
    event ThresholdUpdated(string thresholdType, uint256 oldValue, uint256 newValue);
    event RuleEnabledChanged(bool enabled);
    event BlockModeChanged(bool blockMode);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AML_OFFICER_ROLE, msg.sender);
    }
    
    /**
     * @notice 檢查交易是否符合 AML 規則
     * @dev 主要功能是記錄申報，預設不阻擋交易
     * @param from 發送方地址
     * @param to 接收方地址
     * @param amount 交易金額
     * @return passed 是否通過規則檢查
     * @return error 錯誤訊息
     */
    function checkCompliance(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool passed, string memory error) {
        // 如果規則未啟用，直接通過
        if (!_enabled) {
            return (true, "");
        }
        
        bool isSuspicious = false;
        
        // 1. 檢查是否為大額交易
        if (amount >= largeTransactionThreshold) {
            bytes32 reportId = _generateReportId(from, to, amount);
            _createReport(reportId, from, to, amount, ReportType.LARGE_TRANSACTION);
            
            emit LargeTransactionDetected(reportId, from, to, amount, block.timestamp);
            isSuspicious = true;
        }
        
        // 2. 檢查是否有拆分交易嫌疑
        bool structuringDetected = _checkAndUpdateCumulative(from, to, amount);
        if (structuringDetected) {
            isSuspicious = true;
        }
        
        // 3. 如果帳戶已被標記，視為可疑
        if (flaggedAccounts[from]) {
            isSuspicious = true;
        }
        
        // 4. 根據阻擋模式決定是否拒絕交易
        if (isSuspicious && blockSuspiciousTransactions) {
            return (false, "AML_REVIEW_REQUIRED");
        }
        
        return (true, "");
    }
    
    /**
     * @notice 檢查並更新累計交易追蹤
     */
    function _checkAndUpdateCumulative(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool structuringDetected) {
        CumulativeTracker storage tracker = cumulativeTrackers[from];
        
        // 如果時間窗口已過期，重置追蹤器
        if (block.timestamp > tracker.windowStart + structuringWindow) {
            tracker.totalAmount = 0;
            tracker.transactionCount = 0;
            tracker.windowStart = block.timestamp;
        }
        
        // 更新累計
        tracker.totalAmount += amount;
        tracker.transactionCount += 1;
        
        // 檢查是否觸發拆分交易警報
        // 條件：累計金額超過門檻 且 交易次數超過閾值 且 單筆金額小於大額門檻
        if (
            tracker.totalAmount >= structuringThreshold &&
            tracker.transactionCount >= structuringTxCountThreshold &&
            amount < largeTransactionThreshold
        ) {
            bytes32 reportId = _generateReportId(from, to, amount);
            _createReport(reportId, from, to, tracker.totalAmount, ReportType.STRUCTURING_SUSPECTED);
            
            emit StructuringDetected(
                reportId,
                from,
                tracker.totalAmount,
                tracker.transactionCount,
                tracker.windowStart,
                block.timestamp
            );
            
            return true;
        }
        
        return false;
    }
    
    /**
     * @notice 產生申報 ID
     */
    function _generateReportId(
        address from,
        address to,
        uint256 amount
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(from, to, amount, block.timestamp, block.number));
    }
    
    /**
     * @notice 建立申報記錄
     */
    function _createReport(
        bytes32 reportId,
        address from,
        address to,
        uint256 amount,
        ReportType reportType
    ) internal {
        reports[reportId] = AMLReport({
            reportId: reportId,
            from: from,
            to: to,
            amount: amount,
            timestamp: block.timestamp,
            reportType: reportType,
            reviewed: false,
            flagged: false,
            notes: ""
        });
        
        reportIds.push(reportId);
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
        return "AML_THRESHOLD";
    }
    
    /**
     * @notice 檢查規則是否啟用
     */
    function isEnabled() external view override returns (bool) {
        return _enabled;
    }
    
    // ============ AML 審查函數 ============
    
    /**
     * @notice 審查申報記錄
     * @dev 僅限 AML_OFFICER_ROLE
     */
    function reviewReport(
        bytes32 reportId,
        bool flagged,
        string calldata notes
    ) external onlyRole(AML_OFFICER_ROLE) {
        AMLReport storage report = reports[reportId];
        require(report.timestamp > 0, "Report not found");
        
        report.reviewed = true;
        report.flagged = flagged;
        report.notes = notes;
        
        // 如果標記為可疑，同時標記發送方帳戶
        if (flagged) {
            flaggedAccounts[report.from] = true;
            emit AccountFlagged(report.from, true, msg.sender);
        }
        
        emit ReportReviewed(reportId, msg.sender, flagged, notes);
    }
    
    /**
     * @notice 手動標記帳戶
     */
    function flagAccount(
        address account,
        bool flagged
    ) external onlyRole(AML_OFFICER_ROLE) {
        flaggedAccounts[account] = flagged;
        emit AccountFlagged(account, flagged, msg.sender);
    }
    
    /**
     * @notice 手動建立申報記錄
     */
    function createManualReport(
        address from,
        address to,
        uint256 amount,
        string calldata notes
    ) external onlyRole(AML_OFFICER_ROLE) returns (bytes32 reportId) {
        reportId = _generateReportId(from, to, amount);
        
        reports[reportId] = AMLReport({
            reportId: reportId,
            from: from,
            to: to,
            amount: amount,
            timestamp: block.timestamp,
            reportType: ReportType.MANUAL_FLAG,
            reviewed: true,
            flagged: true,
            notes: notes
        });
        
        reportIds.push(reportId);
        
        return reportId;
    }
    
    // ============ 查詢函數 ============
    
    /**
     * @notice 獲取申報記錄總數
     */
    function getReportCount() external view returns (uint256) {
        return reportIds.length;
    }
    
    /**
     * @notice 獲取申報記錄
     */
    function getReport(bytes32 reportId) external view returns (AMLReport memory) {
        return reports[reportId];
    }
    
    /**
     * @notice 分頁獲取申報記錄 ID
     */
    function getReportIds(
        uint256 offset,
        uint256 limit
    ) external view returns (bytes32[] memory) {
        uint256 total = reportIds.length;
        
        if (offset >= total) {
            return new bytes32[](0);
        }
        
        uint256 end = offset + limit;
        if (end > total) {
            end = total;
        }
        
        bytes32[] memory result = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = reportIds[i];
        }
        
        return result;
    }
    
    /**
     * @notice 獲取帳戶的累計交易資訊
     */
    function getCumulativeInfo(address account) external view returns (
        uint256 totalAmount,
        uint256 transactionCount,
        uint256 windowStart,
        bool isWindowActive
    ) {
        CumulativeTracker memory tracker = cumulativeTrackers[account];
        totalAmount = tracker.totalAmount;
        transactionCount = tracker.transactionCount;
        windowStart = tracker.windowStart;
        isWindowActive = block.timestamp <= tracker.windowStart + structuringWindow;
    }
    
    /**
     * @notice 檢查帳戶是否被標記
     */
    function isAccountFlagged(address account) external view returns (bool) {
        return flaggedAccounts[account];
    }
    
    // ============ 管理函數 ============
    
    /**
     * @notice 設定大額交易門檻
     */
    function setLargeTransactionThreshold(
        uint256 newThreshold
    ) external onlyRole(AML_OFFICER_ROLE) {
        require(newThreshold > 0, "Threshold must be > 0");
        uint256 oldThreshold = largeTransactionThreshold;
        largeTransactionThreshold = newThreshold;
        emit ThresholdUpdated("LARGE_TRANSACTION", oldThreshold, newThreshold);
    }
    
    /**
     * @notice 設定拆分交易門檻
     */
    function setStructuringThreshold(
        uint256 newThreshold
    ) external onlyRole(AML_OFFICER_ROLE) {
        require(newThreshold > 0, "Threshold must be > 0");
        uint256 oldThreshold = structuringThreshold;
        structuringThreshold = newThreshold;
        emit ThresholdUpdated("STRUCTURING", oldThreshold, newThreshold);
    }
    
    /**
     * @notice 設定拆分交易時間窗口
     */
    function setStructuringWindow(
        uint256 newWindow
    ) external onlyRole(AML_OFFICER_ROLE) {
        require(newWindow >= 1 hours, "Window too short");
        require(newWindow <= 7 days, "Window too long");
        uint256 oldWindow = structuringWindow;
        structuringWindow = newWindow;
        emit ThresholdUpdated("STRUCTURING_WINDOW", oldWindow, newWindow);
    }
    
    /**
     * @notice 設定拆分交易次數門檻
     */
    function setStructuringTxCountThreshold(
        uint256 newCount
    ) external onlyRole(AML_OFFICER_ROLE) {
        require(newCount >= 2, "Count too low");
        uint256 oldCount = structuringTxCountThreshold;
        structuringTxCountThreshold = newCount;
        emit ThresholdUpdated("STRUCTURING_TX_COUNT", oldCount, newCount);
    }
    
    /**
     * @notice 設定是否阻擋可疑交易
     */
    function setBlockSuspiciousTransactions(
        bool blockMode
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        blockSuspiciousTransactions = blockMode;
        emit BlockModeChanged(blockMode);
    }
    
    /**
     * @notice 啟用/停用規則
     */
    function setEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _enabled = enabled;
        emit RuleEnabledChanged(enabled);
    }
}
