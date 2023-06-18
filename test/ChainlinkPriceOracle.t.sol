pragma solidity 0.8;

import "forge-std/Test.sol";

import "../external/chainlink/AggregatorV3Interface.sol";

import "../src/MasterPriceOracle.sol";
import "../src/ChainlinkPriceOracle.sol";

contract MockOracle is PriceOracle {
    mapping(address => uint256) prices;

    function harnessSetPrice(address underlying, uint256 p) public {
        prices[underlying] = p;
    }

    function price(address underlying) public view returns (uint256) {
        uint256 p = prices[underlying];

        require(p != 0, "invalid price");
        return p;
    }
}

contract MockChainlinkAggregator is AggregatorV3Interface {
    function decimals() external pure returns (uint8) {
        return 8;
    }

    function description() external pure returns (string memory) {
        return "ETH / USD";
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = _roundId;
        answer = 2000e8;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = _roundId;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return this.getRoundData(1);
    }
}

contract ChainlinkPriceOracleTest is Test {
    function testChailinkOracle() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);
        ChainlinkPriceOracle chainlinkOracle = new ChainlinkPriceOracle(address(this));

        address token = makeAddr("token 1");

        chainlinkOracle.setPriceFeeds(toArray(token), toArray(address(new MockChainlinkAggregator())), address(840));

        oracle.add(toArray(token), toArray(address(chainlinkOracle)));

        assertEq(oracle.price(token), 2000e18);
    }

    function testChainlinkNotSetup() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);
        ChainlinkPriceOracle chainlinkOracle = new ChainlinkPriceOracle(address(this));

        address token = makeAddr("token 1");

        oracle.add(toArray(token), toArray(address(chainlinkOracle)));

        vm.expectRevert("No Chainlink price feed found for this underlying ERC20 token.");
        oracle.price(token);
    }

    function testTrySettingChailinkOracleAsUser() public {
        ChainlinkPriceOracle chainlinkOracle = new ChainlinkPriceOracle(address(this));

        address token = makeAddr("token 1");

        MockChainlinkAggregator aggregator = new MockChainlinkAggregator();

        vm.expectRevert("Sender is not the admin.");
        vm.prank(makeAddr("user"));
        chainlinkOracle.setPriceFeeds(toArray(token), toArray(address(aggregator)), address(840));
    }

    function toArray(address val1) internal pure returns (address[] memory arr) {
        arr = new address[](1);

        arr[0] = val1;
    }
}
