// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8;

import "./PriceOracle.sol";

interface BasePriceOracle is PriceOracle {
    /**
     * @notice Get the underlying price of a cToken asset
     * @param cToken The cToken to get the underlying price of
     * @return The underlying asset price mantissa (scaled by 1e18).
     *  Zero means the price is unavailable.
     */
    function getUnderlyingPrice(address cToken) external view returns (uint256);

    /**
     * @notice Get the base currency of the oracle
     * @return The base currency against all currencies are priced against.
     */
    function baseCurrency() external view returns (address);
}
