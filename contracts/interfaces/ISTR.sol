// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISTR
 * @notice CAST Settlement Transaction Repository (STR) on-chain pointer interface
 * @dev STR is off-chain; on-chain only stores hashes/URIs and settlement state pointers.
 */
interface ISTR {
    enum SettlementStatus {
        NONE,
        INITIATED,
        LOCKED,
        RELEASED,
        CANCELLED
    }

    struct STRRecord {
        bytes32 strId;
        bytes32 offchainHash;
        string uri;
        address registrar;
        uint256 createdAt;
        uint256 updatedAt;
        SettlementStatus status;
        bytes32 onchainTx;
    }

    event STRRegistered(
        bytes32 indexed strId,
        bytes32 indexed offchainHash,
        string uri,
        address indexed registrar,
        uint256 timestamp
    );

    event STRHashUpdated(
        bytes32 indexed strId,
        bytes32 indexed newOffchainHash,
        string uri,
        uint256 timestamp
    );

    event STRStatusUpdated(
        bytes32 indexed strId,
        SettlementStatus status,
        uint256 timestamp
    );

    event STROnchainLinked(
        bytes32 indexed strId,
        bytes32 indexed onchainTx,
        uint256 timestamp
    );

    function registerSTR(
        bytes32 strId,
        bytes32 offchainHash,
        string calldata uri,
        bytes32 onchainTx,
        SettlementStatus status
    ) external;

    function updateSTRHash(
        bytes32 strId,
        bytes32 newOffchainHash,
        string calldata uri
    ) external;

    function updateSTRStatus(
        bytes32 strId,
        SettlementStatus status
    ) external;

    function linkOnchainTx(bytes32 strId, bytes32 onchainTx) external;

    function getSTR(bytes32 strId) external view returns (STRRecord memory);
}
