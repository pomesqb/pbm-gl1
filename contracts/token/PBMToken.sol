// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title PBMToken
 * @notice Purpose Bound Money - 單一 ERC1155 代幣，用不同 tokenId 代表不同底層資產
 * @dev 所有 wrapped assets 都在這個合約中，由 PolicyWrapper 統一管理
 */
contract PBMToken is ERC1155, AccessControl {
    bytes32 public constant WRAPPER_ROLE = keccak256("WRAPPER_ROLE");
    
    // PolicyWrapper 地址
    address public wrapper;
    
    // tokenId → 資產名稱（可選，用於前端顯示）
    mapping(uint256 => string) public tokenNames;
    
    // tokenId → 總供應量
    mapping(uint256 => uint256) public totalSupply;
    
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event TokenBurned(address indexed from, uint256 indexed tokenId, uint256 amount);
    event WrapperUpdated(address indexed oldWrapper, address indexed newWrapper);
    
    constructor(address _wrapper) ERC1155("") {
        require(_wrapper != address(0), "Invalid wrapper address");
        wrapper = _wrapper;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(WRAPPER_ROLE, _wrapper);
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
                    require(isCompliant, "PBM: Transfer not compliant");
                }
                // 如果 wrapper 調用失敗，允許轉移（可配置為嚴格模式）
            }
        }
        
        super._update(from, to, ids, values);
    }
    
    /**
     * @notice 支援 AccessControl 和 ERC1155 的 supportsInterface
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
