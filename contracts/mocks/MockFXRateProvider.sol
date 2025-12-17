// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IFXRateProvider.sol";

/**
 * @title MockFXRateProvider
 * @notice 測試用匯率提供者
 * @dev 提供預設匯率，方便單元測試
 */
contract MockFXRateProvider is IFXRateProvider {
    
    uint256 public constant PRECISION = 1e18;
    
    // 貨幣對 → 匯率
    mapping(bytes32 => mapping(bytes32 => uint256)) public rates;
    
    // 支援的貨幣
    bytes32[] public currencies;
    mapping(bytes32 => bool) public currencyExists;
    
    // 貨幣代碼
    bytes32 public constant USD = keccak256("USD");
    bytes32 public constant SGD = keccak256("SGD");
    bytes32 public constant CNY = keccak256("CNY");
    bytes32 public constant TWD = keccak256("TWD");
    
    constructor() {
        // 初始化預設貨幣
        _addCurrency(USD);
        _addCurrency(SGD);
        _addCurrency(CNY);
        _addCurrency(TWD);
        
        // 設定預設匯率 (以 18 位小數表示)
        // 假設匯率：
        // 1 USD = 1.35 SGD
        // 1 USD = 7.25 CNY
        // 1 USD = 32.0 TWD
        
        // USD 對其他貨幣
        rates[USD][SGD] = 1.35e18;  // 1 USD = 1.35 SGD
        rates[USD][CNY] = 7.25e18;  // 1 USD = 7.25 CNY
        rates[USD][TWD] = 32e18;    // 1 USD = 32 TWD
        rates[USD][USD] = 1e18;
        
        // SGD 對其他貨幣
        rates[SGD][USD] = 0.741e18;    // 1 SGD = 0.741 USD (1/1.35)
        rates[SGD][CNY] = 5.37e18;     // 1 SGD = 5.37 CNY (7.25/1.35)
        rates[SGD][TWD] = 23.70e18;    // 1 SGD = 23.70 TWD (32/1.35)
        rates[SGD][SGD] = 1e18;
        
        // CNY 對其他貨幣
        rates[CNY][USD] = 0.138e18;    // 1 CNY = 0.138 USD (1/7.25)
        rates[CNY][SGD] = 0.186e18;    // 1 CNY = 0.186 SGD (1.35/7.25)
        rates[CNY][TWD] = 4.41e18;     // 1 CNY = 4.41 TWD (32/7.25)
        rates[CNY][CNY] = 1e18;
        
        // TWD 對其他貨幣
        rates[TWD][USD] = 0.03125e18;  // 1 TWD = 0.03125 USD (1/32)
        rates[TWD][SGD] = 0.0422e18;   // 1 TWD = 0.0422 SGD (1.35/32)
        rates[TWD][CNY] = 0.227e18;    // 1 TWD = 0.227 CNY (7.25/32)
        rates[TWD][TWD] = 1e18;
    }
    
    function _addCurrency(bytes32 currency) internal {
        if (!currencyExists[currency]) {
            currencies.push(currency);
            currencyExists[currency] = true;
        }
    }
    
    /**
     * @notice 取得匯率
     */
    function getRate(
        bytes32 baseCurrency,
        bytes32 quoteCurrency
    ) external view override returns (uint256 rate, uint256 timestamp) {
        rate = rates[baseCurrency][quoteCurrency];
        require(rate > 0, "Rate not set");
        return (rate, block.timestamp);
    }
    
    /**
     * @notice 轉換金額
     */
    function convert(
        bytes32 fromCurrency,
        bytes32 toCurrency,
        uint256 amount
    ) external view override returns (uint256 convertedAmount, uint256 rateUsed) {
        rateUsed = rates[fromCurrency][toCurrency];
        require(rateUsed > 0, "Rate not set");
        convertedAmount = (amount * rateUsed) / PRECISION;
        return (convertedAmount, rateUsed);
    }
    
    /**
     * @notice 匯率是否過期 (Mock 永不過期)
     */
    function isRateStale(
        bytes32,
        bytes32
    ) external pure override returns (bool) {
        return false;
    }
    
    /**
     * @notice 取得支援的貨幣列表
     */
    function getSupportedCurrencies() external view override returns (bytes32[] memory) {
        return currencies;
    }
    
    /**
     * @notice 設定匯率 (測試用)
     */
    function setRate(
        bytes32 baseCurrency,
        bytes32 quoteCurrency,
        uint256 rate
    ) external {
        if (!currencyExists[baseCurrency]) {
            _addCurrency(baseCurrency);
        }
        if (!currencyExists[quoteCurrency]) {
            _addCurrency(quoteCurrency);
        }
        
        rates[baseCurrency][quoteCurrency] = rate;
        emit RateUpdated(baseCurrency, quoteCurrency, rate, block.timestamp);
    }
}
