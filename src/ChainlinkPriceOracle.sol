// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../external/chainlink/AggregatorV3Interface.sol";

import "./interfaces/PriceOracle.sol";
import "./interfaces/BasePriceOracle.sol";

/**
 * @title ChainlinkPriceOracle
 * @notice Returns prices from Chainlink.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * Changes by Citrus team:
 * - remove hardcoded base currencies, uses the master oracle instead
 */
contract ChainlinkPriceOracle is PriceOracle {
    /**
     * @notice Maps ERC20 token addresses to ETH-based Chainlink price feed contracts.
     */
    mapping(address => AggregatorV3Interface) public priceFeeds;

    /**
     * @notice Maps ERC20 token addresses to enums indicating the base currency of the feed.
     */
    mapping(address => address) public feedBaseCurrencies;

    /**
     * @dev The administrator of this `MasterPriceOracle`.
     */
    address public admin;

    /**
     * @dev Constructor to set admin and canAdminOverwrite.
     */
    constructor(address _admin) {
        admin = _admin;
    }

    /**
     * @dev Changes the admin and emits an event.
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        address oldAdmin = admin;
        admin = newAdmin;
        emit NewAdmin(oldAdmin, newAdmin);
    }

    /**
     * @dev Event emitted when `admin` is changed.
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
     * @dev Modifier that checks if `msg.sender == admin`.
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Sender is not the admin.");
        _;
    }

    /**
     * @dev Admin-only function to set price feeds.
     * @param underlyings Underlying token addresses for which to set price feeds.
     * @param feeds The Chainlink price feed contract addresses for each of `underlyings`.
     * @param baseCurrency The currency in which `feeds` are based.
     */
    function setPriceFeeds(address[] memory underlyings, address[] memory feeds, address baseCurrency)
        external
        onlyAdmin
    {
        // Input validation
        require(
            underlyings.length > 0 && underlyings.length == feeds.length,
            "Lengths of both arrays must be equal and greater than 0."
        );

        // For each token/feed
        for (uint256 i = 0; i < underlyings.length; i++) {
            address underlying = underlyings[i];

            // Set feed and base currency
            priceFeeds[underlying] = AggregatorV3Interface(feeds[i]);
            feedBaseCurrencies[underlying] = baseCurrency;
        }
    }

    /**
     * @dev Function returning the price in base currency of `underlying`.
     */
    function price(address underlying) external view override returns (uint256) {
        // Get token price from Chainlink
        AggregatorV3Interface feed = priceFeeds[underlying];
        require(address(feed) != address(0), "No Chainlink price feed found for this underlying ERC20 token.");

        (uint80 roundId, int256 _price,, uint256 timestamp, uint80 answeredInRound) = feed.latestRoundData();

        require(answeredInRound >= roundId, "Stale price");
        require(timestamp != 0, "Round not complete");
        require(_price > 0, "invalid price");

        uint256 basePrice = BasePriceOracle(msg.sender).price(feedBaseCurrencies[underlying]);

        return (uint256(_price) * 10 ** (18 - uint256(feed.decimals())) * basePrice) / 1e18;
    }
}
