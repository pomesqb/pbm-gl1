// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IGL1PolicyWrapper
 * @notice GL1 Policy Wrapper 介面 - PBM 風格
 * @dev 定義 wrap/unwrap 和合規檢查的標準介面
 */
interface IGL1PolicyWrapper {
    
    /// @notice 底層資產類型
    enum AssetType {
        ERC20,
        ERC721,
        ERC1155
    }
    
    /// @notice 合規證明集
    struct ProofSet {
        bytes32 proofType;        // "KYC", "AML", "ACCREDITATION"
        bytes32 credentialHash;   // 鏈下憑證的雜湊
        uint256 issuedAt;         // 發行時間
        uint256 expiresAt;        // 過期時間
        address issuer;           // 發行機構
        bytes signature;          // 發行機構簽名
    }
    
    /// @notice 底層資產資訊
    struct AssetInfo {
        AssetType assetType;
        address assetAddress;
        uint256 assetTokenId;     // ERC20 用 0
    }
    
    /**
     * @notice 包裝底層資產
     * @param assetType 資產類型 (ERC20/ERC721/ERC1155)
     * @param assetAddress 底層資產合約地址
     * @param assetTokenId 底層 tokenId (ERC20 傳 0)
     * @param amount 數量 (ERC721 傳 1)
     * @param proof 合規證明
     * @return pbmTokenId 產生的 PBM tokenId
     */
    function wrap(
        AssetType assetType,
        address assetAddress,
        uint256 assetTokenId,
        uint256 amount,
        ProofSet calldata proof
    ) external returns (uint256 pbmTokenId);
    
    /**
     * @notice 解包取回底層資產
     * @param pbmTokenId PBM tokenId
     * @param amount 數量
     * @param beneficiary 接收底層資產的地址
     */
    function unwrap(
        uint256 pbmTokenId,
        uint256 amount,
        address beneficiary
    ) external;
    
    /**
     * @notice 檢查轉移合規性
     * @param from 發送方
     * @param to 接收方
     * @param tokenId PBM tokenId
     * @param amount 數量
     * @return isCompliant 是否合規
     * @return reason 原因
     */
    function checkTransferCompliance(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) external returns (bool isCompliant, string memory reason);
    
    // Events
    event TokenWrapped(
        address indexed user,
        uint256 indexed pbmTokenId,
        AssetType assetType,
        address assetAddress,
        uint256 assetTokenId,
        uint256 amount
    );
    
    event TokenUnwrapped(
        address indexed user,
        uint256 indexed pbmTokenId,
        uint256 amount,
        address indexed beneficiary
    );
}
