// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Redeem {
    struct Redemption {
        mapping(uint256 => uint256) redemptionStartTimes; // Tracks when each token's redemption starts
        uint256 redemptionPeriod; // The required waiting period for redemption
    }

    /**
     * @notice Initializes the redemption process with a specific waiting period.
     * @param redemption The Redemption struct to initialize.
     * @param _redemptionPeriod The period to wait before allowing redemption, in seconds.
     */
    function initialize(Redemption storage redemption, uint256 _redemptionPeriod) internal {
        redemption.redemptionPeriod = _redemptionPeriod;
    }

    /**
     * @notice Starts the redemption process for a given token.
     * @param redemption The Redemption struct.
     * @param tokenId The token ID for which to start the redemption.
     */
    function startRedemption(Redemption storage redemption, uint256 tokenId) internal {
        require(redemption.redemptionStartTimes[tokenId] == 0, "Redemption already started");
        redemption.redemptionStartTimes[tokenId] = block.timestamp;
    }

    /**
     * @notice Checks if the redemption period has passed for a given token, allowing for its claim.
     * @param redemption The Redemption struct.
     * @param tokenId The token ID to check for redemption eligibility.
     * @return bool True if the token is eligible for redemption, false otherwise.
     */
    function canRedeem(Redemption storage redemption, uint256 tokenId) internal view returns (bool) {
        uint256 startTime = redemption.redemptionStartTimes[tokenId];
        return (startTime != 0 && block.timestamp >= startTime + redemption.redemptionPeriod);
    }

    /**
     * @notice Clears the redemption data for a given token, typically after successful redemption.
     * @param redemption The Redemption struct.
     * @param tokenId The token ID whose redemption data is to be cleared.
     */
    function clearRedemption(Redemption storage redemption, uint256 tokenId) internal {
        delete redemption.redemptionStartTimes[tokenId];
    }
}
