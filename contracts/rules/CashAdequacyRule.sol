// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IComplianceRule.sol";

/**
 * @title CashAdequacyRule
 * @notice 現金充足性規則 - 驗證 Lender 是否有足夠現金
 * @dev 實作 GL1 Repo 範例中的 Cash Adequacy 檢查
 * 
 * 使用場景：
 * - Repo 交易中驗證 Lender 帳戶餘額是否足夠
 * - 確保 Lender 有能力提供所需現金
 */
contract CashAdequacyRule is IComplianceRule, AccessControl {
    bytes32 public constant CASH_ADMIN_ROLE = keccak256("CASH_ADMIN_ROLE");
    
    // 規則標識符
    bytes32 public constant RULE_ID = keccak256("CASH_ADEQUACY_RULE");
    
    // 規則是否啟用
    bool private _enabled = true;
    
    // 允許的現金資產 (穩定幣等)
    mapping(address => bool) public allowedCashAssets;
    
    // 當前檢查的上下文
    struct CheckContext {
        address cashAsset;      // 現金資產地址
        uint256 requiredAmount; // 所需金額
    }
    
    // 每個地址的檢查上下文
    mapping(address => CheckContext) public checkContexts;
    
    event CashAssetAdded(address indexed asset);
    event CashAssetRemoved(address indexed asset);
    event RuleEnabledChanged(bool enabled);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CASH_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @notice 檢查交易是否符合現金充足性規則
     * @dev 須先調用 setCheckContext 設定檢查上下文
     * @param from 發送方地址 (Lender)
     * @param to 接收方地址 (不使用)
     * @param amount 交易金額 (不使用，使用 context 中的值)
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
        amount;
        
        // 如果規則未啟用，直接通過
        if (!_enabled) {
            return (true, "");
        }
        
        CheckContext memory ctx = checkContexts[from];
        
        // 如果沒有設定上下文，直接通過
        if (ctx.cashAsset == address(0)) {
            return (true, "");
        }
        
        // 檢查現金資產是否在白名單中
        if (!allowedCashAssets[ctx.cashAsset]) {
            return (false, "Cash asset not allowed");
        }
        
        // 檢查餘額是否足夠
        uint256 balance = IERC20(ctx.cashAsset).balanceOf(from);
        
        if (balance < ctx.requiredAmount) {
            return (false, "Insufficient cash balance");
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
        return "CASH_ADEQUACY";
    }
    
    /**
     * @notice 檢查規則是否啟用
     */
    function isEnabled() external view override returns (bool) {
        return _enabled;
    }
    
    // ============ 上下文管理 ============
    
    /**
     * @notice 設定檢查上下文
     * @dev 由 RepoContract 在驗證前調用
     */
    function setCheckContext(
        address lender,
        address cashAsset,
        uint256 requiredAmount
    ) external {
        checkContexts[lender] = CheckContext({
            cashAsset: cashAsset,
            requiredAmount: requiredAmount
        });
    }
    
    /**
     * @notice 清除檢查上下文
     */
    function clearCheckContext(address lender) external {
        delete checkContexts[lender];
    }
    
    // ============ 管理函數 ============
    
    /**
     * @notice 新增允許的現金資產
     */
    function addCashAsset(address asset) external onlyRole(CASH_ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        allowedCashAssets[asset] = true;
        emit CashAssetAdded(asset);
    }
    
    /**
     * @notice 移除現金資產
     */
    function removeCashAsset(address asset) external onlyRole(CASH_ADMIN_ROLE) {
        allowedCashAssets[asset] = false;
        emit CashAssetRemoved(asset);
    }
    
    /**
     * @notice 批量新增現金資產
     */
    function batchAddCashAssets(address[] calldata assets) external onlyRole(CASH_ADMIN_ROLE) {
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] != address(0)) {
                allowedCashAssets[assets[i]] = true;
                emit CashAssetAdded(assets[i]);
            }
        }
    }
    
    /**
     * @notice 啟用/停用規則
     */
    function setEnabled(bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _enabled = enabled;
        emit RuleEnabledChanged(enabled);
    }
    
    // ============ 查詢函數 ============
    
    /**
     * @notice 檢查現金是否充足
     */
    function isCashAdequate(
        address lender,
        address cashAsset,
        uint256 requiredAmount
    ) external view returns (bool adequate, uint256 currentBalance, uint256 shortfall) {
        currentBalance = IERC20(cashAsset).balanceOf(lender);
        
        if (currentBalance >= requiredAmount) {
            adequate = true;
            shortfall = 0;
        } else {
            adequate = false;
            shortfall = requiredAmount - currentBalance;
        }
    }
    
    /**
     * @notice 檢查資產是否為允許的現金資產
     */
    function isCashAssetAllowed(address asset) external view returns (bool) {
        return allowedCashAssets[asset];
    }
}
