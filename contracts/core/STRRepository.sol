// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/ISTR.sol";

/**
 * @title STRRepository
 * @notice On-chain pointer registry for CAST Settlement Transaction Repository (STR)
 * @dev Stores only hashes/URIs and settlement status for off-chain STR records.
 */
contract STRRepository is ISTR, AccessControl {
    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    mapping(bytes32 => STRRecord) private records;

    error STRAlreadyExists(bytes32 strId);
    error STRNotFound(bytes32 strId);
    error InvalidSTRHash();

    constructor(address registrar) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        if (registrar != address(0)) {
            _grantRole(REGISTRAR_ROLE, registrar);
        }
    }

    /**
     * @notice Register a new STR pointer
     */
    function registerSTR(
        bytes32 strId,
        bytes32 offchainHash,
        string calldata uri,
        bytes32 onchainTx,
        SettlementStatus status
    ) external override onlyRole(REGISTRAR_ROLE) {
        if (records[strId].strId != bytes32(0)) revert STRAlreadyExists(strId);
        if (offchainHash == bytes32(0)) revert InvalidSTRHash();

        records[strId] = STRRecord({
            strId: strId,
            offchainHash: offchainHash,
            uri: uri,
            registrar: msg.sender,
            createdAt: block.timestamp,
            updatedAt: block.timestamp,
            status: status,
            onchainTx: onchainTx
        });

        emit STRRegistered(strId, offchainHash, uri, msg.sender, block.timestamp);

        if (onchainTx != bytes32(0)) {
            emit STROnchainLinked(strId, onchainTx, block.timestamp);
        }

        emit STRStatusUpdated(strId, status, block.timestamp);
    }

    /**
     * @notice Update STR off-chain hash/URI (e.g., BCP reconciliation)
     */
    function updateSTRHash(
        bytes32 strId,
        bytes32 newOffchainHash,
        string calldata uri
    ) external override onlyRole(REGISTRAR_ROLE) {
        STRRecord storage record = records[strId];
        if (record.strId == bytes32(0)) revert STRNotFound(strId);
        if (newOffchainHash == bytes32(0)) revert InvalidSTRHash();

        record.offchainHash = newOffchainHash;
        record.uri = uri;
        record.updatedAt = block.timestamp;

        emit STRHashUpdated(strId, newOffchainHash, uri, block.timestamp);
    }

    /**
     * @notice Update settlement status workflow
     */
    function updateSTRStatus(
        bytes32 strId,
        SettlementStatus status
    ) external override onlyRole(REGISTRAR_ROLE) {
        STRRecord storage record = records[strId];
        if (record.strId == bytes32(0)) revert STRNotFound(strId);

        record.status = status;
        record.updatedAt = block.timestamp;

        emit STRStatusUpdated(strId, status, block.timestamp);
    }

    /**
     * @notice Link an on-chain transaction hash to STR record
     */
    function linkOnchainTx(
        bytes32 strId,
        bytes32 onchainTx
    ) external override onlyRole(REGISTRAR_ROLE) {
        STRRecord storage record = records[strId];
        if (record.strId == bytes32(0)) revert STRNotFound(strId);

        record.onchainTx = onchainTx;
        record.updatedAt = block.timestamp;

        emit STROnchainLinked(strId, onchainTx, block.timestamp);
    }

    /**
     * @notice Fetch STR pointer record
     */
    function getSTR(bytes32 strId) external view override returns (STRRecord memory) {
        return records[strId];
    }
}
