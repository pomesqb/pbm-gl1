// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "../interfaces/IRepoContract.sol";
import "../interfaces/IPolicyManager.sol";
import "../token/PBMToken.sol";

/**
 * @title RepoContract
 * @notice GL1 Repurchase Agreement (Repo) 合約實作
 * @dev 實作完整的 Repo 交易生命週期，包含原子交換與合規驗證
 * 
 * ═══════════════════════════════════════════════════════════════════
 * Repo 交易流程：
 * ═══════════════════════════════════════════════════════════════════
 * 1. Borrower 發起 Repo (initiateRepo)
 * 2. Borrower 存入抵押品 (fundAsBorrower)
 * 3. Lender 存入現金 (fundAsLender)
 * 4. 執行原子交換 (executeRepo)
 * 5. 到期結算 (settleRepo) 或 違約處理 (claimCollateral)
 * ═══════════════════════════════════════════════════════════════════
 */
contract RepoContract is IRepoContract, AccessControl, ReentrancyGuard {
    
    bytes32 public constant REPO_ADMIN_ROLE = keccak256("REPO_ADMIN_ROLE");
    
    // PBM Token 合約
    PBMToken public pbmToken;
    
    // Policy Manager 合約
    IPolicyManager public policyManager;
    
    // 司法管轄區
    bytes32 public jurisdictionCode;
    
    // Repo 協議儲存
    mapping(bytes32 => RepoAgreement) public repos;
    
    // 用戶的活躍 Repo 列表
    mapping(address => bytes32[]) public userRepos;
    
    // 預設寬限期 (3 天)
    uint256 public constant DEFAULT_GRACE_PERIOD = 3 days;
    
    // 最大利率 (50% APY)
    uint256 public constant MAX_REPO_RATE = 5000;
    
    // RepoId 計數器
    uint256 private repoNonce;
    
    // ============ 錯誤定義 ============
    
    error InvalidAmount();
    error InvalidDuration();
    error InvalidRate();
    error RepoNotFound();
    error InvalidState(RepoState expected, RepoState actual);
    error NotAuthorized();
    error AlreadyFunded();
    error NotMatured();
    error AlreadyMatured();
    error NotDefaulted();
    error ComplianceFailed(string reason);
    
    // ============ 建構子 ============
    
    constructor(
        address _pbmToken,
        address _policyManager,
        bytes32 _jurisdictionCode
    ) {
        pbmToken = PBMToken(_pbmToken);
        policyManager = IPolicyManager(_policyManager);
        jurisdictionCode = _jurisdictionCode;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(REPO_ADMIN_ROLE, msg.sender);
    }
    
    // ============ 核心函數 ============
    
    /**
     * @notice 發起 Repo 交易
     */
    function initiateRepo(
        uint256 cashAmount,
        uint256 collateralPbmTokenId,
        uint256 collateralAmount,
        uint256 repoRate,
        uint256 durationSeconds,
        address lender
    ) external override nonReentrant returns (bytes32 repoId) {
        // 驗證參數
        if (cashAmount == 0 || collateralAmount == 0) revert InvalidAmount();
        if (durationSeconds == 0 || durationSeconds > 365 days) revert InvalidDuration();
        if (repoRate > MAX_REPO_RATE) revert InvalidRate();
        
        // 產生唯一 repoId
        repoId = keccak256(abi.encodePacked(
            msg.sender,
            cashAmount,
            collateralPbmTokenId,
            block.timestamp,
            repoNonce++
        ));
        
        // 創建 Repo 協議
        repos[repoId] = RepoAgreement({
            repoId: repoId,
            state: RepoState.INITIATED,
            borrower: msg.sender,
            lender: lender, // 可為 address(0) 表示開放給任何人
            cashPbmTokenId: 0, // Lender 注資時設定
            cashAmount: cashAmount,
            collateralPbmTokenId: collateralPbmTokenId,
            collateralAmount: collateralAmount,
            repoRate: repoRate,
            initiatedAt: block.timestamp,
            maturityDate: block.timestamp + durationSeconds,
            gracePeriod: DEFAULT_GRACE_PERIOD,
            settlementAmount: 0,
            settledAt: 0
        });
        
        // 記錄用戶 Repo
        userRepos[msg.sender].push(repoId);
        if (lender != address(0)) {
            userRepos[lender].push(repoId);
        }
        
        emit RepoInitiated(
            repoId,
            msg.sender,
            cashAmount,
            collateralAmount,
            block.timestamp + durationSeconds
        );
        
        return repoId;
    }
    
    /**
     * @notice Borrower 存入抵押品
     */
    function fundAsBorrower(bytes32 repoId) external override nonReentrant {
        RepoAgreement storage repo = repos[repoId];
        
        // 驗證狀態
        if (repo.repoId == bytes32(0)) revert RepoNotFound();
        if (msg.sender != repo.borrower) revert NotAuthorized();
        if (repo.state != RepoState.INITIATED && repo.state != RepoState.LENDER_FUNDED) {
            revert InvalidState(RepoState.INITIATED, repo.state);
        }
        
        // 檢查 Borrower 持有足夠的抵押品 PBM
        uint256 balance = pbmToken.balanceOf(msg.sender, repo.collateralPbmTokenId);
        if (balance < repo.collateralAmount) revert InvalidAmount();
        
        // 執行身份驗證（簡化版，實際應調用 PolicyManager）
        (bool identityValid, string memory identityError) = policyManager.verifyIdentity(
            msg.sender,
            address(this),
            jurisdictionCode
        );
        if (!identityValid) revert ComplianceFailed(identityError);
        
        // 轉入抵押品 PBM
        pbmToken.safeTransferFrom(
            msg.sender,
            address(this),
            repo.collateralPbmTokenId,
            repo.collateralAmount,
            ""
        );
        
        // 更新狀態
        if (repo.state == RepoState.LENDER_FUNDED) {
            repo.state = RepoState.FUNDED;
        } else {
            repo.state = RepoState.BORROWER_FUNDED;
        }
        
        emit RepoFunded(repoId, msg.sender, PartyRole.BORROWER, repo.collateralAmount);
    }
    
    /**
     * @notice Lender 存入現金
     */
    function fundAsLender(bytes32 repoId, uint256 cashPbmTokenId) external override nonReentrant {
        RepoAgreement storage repo = repos[repoId];
        
        // 驗證狀態
        if (repo.repoId == bytes32(0)) revert RepoNotFound();
        
        // 檢查 Lender 是否被指定
        if (repo.lender != address(0) && repo.lender != msg.sender) {
            revert NotAuthorized();
        }
        
        if (repo.state != RepoState.INITIATED && repo.state != RepoState.BORROWER_FUNDED) {
            revert InvalidState(RepoState.INITIATED, repo.state);
        }
        
        // 如果 Lender 未被事先指定，設定為當前調用者
        if (repo.lender == address(0)) {
            repo.lender = msg.sender;
            userRepos[msg.sender].push(repoId);
        }
        
        // 檢查 Lender 持有足夠的現金 PBM
        uint256 balance = pbmToken.balanceOf(msg.sender, cashPbmTokenId);
        if (balance < repo.cashAmount) revert InvalidAmount();
        
        // 執行身份驗證
        (bool identityValid, string memory identityError) = policyManager.verifyIdentity(
            msg.sender,
            address(this),
            jurisdictionCode
        );
        if (!identityValid) revert ComplianceFailed(identityError);
        
        // 設定現金 PBM tokenId
        repo.cashPbmTokenId = cashPbmTokenId;
        
        // 轉入現金 PBM
        pbmToken.safeTransferFrom(
            msg.sender,
            address(this),
            cashPbmTokenId,
            repo.cashAmount,
            ""
        );
        
        // 更新狀態
        if (repo.state == RepoState.BORROWER_FUNDED) {
            repo.state = RepoState.FUNDED;
        } else {
            repo.state = RepoState.LENDER_FUNDED;
        }
        
        emit RepoFunded(repoId, msg.sender, PartyRole.LENDER, repo.cashAmount);
    }
    
    /**
     * @notice 執行原子交換
     */
    function executeRepo(bytes32 repoId) external override nonReentrant {
        RepoAgreement storage repo = repos[repoId];
        
        // 驗證狀態
        if (repo.repoId == bytes32(0)) revert RepoNotFound();
        if (repo.state != RepoState.FUNDED) {
            revert InvalidState(RepoState.FUNDED, repo.state);
        }
        
        // 只有參與方可以執行
        if (msg.sender != repo.borrower && msg.sender != repo.lender) {
            revert NotAuthorized();
        }
        
        // 執行原子交換
        // 1. 抵押品從本合約轉給 Lender
        pbmToken.safeTransferFrom(
            address(this),
            repo.lender,
            repo.collateralPbmTokenId,
            repo.collateralAmount,
            ""
        );
        
        // 2. 現金從本合約轉給 Borrower
        pbmToken.safeTransferFrom(
            address(this),
            repo.borrower,
            repo.cashPbmTokenId,
            repo.cashAmount,
            ""
        );
        
        // 更新狀態
        repo.state = RepoState.EXECUTED;
        
        emit RepoExecuted(
            repoId,
            repo.borrower,
            repo.lender,
            repo.cashAmount,
            repo.collateralAmount,
            block.timestamp
        );
    }
    
    /**
     * @notice 結算 Repo (到期還款)
     */
    function settleRepo(bytes32 repoId, uint256 repaymentPbmTokenId) external override nonReentrant {
        RepoAgreement storage repo = repos[repoId];
        
        // 驗證狀態
        if (repo.repoId == bytes32(0)) revert RepoNotFound();
        if (repo.state != RepoState.EXECUTED) {
            revert InvalidState(RepoState.EXECUTED, repo.state);
        }
        if (msg.sender != repo.borrower) revert NotAuthorized();
        
        // 計算結算金額
        (uint256 principal, uint256 interest, uint256 total) = calculateSettlementAmount(repoId);
        
        // 檢查 Borrower 持有足夠的還款 PBM
        uint256 balance = pbmToken.balanceOf(msg.sender, repaymentPbmTokenId);
        if (balance < total) revert InvalidAmount();
        
        // Borrower 還款給 Lender
        pbmToken.safeTransferFrom(
            msg.sender,
            repo.lender,
            repaymentPbmTokenId,
            total,
            ""
        );
        
        // Lender 歸還抵押品給 Borrower
        pbmToken.safeTransferFrom(
            repo.lender,
            msg.sender,
            repo.collateralPbmTokenId,
            repo.collateralAmount,
            ""
        );
        
        // 更新狀態
        repo.state = RepoState.SETTLED;
        repo.settlementAmount = total;
        repo.settledAt = block.timestamp;
        
        emit RepoSettled(repoId, principal, interest, total, block.timestamp);
    }
    
    /**
     * @notice 取消未完成的 Repo
     */
    function cancelRepo(bytes32 repoId) external override nonReentrant {
        RepoAgreement storage repo = repos[repoId];
        
        if (repo.repoId == bytes32(0)) revert RepoNotFound();
        
        // 只有在未完全注資前可以取消
        if (repo.state == RepoState.FUNDED || 
            repo.state == RepoState.EXECUTED ||
            repo.state == RepoState.SETTLED ||
            repo.state == RepoState.DEFAULTED) {
            revert InvalidState(RepoState.INITIATED, repo.state);
        }
        
        // 只有參與方可以取消
        if (msg.sender != repo.borrower && msg.sender != repo.lender) {
            revert NotAuthorized();
        }
        
        // 退還已存入的資產
        if (repo.state == RepoState.BORROWER_FUNDED) {
            // 退還抵押品給 Borrower
            pbmToken.safeTransferFrom(
                address(this),
                repo.borrower,
                repo.collateralPbmTokenId,
                repo.collateralAmount,
                ""
            );
        } else if (repo.state == RepoState.LENDER_FUNDED) {
            // 退還現金給 Lender
            pbmToken.safeTransferFrom(
                address(this),
                repo.lender,
                repo.cashPbmTokenId,
                repo.cashAmount,
                ""
            );
        }
        
        repo.state = RepoState.CANCELLED;
        
        emit RepoCancelled(repoId, msg.sender, "Cancelled by participant");
    }
    
    /**
     * @notice Lender 在違約後認領抵押品
     */
    function claimCollateral(bytes32 repoId) external override nonReentrant {
        RepoAgreement storage repo = repos[repoId];
        
        if (repo.repoId == bytes32(0)) revert RepoNotFound();
        if (repo.state != RepoState.EXECUTED) {
            revert InvalidState(RepoState.EXECUTED, repo.state);
        }
        if (msg.sender != repo.lender) revert NotAuthorized();
        
        // 檢查是否已違約（超過到期日 + 寬限期）
        if (!_isDefaulted(repo)) revert NotDefaulted();
        
        // 注意：抵押品已在執行時轉給 Lender，此處只更新狀態
        repo.state = RepoState.DEFAULTED;
        
        emit RepoDefaulted(
            repoId,
            repo.borrower,
            repo.collateralAmount,
            block.timestamp
        );
    }
    
    // ============ 查詢函數 ============
    
    /**
     * @notice 取得 Repo 協議詳情
     */
    function getRepoAgreement(bytes32 repoId) external view override returns (RepoAgreement memory) {
        return repos[repoId];
    }
    
    /**
     * @notice 計算結算金額
     */
    function calculateSettlementAmount(bytes32 repoId) public view override returns (
        uint256 principal,
        uint256 interest,
        uint256 total
    ) {
        RepoAgreement memory repo = repos[repoId];
        
        principal = repo.cashAmount;
        
        // 計算利息：principal * rate * duration / (365 days * 10000)
        uint256 duration = block.timestamp > repo.maturityDate 
            ? repo.maturityDate - repo.initiatedAt 
            : block.timestamp - repo.initiatedAt;
        
        interest = (principal * repo.repoRate * duration) / (365 days * 10000);
        total = principal + interest;
    }
    
    /**
     * @notice 檢查 Repo 是否已違約
     */
    function isDefaulted(bytes32 repoId) external view override returns (bool) {
        RepoAgreement memory repo = repos[repoId];
        return _isDefaulted(repo);
    }
    
    function _isDefaulted(RepoAgreement memory repo) internal view returns (bool) {
        if (repo.state != RepoState.EXECUTED) return false;
        return block.timestamp > repo.maturityDate + repo.gracePeriod;
    }
    
    /**
     * @notice 取得用戶的所有 Repo
     */
    function getUserRepos(address user) external view returns (bytes32[] memory) {
        return userRepos[user];
    }
    
    // ============ 管理函數 ============
    
    /**
     * @notice 更新 Policy Manager
     */
    function updatePolicyManager(address newManager) external onlyRole(REPO_ADMIN_ROLE) {
        require(newManager != address(0), "Invalid address");
        policyManager = IPolicyManager(newManager);
    }
    
    /**
     * @notice 更新管轄區
     */
    function updateJurisdiction(bytes32 newJurisdiction) external onlyRole(REPO_ADMIN_ROLE) {
        jurisdictionCode = newJurisdiction;
    }
    
    // ============ ERC1155 接收器 ============
    
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
}
