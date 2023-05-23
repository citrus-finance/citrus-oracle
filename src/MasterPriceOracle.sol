// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "solmate/tokens/ERC20.sol";

import "./interfaces/PriceOracle.sol";
import "./interfaces/CToken.sol";
import "./interfaces/CErc20.sol";

import "./interfaces/BasePriceOracle.sol";

/**
 * @title MasterPriceOracle
 * @notice Use a combination of price oracles.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * Changes by Citrus team:
 * - added base currency
 * - added guardian to circuit break oracle
 */
contract MasterPriceOracle is PriceOracle, BasePriceOracle {
    /**
     * @dev Maps underlying token addresses to `PriceOracle` contracts (can be `BasePriceOracle` contracts too).
     */
    mapping(address => PriceOracle) public oracles;

    /**
     * @dev Default/fallback `PriceOracle`.
     */
    BasePriceOracle public defaultOracle;

    /**
     * @dev The administrator of this `MasterPriceOracle`.
     */
    address public admin;

    /**
     * @dev The guardian who can unset oracle in case it's misbehaving
     */
    address public guardian;

    /// @notice all other tokens are priced against the base token. Its price is 1e18
    address public immutable baseCurrency;

    /**
     * @dev Event emitted when `admin` is changed.
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
     * @dev Event emitted when `guardian` is changed.
     */
    event NewGuardian(address oldGuardian, address newGuardian);

    /**
     * @dev Event emitted when the default oracle is changed.
     */
    event NewDefaultOracle(address oldOracle, address newOracle);

    /**
     * @dev Event emitted when an underlying token's oracle is changed.
     */
    event NewOracle(address underlying, address oldOracle, address newOracle);

    /**
     * @dev Constructor to initialize state variables.
     * @param _admin The admin who can assign oracles to underlying tokens.
     */
    constructor(address _admin, address _baseCurrency, address _defaultOracle) {
        require(
            _defaultOracle == address(0) || BasePriceOracle(_defaultOracle).baseCurrency() == _baseCurrency,
            "Oracle baseCurrency needs to be the same as defaultOracle"
        );

        admin = _admin;
        baseCurrency = _baseCurrency;
        defaultOracle = BasePriceOracle(_defaultOracle);
    }

    /**
     * @dev Sets `_oracles` for `underlyings`.
     */
    function add(address[] calldata underlyings, address[] calldata _oracles) external onlyAdmin {
        // Input validation
        require(
            underlyings.length > 0 && underlyings.length == _oracles.length,
            "Lengths of both arrays must be equal and greater than 0."
        );

        // Assign oracles to underlying tokens
        for (uint256 i = 0; i < underlyings.length; i++) {
            address underlying = underlyings[i];
            address oldOracle = address(oracles[underlying]);
            PriceOracle newOracle = PriceOracle(_oracles[i]);
            oracles[underlying] = newOracle;
            emit NewOracle(underlying, oldOracle, address(newOracle));
        }
    }

    /**
     * @dev Unsets `oracles` of `underlyings`.
     * @param underlyings The underlying ERC20 token addresses those `oracles` should be cleared.
     */
    function clear(address[] calldata underlyings) external onlyAdminOrGuardian {
        // Unassign oracles of underlying tokens
        for (uint256 i = 0; i < underlyings.length; i++) {
            address underlying = underlyings[i];
            emit NewOracle(underlying, address(oracles[underlying]), address(0));
            oracles[underlying] = BasePriceOracle(address(0));
        }
    }

    /**
     * @dev Changes the default oracle.
     */
    function setDefaultOracle(address newOracle) external onlyAdmin {
        require(
            newOracle == address(0) || BasePriceOracle(newOracle).baseCurrency() == baseCurrency,
            "Oracle baseCurrency needs to be the same as defaultOracle"
        );

        PriceOracle oldOracle = defaultOracle;
        defaultOracle = BasePriceOracle(newOracle);
        emit NewDefaultOracle(address(oldOracle), address(newOracle));
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
     * @dev Changes the guardian.
     */
    function changeGuardian(address newGuardian) external onlyAdmin {
        address oldGuardian = guardian;
        guardian = newGuardian;
        emit NewGuardian(oldGuardian, newGuardian);
    }

    /**
     * @dev Modifier that checks if `msg.sender == admin`.
     */
    modifier onlyAdmin() {
        require(msg.sender == admin, "Sender is not the admin.");
        _;
    }

    /**
     * @dev Modifier that checks if `msg.sender` is admin or guardian.
     */
    modifier onlyAdminOrGuardian() {
        require(msg.sender == admin || msg.sender == guardian, "Sender is not the admin or guardian.");
        _;
    }

    /**
     * @notice Returns the price in base currency of the token underlying `cToken`.
     * @return Price in base currency of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(address cToken) external view returns (uint256) {
        // Get underlying ERC20 token address
        address underlying = CErc20(cToken).underlying();

        // Get underlying price
        uint256 underlyingPrice = _price(underlying);
        uint256 underlyingDecimals = ERC20(underlying).decimals();

        return underlyingDecimals <= 18
            ? underlyingPrice * (10 ** (18 - underlyingDecimals))
            : underlyingPrice / (10 ** (underlyingDecimals - 18));
    }

    /**
     * @dev Attempts to return the price in base currency of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external view returns (uint256) {
        return _price(underlying);
    }

    /**
     * @dev Attempts to return the price in base currency of `underlying`
     */
    function _price(address underlying) internal view returns (uint256) {
        if (underlying == baseCurrency) {
            return 1e18;
        }

        // Get underlying price from assigned oracle
        PriceOracle oracle = oracles[underlying];
        if (address(oracle) != address(0)) {
            return BasePriceOracle(address(oracle)).price(underlying);
        }
        if (address(defaultOracle) != address(0)) {
            return BasePriceOracle(address(defaultOracle)).price(underlying);
        }
        revert("Price oracle not found for this underlying token address.");
    }
}
