// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IComplianceRule.sol";

/**
 * @title CollateralRule
 * @notice 抵押品驗證規則 - 驗證抵押品價值是否足夠
 * @dev 實作 GL1 Repo 範例中的 Collateral Sufficiency 檢查
 * 
 * 使用場景：
 * - Repo 交易中驗證 Borrower 提供的抵押品價值
 * - 確保抵押率 (LTV) 符合要求
 */
contract CollateralRule is IComplianceRule, AccessControl {
    bytes32 public constant COLLATERAL_ADMIN_ROLE = keccak256("COLLATERAL_ADMIN_ROLE");
    
    // 規則標識符
    bytes32 public constant RULE_ID = keccak256("COLLATERAL_RULE");
    
    // 規則是否啟用
    bool private _enabled = true;
    
    // 最低抵押率 (basis points, 15000 = 150%)
    uint256 public minCollateralRatio;
    
    // 允許的抵押品資產白名單
    mapping(address => bool) public allowedCollaterals;
    
    // 抵押品價格預言機 (簡化版：管理員設定價格)
    // 實際生產環境應使用 Chainlink 等預言機
    mapping(address => uint256) public collateralPrices; // 18 decimals
    
    // 當前檢查的上下文
    struct CheckContext {
        address collateralAsset;    // 抵押品資產地址
        uint256 collateralAmount;   // 抵押品數量
        uint256 loanAmount;         // 貸款金額
    }
    
    // 每個地址的檢查上下文
    mapping(address => CheckContext) public checkContexts;
    
    event CollateralAdded(address indexed asset, uint256 price);
    event CollateralRemoved(address indexed asset);
    event CollateralPriceUpdated(address indexed asset, uint256 oldPrice, uint256 newPrice);
    event MinCollateralRatioUpdated(uint256 oldRatio, uint256 newRatio);
    event RuleEnabledChanged(bool enabled);
    
    constructor(uint256 _minCollateralRatio) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COLLATERAL_ADMIN_ROLE, msg.sender);
        
        minCollateralRatio = _minCollateralRatio;
    }
    
    /**
     * @notice 檢查交易是否符合抵押品規則
     * @dev 須先調用 setCheckContext 設定檢查上下文
     * @param from 發送方地址 (Borrower)
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
        
        // 如果沒有設定上下文，直接通過（由其他地方驗證）
        if (ctx.collateralAsset == address(0)) {
            return (true, "");
        }
        
        // 檢查抵押品是否在白名單中
        if (!allowedCollaterals[ctx.collateralAsset]) {
            return (false, "Collateral asset not allowed");
        }
        
        // 計算抵押品價值
        uint256 collateralPrice = collateralPrices[ctx.collateralAsset];
        if (collateralPrice == 0) {
            return (false, "Collateral price not set");
        }
        
        // collateralValue = collateralAmount * price / 1e18
        uint256 collateralValue = (ctx.collateralAmount * collateralPrice) / 1e18;
        
        // 計算所需最低抵押品價值
        // requiredValue = loanAmount * minCollateralRatio / 10000
        uint256 requiredValue = (ctx.loanAmount * minCollateralRatio) / 10000;
        
        if (collateralValue < requiredValue) {
            return (false, "Insufficient collateral value");
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
        return "COLLATERAL";
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
        address borrower,
        address collateralAsset,
        uint256 collateralAmount,
        uint256 loanAmount
    ) external {
        checkContexts[borrower] = CheckContext({
            collateralAsset: collateralAsset,
            collateralAmount: collateralAmount,
            loanAmount: loanAmount
        });
    }
    
    /**
     * @notice 清除檢查上下文
     */
    function clearCheckContext(address borrower) external {
        delete checkContexts[borrower];
    }
    
    // ============ 管理函數 ============
    
    /**
     * @notice 新增允許的抵押品
     */
    function addCollateral(
        address asset,
        uint256 price
    ) external onlyRole(COLLATERAL_ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        require(price > 0, "Price must be > 0");
        
        allowedCollaterals[asset] = true;
        collateralPrices[asset] = price;
        
        emit CollateralAdded(asset, price);
    }
    
    /**
     * @notice 移除抵押品
     */
    function removeCollateral(address asset) external onlyRole(COLLATERAL_ADMIN_ROLE) {
        allowedCollaterals[asset] = false;
        emit CollateralRemoved(asset);
    }
    
    /**
     * @notice 更新抵押品價格
     */
    function updateCollateralPrice(
        address asset,
        uint256 newPrice
    ) external onlyRole(COLLATERAL_ADMIN_ROLE) {
        require(allowedCollaterals[asset], "Collateral not allowed");
        require(newPrice > 0, "Price must be > 0");
        
        uint256 oldPrice = collateralPrices[asset];
        collateralPrices[asset] = newPrice;
        
        emit CollateralPriceUpdated(asset, oldPrice, newPrice);
    }
    
    /**
     * @notice 設定最低抵押率
     */
    function setMinCollateralRatio(uint256 newRatio) external onlyRole(COLLATERAL_ADMIN_ROLE) {
        require(newRatio >= 10000, "Ratio must be >= 100%");
        
        uint256 oldRatio = minCollateralRatio;
        minCollateralRatio = newRatio;
        
        emit MinCollateralRatioUpdated(oldRatio, newRatio);
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
     * @notice 計算當前抵押率
     * @return ratio 抵押率 (basis points)
     */
    function calculateCollateralRatio(
        address collateralAsset,
        uint256 collateralAmount,
        uint256 loanAmount
    ) external view returns (uint256 ratio) {
        if (loanAmount == 0) {
            return type(uint256).max;
        }
        
        uint256 price = collateralPrices[collateralAsset];
        if (price == 0) {
            return 0;
        }
        
        uint256 collateralValue = (collateralAmount * price) / 1e18;
        ratio = (collateralValue * 10000) / loanAmount;
    }
    
    /**
     * @notice 檢查抵押品是否充足
     */
    function isCollateralSufficient(
        address collateralAsset,
        uint256 collateralAmount,
        uint256 loanAmount
    ) external view returns (bool sufficient, uint256 currentRatio, uint256 requiredRatio) {
        requiredRatio = minCollateralRatio;
        
        uint256 price = collateralPrices[collateralAsset];
        if (price == 0 || loanAmount == 0) {
            return (false, 0, requiredRatio);
        }
        
        uint256 collateralValue = (collateralAmount * price) / 1e18;
        currentRatio = (collateralValue * 10000) / loanAmount;
        sufficient = currentRatio >= requiredRatio;
    }
}
