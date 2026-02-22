// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IERC3643.sol";
import "../interfaces/IIdentityRegistry.sol";
import "../interfaces/ICompliance3643.sol";

/**
 * @title ERC3643Token
 * @notice ERC-3643 (T-REX) 安全代幣實作
 * @dev Asset Layer：負責證券發行、配息、凍結、強制轉移、KYC/AML 身份驗證
 *
 * 雙層架構角色：
 * ┌────────────────────────────────────────────────┐
 * │ Transaction Layer (PBM)                         │
 * │  - GL1PolicyWrapper wrap 此代幣 (AssetType.ERC20)│
 * │  - 條件式支付 / Repo 原子交換                    │
 * └────────────────────────────────────────────────┘
 * ┌────────────────────────────────────────────────┐
 * │ Asset Layer (ERC-3643) ← 本合約                 │
 * │  - transfer/transferFrom 前置合規檢查            │
 * │  - Identity Registry + Compliance Module        │
 * │  - 凍結 / 強制轉帳 / 暫停 / 錢包回復            │
 * └────────────────────────────────────────────────┘
 *
 * 使用 AccessControl 的 AGENT_ROLE 取代 ERC-173 Owner 機制
 */
contract ERC3643Token is ERC20, AccessControl, IERC3643 {
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");

    // ============ State Variables ============

    // 代幣資訊
    string private _tokenVersion;
    address private _onchainID;

    // 關聯合約
    IIdentityRegistry private _identityRegistry;
    ICompliance3643 private _compliance;

    // 暫停狀態
    bool private _paused;

    // 地址凍結（整個錢包）
    mapping(address => bool) private _frozen;

    // 部分代幣凍結
    mapping(address => uint256) private _frozenTokens;

    // ============ Modifiers ============

    modifier whenNotPaused() {
        require(!_paused, "ERC-3643: Token is paused");
        _;
    }

    // ============ Constructor ============

    constructor(
        string memory name_,
        string memory symbol_,
        address identityRegistry_,
        address compliance_
    ) ERC20(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(AGENT_ROLE, msg.sender);

        _tokenVersion = "1.0.0";
        _identityRegistry = IIdentityRegistry(identityRegistry_);
        _compliance = ICompliance3643(compliance_);
    }

    // ============ ERC-20 Override with Compliance ============

    /**
     * @notice 合規轉帳 — 前置合規檢查
     * @dev 檢查順序：
     *      1. 代幣未暫停
     *      2. 發送方和接收方未被凍結
     *      3. 發送方有足夠的未凍結餘額
     *      4. 接收方在 Identity Registry 中已驗證
     *      5. Compliance 合約允許此轉帳
     */
    function transfer(
        address _to,
        uint256 _amount
    ) public override(ERC20, IERC20) whenNotPaused returns (bool) {
        require(!_frozen[msg.sender] && !_frozen[_to], "ERC-3643: Frozen wallet");
        require(
            _amount <= balanceOf(msg.sender) - _frozenTokens[msg.sender],
            "ERC-3643: Insufficient unfrozen balance"
        );
        require(
            _identityRegistry.isVerified(_to),
            "ERC-3643: Invalid identity"
        );
        require(
            _compliance.canTransfer(msg.sender, _to, _amount),
            "ERC-3643: Compliance failure"
        );

        _transfer(msg.sender, _to, _amount);
        _compliance.transferred(msg.sender, _to, _amount);
        return true;
    }

    /**
     * @notice 合規授權轉帳
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override(ERC20, IERC20) whenNotPaused returns (bool) {
        require(!_frozen[_from] && !_frozen[_to], "ERC-3643: Frozen wallet");
        require(
            _amount <= balanceOf(_from) - _frozenTokens[_from],
            "ERC-3643: Insufficient unfrozen balance"
        );
        require(
            _identityRegistry.isVerified(_to),
            "ERC-3643: Invalid identity"
        );
        require(
            _compliance.canTransfer(_from, _to, _amount),
            "ERC-3643: Compliance failure"
        );

        _spendAllowance(_from, msg.sender, _amount);
        _transfer(_from, _to, _amount);
        _compliance.transferred(_from, _to, _amount);
        return true;
    }

    // ============ IERC3643 Getters ============

    function onchainID() external view override returns (address) {
        return _onchainID;
    }

    function version() external view override returns (string memory) {
        return _tokenVersion;
    }

    function identityRegistry() external view override returns (address) {
        return address(_identityRegistry);
    }

    function compliance() external view override returns (address) {
        return address(_compliance);
    }

    function paused() external view override returns (bool) {
        return _paused;
    }

    function isFrozen(
        address _userAddress
    ) external view override returns (bool) {
        return _frozen[_userAddress];
    }

    function getFrozenTokens(
        address _userAddress
    ) external view override returns (uint256) {
        return _frozenTokens[_userAddress];
    }

    // ============ IERC3643 Setters ============

    function setName(
        string calldata _name
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // ERC20 不允許直接改名，用事件記錄
        emit UpdatedTokenInformation(_name, symbol(), decimals(), _tokenVersion, _onchainID);
    }

    function setSymbol(
        string calldata _symbol
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        emit UpdatedTokenInformation(name(), _symbol, decimals(), _tokenVersion, _onchainID);
    }

    function setOnchainID(
        address _newOnchainID
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _onchainID = _newOnchainID;
    }

    function pause() external override onlyRole(AGENT_ROLE) {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external override onlyRole(AGENT_ROLE) {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /**
     * @notice 凍結或解凍整個錢包
     */
    function setAddressFrozen(
        address _userAddress,
        bool _freeze
    ) external override onlyRole(AGENT_ROLE) {
        _frozen[_userAddress] = _freeze;
        emit AddressFrozen(_userAddress, _freeze, msg.sender);
    }

    /**
     * @notice 凍結部分代幣
     */
    function freezePartialTokens(
        address _userAddress,
        uint256 _amount
    ) external override onlyRole(AGENT_ROLE) {
        _frozenTokens[_userAddress] += _amount;
        emit TokensFrozen(_userAddress, _amount);
    }

    /**
     * @notice 解凍部分代幣
     */
    function unfreezePartialTokens(
        address _userAddress,
        uint256 _amount
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _frozenTokens[_userAddress] >= _amount,
            "ERC-3643: Amount exceeds frozen tokens"
        );
        _frozenTokens[_userAddress] -= _amount;
        emit TokensUnfrozen(_userAddress, _amount);
    }

    function setIdentityRegistry(
        address _newIdentityRegistry
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newIdentityRegistry != address(0), "Invalid address");
        _identityRegistry = IIdentityRegistry(_newIdentityRegistry);
        emit IdentityRegistryAdded(_newIdentityRegistry);
    }

    function setCompliance(
        address _newCompliance
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newCompliance != address(0), "Invalid address");
        _compliance = ICompliance3643(_newCompliance);
        emit ComplianceAdded(_newCompliance);
    }

    // ============ Transfer Actions ============

    /**
     * @notice Agent 強制轉移代幣
     * @dev 只檢查接收方身份，繞過 Compliance 規則
     */
    function forcedTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external override onlyRole(AGENT_ROLE) returns (bool) {
        require(
            _identityRegistry.isVerified(_to),
            "ERC-3643: Invalid identity"
        );

        // 如果凍結代幣超過轉移量，減少凍結量
        if (_frozenTokens[_from] > 0) {
            uint256 unfrozen = balanceOf(_from) - _frozenTokens[_from];
            if (_amount > unfrozen) {
                uint256 frozenToReduce = _amount - unfrozen;
                _frozenTokens[_from] -= frozenToReduce;
                emit TokensUnfrozen(_from, frozenToReduce);
            }
        }

        _transfer(_from, _to, _amount);
        _compliance.transferred(_from, _to, _amount);
        return true;
    }

    /**
     * @notice 鑄造新代幣
     * @dev 只檢查接收方身份
     */
    function mint(
        address _to,
        uint256 _amount
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _identityRegistry.isVerified(_to),
            "ERC-3643: Invalid identity"
        );
        _mint(_to, _amount);
        _compliance.created(_to, _amount);
    }

    /**
     * @notice 銷毀代幣
     */
    function burn(
        address _userAddress,
        uint256 _amount
    ) external override onlyRole(AGENT_ROLE) {
        // 如果凍結代幣超過餘額減去銷毀量，調整凍結量
        uint256 newBalance = balanceOf(_userAddress) - _amount;
        if (_frozenTokens[_userAddress] > newBalance) {
            _frozenTokens[_userAddress] = newBalance;
        }
        _burn(_userAddress, _amount);
        _compliance.destroyed(_userAddress, _amount);
    }

    /**
     * @notice 錢包回復 — 投資者遺失私鑰時
     * @dev 將舊錢包的所有代幣轉移到新錢包
     */
    function recoveryAddress(
        address _lostWallet,
        address _newWallet,
        address _investorOnchainID
    ) external override onlyRole(AGENT_ROLE) returns (bool) {
        require(
            _identityRegistry.isVerified(_newWallet),
            "ERC-3643: New wallet not verified"
        );

        uint256 balance = balanceOf(_lostWallet);
        if (balance > 0) {
            // 解除凍結以便轉移
            uint256 frozenAmount = _frozenTokens[_lostWallet];
            if (frozenAmount > 0) {
                _frozenTokens[_lostWallet] = 0;
                _frozenTokens[_newWallet] += frozenAmount;
            }

            // 轉移代幣
            _transfer(_lostWallet, _newWallet, balance);
            _compliance.transferred(_lostWallet, _newWallet, balance);
        }

        // 轉移凍結狀態
        if (_frozen[_lostWallet]) {
            _frozen[_lostWallet] = false;
            _frozen[_newWallet] = true;
        }

        emit RecoverySuccess(_lostWallet, _newWallet, _investorOnchainID);
        return true;
    }

    // ============ Batch Functions ============

    function batchTransfer(
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external override {
        require(_toList.length == _amounts.length, "Array length mismatch");
        for (uint256 i = 0; i < _toList.length; i++) {
            transfer(_toList[i], _amounts[i]);
        }
    }

    function batchForcedTransfer(
        address[] calldata _fromList,
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _fromList.length == _toList.length &&
                _fromList.length == _amounts.length,
            "Array length mismatch"
        );
        for (uint256 i = 0; i < _fromList.length; i++) {
            // 內聯強制轉帳邏輯以避免重複的 AGENT_ROLE 檢查
            require(
                _identityRegistry.isVerified(_toList[i]),
                "ERC-3643: Invalid identity"
            );
            _transfer(_fromList[i], _toList[i], _amounts[i]);
            _compliance.transferred(_fromList[i], _toList[i], _amounts[i]);
        }
    }

    function batchMint(
        address[] calldata _toList,
        uint256[] calldata _amounts
    ) external override onlyRole(AGENT_ROLE) {
        require(_toList.length == _amounts.length, "Array length mismatch");
        for (uint256 i = 0; i < _toList.length; i++) {
            require(
                _identityRegistry.isVerified(_toList[i]),
                "ERC-3643: Invalid identity"
            );
            _mint(_toList[i], _amounts[i]);
            _compliance.created(_toList[i], _amounts[i]);
        }
    }

    function batchBurn(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _userAddresses.length == _amounts.length,
            "Array length mismatch"
        );
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            uint256 newBalance = balanceOf(_userAddresses[i]) - _amounts[i];
            if (_frozenTokens[_userAddresses[i]] > newBalance) {
                _frozenTokens[_userAddresses[i]] = newBalance;
            }
            _burn(_userAddresses[i], _amounts[i]);
            _compliance.destroyed(_userAddresses[i], _amounts[i]);
        }
    }

    function batchSetAddressFrozen(
        address[] calldata _userAddresses,
        bool[] calldata _freeze
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _userAddresses.length == _freeze.length,
            "Array length mismatch"
        );
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            _frozen[_userAddresses[i]] = _freeze[i];
            emit AddressFrozen(_userAddresses[i], _freeze[i], msg.sender);
        }
    }

    function batchFreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _userAddresses.length == _amounts.length,
            "Array length mismatch"
        );
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            _frozenTokens[_userAddresses[i]] += _amounts[i];
            emit TokensFrozen(_userAddresses[i], _amounts[i]);
        }
    }

    function batchUnfreezePartialTokens(
        address[] calldata _userAddresses,
        uint256[] calldata _amounts
    ) external override onlyRole(AGENT_ROLE) {
        require(
            _userAddresses.length == _amounts.length,
            "Array length mismatch"
        );
        for (uint256 i = 0; i < _userAddresses.length; i++) {
            require(
                _frozenTokens[_userAddresses[i]] >= _amounts[i],
                "ERC-3643: Amount exceeds frozen tokens"
            );
            _frozenTokens[_userAddresses[i]] -= _amounts[i];
            emit TokensUnfrozen(_userAddresses[i], _amounts[i]);
        }
    }

    // ============ Utility ============

    /**
     * @notice 計算未凍結餘額
     */
    function getUnfrozenBalance(
        address _userAddress
    ) external view returns (uint256) {
        uint256 balance = balanceOf(_userAddress);
        uint256 frozen = _frozenTokens[_userAddress];
        return balance > frozen ? balance - frozen : 0;
    }

    /**
     * @notice 檢查是否允許接收指定資產
     * @dev 供 ERC20 approve + transferFrom 前使用的預檢查
     */
    function canReceive(address _to) external view returns (bool) {
        return _identityRegistry.isVerified(_to) && !_frozen[_to];
    }
}
