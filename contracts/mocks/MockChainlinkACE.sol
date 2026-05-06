// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IChainlinkACE.sol";

/**
 * @title MockChainlinkACE
 * @notice 測試用的 Chainlink ACE 模擬合約，永遠回傳合規通過。
 * @dev 用於 gas benchmark；不阻擋任何交易、不提供真實制裁名單檢查。
 */
contract MockChainlinkACE is IChainlinkACE {
    function checkSanctionsList(
        address /* from */,
        address /* to */
    ) external pure override returns (bool) {
        return true;
    }

    function verifyTransactionCompliance(
        address /* from */,
        address /* to */,
        uint256 /* amount */,
        bytes32 /* jurisdiction */
    ) external pure override returns (bool isCompliant, string memory reason) {
        return (true, "");
    }

    function getRiskScore(
        address /* account */
    ) external pure override returns (uint256) {
        return 0;
    }
}
