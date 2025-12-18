// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IRepoContract
 * @notice GL1 Repurchase Agreement (Repo) 合約介面
 * @dev 定義 Repo 交易的標準介面，支援多方原子交換與合規驗證
 * 
 * ═══════════════════════════════════════════════════════════════════
 * Repo 交易流程：
 * ═══════════════════════════════════════════════════════════════════
 * 1. Borrower 發起 Repo → 提供抵押品換取現金
 * 2. Lender 接受 Repo → 提供現金獲得抵押品擔保
 * 3. 到期結算 → Borrower 還款 + 利息，取回抵押品
 * ═══════════════════════════════════════════════════════════════════
 */
interface IRepoContract {
    
    // ============ 枚舉類型 ============
    
    /**
     * @notice 參與方角色
     */
    enum PartyRole {
        NONE,       // 未指定
        LENDER,     // 貸款人 (提供現金，接收抵押品)
        BORROWER    // 借款人 (提供抵押品，接收現金)
    }
    
    /**
     * @notice Repo 交易狀態
     */
    enum RepoState {
        NONE,           // 不存在
        INITIATED,      // 已發起，等待雙方注資
        BORROWER_FUNDED,// Borrower 已存入抵押品
        LENDER_FUNDED,  // Lender 已存入現金
        FUNDED,         // 雙方都已注資，可執行交換
        EXECUTED,       // 已執行原子交換
        SETTLED,        // 已完成結算
        DEFAULTED,      // 違約
        CANCELLED       // 已取消
    }
    
    // ============ 結構體 ============
    
    /**
     * @notice Repo 協議詳情
     */
    struct RepoAgreement {
        // 基本信息
        bytes32 repoId;             // 唯一識別碼
        RepoState state;            // 當前狀態
        
        // 參與方
        address borrower;           // 借款人
        address lender;             // 貸款人
        
        // 現金部分 (Lender 提供)
        uint256 cashPbmTokenId;     // 現金 PBM tokenId
        uint256 cashAmount;         // 現金金額
        
        // 抵押品部分 (Borrower 提供)
        uint256 collateralPbmTokenId;   // 抵押品 PBM tokenId
        uint256 collateralAmount;       // 抵押品數量
        
        // 利率與時間
        uint256 repoRate;           // 年化利率 (以 basis points 表示, 500 = 5%)
        uint256 initiatedAt;        // 發起時間
        uint256 maturityDate;       // 到期日
        uint256 gracePeriod;        // 寬限期 (秒)
        
        // 結算資訊
        uint256 settlementAmount;   // 結算金額 (本金 + 利息)
        uint256 settledAt;          // 實際結算時間
    }
    
    // ============ 事件 ============
    
    event RepoInitiated(
        bytes32 indexed repoId,
        address indexed borrower,
        uint256 cashAmount,
        uint256 collateralAmount,
        uint256 maturityDate
    );
    
    event RepoFunded(
        bytes32 indexed repoId,
        address indexed party,
        PartyRole role,
        uint256 amount
    );
    
    event RepoExecuted(
        bytes32 indexed repoId,
        address indexed borrower,
        address indexed lender,
        uint256 cashAmount,
        uint256 collateralAmount,
        uint256 timestamp
    );
    
    event RepoSettled(
        bytes32 indexed repoId,
        uint256 principalAmount,
        uint256 interestAmount,
        uint256 totalSettled,
        uint256 timestamp
    );
    
    event RepoDefaulted(
        bytes32 indexed repoId,
        address indexed defaulter,
        uint256 collateralClaimed,
        uint256 timestamp
    );
    
    event RepoCancelled(
        bytes32 indexed repoId,
        address indexed cancelledBy,
        string reason
    );
    
    // ============ 核心函數 ============
    
    /**
     * @notice 發起 Repo 交易
     * @param cashAmount 需要借入的現金金額
     * @param collateralPbmTokenId 抵押品的 PBM tokenId
     * @param collateralAmount 抵押品數量
     * @param repoRate 年化利率 (basis points)
     * @param durationSeconds 期限 (秒)
     * @param lender 指定的貸款人地址 (可選，address(0) 表示任何人)
     * @return repoId 產生的 Repo ID
     */
    function initiateRepo(
        uint256 cashAmount,
        uint256 collateralPbmTokenId,
        uint256 collateralAmount,
        uint256 repoRate,
        uint256 durationSeconds,
        address lender
    ) external returns (bytes32 repoId);
    
    /**
     * @notice Borrower 存入抵押品
     * @param repoId Repo ID
     */
    function fundAsBorrower(bytes32 repoId) external;
    
    /**
     * @notice Lender 存入現金
     * @param repoId Repo ID
     * @param cashPbmTokenId 現金 PBM tokenId
     */
    function fundAsLender(bytes32 repoId, uint256 cashPbmTokenId) external;
    
    /**
     * @notice 執行原子交換
     * @param repoId Repo ID
     */
    function executeRepo(bytes32 repoId) external;
    
    /**
     * @notice 結算 Repo (到期還款)
     * @param repoId Repo ID
     * @param repaymentPbmTokenId 還款使用的 PBM tokenId
     */
    function settleRepo(bytes32 repoId, uint256 repaymentPbmTokenId) external;
    
    /**
     * @notice 取消未完成的 Repo
     * @param repoId Repo ID
     */
    function cancelRepo(bytes32 repoId) external;
    
    /**
     * @notice Lender 在違約後認領抵押品
     * @param repoId Repo ID
     */
    function claimCollateral(bytes32 repoId) external;
    
    // ============ 查詢函數 ============
    
    /**
     * @notice 取得 Repo 協議詳情
     * @param repoId Repo ID
     * @return agreement Repo 協議結構
     */
    function getRepoAgreement(bytes32 repoId) external view returns (RepoAgreement memory agreement);
    
    /**
     * @notice 計算結算金額
     * @param repoId Repo ID
     * @return principal 本金
     * @return interest 利息
     * @return total 總結算金額
     */
    function calculateSettlementAmount(bytes32 repoId) external view returns (
        uint256 principal,
        uint256 interest,
        uint256 total
    );
    
    /**
     * @notice 檢查 Repo 是否已違約
     * @param repoId Repo ID
     * @return isDefaulted 是否違約
     */
    function isDefaulted(bytes32 repoId) external view returns (bool isDefaulted);
}
