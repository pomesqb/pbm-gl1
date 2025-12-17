// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IFXRateProvider.sol";

// Chainlink Aggregator Interface
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

/**
 * @title FXRateProvider
 * @notice 外匯匯率提供者 - 整合 Chainlink Price Feeds
 * @dev 支援 TWD/SGD/USD/CNY 等多幣種匯率查詢與轉換
 * 
 * ═══════════════════════════════════════════════════════════════════
 * 使用情境 (StraitsX/Alipay+ 案例)：
 * ═══════════════════════════════════════════════════════════════════
 * 1. 旅客在新加坡用人民幣付款
 * 2. 系統查詢 CNY/SGD 匯率
 * 3. 計算等值 SGD 金額
 * 4. 商家收到 SGD 結算
 * ═══════════════════════════════════════════════════════════════════
 */
contract FXRateProvider is IFXRateProvider, AccessControl {
    bytes32 public constant RATE_ADMIN_ROLE = keccak256("RATE_ADMIN_ROLE");
    
    // 精度常數 (18 位小數)
    uint256 public constant PRECISION = 1e18;
    
    // 匯率過期時間 (預設 1 小時)
    uint256 public stalePeriod = 1 hours;
    
    // 貨幣代碼 → Chainlink Price Feed 地址
    // 注意：Chainlink 通常提供 XXX/USD，我們用 USD 作為中間貨幣
    mapping(bytes32 => address) public currencyPriceFeeds;
    
    // 貨幣代碼 → 是否啟用
    mapping(bytes32 => bool) public currencyEnabled;
    
    // 支援的貨幣列表
    bytes32[] public supportedCurrencies;
    
    // 貨幣代碼常數
    bytes32 public constant USD = keccak256("USD");
    bytes32 public constant SGD = keccak256("SGD");
    bytes32 public constant CNY = keccak256("CNY");
    bytes32 public constant TWD = keccak256("TWD");
    
    // 手動設定的匯率 (當 Chainlink 不可用時的備用)
    mapping(bytes32 => mapping(bytes32 => RateInfo)) public manualRates;
    
    // 是否使用手動匯率
    bool public useManualRates = false;
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RATE_ADMIN_ROLE, msg.sender);
        
        // 預設啟用 USD (作為基準貨幣)
        currencyEnabled[USD] = true;
        supportedCurrencies.push(USD);
    }
    
    /**
     * @notice 添加支援的貨幣及其 Chainlink Price Feed
     * @param currency 貨幣代碼 (如 "SGD")
     * @param priceFeed Chainlink Price Feed 地址 (如 SGD/USD feed)
     */
    function addCurrency(
        bytes32 currency,
        address priceFeed
    ) external onlyRole(RATE_ADMIN_ROLE) {
        require(!currencyEnabled[currency], "Currency already exists");
        require(priceFeed != address(0), "Invalid price feed");
        
        currencyPriceFeeds[currency] = priceFeed;
        currencyEnabled[currency] = true;
        supportedCurrencies.push(currency);
        
        emit CurrencyAdded(currency, priceFeed);
    }
    
    /**
     * @notice 移除貨幣支援
     */
    function removeCurrency(bytes32 currency) external onlyRole(RATE_ADMIN_ROLE) {
        require(currencyEnabled[currency], "Currency not found");
        require(currency != USD, "Cannot remove USD");
        
        currencyEnabled[currency] = false;
        currencyPriceFeeds[currency] = address(0);
        
        // 從列表中移除
        for (uint256 i = 0; i < supportedCurrencies.length; i++) {
            if (supportedCurrencies[i] == currency) {
                supportedCurrencies[i] = supportedCurrencies[supportedCurrencies.length - 1];
                supportedCurrencies.pop();
                break;
            }
        }
        
        emit CurrencyRemoved(currency);
    }
    
    /**
     * @notice 取得兩種貨幣之間的匯率
     * @dev 使用 USD 作為中間貨幣進行交叉匯率計算
     *      例如：CNY/SGD = (CNY/USD) / (SGD/USD)
     */
    function getRate(
        bytes32 baseCurrency,
        bytes32 quoteCurrency
    ) public view override returns (uint256 rate, uint256 timestamp) {
        require(currencyEnabled[baseCurrency], "Base currency not supported");
        require(currencyEnabled[quoteCurrency], "Quote currency not supported");
        
        if (baseCurrency == quoteCurrency) {
            return (PRECISION, block.timestamp);
        }
        
        // 使用手動匯率
        if (useManualRates) {
            RateInfo memory rateInfo = manualRates[baseCurrency][quoteCurrency];
            require(rateInfo.rate > 0, "Rate not set");
            return (rateInfo.rate, rateInfo.timestamp);
        }
        
        // USD 對其他貨幣
        if (baseCurrency == USD) {
            (int256 price, uint256 updatedAt) = _getChainlinkPrice(quoteCurrency);
            // quoteCurrency/USD price, we need USD/quoteCurrency
            rate = (PRECISION * PRECISION) / uint256(price);
            return (rate, updatedAt);
        }
        
        if (quoteCurrency == USD) {
            (int256 price, uint256 updatedAt) = _getChainlinkPrice(baseCurrency);
            return (uint256(price), updatedAt);
        }
        
        // 交叉匯率：baseCurrency/quoteCurrency = (baseCurrency/USD) / (quoteCurrency/USD)
        (int256 basePrice, uint256 baseUpdated) = _getChainlinkPrice(baseCurrency);
        (int256 quotePrice, uint256 quoteUpdated) = _getChainlinkPrice(quoteCurrency);
        
        rate = (uint256(basePrice) * PRECISION) / uint256(quotePrice);
        timestamp = baseUpdated < quoteUpdated ? baseUpdated : quoteUpdated;
        
        return (rate, timestamp);
    }
    
    /**
     * @notice 將金額從一種貨幣轉換為另一種貨幣
     */
    function convert(
        bytes32 fromCurrency,
        bytes32 toCurrency,
        uint256 amount
    ) external view override returns (uint256 convertedAmount, uint256 rateUsed) {
        (rateUsed,) = getRate(fromCurrency, toCurrency);
        convertedAmount = (amount * rateUsed) / PRECISION;
        return (convertedAmount, rateUsed);
    }
    
    /**
     * @notice 檢查匯率是否過期
     */
    function isRateStale(
        bytes32 baseCurrency,
        bytes32 quoteCurrency
    ) external view override returns (bool isStale) {
        (, uint256 timestamp) = getRate(baseCurrency, quoteCurrency);
        return (block.timestamp - timestamp) > stalePeriod;
    }
    
    /**
     * @notice 取得支援的貨幣列表
     */
    function getSupportedCurrencies() external view override returns (bytes32[] memory) {
        return supportedCurrencies;
    }
    
    /**
     * @notice 從 Chainlink 取得價格
     */
    function _getChainlinkPrice(bytes32 currency) internal view returns (int256 price, uint256 updatedAt) {
        address priceFeed = currencyPriceFeeds[currency];
        require(priceFeed != address(0), "Price feed not configured");
        
        AggregatorV3Interface feed = AggregatorV3Interface(priceFeed);
        
        (, price,, updatedAt,) = feed.latestRoundData();
        require(price > 0, "Invalid price");
        
        // 標準化為 18 位小數
        uint8 decimals = feed.decimals();
        if (decimals < 18) {
            price = price * int256(10 ** (18 - decimals));
        } else if (decimals > 18) {
            price = price / int256(10 ** (decimals - 18));
        }
        
        return (price, updatedAt);
    }
    
    // ============ Admin Functions ============
    
    /**
     * @notice 設定手動匯率 (測試或備用)
     */
    function setManualRate(
        bytes32 baseCurrency,
        bytes32 quoteCurrency,
        uint256 rate
    ) external onlyRole(RATE_ADMIN_ROLE) {
        manualRates[baseCurrency][quoteCurrency] = RateInfo({
            rate: rate,
            timestamp: block.timestamp,
            decimals: 18
        });
        
        emit RateUpdated(baseCurrency, quoteCurrency, rate, block.timestamp);
    }
    
    /**
     * @notice 切換手動/Chainlink 匯率模式
     */
    function setUseManualRates(bool _useManualRates) external onlyRole(RATE_ADMIN_ROLE) {
        useManualRates = _useManualRates;
    }
    
    /**
     * @notice 設定匯率過期時間
     */
    function setStalePeriod(uint256 _stalePeriod) external onlyRole(RATE_ADMIN_ROLE) {
        stalePeriod = _stalePeriod;
    }
    
    /**
     * @notice 更新 Price Feed 地址
     */
    function updatePriceFeed(
        bytes32 currency,
        address newPriceFeed
    ) external onlyRole(RATE_ADMIN_ROLE) {
        require(currencyEnabled[currency], "Currency not found");
        require(newPriceFeed != address(0), "Invalid price feed");
        
        currencyPriceFeeds[currency] = newPriceFeed;
    }
}
