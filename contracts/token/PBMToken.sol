// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IERC7943MultiToken.sol";

/**
 * @title PBMToken
 * @notice Purpose Bound Money - 單一 ERC1155 代幣，用不同 tokenId 代表不同底層資產
 * @dev 所有 wrapped assets 都在這個合約中，由 PolicyWrapper 統一管理
 *      實作 ERC-7943 (uRWA) 標準以支援 RWA 合規功能
 */
contract PBMToken is ERC1155, AccessControl, IERC7943MultiToken {
    bytes32 public constant WRAPPER_ROLE = keccak256("WRAPPER_ROLE");
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    
    // PolicyWrapper 地址
    address public wrapper;
    
    // tokenId → 資產名稱（可選，用於前端顯示）
    mapping(uint256 => string) public tokenNames;
    
    // tokenId → 總供應量
    mapping(uint256 => uint256) public totalSupply;
    
    // ============ ERC-7943 State ============
    
    // 凍結代幣追蹤：account → tokenId → frozen amount
    mapping(address => mapping(uint256 => uint256)) private _frozenTokens;
    
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event TokenBurned(address indexed from, uint256 indexed tokenId, uint256 amount);
    event WrapperUpdated(address indexed oldWrapper, address indexed newWrapper);
    
    constructor(address _wrapper) ERC1155("") {
        require(_wrapper != address(0), "Invalid wrapper address");
        wrapper = _wrapper;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(WRAPPER_ROLE, _wrapper);
        _grantRole(REGULATOR_ROLE, msg.sender);
    }
    
    /**
     * @notice 鑄造 PBM 代幣（僅限 Wrapper 調用）
     * @param to 接收者地址
     * @param tokenId PBM tokenId（對應特定底層資產）
     * @param amount 數量
     */
    function mint(
        address to,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(WRAPPER_ROLE) {
        _mint(to, tokenId, amount, "");
        totalSupply[tokenId] += amount;
        emit TokenMinted(to, tokenId, amount);
    }
    
    /**
     * @notice 銷毀 PBM 代幣（僅限 Wrapper 調用）
     * @param from 持有者地址
     * @param tokenId PBM tokenId
     * @param amount 數量
     */
    function burn(
        address from,
        uint256 tokenId,
        uint256 amount
    ) external onlyRole(WRAPPER_ROLE) {
        _burn(from, tokenId, amount);
        totalSupply[tokenId] -= amount;
        emit TokenBurned(from, tokenId, amount);
    }
    
    /**
     * @notice 設置 tokenId 的名稱
     */
    function setTokenName(uint256 tokenId, string calldata name) 
        external 
        onlyRole(WRAPPER_ROLE) 
    {
        tokenNames[tokenId] = name;
    }
    
    /**
     * @notice 更新 Wrapper 地址
     */
    function updateWrapper(address newWrapper) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newWrapper != address(0), "Invalid wrapper address");
        
        address oldWrapper = wrapper;
        
        // 移除舊 wrapper 權限
        _revokeRole(WRAPPER_ROLE, oldWrapper);
        
        // 設置新 wrapper
        wrapper = newWrapper;
        _grantRole(WRAPPER_ROLE, newWrapper);
        
        emit WrapperUpdated(oldWrapper, newWrapper);
    }
    
    // ============ ERC-7943 Implementation ============
    
    /**
     * @notice 檢查帳戶是否允許進行交易（KYC/AML 檢查）
     * @dev 調用 wrapper 進行合規驗證
     * @param account 要檢查的地址
     * @return allowed 如果帳戶被允許返回 true
     */
    function canTransact(address account) external view override returns (bool allowed) {
        if (account == address(0)) {
            return false;
        }
        
        // 調用 wrapper 檢查帳戶合規性
        // 使用 staticcall 確保不修改狀態
        (bool success, bytes memory result) = wrapper.staticcall(
            abi.encodeWithSignature("checkAccountCompliance(address)", account)
        );
        
        if (success && result.length >= 32) {
            return abi.decode(result, (bool));
        }
        
        // 如果 wrapper 沒有實作此函數，預設允許
        return true;
    }
    
    /**
     * @notice 檢查轉帳是否允許
     * @dev 驗證 canTransact 和凍結餘額
     * @param from 發送代幣的地址
     * @param to 接收代幣的地址
     * @param tokenId 代幣 ID
     * @param amount 轉移數量
     * @return allowed 如果轉帳被允許返回 true
     */
    function canTransfer(
        address from, 
        address to, 
        uint256 tokenId, 
        uint256 amount
    ) external view override returns (bool allowed) {
        // 檢查雙方是否允許交易
        if (!this.canTransact(from) || !this.canTransact(to)) {
            return false;
        }
        
        // 檢查未凍結餘額是否足夠
        uint256 balance = balanceOf(from, tokenId);
        uint256 frozen = _frozenTokens[from][tokenId];
        uint256 unfrozen = balance > frozen ? balance - frozen : 0;
        
        if (amount > unfrozen) {
            return false;
        }
        
        // 調用 wrapper 進行額外合規檢查
        (bool success, bytes memory result) = wrapper.staticcall(
            abi.encodeWithSignature(
                "checkTransferCompliance(address,address,uint256,uint256)",
                from, to, tokenId, amount
            )
        );
        
        if (success && result.length >= 32) {
            (bool isCompliant,) = abi.decode(result, (bool, string));
            return isCompliant;
        }
        
        // 如果 wrapper 調用失敗，使用寬鬆模式
        return true;
    }
    
    /**
     * @notice 查詢帳戶的凍結代幣數量
     * @param account 帳戶地址
     * @param tokenId 代幣 ID
     * @return amount 凍結的代幣數量
     */
    function getFrozenTokens(
        address account, 
        uint256 tokenId
    ) external view override returns (uint256 amount) {
        return _frozenTokens[account][tokenId];
    }
    
    /**
     * @notice 設定帳戶的凍結代幣數量
     * @dev 僅限 REGULATOR_ROLE 調用
     * @param account 帳戶地址
     * @param tokenId 代幣 ID
     * @param amount 凍結數量（可以大於餘額）
     * @return result 操作是否成功
     */
    function setFrozenTokens(
        address account, 
        uint256 tokenId, 
        uint256 amount
    ) external override onlyRole(REGULATOR_ROLE) returns (bool result) {
        _frozenTokens[account][tokenId] = amount;
        emit Frozen(account, tokenId, amount);
        return true;
    }
    
    /**
     * @notice 強制轉移代幣
     * @dev 僅限 REGULATOR_ROLE 調用，用於監管合規或資產回收
     *      如果代幣被凍結，會先自動解凍
     * @param from 代幣來源地址
     * @param to 代幣目標地址
     * @param tokenId 代幣 ID
     * @param amount 轉移數量
     * @return result 操作是否成功
     */
    function forcedTransfer(
        address from, 
        address to, 
        uint256 tokenId, 
        uint256 amount
    ) external override onlyRole(REGULATOR_ROLE) returns (bool result) {
        require(from != address(0), "ERC7943: transfer from zero address");
        require(to != address(0), "ERC7943: transfer to zero address");
        
        uint256 balance = balanceOf(from, tokenId);
        require(balance >= amount, "ERC7943: insufficient balance");
        
        // 如果代幣被凍結，先解凍（根據 ERC-7943 規範）
        uint256 frozen = _frozenTokens[from][tokenId];
        if (frozen > 0) {
            uint256 newFrozen = frozen > amount ? frozen - amount : 0;
            _frozenTokens[from][tokenId] = newFrozen;
            emit Frozen(from, tokenId, newFrozen);
        }
        
        // 執行轉移（繞過常規合規檢查）
        _safeTransferFrom(from, to, tokenId, amount, "");
        
        // 發送 ForcedTransfer 事件
        emit ForcedTransfer(from, to, tokenId, amount);
        
        return true;
    }
    
    /**
     * @notice 計算未凍結餘額
     * @param account 帳戶地址
     * @param tokenId 代幣 ID
     * @return unfrozen 可用於轉移的未凍結數量
     */
    function getUnfrozenBalance(
        address account, 
        uint256 tokenId
    ) external view returns (uint256 unfrozen) {
        uint256 balance = balanceOf(account, tokenId);
        uint256 frozen = _frozenTokens[account][tokenId];
        return balance > frozen ? balance - frozen : 0;
    }
    
    /**
     * @notice 轉移前的合規檢查
     * @dev 覆寫 ERC1155 的 _update 函數
     */
    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override {
        // 跳過 mint (from == 0) 和 burn (to == 0) 的合規檢查
        // 這些操作由 wrapper 控制
        if (from != address(0) && to != address(0)) {
            // 檢查凍結代幣
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 frozen = _frozenTokens[from][ids[i]];
                uint256 balance = balanceOf(from, ids[i]);
                uint256 unfrozen = balance > frozen ? balance - frozen : 0;
                
                // 使用 ERC-7943 自定義錯誤
                if (values[i] > unfrozen) {
                    revert ERC7943InsufficientUnfrozenBalance(
                        from, 
                        ids[i], 
                        values[i], 
                        unfrozen
                    );
                }
            }
            
            // 調用 wrapper 進行合規檢查
            // 注意：這裡不能直接 import PolicyWrapper 避免循環依賴
            // 使用低階調用
            for (uint256 i = 0; i < ids.length; i++) {
                (bool success, bytes memory result) = wrapper.call(
                    abi.encodeWithSignature(
                        "checkTransferCompliance(address,address,uint256,uint256)",
                        from, to, ids[i], values[i]
                    )
                );
                
                if (success && result.length >= 32) {
                    (bool isCompliant,) = abi.decode(result, (bool, string));
                    if (!isCompliant) {
                        revert ERC7943CannotTransfer(from, to, ids[i], values[i]);
                    }
                }
                // 如果 wrapper 調用失敗，允許轉移（可配置為嚴格模式）
            }
        }
        
        super._update(from, to, ids, values);
    }
    
    /**
     * @notice 支援 AccessControl、ERC1155 和 ERC7943 的 supportsInterface
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl, IERC165)
        returns (bool)
    {
        return 
            interfaceId == type(IERC7943MultiToken).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
