// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/ICompliance3643.sol";
import "../interfaces/IIdentityRegistry.sol";

/**
 * @title ComplianceModule
 * @notice ERC-3643 合規模組
 * @dev 實作全局合規規則，由 ERC3643Token 在每次轉帳時調用
 *      支援每國持有人上限、每人持有量上限等規則
 *      整合 IdentityRegistry 進行國家級合規檢查
 */
contract ComplianceModule is ICompliance3643, AccessControl {
    // 綁定的代幣合約地址
    address private _tokenBound;

    // IdentityRegistry 參考
    IIdentityRegistry public identityRegistry;

    // ============ 合規參數 ============

    // 每國最大持有人數（0 = 不限制）
    mapping(uint16 => uint256) public maxHoldersPerCountry;

    // 每人最大持有量（0 = 不限制）
    uint256 public maxTokensPerHolder;

    // ============ 合規統計 ============

    // 每國目前持有人數
    mapping(uint16 => uint256) public countryHolderCount;

    // 每個地址是否為持有者
    mapping(address => bool) public isHolder;

    // 每個地址的持有量（由 transferred/created/destroyed 維護）
    mapping(address => uint256) public holderBalance;

    // ============ Events ============

    event MaxHoldersPerCountrySet(uint16 indexed country, uint256 maxHolders);
    event MaxTokensPerHolderSet(uint256 maxTokens);
    event IdentityRegistryUpdated(address indexed identityRegistry);

    constructor(address _identityRegistry) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        identityRegistry = IIdentityRegistry(_identityRegistry);
    }

    // ============ Token Binding ============

    function bindToken(
        address _token
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_token != address(0), "Invalid token address");
        require(_tokenBound == address(0), "Token already bound");
        _tokenBound = _token;
        emit TokenBound(_token);
    }

    function unbindToken(
        address _token
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_token == _tokenBound, "Token not bound");
        _tokenBound = address(0);
        emit TokenUnbound(_token);
    }

    function isTokenBound(
        address _token
    ) external view override returns (bool) {
        return _token == _tokenBound;
    }

    function getTokenBound() external view override returns (address) {
        return _tokenBound;
    }

    // ============ Compliance Check ============

    /**
     * @notice 檢查轉帳是否符合合規規則
     * @dev 檢查邏輯：
     *      1. 每人持有量上限檢查
     *      2. 每國持有人數上限檢查（新持有人加入時）
     */
    function canTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external view override returns (bool) {
        // 抑制未使用參數警告
        _from;

        // 1. 每人持有量上限檢查
        if (maxTokensPerHolder > 0) {
            uint256 newBalance = holderBalance[_to] + _amount;
            if (newBalance > maxTokensPerHolder) {
                return false;
            }
        }

        // 2. 每國持有人數上限檢查
        if (!isHolder[_to]) {
            uint16 country = identityRegistry.investorCountry(_to);
            uint256 maxHolders = maxHoldersPerCountry[country];
            if (maxHolders > 0 && countryHolderCount[country] >= maxHolders) {
                return false;
            }
        }

        return true;
    }

    // ============ State Updates ============

    /**
     * @notice 轉帳完成後更新合規統計
     */
    function transferred(
        address _from,
        address _to,
        uint256 _amount
    ) external override {
        require(msg.sender == _tokenBound, "Only bound token");

        // 更新發送方
        if (holderBalance[_from] >= _amount) {
            holderBalance[_from] -= _amount;
        } else {
            holderBalance[_from] = 0;
        }

        // 如果發送方餘額歸零，移除持有人狀態
        if (holderBalance[_from] == 0 && isHolder[_from]) {
            isHolder[_from] = false;
            uint16 fromCountry = identityRegistry.investorCountry(_from);
            if (countryHolderCount[fromCountry] > 0) {
                countryHolderCount[fromCountry]--;
            }
        }

        // 更新接收方
        if (!isHolder[_to]) {
            isHolder[_to] = true;
            uint16 toCountry = identityRegistry.investorCountry(_to);
            countryHolderCount[toCountry]++;
        }
        holderBalance[_to] += _amount;
    }

    /**
     * @notice 鑄造後更新合規統計
     */
    function created(address _to, uint256 _amount) external override {
        require(msg.sender == _tokenBound, "Only bound token");

        if (!isHolder[_to]) {
            isHolder[_to] = true;
            uint16 toCountry = identityRegistry.investorCountry(_to);
            countryHolderCount[toCountry]++;
        }
        holderBalance[_to] += _amount;
    }

    /**
     * @notice 銷毀後更新合規統計
     */
    function destroyed(address _from, uint256 _amount) external override {
        require(msg.sender == _tokenBound, "Only bound token");

        if (holderBalance[_from] >= _amount) {
            holderBalance[_from] -= _amount;
        } else {
            holderBalance[_from] = 0;
        }

        if (holderBalance[_from] == 0 && isHolder[_from]) {
            isHolder[_from] = false;
            uint16 fromCountry = identityRegistry.investorCountry(_from);
            if (countryHolderCount[fromCountry] > 0) {
                countryHolderCount[fromCountry]--;
            }
        }
    }

    // ============ Admin Functions ============

    /**
     * @notice 設定每國最大持有人數
     * @param _country ISO-3166 國家代碼
     * @param _maxHolders 最大持有人數（0 = 不限制）
     */
    function setMaxHoldersPerCountry(
        uint16 _country,
        uint256 _maxHolders
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxHoldersPerCountry[_country] = _maxHolders;
        emit MaxHoldersPerCountrySet(_country, _maxHolders);
    }

    /**
     * @notice 設定每人最大持有量
     * @param _maxTokens 最大持有量（0 = 不限制）
     */
    function setMaxTokensPerHolder(
        uint256 _maxTokens
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxTokensPerHolder = _maxTokens;
        emit MaxTokensPerHolderSet(_maxTokens);
    }

    /**
     * @notice 更新 IdentityRegistry 地址
     */
    function setIdentityRegistry(
        address _identityRegistry
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_identityRegistry != address(0), "Invalid address");
        identityRegistry = IIdentityRegistry(_identityRegistry);
        emit IdentityRegistryUpdated(_identityRegistry);
    }
}
