pragma solidity 0.8;

import "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/test/utils/mocks/MockERC20.sol";

import "../src/MasterPriceOracle.sol";

contract MockOracle is PriceOracle {
    mapping(address => uint256) prices;

    function harnessSetPrice(address underlying, uint256 price) public {
        prices[underlying] = price;
    }

    function price(address underlying) public view returns (uint256) {
        uint256 price = prices[underlying];

        require(price != 0, "invalid price");
        return price;
    }
}

contract MockCToken is ERC20 {
    address public immutable underlying;

    constructor(string memory name, string memory symbol, uint8 decimals, address _underlying)
        ERC20(name, symbol, decimals)
    {
        underlying = _underlying;
    }
}

contract MasterPriceOracleTest is Test {
    function testBaseCurrency() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        assertEq(oracle.price(address(840)), 1e18);
    }

    function testOracle() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        address token = makeAddr("token 1");

        MockOracle mockOracle = new MockOracle();
        mockOracle.harnessSetPrice(token, 0.5e18);

        oracle.add(toArray(token), toArray(address(mockOracle)));

        assertEq(oracle.price(token), 0.5e18);
    }

    function testGetUnderlyingPriceWith18Decimals() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        MockERC20 token = new MockERC20("Wrapped Ether", "WETH", 18);
        MockCToken cToken = new MockCToken("Citrus Wrapped Ether", "WETH", 18, address(token));

        MockOracle mockOracle = new MockOracle();
        mockOracle.harnessSetPrice(address(token), 2000e18);

        oracle.add(toArray(address(token)), toArray(address(mockOracle)));

        assertEq(oracle.getUnderlyingPrice(address(cToken)), 2000e18);
    }

    function testGetUnderlyingPriceWith8Decimals() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        MockERC20 token = new MockERC20("Wrapped BTC", "WBTC", 8);
        MockCToken cToken = new MockCToken("Citrus Wrapped BTC", "WBTC", 8, address(token));

        MockOracle mockOracle = new MockOracle();
        mockOracle.harnessSetPrice(address(token), 20_000e18);

        oracle.add(toArray(address(token)), toArray(address(mockOracle)));

        assertEq(oracle.getUnderlyingPrice(address(cToken)), 20_000e28);
    }

    function testGetUnderlyingPriceWith36Decimals() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        MockERC20 token = new MockERC20("Wrapped BTC", "WBTC", 36);
        MockCToken cToken = new MockCToken("Citrus Wrapped BTC", "WBTC", 36, address(token));

        MockOracle mockOracle = new MockOracle();
        mockOracle.harnessSetPrice(address(token), 20_000e18);

        oracle.add(toArray(address(token)), toArray(address(mockOracle)));

        assertEq(oracle.getUnderlyingPrice(address(cToken)), 20_000);
    }

    function testTrySettingOracleAsUser() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        address token = makeAddr("token 1");

        MockOracle mockOracle = new MockOracle();
        mockOracle.harnessSetPrice(token, 0.5e18);

        vm.expectRevert("Sender is not the admin.");
        vm.prank(makeAddr("user"));
        oracle.add(toArray(token), toArray(address(mockOracle)));
    }

    function testClearingOracle() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        address token = makeAddr("token 1");

        MockOracle mockOracle = new MockOracle();
        mockOracle.harnessSetPrice(token, 0.5e18);

        oracle.add(toArray(token), toArray(address(mockOracle)));

        assertEq(oracle.price(token), 0.5e18);

        oracle.clear(toArray(token));

        vm.expectRevert();
        oracle.price(token);
    }

    function testClearingOracleAsGuardian() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        address guardian = makeAddr("guardian");
        oracle.changeGuardian(guardian);

        address token = makeAddr("token 1");

        MockOracle mockOracle = new MockOracle();
        mockOracle.harnessSetPrice(token, 0.5e18);

        oracle.add(toArray(token), toArray(address(mockOracle)));

        assertEq(oracle.price(token), 0.5e18);

        vm.prank(guardian);
        oracle.clear(toArray(token));

        vm.expectRevert();
        oracle.price(token);
    }

    function testTryClearingOracleAsUser() public {
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        address guardian = makeAddr("guardian");
        oracle.changeGuardian(guardian);

        address token = makeAddr("token 1");

        MockOracle mockOracle = new MockOracle();
        mockOracle.harnessSetPrice(token, 0.5e18);

        oracle.add(toArray(token), toArray(address(mockOracle)));

        assertEq(oracle.price(token), 0.5e18);

        vm.expectRevert("Sender is not the admin or guardian.");
        vm.prank(makeAddr("user"));
        oracle.clear(toArray(token));
    }

    function testDefaultOracleForNotSetupOracle() public {
        address token = makeAddr("token 1");

        MasterPriceOracle defaultOracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        MockOracle mockOracle1 = new MockOracle();
        mockOracle1.harnessSetPrice(token, 0.5e18);

        defaultOracle.add(toArray(token), toArray(address(mockOracle1)));

        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(defaultOracle), false);

        assertEq(oracle.price(token), 0.5e18);
    }

    function testDefaultOracleWithProperlySetupOracle() public {
        address token = makeAddr("token 1");

        MasterPriceOracle defaultOracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        MockOracle mockOracle1 = new MockOracle();
        mockOracle1.harnessSetPrice(token, 0.5e18);

        defaultOracle.add(toArray(token), toArray(address(mockOracle1)));

        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(defaultOracle), false);

        MockOracle mockOracle2 = new MockOracle();
        mockOracle2.harnessSetPrice(token, 1e18);

        oracle.add(toArray(token), toArray(address(mockOracle2)));

        assertEq(oracle.price(token), 1e18);
    }

    function testCallFirstDefaultOracle() public {
        address token = makeAddr("token 1");

        MasterPriceOracle defaultOracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        MockOracle mockOracle1 = new MockOracle();
        mockOracle1.harnessSetPrice(token, 0.5e18);

        defaultOracle.add(toArray(token), toArray(address(mockOracle1)));

        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(defaultOracle), true);

        MockOracle mockOracle2 = new MockOracle();
        mockOracle2.harnessSetPrice(token, 1e18);

        oracle.add(toArray(token), toArray(address(mockOracle2)));

        assertEq(oracle.price(token), 0.5e18);
    }

    function testCallFirstWithInvalidDefaultOracle() public {
        address token = makeAddr("token 1");

        MasterPriceOracle defaultOracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(defaultOracle), true);

        MockOracle mockOracle2 = new MockOracle();
        mockOracle2.harnessSetPrice(token, 1e18);

        oracle.add(toArray(token), toArray(address(mockOracle2)));

        assertEq(oracle.price(token), 1e18);
    }

    function testIncorrectBaseCurrencyInContructor() public {
        MasterPriceOracle defaultOracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        vm.expectRevert("Oracle baseCurrency needs to be the same as defaultOracle");
        new MasterPriceOracle(address(this), address(0), address(defaultOracle), false);
    }

    function testSetDefaultOracleWithIncorrectBaseCurrency() public {
        MasterPriceOracle defaultOracle = new MasterPriceOracle(address(this), address(840), address(0), false);
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(0), address(0), false);

        vm.expectRevert("Oracle baseCurrency needs to be the same as defaultOracle");
        oracle.setDefaultOracle(address(defaultOracle), false);
    }

    function testTrySettingDefaultOracleAsUser() public {
        MasterPriceOracle defaultOracle = new MasterPriceOracle(address(this), address(840), address(0), false);
        MasterPriceOracle oracle = new MasterPriceOracle(address(this), address(840), address(0), false);

        vm.prank(makeAddr("user"));
        vm.expectRevert("Sender is not the admin.");
        oracle.setDefaultOracle(address(defaultOracle), false);
    }

    function toArray(address val1) internal pure returns (address[] memory arr) {
        arr = new address[](1);

        arr[0] = val1;
    }
}
