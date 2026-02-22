// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICompliance3643
 * @notice ERC-3643 合規介面
 * @dev 定義安全代幣的全局合規規則（如每國持有人上限、每人持有量上限）
 *      在本專案中委託至 GL1PolicyManager 規則引擎
 *
 * 命名為 ICompliance3643 以避免與現有介面衝突
 */
interface ICompliance3643 {
    // ============ Events ============

    event TokenBound(address _token);
    event TokenUnbound(address _token);

    // ============ Functions ============

    /**
     * @notice 綁定代幣合約
     * @param _token ERC-3643 代幣合約地址
     */
    function bindToken(address _token) external;

    /**
     * @notice 解綁代幣合約
     * @param _token ERC-3643 代幣合約地址
     */
    function unbindToken(address _token) external;

    /**
     * @notice 檢查代幣是否已綁定
     */
    function isTokenBound(address _token) external view returns (bool);

    /**
     * @notice 取得已綁定的代幣地址
     */
    function getTokenBound() external view returns (address);

    /**
     * @notice 檢查轉帳是否符合合規規則
     * @dev 由 ERC3643Token 的 transfer/transferFrom 調用
     * @param _from 發送方
     * @param _to 接收方
     * @param _amount 轉帳數量
     * @return 是否合規
     */
    function canTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (bool);

    /**
     * @notice 通知合規合約已發生轉帳（用於更新狀態統計）
     * @param _from 發送方
     * @param _to 接收方
     * @param _amount 轉帳數量
     */
    function transferred(
        address _from,
        address _to,
        uint256 _amount
    ) external;

    /**
     * @notice 通知合規合約已鑄造代幣
     * @param _to 接收方
     * @param _amount 數量
     */
    function created(address _to, uint256 _amount) external;

    /**
     * @notice 通知合規合約已銷毀代幣
     * @param _from 持有者
     * @param _amount 數量
     */
    function destroyed(address _from, uint256 _amount) external;
}
