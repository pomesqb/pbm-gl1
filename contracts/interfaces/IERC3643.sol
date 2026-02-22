// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC3643
 * @notice ERC-3643 (T-REX) 安全代幣介面
 * @dev Token for Regulated EXchanges - 機構級安全代幣標準
 *      https://eips.ethereum.org/EIPS/eip-3643
 *
 * Asset Layer 角色：
 * - 負責證券發行、配息、凍結、強制轉移
 * - transfer/transferFrom 內建合規前置檢查
 * - 可被 PBM wrap 進 Transaction Layer 用於 Repo 等場景
 */
interface IERC3643 is IERC20 {
    // ============ Events ============

    event UpdatedTokenInformation(
        string _newName,
        string _newSymbol,
        uint8 _newDecimals,
        string _newVersion,
        address _newOnchainID
    );
    event IdentityRegistryAdded(address indexed _identityRegistry);
    event ComplianceAdded(address indexed _compliance);
    event RecoverySuccess(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    );
    event AddressFrozen(
        address indexed _userAddress,
        bool indexed _isFrozen,
        address indexed _owner
    );
    event TokensFrozen(address indexed _userAddress, uint256 _amount);
    event TokensUnfrozen(address indexed _userAddress, uint256 _amount);
    event Paused(address _userAddress);
    event Unpaused(address _userAddress);

    // ============ Getters ============

    /**
     * @notice 取得代幣的鏈上身份合約地址
     */
    function onchainID() external view returns (address);

    /**
     * @notice 取得代幣版本
     */
    function version() external view returns (string memory);

    /**
     * @notice 取得關聯的 Identity Registry
     */
    function identityRegistry() external view returns (address);

    /**
     * @notice 取得關聯的 Compliance 合約
     */
    function compliance() external view returns (address);

    /**
     * @notice 代幣是否處於暫停狀態
     */
    function paused() external view returns (bool);

    /**
     * @notice 檢查地址是否被整個凍結
     */
    function isFrozen(address _userAddress) external view returns (bool);

    /**
     * @notice 取得地址被部分凍結的代幣數量
     */
    function getFrozenTokens(address _userAddress) external view returns (uint256);

    // ============ Setters ============

    /**
     * @notice 設定代幣名稱
     */
    function setName(string calldata _name) external;

    /**
     * @notice 設定代幣符號
     */
    function setSymbol(string calldata _symbol) external;

    /**
     * @notice 設定鏈上身份合約地址
     */
    function setOnchainID(address _onchainID) external;

    /**
     * @notice 暫停所有代幣轉帳
     */
    function pause() external;

    /**
     * @notice 恢復代幣轉帳
     */
    function unpause() external;

    /**
     * @notice 凍結或解凍指定地址（整個錢包）
     * @param _userAddress 目標地址
     * @param _freeze true=凍結, false=解凍
     */
    function setAddressFrozen(address _userAddress, bool _freeze) external;

    /**
     * @notice 凍結指定地址的部分代幣
     * @param _userAddress 目標地址
     * @param _amount 凍結數量
     */
    function freezePartialTokens(address _userAddress, uint256 _amount) external;

    /**
     * @notice 解凍指定地址的部分代幣
     * @param _userAddress 目標地址
     * @param _amount 解凍數量
     */
    function unfreezePartialTokens(address _userAddress, uint256 _amount) external;

    /**
     * @notice 設定 Identity Registry 合約地址
     */
    function setIdentityRegistry(address _identityRegistry) external;

    /**
     * @notice 設定 Compliance 合約地址
     */
    function setCompliance(address _compliance) external;

    // ============ Transfer Actions ============

    /**
     * @notice Agent 強制轉移代幣（用於合規執法或資產回收）
     * @param _from 來源地址
     * @param _to 目標地址
     * @param _amount 轉移數量
     */
    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);

    /**
     * @notice 鑄造新代幣（僅限 Agent）
     * @param _to 接收者地址
     * @param _amount 鑄造數量
     */
    function mint(address _to, uint256 _amount) external;

    /**
     * @notice 銷毀代幣（僅限 Agent）
     * @param _userAddress 目標地址
     * @param _amount 銷毀數量
     */
    function burn(address _userAddress, uint256 _amount) external;

    /**
     * @notice 錢包回復 - 當投資者遺失私鑰時轉移代幣到新地址
     * @param _lostWallet 遺失的錢包地址
     * @param _newWallet 新的錢包地址
     * @param _investorOnchainID 投資者的鏈上身份
     */
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external returns (bool);

    // ============ Batch Functions ============

    function batchTransfer(
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external;

    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external;

    function batchMint(
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external;

    function batchBurn(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external;

    function batchSetAddressFrozen(
        address[] calldata _userAddresses,
        bool[] calldata _freeze
    ) external;

    function batchFreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external;

    function batchUnfreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external;
}
