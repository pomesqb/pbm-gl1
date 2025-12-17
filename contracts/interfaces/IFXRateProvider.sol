// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IFXRateProvider
 * @notice 外匯匯率提供者介面 - 支援跨境支付的即時匯率轉換
 * @dev 整合 Chainlink Price Feeds 提供 TWD/SGD/USD/CNY 等多幣種支援
 */
interface IFXRateProvider {
    
    /// @notice 匯率資訊結構
    struct RateInfo {
        uint256 rate;           // 匯率（18 位小數）
        uint256 timestamp;      // 更新時間
        uint8 decimals;         // 匯率小數位數
    }
    
    /**
     * @notice 取得兩種貨幣之間的匯率
     * @param baseCurrency 基礎貨幣代碼 (例如 "CNY", "TWD")
     * @param quoteCurrency 報價貨幣代碼 (例如 "SGD", "USD")
     * @return rate 匯率（18 位小數）
     * @return timestamp 匯率更新時間
     */
    function getRate(
        bytes32 baseCurrency,
        bytes32 quoteCurrency
    ) external view returns (uint256 rate, uint256 timestamp);
    
    /**
     * @notice 將金額從一種貨幣轉換為另一種貨幣
     * @param fromCurrency 來源貨幣代碼
     * @param toCurrency 目標貨幣代碼
     * @param amount 來源金額
     * @return convertedAmount 轉換後金額
     * @return rateUsed 使用的匯率
     */
    function convert(
        bytes32 fromCurrency,
        bytes32 toCurrency,
        uint256 amount
    ) external view returns (uint256 convertedAmount, uint256 rateUsed);
    
    /**
     * @notice 檢查匯率是否過期
     * @param baseCurrency 基礎貨幣代碼
     * @param quoteCurrency 報價貨幣代碼
     * @return isStale 是否過期
     */
    function isRateStale(
        bytes32 baseCurrency,
        bytes32 quoteCurrency
    ) external view returns (bool isStale);
    
    /**
     * @notice 取得支援的貨幣列表
     * @return currencies 貨幣代碼陣列
     */
    function getSupportedCurrencies() external view returns (bytes32[] memory currencies);
    
    // Events
    event RateUpdated(
        bytes32 indexed baseCurrency,
        bytes32 indexed quoteCurrency,
        uint256 rate,
        uint256 timestamp
    );
    
    event CurrencyAdded(bytes32 indexed currency, address indexed priceFeed);
    event CurrencyRemoved(bytes32 indexed currency);
}
