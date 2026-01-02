// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title IERC7943MultiToken
 * @notice ERC-7943 介面 - 針對 ERC-1155 代幣的 RWA 合規標準
 * @dev Universal Real World Asset Interface for multi-token implementations
 *      https://eips.ethereum.org/EIPS/eip-7943
 */
interface IERC7943MultiToken is IERC165 {
    // ============ Events ============

    /**
     * @notice 當代幣被強制從一個地址轉移到另一個地址時發出
     * @param from 代幣被取走的地址
     * @param to 代幣被轉入的地址
     * @param tokenId 被轉移的代幣 ID
     * @param amount 被轉移的數量
     */
    event ForcedTransfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        uint256 amount
    );

    /**
     * @notice 當調用 setFrozenTokens 時發出，表示帳戶的凍結代幣數量已變更
     * @param account 代幣被凍結的帳戶地址
     * @param tokenId 被凍結的代幣 ID
     * @param amount 凍結後的代幣數量
     */
    event Frozen(
        address indexed account,
        uint256 indexed tokenId,
        uint256 amount
    );

    // ============ Errors ============

    /**
     * @notice 當帳戶不允許進行交易時拋出
     * @param account 不允許交易的帳戶地址
     */
    error ERC7943CannotTransact(address account);

    /**
     * @notice 當根據內部規則不允許轉帳時拋出
     * @param from 發送代幣的地址
     * @param to 接收代幣的地址
     * @param tokenId 被發送的代幣 ID
     * @param amount 發送的數量
     */
    error ERC7943CannotTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    );

    /**
     * @notice 當轉帳數量超過未凍結餘額時拋出
     * @param account 持有代幣的地址
     * @param tokenId 被轉移的代幣 ID
     * @param amount 嘗試轉移的數量
     * @param unfrozen 可用於轉移的未凍結數量
     */
    error ERC7943InsufficientUnfrozenBalance(
        address account,
        uint256 tokenId,
        uint256 amount,
        uint256 unfrozen
    );

    // ============ Functions ============

    /**
     * @notice 強制將代幣從一個地址轉移到另一個地址
     * @dev 需要特定授權。用於監管合規或資產回收場景
     * @param from 代幣被取走的地址
     * @param to 代幣接收的地址
     * @param tokenId 被轉移的代幣 ID
     * @param amount 強制轉移的數量
     * @return result 如果轉移成功執行返回 true，否則返回 false
     */
    function forcedTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external returns (bool result);

    /**
     * @notice 變更帳戶特定代幣的凍結數量
     * @dev 需要特定授權。被凍結的代幣無法被帳戶轉移
     *      此函數覆寫當前值，類似於 approve 函數
     *      凍結數量可以大於帳戶餘額，用於預先凍結未來可能收到的代幣
     * @param account 代幣被凍結的帳戶地址
     * @param tokenId 要凍結的代幣 ID
     * @param amount 要凍結的代幣數量
     * @return result 如果凍結成功執行返回 true，否則返回 false
     */
    function setFrozenTokens(
        address account,
        uint256 tokenId,
        uint256 amount
    ) external returns (bool result);

    /**
     * @notice 檢查特定帳戶是否允許進行交易
     * @dev 通常用於白名單/KYC/KYB/AML 檢查
     * @param account 要檢查的地址
     * @return allowed 如果帳戶被允許返回 true，否則返回 false
     */
    function canTransact(address account) external view returns (bool allowed);

    /**
     * @notice 檢查特定代幣的凍結狀態/數量
     * @dev 可能返回超過帳戶餘額的數量
     * @param account 帳戶地址
     * @param tokenId 代幣 ID
     * @return amount 該帳戶當前被凍結的代幣數量
     */
    function getFrozenTokens(
        address account,
        uint256 tokenId
    ) external view returns (uint256 amount);

    /**
     * @notice 檢查根據代幣規則當前是否允許轉帳
     * @dev 可能涉及白名單、黑名單、轉帳限額等策略限制的檢查
     *      必須驗證轉帳數量不超過未凍結數量
     *      必須對 from 和 to 參數執行 canTransact 檢查
     * @param from 發送代幣的地址
     * @param to 接收代幣的地址
     * @param tokenId 被轉移的代幣 ID
     * @param amount 被轉移的數量
     * @return allowed 如果轉帳被允許返回 true，否則返回 false
     */
    function canTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external view returns (bool allowed);
}
