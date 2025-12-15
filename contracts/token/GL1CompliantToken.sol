// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../core/GL1PolicyWrapper.sol";

/**
 * @title GL1CompliantToken
 * @notice 符合 GL1 標準的證券代幣（支援多管轄區政策包裝器）
 * @dev 整合 GL1 Policy Wrapper 進行自動合規檢查
 */
contract GL1CompliantToken is ERC20, ERC20Burnable, ERC20Pausable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant JURISDICTION_ADMIN_ROLE = keccak256("JURISDICTION_ADMIN_ROLE");
    
    // 管轄區 → Policy Wrapper 映射
    mapping(bytes32 => address) public policyWrappers;
    
    // 默認管轄區
    bytes32 public defaultJurisdiction;
    
    // 地址 → 管轄區映射（用於確定適用哪個 wrapper）
    mapping(address => bytes32) public addressJurisdiction;
    
    // 豁免合規檢查的地址（例如：系統合約、流動性池）
    mapping(address => bool) public complianceExempt;
    
    // 合規檢查開關
    bool public complianceEnabled = true;
    
    event PolicyWrapperSet(bytes32 indexed jurisdiction, address wrapperAddress);
    event AddressJurisdictionSet(address indexed account, bytes32 jurisdiction);
    event TransferCompliant(address indexed from, address indexed to, uint256 amount, bytes32 jurisdiction);
    event ComplianceExemptionSet(address indexed account, bool exempt);
    event ComplianceEnabledChanged(bool enabled);
    
    constructor(
        string memory name,
        string memory symbol,
        bytes32 _defaultJurisdiction
    ) ERC20(name, symbol) {
        defaultJurisdiction = _defaultJurisdiction;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(JURISDICTION_ADMIN_ROLE, msg.sender);
        
        // 發行者預設豁免合規檢查
        complianceExempt[msg.sender] = true;
    }
    
    /**
     * @notice 覆寫轉移函數，整合 GL1 合規檢查
     */
    function transfer(address to, uint256 amount) 
        public 
        override 
        returns (bool) 
    {
        return _compliantTransfer(msg.sender, to, amount);
    }
    
    /**
     * @notice 覆寫授權轉移函數
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        _spendAllowance(from, msg.sender, amount);
        return _compliantTransfer(from, to, amount);
    }
    
    /**
     * @notice GL1 合規轉移邏輯
     */
    function _compliantTransfer(address from, address to, uint256 amount) 
        internal 
        returns (bool) 
    {
        // 如果合規檢查已停用或任一方豁免，直接轉移
        if (!complianceEnabled || complianceExempt[from] || complianceExempt[to]) {
            _transfer(from, to, amount);
            return true;
        }
        
        // 確定適用的管轄區
        bytes32 jurisdiction = _determineJurisdiction(from, to);
        
        // 獲取對應的 Policy Wrapper
        address wrapperAddress = policyWrappers[jurisdiction];
        require(wrapperAddress != address(0), "No policy wrapper for jurisdiction");
        
        GL1PolicyWrapper wrapper = GL1PolicyWrapper(wrapperAddress);
        
        // 執行合規檢查
        (bool isCompliant, string memory failureReason) = 
            wrapper.checkTransferCompliance(from, to, amount);
        
        require(isCompliant, failureReason);
        
        // 執行實際轉移
        _transfer(from, to, amount);
        
        emit TransferCompliant(from, to, amount, jurisdiction);
        return true;
    }
    
    /**
     * @notice 確定交易適用的管轄區
     * @dev 優先順序：發送方管轄區 > 接收方管轄區 > 默認管轄區
     */
    function _determineJurisdiction(address from, address to) 
        internal 
        view 
        returns (bytes32) 
    {
        bytes32 fromJurisdiction = addressJurisdiction[from];
        if (fromJurisdiction != bytes32(0)) {
            return fromJurisdiction;
        }
        
        bytes32 toJurisdiction = addressJurisdiction[to];
        if (toJurisdiction != bytes32(0)) {
            return toJurisdiction;
        }
        
        return defaultJurisdiction;
    }
    
    /**
     * @notice 設置特定管轄區的 Policy Wrapper
     */
    function setPolicyWrapper(bytes32 jurisdiction, address wrapperAddress) 
        external 
        onlyRole(JURISDICTION_ADMIN_ROLE)
    {
        require(wrapperAddress != address(0), "Invalid wrapper address");
        policyWrappers[jurisdiction] = wrapperAddress;
        emit PolicyWrapperSet(jurisdiction, wrapperAddress);
    }
    
    /**
     * @notice 設置地址的管轄區
     */
    function setAddressJurisdiction(address account, bytes32 jurisdiction) 
        external 
        onlyRole(JURISDICTION_ADMIN_ROLE)
    {
        addressJurisdiction[account] = jurisdiction;
        emit AddressJurisdictionSet(account, jurisdiction);
    }
    
    /**
     * @notice 批量設置地址管轄區
     */
    function batchSetAddressJurisdiction(
        address[] calldata accounts,
        bytes32 jurisdiction
    ) external onlyRole(JURISDICTION_ADMIN_ROLE) {
        for (uint256 i = 0; i < accounts.length; i++) {
            addressJurisdiction[accounts[i]] = jurisdiction;
            emit AddressJurisdictionSet(accounts[i], jurisdiction);
        }
    }
    
    /**
     * @notice 設置合規豁免
     */
    function setComplianceExemption(address account, bool exempt)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        complianceExempt[account] = exempt;
        emit ComplianceExemptionSet(account, exempt);
    }
    
    /**
     * @notice 啟用或停用合規檢查
     */
    function setComplianceEnabled(bool enabled)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        complianceEnabled = enabled;
        emit ComplianceEnabledChanged(enabled);
    }
    
    /**
     * @notice 更新默認管轄區
     */
    function setDefaultJurisdiction(bytes32 jurisdiction)
        external
        onlyRole(JURISDICTION_ADMIN_ROLE)
    {
        defaultJurisdiction = jurisdiction;
    }
    
    /**
     * @notice 鑄造新代幣
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }
    
    /**
     * @notice 暫停合約
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
    
    /**
     * @notice 恢復合約
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @notice 覆寫 _update 函數以支援 Pausable
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
    
    /**
     * @notice 獲取地址的有效管轄區
     */
    function getEffectiveJurisdiction(address account) external view returns (bytes32) {
        bytes32 jurisdiction = addressJurisdiction[account];
        return jurisdiction != bytes32(0) ? jurisdiction : defaultJurisdiction;
    }
    
    /**
     * @notice 檢查地址是否有有效的 Policy Wrapper
     */
    function hasValidPolicyWrapper(address account) external view returns (bool) {
        bytes32 jurisdiction = addressJurisdiction[account];
        if (jurisdiction == bytes32(0)) {
            jurisdiction = defaultJurisdiction;
        }
        return policyWrappers[jurisdiction] != address(0);
    }
}
