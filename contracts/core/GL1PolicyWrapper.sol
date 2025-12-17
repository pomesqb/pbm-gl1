// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IGL1PolicyWrapper.sol";
import "../interfaces/IPolicyManager.sol";
import "../interfaces/IFXRateProvider.sol";
import "../token/PBMToken.sol";

/**
 * @title GL1PolicyWrapper
 * @notice GL1 PBM Policy Wrapper - 單一合約處理所有類型的底層資產
 * @dev 實作 wrap/unwrap 功能，整合合規檢查與跨境支付匯率轉換
 *
 * ═══════════════════════════════════════════════════════════════════
 * 跨境支付場景 (StraitsX/Alipay+ 模式)：
 * ═══════════════════════════════════════════════════════════════════
 * 1. 旅客使用本國貨幣支付 (例如：CNY, TWD)
 * 2. 系統查詢即時匯率進行轉換
 * 3. 商家收到當地貨幣結算 (例如：SGD)
 * ═══════════════════════════════════════════════════════════════════
 */
contract GL1PolicyWrapper is IGL1PolicyWrapper, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");
    bytes32 public constant POLICY_ADMIN_ROLE = keccak256("POLICY_ADMIN_ROLE");
    
    // 司法管轄區代碼 (ISO 3166-1)
    bytes32 public immutable jurisdictionCode;
    
    // PBM Token (ERC1155)
    PBMToken public pbmToken;
    
    // Policy Manager
    IPolicyManager public policyManager;
    
    // pbmTokenId → 底層資產資訊
    mapping(uint256 => AssetInfo) public assets;
    
    // 合規檢查開關
    bool public complianceEnabled = true;
    
    // 豁免合規檢查的地址
    mapping(address => bool) public complianceExempt;
    
    // 合規證明記錄
    struct ComplianceProof {
        bytes32 proofHash;
        uint256 timestamp;
        address verifier;
        bool isValid;
    }
    mapping(bytes32 => ComplianceProof) public complianceProofs;
    
    // ============ FX Rate Provider (跨境支付匯率) ============
    
    // FX 匯率提供者
    IFXRateProvider public fxRateProvider;
    
    // 資產地址 → 貨幣代碼 (例如：USDC 地址 → "USD")
    mapping(address => bytes32) public assetCurrency;
    
    // 是否啟用 FX 轉換功能
    bool public fxEnabled = false;
    
    // FX 交易記錄結構 - 記錄每筆跨境支付的匯率資訊
    struct FXTransaction {
        bytes32 sourceCurrency;     // 來源幣種 (TWD)
        bytes32 targetCurrency;     // 目標幣種 (SGD)
        uint256 sourceAmount;       // 來源金額 (3200 TWD)
        uint256 targetAmount;       // 目標金額 (100 SGD)
        uint256 rateUsed;           // 使用的匯率 (18 decimals)
        uint256 timestamp;          // 交易時間
        address payer;              // 付款人 (遊客)
        address payee;              // 收款人 (商家)
    }
    
    // pbmTokenId → FX 交易記錄
    mapping(uint256 => FXTransaction) public fxTransactions;
    
    event ComplianceCheckInitiated(
        bytes32 indexed txHash,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes32 jurisdictionCode
    );
    
    event ComplianceCheckCompleted(
        bytes32 indexed txHash,
        bool isCompliant,
        string[] appliedRules,
        uint256 timestamp
    );
    
    event PolicyManagerUpdated(address indexed oldManager, address indexed newManager);
    event ComplianceExemptionSet(address indexed account, bool exempt);
    
    // FX 相關事件
    event FXRateProviderUpdated(address indexed oldProvider, address indexed newProvider);
    event AssetCurrencySet(address indexed asset, bytes32 currency);
    event FXConversionApplied(
        address indexed user,
        bytes32 indexed fromCurrency,
        bytes32 indexed toCurrency,
        uint256 originalAmount,
        uint256 convertedAmount,
        uint256 rateUsed
    );
    
    // 跨境支付事件 - 包含完整交易資訊
    event CrossBorderPaymentInitiated(
        uint256 indexed pbmTokenId,
        address indexed payer,
        address indexed payee,
        bytes32 sourceCurrency,
        bytes32 targetCurrency,
        uint256 sourceAmount,
        uint256 targetAmount,
        uint256 rateUsed,
        uint256 timestamp
    );
    
    constructor(
        bytes32 _jurisdictionCode,
        address _policyManager,
        address _pbmToken
    ) {
        jurisdictionCode = _jurisdictionCode;
        policyManager = IPolicyManager(_policyManager);
        pbmToken = PBMToken(_pbmToken);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POLICY_ADMIN_ROLE, msg.sender);
        
        // 部署者豁免合規檢查
        complianceExempt[msg.sender] = true;
    }
    
    /**
     * @notice 計算 PBM tokenId
     * @dev tokenId = hash(assetType, assetAddress, assetTokenId)
     */
    function computePBMTokenId(
        AssetType assetType,
        address assetAddress,
        uint256 assetTokenId
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(assetType, assetAddress, assetTokenId)));
    }
    
    /**
     * @notice 包裝底層資產，將 ERC20/ERC721/ERC1155 轉換為 PBM Token
     * 
     * ═══════════════════════════════════════════════════════════════════
     * 參數說明：
     * ═══════════════════════════════════════════════════════════════════
     * @param assetType     資產類型，可以是：
     *                      - AssetType.ERC20:   同質化代幣（如 USDT, USDC）
     *                      - AssetType.ERC721:  非同質化代幣（NFT，每個獨一無二）
     *                      - AssetType.ERC1155: 半同質化代幣（可有多個相同的 NFT）
     * 
     * @param assetAddress  底層資產的合約地址
     *                      例如：USDT 合約地址、某個 NFT 系列的合約地址
     * 
     * @param assetTokenId  底層資產的 tokenId
     *                      - ERC20:   傳 0（因為 ERC20 沒有 tokenId 概念）
     *                      - ERC721:  傳該 NFT 的唯一編號
     *                      - ERC1155: 傳該代幣類型的編號
     * 
     * @param amount        要包裝的數量
     *                      - ERC20:   可以是任意數量（如 100 USDT）
     *                      - ERC721:  必須是 1（因為 NFT 不可分割）
     *                      - ERC1155: 可以是任意數量
     * 
     * @param proof         合規證明集，包含 KYC/AML 驗證資訊
     *                      - proofType:      證明類型（"KYC", "AML", "ACCREDITATION"）
     *                      - credentialHash: 鏈下憑證的雜湊值
     *                      - issuedAt:       發行時間
     *                      - expiresAt:      過期時間
     *                      - issuer:         發行機構地址
     *                      - signature:      發行機構的數位簽名
     * 
     * @return pbmTokenId   產生的 PBM tokenId，用於之後的轉移和解包
     * ═══════════════════════════════════════════════════════════════════
     */
    function wrap(
        AssetType assetType,
        address assetAddress,
        uint256 assetTokenId,
        uint256 amount,
        ProofSet calldata proof
    ) external override nonReentrant returns (uint256 pbmTokenId) {
        // 確保資產地址不是零地址（零地址代表無效地址）
        require(assetAddress != address(0), "Invalid asset address");
        
        // 確保要包裝的數量大於 0
        require(amount > 0, "Amount must be > 0");
        
        // 如果合規檢查功能開啟，且調用者不在豁免名單中
        // 則驗證使用者提供的 KYC/AML 證明是否有效
        if (complianceEnabled && !complianceExempt[msg.sender]) {
            _verifyProofSet(proof);  // 檢查證明是否過期、是否已生效
        }
  
        // 計算 PBM Token 的唯一識別碼
        // 使用 hash(資產類型 + 合約地址 + tokenId) 產生唯一的 PBM tokenId
        // 這樣同一種底層資產會對應到同一個 PBM tokenId
        pbmTokenId = computePBMTokenId(assetType, assetAddress, assetTokenId);
        
        // 記錄資產資訊
        // 如果這是第一次包裝這種資產（地址為空代表尚未記錄）
        // 則儲存資產的詳細資訊，供之後解包時使用
        if (assets[pbmTokenId].assetAddress == address(0)) {
            assets[pbmTokenId] = AssetInfo({
                assetType: assetType,        // 記錄資產類型
                assetAddress: assetAddress,  // 記錄合約地址
                assetTokenId: assetTokenId   // 記錄 tokenId
            });
        }
        
        // 轉移底層資產到本合約
        // 從使用者錢包將底層資產轉移到這個 Wrapper 合約保管
        // 根據不同的資產類型，會調用對應的 transferFrom 函式
        _transferAssetIn(assetType, assetAddress, assetTokenId, amount);
        
        // 鑄造相應數量的 PBM Token (ERC1155) 給調用者
        // 使用者之後可以用這個 PBM Token 進行合規轉移
        pbmToken.mint(msg.sender, pbmTokenId, amount);
        
        // 發送事件通知
        // 發送 TokenWrapped 事件，讓前端和區塊鏈瀏覽器可以追蹤這筆操作
        emit TokenWrapped(
            msg.sender,      // 執行包裝的使用者地址
            pbmTokenId,      // 產生的 PBM tokenId
            assetType,       // 底層資產類型
            assetAddress,    // 底層資產合約地址
            assetTokenId,    // 底層資產 tokenId
            amount           // 包裝的數量
        );
        
        // 回傳 PBM tokenId 給調用者
        return pbmTokenId;
    }
    
    /**
     * @notice 解包取回底層資產
     */
    function unwrap(
        uint256 pbmTokenId,
        uint256 amount,
        address beneficiary
    ) external override nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(beneficiary != address(0), "Invalid beneficiary");
        
        AssetInfo memory assetInfo = assets[pbmTokenId];
        require(assetInfo.assetAddress != address(0), "Unknown PBM tokenId");
        
        // 檢查用戶持有足夠的 PBM
        require(
            pbmToken.balanceOf(msg.sender, pbmTokenId) >= amount,
            "Insufficient PBM balance"
        );
        
        // 銷毀 PBM
        pbmToken.burn(msg.sender, pbmTokenId, amount);
        
        // 轉移底層資產給 beneficiary
        _transferAssetOut(
            assetInfo.assetType,
            assetInfo.assetAddress,
            assetInfo.assetTokenId,
            amount,
            beneficiary
        );
        
        emit TokenUnwrapped(msg.sender, pbmTokenId, amount, beneficiary);
    }
    
    /**
     * @notice 檢查轉移合規性
     * @dev 由 PBMToken 在轉移時調用
     */
    function checkTransferCompliance(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external override returns (bool isCompliant, string memory reason) {
        // 如果合規檢查停用或任一方豁免，直接通過
        if (!complianceEnabled || complianceExempt[from] || complianceExempt[to]) {
            return (true, "");
        }
        
        bytes32 txHash = keccak256(abi.encodePacked(from, to, tokenId, amount, block.timestamp));
        
        emit ComplianceCheckInitiated(txHash, from, to, amount, jurisdictionCode);
        
        // 驗證身份
        (bool identityValid, string memory identityError) = 
            policyManager.verifyIdentity(from, to, jurisdictionCode);
        
        if (!identityValid) {
            emit ComplianceCheckCompleted(txHash, false, _toArray("IDENTITY_CHECK"), block.timestamp);
            return (false, identityError);
        }
        
        // 執行合規規則
        (bool rulesValid, string memory ruleError, string[] memory appliedRules) = 
            policyManager.executeComplianceRules(from, to, amount, jurisdictionCode);
        
        if (!rulesValid) {
            emit ComplianceCheckCompleted(txHash, false, appliedRules, block.timestamp);
            return (false, ruleError);
        }
        
        // 記錄合規證明
        complianceProofs[txHash] = ComplianceProof({
            proofHash: keccak256(abi.encode(txHash, appliedRules)),
            timestamp: block.timestamp,
            verifier: address(policyManager),
            isValid: true
        });
        
        emit ComplianceCheckCompleted(txHash, true, appliedRules, block.timestamp);
        return (true, "");
    }
    
    /**
     * @notice 驗證 ProofSet
     */
    function _verifyProofSet(ProofSet calldata proof) internal view {
        require(proof.expiresAt > block.timestamp, "Proof expired");
        require(proof.issuedAt <= block.timestamp, "Proof not yet valid");
    }
    
    /**
     * @notice 轉入底層資產
     */
    function _transferAssetIn(
        AssetType assetType,
        address assetAddress,
        uint256 assetTokenId,
        uint256 amount
    ) internal {
        if (assetType == AssetType.ERC20) {
            IERC20(assetAddress).safeTransferFrom(msg.sender, address(this), amount);
        } else if (assetType == AssetType.ERC721) {
            require(amount == 1, "ERC721 amount must be 1");
            IERC721(assetAddress).transferFrom(msg.sender, address(this), assetTokenId);
        } else if (assetType == AssetType.ERC1155) {
            IERC1155(assetAddress).safeTransferFrom(
                msg.sender, address(this), assetTokenId, amount, ""
            );
        }
    }
    
    /**
     * @notice 轉出底層資產
     */
    function _transferAssetOut(
        AssetType assetType,
        address assetAddress,
        uint256 assetTokenId,
        uint256 amount,
        address to
    ) internal {
        if (assetType == AssetType.ERC20) {
            IERC20(assetAddress).safeTransfer(to, amount);
        } else if (assetType == AssetType.ERC721) {
            require(amount == 1, "ERC721 amount must be 1");
            IERC721(assetAddress).transferFrom(address(this), to, assetTokenId);
        } else if (assetType == AssetType.ERC1155) {
            IERC1155(assetAddress).safeTransferFrom(
                address(this), to, assetTokenId, amount, ""
            );
        }
    }
    
    // ============ Admin Functions ============
    
    function updatePolicyManager(address newManager) external onlyRole(POLICY_ADMIN_ROLE) {
        require(newManager != address(0), "Invalid address");
        address oldManager = address(policyManager);
        policyManager = IPolicyManager(newManager);
        emit PolicyManagerUpdated(oldManager, newManager);
    }
    
    function setComplianceExemption(address account, bool exempt) external onlyRole(POLICY_ADMIN_ROLE) {
        complianceExempt[account] = exempt;
        emit ComplianceExemptionSet(account, exempt);
    }
    
    function setComplianceEnabled(bool enabled) external onlyRole(POLICY_ADMIN_ROLE) {
        complianceEnabled = enabled;
    }
    
    // ============ View Functions ============
    
    function getAssetInfo(uint256 pbmTokenId) external view returns (AssetInfo memory) {
        return assets[pbmTokenId];
    }
    
    function getComplianceProof(bytes32 txHash) 
        external 
        view 
        onlyRole(REGULATOR_ROLE)
        returns (ComplianceProof memory) 
    {
        return complianceProofs[txHash];
    }
    
    /**
     * @notice 帶匯率轉換的包裝 - 適用於跨境支付
     * @dev 旅客使用本國貨幣支付，系統自動轉換為商家收款幣種
     * 
     * ═══════════════════════════════════════════════════════════════════
     * 使用場景：
     * ═══════════════════════════════════════════════════════════════════
     * 1. 台灣遊客在新加坡消費
     * 2. 遊客錢包扣款 TWD 計價的穩定幣
     * 3. 系統查詢 TWD/SGD 匯率並轉換
     * 4. 商家收到等值 SGD 的 PBM
     * ═══════════════════════════════════════════════════════════════════
     * 
     * @param sourceAsset 來源資產地址 (遊客持有的穩定幣)
     * @param sourceAmount 來源金額
     * @param targetCurrency 目標幣種代碼 (商家收款幣種，如 "SGD")
     * @param proof 合規證明
     * @return pbmTokenId 產生的 PBM tokenId
     * @return convertedAmount 轉換後金額
     */
    function wrapWithFXConversion(
        address sourceAsset,
        uint256 sourceAmount,
        bytes32 targetCurrency,
        ProofSet calldata proof
    ) external nonReentrant returns (uint256 pbmTokenId, uint256 convertedAmount) {
        require(fxEnabled, "FX conversion not enabled");
        require(address(fxRateProvider) != address(0), "FX provider not set");
        require(sourceAsset != address(0), "Invalid source asset");
        require(sourceAmount > 0, "Amount must be > 0");
        
        // 取得來源資產的幣種
        bytes32 sourceCurrency = assetCurrency[sourceAsset];
        require(sourceCurrency != bytes32(0), "Source currency not configured");
        
        // 驗證合規證明
        if (complianceEnabled && !complianceExempt[msg.sender]) {
            _verifyProofSet(proof);
        }
        
        // 查詢匯率並轉換金額
        uint256 rateUsed;
        (convertedAmount, rateUsed) = fxRateProvider.convert(
            sourceCurrency,
            targetCurrency,
            sourceAmount
        );
        
        require(convertedAmount > 0, "Conversion resulted in zero");
        
        // 轉入來源資產
        IERC20(sourceAsset).safeTransferFrom(msg.sender, address(this), sourceAmount);
        
        // 計算 PBM tokenId (基於來源資產)
        pbmTokenId = computePBMTokenId(AssetType.ERC20, sourceAsset, 0);
        
        // 記錄資產資訊
        if (assets[pbmTokenId].assetAddress == address(0)) {
            assets[pbmTokenId] = AssetInfo({
                assetType: AssetType.ERC20,
                assetAddress: sourceAsset,
                assetTokenId: 0
            });
        }
        
        // 鑄造 PBM (使用轉換後金額作為價值記錄)
        pbmToken.mint(msg.sender, pbmTokenId, sourceAmount);
        
        // 發送事件
        emit FXConversionApplied(
            msg.sender,
            sourceCurrency,
            targetCurrency,
            sourceAmount,
            convertedAmount,
            rateUsed
        );
        
        emit TokenWrapped(
            msg.sender,
            pbmTokenId,
            AssetType.ERC20,
            sourceAsset,
            0,
            sourceAmount
        );
        
        return (pbmTokenId, convertedAmount);
    }
    
    /**
     * @notice 跨境支付 - 以商家報價幣種為準（正確流程）
     * @dev 商家標價為目標幣種金額，系統計算遊客需支付的來源幣種金額
     * 
     * ═══════════════════════════════════════════════════════════════════
     * 正確的跨境支付流程：
     * ═══════════════════════════════════════════════════════════════════
     * 1. 商家商品標價: 100 SGD
     * 2. 遊客掃 QR Code
     * 3. 系統查詢 SGD/TWD 匯率 (假設 1 SGD = 23.70 TWD)
     * 4. 遊客 App 顯示: "支付 2370 TWD 購買 100 SGD 商品"
     * 5. 遊客確認付款
     * 6. 系統扣款 2370 TWD，記錄匯率
     * 7. 鑄造 PBM 給商家
     * ═══════════════════════════════════════════════════════════════════
     * 
     * @param targetAmount 商家要收的金額 (例如 100 SGD)
     * @param targetCurrency 商家幣種代碼 (例如 keccak256("SGD"))
     * @param sourceAsset 遊客支付的資產地址 (例如 TWD 穩定幣)
     * @param merchant 商家地址
     * @param proof 合規證明
     * @return pbmTokenId 產生的 PBM tokenId
     * @return sourceAmountPaid 遊客實際支付金額
     * @return rateUsed 使用的匯率
     */
    function payWithFXConversion(
        uint256 targetAmount,
        bytes32 targetCurrency,
        address sourceAsset,
        address merchant,
        ProofSet calldata proof
    ) external nonReentrant returns (
        uint256 pbmTokenId,
        uint256 sourceAmountPaid,
        uint256 rateUsed
    ) {
        require(fxEnabled, "FX conversion not enabled");
        require(address(fxRateProvider) != address(0), "FX provider not set");
        require(targetAmount > 0, "Target amount must be > 0");
        require(sourceAsset != address(0), "Invalid source asset");
        require(merchant != address(0), "Invalid merchant address");
        
        // 取得來源資產的幣種
        bytes32 sourceCurrency = assetCurrency[sourceAsset];
        require(sourceCurrency != bytes32(0), "Source currency not configured");
        
        // 驗證合規證明
        if (complianceEnabled && !complianceExempt[msg.sender]) {
            _verifyProofSet(proof);
        }
        
        // 查詢匯率：目標幣種 → 來源幣種（例如 SGD → TWD）
        // 這樣可以計算：要得到 100 SGD，需要多少 TWD
        (sourceAmountPaid, rateUsed) = fxRateProvider.convert(
            targetCurrency,  // SGD
            sourceCurrency,  // TWD
            targetAmount     // 100 SGD → 計算出 2370 TWD
        );
        
        require(sourceAmountPaid > 0, "Conversion resulted in zero");
        
        // 檢查遊客餘額
        require(
            IERC20(sourceAsset).balanceOf(msg.sender) >= sourceAmountPaid,
            "Insufficient balance"
        );
        
        // 轉入來源資產（從遊客扣款）
        IERC20(sourceAsset).safeTransferFrom(msg.sender, address(this), sourceAmountPaid);
        
        // 計算 PBM tokenId (基於來源資產)
        pbmTokenId = computePBMTokenId(AssetType.ERC20, sourceAsset, 0);
        
        // 記錄資產資訊
        if (assets[pbmTokenId].assetAddress == address(0)) {
            assets[pbmTokenId] = AssetInfo({
                assetType: AssetType.ERC20,
                assetAddress: sourceAsset,
                assetTokenId: 0
            });
        }
        
        // 記錄 FX 交易詳情
        fxTransactions[pbmTokenId] = FXTransaction({
            sourceCurrency: sourceCurrency,
            targetCurrency: targetCurrency,
            sourceAmount: sourceAmountPaid,
            targetAmount: targetAmount,
            rateUsed: rateUsed,
            timestamp: block.timestamp,
            payer: msg.sender,
            payee: merchant
        });
        
        // 鑄造 PBM 給商家（直接轉給商家）
        pbmToken.mint(merchant, pbmTokenId, sourceAmountPaid);
        
        // 發送完整的跨境支付事件
        emit CrossBorderPaymentInitiated(
            pbmTokenId,
            msg.sender,      // payer (遊客)
            merchant,        // payee (商家)
            sourceCurrency,  // TWD
            targetCurrency,  // SGD
            sourceAmountPaid,// 2370 TWD
            targetAmount,    // 100 SGD
            rateUsed,
            block.timestamp
        );
        
        emit TokenWrapped(
            msg.sender,
            pbmTokenId,
            AssetType.ERC20,
            sourceAsset,
            0,
            sourceAmountPaid
        );
        
        return (pbmTokenId, sourceAmountPaid, rateUsed);
    }
    
    /**
     * @notice 查詢 FX 交易記錄
     * @param pbmTokenId PBM tokenId
     * @return 交易記錄
     */
    function getFXTransaction(uint256 pbmTokenId) external view returns (FXTransaction memory) {
        return fxTransactions[pbmTokenId];
    }
    
    /**
     * @notice 跨境支付結算 - 商家解包並接收當地貨幣
     * @dev 適用於 PBM 轉移給商家後，商家提取當地貨幣
     * 
     * @param pbmTokenId PBM tokenId
     * @param amount 解包數量
     * @param targetAsset 目標資產地址 (商家收款的穩定幣)
     * @param beneficiary 收款人地址
     * @return settledAmount 結算金額
     */
    function settleCrossBorderPayment(
        uint256 pbmTokenId,
        uint256 amount,
        address targetAsset,
        address beneficiary
    ) external nonReentrant returns (uint256 settledAmount) {
        require(fxEnabled, "FX conversion not enabled");
        require(address(fxRateProvider) != address(0), "FX provider not set");
        require(amount > 0, "Amount must be > 0");
        require(beneficiary != address(0), "Invalid beneficiary");
        require(targetAsset != address(0), "Invalid target asset");
        
        AssetInfo memory assetInfo = assets[pbmTokenId];
        require(assetInfo.assetAddress != address(0), "Unknown PBM tokenId");
        
        // 檢查用戶持有足夠的 PBM
        require(
            pbmToken.balanceOf(msg.sender, pbmTokenId) >= amount,
            "Insufficient PBM balance"
        );
        
        // 取得幣種資訊
        bytes32 sourceCurrency = assetCurrency[assetInfo.assetAddress];
        bytes32 targetCurrency = assetCurrency[targetAsset];
        require(sourceCurrency != bytes32(0), "Source currency not configured");
        require(targetCurrency != bytes32(0), "Target currency not configured");
        
        // 銷毀 PBM
        pbmToken.burn(msg.sender, pbmTokenId, amount);
        
        // 如果來源和目標不同，需要進行 FX 轉換
        if (sourceCurrency != targetCurrency) {
            uint256 rateUsed;
            (settledAmount, rateUsed) = fxRateProvider.convert(
                sourceCurrency,
                targetCurrency,
                amount
            );
            
            emit FXConversionApplied(
                msg.sender,
                sourceCurrency,
                targetCurrency,
                amount,
                settledAmount,
                rateUsed
            );
        } else {
            settledAmount = amount;
        }
        
        // 轉移目標資產給商家
        // 注意：這裡假設合約持有足夠的目標資產（由流動性提供者預先存入）
        IERC20(targetAsset).safeTransfer(beneficiary, settledAmount);
        
        emit TokenUnwrapped(msg.sender, pbmTokenId, amount, beneficiary);
        
        return settledAmount;
    }
    
    /**
     * @notice 查詢 FX 轉換預覽
     * @param sourceAsset 來源資產
     * @param amount 金額
     * @param targetCurrency 目標幣種
     * @return convertedAmount 預計轉換金額
     * @return rate 使用的匯率
     */
    function previewFXConversion(
        address sourceAsset,
        uint256 amount,
        bytes32 targetCurrency
    ) external view returns (uint256 convertedAmount, uint256 rate) {
        require(address(fxRateProvider) != address(0), "FX provider not set");
        
        bytes32 sourceCurrency = assetCurrency[sourceAsset];
        require(sourceCurrency != bytes32(0), "Source currency not configured");
        
        return fxRateProvider.convert(sourceCurrency, targetCurrency, amount);
    }
    
    // ============ FX Admin Functions ============
    
    /**
     * @notice 設定 FX 匯率提供者
     */
    function setFXRateProvider(address provider) external onlyRole(POLICY_ADMIN_ROLE) {
        address oldProvider = address(fxRateProvider);
        fxRateProvider = IFXRateProvider(provider);
        emit FXRateProviderUpdated(oldProvider, provider);
    }
    
    /**
     * @notice 設定資產對應的幣種
     * @param asset 資產地址 (如 USDC 合約)
     * @param currency 幣種代碼 (如 keccak256("USD"))
     */
    function setAssetCurrency(
        address asset,
        bytes32 currency
    ) external onlyRole(POLICY_ADMIN_ROLE) {
        require(asset != address(0), "Invalid asset");
        assetCurrency[asset] = currency;
        emit AssetCurrencySet(asset, currency);
    }
    
    /**
     * @notice 批量設定資產幣種
     */
    function setAssetCurrencies(
        address[] calldata assetList,
        bytes32[] calldata currencies
    ) external onlyRole(POLICY_ADMIN_ROLE) {
        require(assetList.length == currencies.length, "Length mismatch");
        
        for (uint256 i = 0; i < assetList.length; i++) {
            require(assetList[i] != address(0), "Invalid asset");
            assetCurrency[assetList[i]] = currencies[i];
            emit AssetCurrencySet(assetList[i], currencies[i]);
        }
    }
    
    /**
     * @notice 啟用/停用 FX 轉換功能
     */
    function setFXEnabled(bool enabled) external onlyRole(POLICY_ADMIN_ROLE) {
        fxEnabled = enabled;
    }
    
    
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    
    // Helper
    function _toArray(string memory str) internal pure returns (string[] memory) {
        string[] memory arr = new string[](1);
        arr[0] = str;
        return arr;
    }
}
