// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/DecentralizedStableCoin.sol";
import "../src/DSCEngine.sol";
import "../mock/AggregatorMock.sol";
import "../mock/ERC20Mock.sol";
import "forge-std/StdInvariant.sol";
import {Handler} from "../test/Handler.t.sol";

contract Testing is StdInvariant, Test {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    DecentralizedStableCoin token;
    DSCEngine engine;

    ERC20Mock weth;
    ERC20Mock wbtc;
    MockV3Aggregator ethUsdPriceFeed;
    MockV3Aggregator btcUsdPriceFeed;
    Handler handler;

    address public user = address(1);
    address public owner = makeAddr("owner");
    address public gakarot = makeAddr("TheLiquidator");

    uint256 amountCollateral = 10 ether;

    function setUp() external {
        ethUsdPriceFeed = new MockV3Aggregator(8, 2000e8);
        btcUsdPriceFeed = new MockV3Aggregator(8, 30000e8);
        weth = new ERC20Mock("mock", "mock", user, 1000e18);
        wbtc = new ERC20Mock("mock", "mock", user, 1000e18);

        token = new DecentralizedStableCoin(0xdf93d8C39Fc87dfB7764680D0cdF846fDDA1Add2);

        tokenAddresses.push(address(weth));
        tokenAddresses.push(address(wbtc));
        priceFeedAddresses.push(address(ethUsdPriceFeed));
        priceFeedAddresses.push(address(btcUsdPriceFeed));

        engine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(token), owner);

        vm.prank(0xdf93d8C39Fc87dfB7764680D0cdF846fDDA1Add2);
        token.transferOwnership(address(engine));

        targetContract(address(engine));
        handler = new Handler(engine, token, weth);
    }

    //////////////////
    // Constructor ///
    //////////////////

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public view {
        assertEq(tokenAddresses.length, priceFeedAddresses.length);
    }

    ///////////////
    // Unit Test //
    ///////////////

    function testMintDscWithoutDepositingCollateral() external {
        vm.startPrank(user);
        vm.expectRevert();
        engine.mintDsc(100000000);
        vm.stopPrank();
    }

    function testDepositCollateral() external {
        vm.startPrank(user);
        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        vm.stopPrank();
    }

    function testGetUsdValue() external view {
        assertEq(engine.getUsdValue(address(weth), 5e18), 10000e18);
    }

    function testGetTokenAmountFromUsd() external view {
        assertEq(engine.getTokenAmountFromUsd(address(weth), 10000e18), 5e18);
    }

    function testGetAccountCollateralValue() external {
        vm.startPrank(user);
        weth.approve(address(engine), 5e18);
        wbtc.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        engine.depositCollateral(address(wbtc), 5e18);
        assertEq(engine.getAccountCollateralValue(user), 160000e18);
        vm.stopPrank();
    }

    //////////////////////
    // Integration Test //
    //////////////////////

    function testDepositCollateralMintDscBurnDscRedeemCollateral() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);

        console.log("User Collateral Balance:", engine.getCollateralBalanceOfUser(user, address(weth)));

        console.log("User Health Factor:", engine.getHealthFactor(user));

        engine.mintDsc(2.5e18);

        console.log("User Health Factor:", engine.getHealthFactor(user));

        token.approve(address(engine), 2.5e18);
        engine.burnDsc(2.5e18);

        console.log("User Health Factor:", engine.getHealthFactor(user));

        engine.redeemCollateral(address(weth), 5e18);

        console.log("User Collateral Balance:", engine.getCollateralBalanceOfUser(user, address(weth)));

        vm.stopPrank();
    }

    function testOverMinting() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);

        console.log("User Collateral Balance:", engine.getCollateralBalanceOfUser(user, address(weth)));

        console.log("User Health Factor:", engine.getHealthFactor(user));

        vm.expectRevert();
        engine.mintDsc(5001e18);

        vm.stopPrank();
    }

    function testMintDscDropPriceLiquidateUser() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        console.log("User Health Factor before minting:", engine.getHealthFactor(user));

        engine.mintDsc(4545e18);
        console.log("User Health Factor after minting:", engine.getHealthFactor(user));

        ethUsdPriceFeed.changeAnswer(1900e8);
        console.log("User Health Factor after price dropped:", engine.getHealthFactor(user));

        vm.stopPrank();

        vm.startPrank(address(engine));

        token.mint(gakarot, 10000e18);
        assertEq(token.balanceOf(gakarot), 10000e18);
        vm.stopPrank();

        vm.startPrank(gakarot);

        console.log("Gakarot total balance before liquidating:", weth.balanceOf(gakarot));

        token.approve(address(engine), 4545e18);
        engine.liquidate(user, 4545e18);

        console.log("User Health Factor after liquidation:", engine.getHealthFactor(user));
        console.log("Gakarot total balance after liquidating:", weth.balanceOf(gakarot));

        vm.stopPrank();
    }

    function testRedeemCollateralForDsc() external {
        vm.startPrank(user);
        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);

        console.log("Collateral before minting Dsc:", engine.getCollateralBalanceOfUser(user, address(weth)));

        engine.mintDsc(4545e18);
        assertEq(token.balanceOf(user), 4545e18);

        console.log("Collateral after minting Dsc:", engine.getCollateralBalanceOfUser(user, address(weth)));

        token.approve(address(engine), 5000e18);
        engine.redeemCollateralForDsc(address(weth), 2.27e18, 4545e18);
        assertEq(token.balanceOf(user), 0);
        console.log("Collateral after burning Dsc:", engine.getCollateralBalanceOfUser(user, address(weth)));

        vm.stopPrank();
    }

    function testRedeemCollateral() external {
        vm.startPrank(user);
        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        engine.redeemCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 0);
        vm.stopPrank();
    }

    function testDepositWhenHaveNoFundsToDeposit() external {
        address dummy = makeAddr("dummy");

        vm.startPrank(dummy);
        weth.approve(address(engine), 5e18);
        vm.expectRevert();
        engine.depositCollateral(address(weth), 5e18);
        vm.stopPrank();
    }

    function testRevertIfTokenIsNotAllowed() external {
        ERC20Mock fakeToken = new ERC20Mock("Fake", "FAKE", user, 1000e18);

        vm.startPrank(user);
        fakeToken.approve(address(engine), 1e18);
        vm.expectRevert();
        engine.depositCollateral(address(fakeToken), 1e18);
        vm.stopPrank();
    }

    function testRedeemCollateralMoreThanDeposited() external {
        vm.startPrank(user);
        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        vm.expectRevert();
        engine.redeemCollateral(address(weth), 6e18);
        vm.stopPrank();
    }

    function testLiquidationFailsIfHealthFactorIsOk() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        console.log("User Health Factor before minting:", engine.getHealthFactor(user));

        engine.mintDsc(4545e18);
        console.log("User Health Factor after minting:", engine.getHealthFactor(user));
        vm.stopPrank();

        vm.startPrank(address(engine));
        token.mint(gakarot, 10000e18);
        assertEq(token.balanceOf(gakarot), 10000e18);
        vm.stopPrank();

        vm.startPrank(gakarot);

        token.approve(address(engine), 5e18);
        vm.expectRevert();
        engine.liquidate(user, 2e18);
        vm.stopPrank();
    }

    function testLiquidatorDoesNothaveEnoughDscTokensToLiquidate() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        console.log("User Health Factor before minting:", engine.getHealthFactor(user));

        engine.mintDsc(4545e18);
        console.log("User Health Factor after minting:", engine.getHealthFactor(user));

        ethUsdPriceFeed.changeAnswer(1900e8);
        console.log("User Health Factor after price dropped:", engine.getHealthFactor(user));

        vm.stopPrank();

        vm.startPrank(address(engine));

        token.mint(gakarot, 1000e18);
        assertEq(token.balanceOf(gakarot), 1000e18);
        vm.stopPrank();

        vm.startPrank(gakarot);

        console.log("Gakarot total balance before liquidating:", weth.balanceOf(gakarot));

        token.approve(address(engine), 4545e18);
        vm.expectRevert();
        engine.liquidate(user, 4545e18);

        vm.stopPrank();
    }

    function testGetFunctions() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        console.log("User Health Factor before minting:", engine.getHealthFactor(user));

        engine.mintDsc(4545e18);
        console.log("User Health Factor after minting:", engine.getHealthFactor(user));
        vm.stopPrank();

        console.log("Healthfactor is:", engine.getHealthFactor(user));
        console.log("Collateral token price feed is:", engine.getCollateralTokenPriceFeed(address(weth)));
        console.log("Dsc address is:", engine.getDsc());
        console.log("Minimum healthfactor is:", engine.getMinHealthFactor());
        console.log("Liquidation threshold is:", engine.getLiquidationPrecision());
        console.log("Liquidation Precision is:", engine.getLiquidationThreshold());
        console.log("Liquidation Bonus is:", engine.getLiquidationBonus());
        console.log("Liquidation Bonus is:", engine.getLiquidationBonus());
        console.log("Precision is:", engine.getPrecision());
        console.log("Protocol collateral balance is is:", engine.getProtocolCollateralBalance(address(weth)));
    }

    function testWithdraCollateralByOwner() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        console.log("User deposited Collateral:", engine.getCollateralBalanceOfUser(user, address(weth)));
        vm.stopPrank();

        vm.startPrank(owner);
        console.log("Owner  token :", weth.balanceOf(owner));
        engine.withdrawProtocolCollateral(address(weth));
        console.log("Owner  token :", weth.balanceOf(owner));
    }

    function testRedeemCollateralForDscAfterCollateralPriceDrops() external {
        vm.startPrank(user);
        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);

        console.log("Collateral before minting Dsc:", engine.getCollateralBalanceOfUser(user, address(weth)));
        console.log("Health Factor before minting DSC:", engine.getHealthFactor(user));

        engine.mintDsc(4545e18);
        assertEq(token.balanceOf(user), 4545e18);

        console.log("Collateral after minting Dsc:", engine.getCollateralBalanceOfUser(user, address(weth)));

        console.log("Health Factor before collateral price drops:", engine.getHealthFactor(user));

        ethUsdPriceFeed.changeAnswer(1900e8);

        token.approve(address(engine), 5000e18);
        vm.expectRevert();
        engine.redeemCollateral(address(weth), 5e18);
        console.log("Collateral after burning Dsc:", engine.getCollateralBalanceOfUser(user, address(weth)));
        console.log("Health Factor after price drops:", engine.getHealthFactor(user));

        vm.stopPrank();
    }

    function testPartialLiquidationEnoughToCoverDebtButNotFullBonusOf10Percent() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        console.log("User Health Factor before minting:", engine.getHealthFactor(user));

        engine.mintDsc(4545e18);
        console.log("User Health Factor after minting:", engine.getHealthFactor(user));

        ethUsdPriceFeed.changeAnswer(1900e8);
        console.log("User Health Factor after price dropped:", engine.getHealthFactor(user));

        vm.stopPrank();

        vm.startPrank(address(engine));

        token.mint(gakarot, 4545e18);
        assertEq(token.balanceOf(gakarot), 4545e18);
        vm.stopPrank();

        vm.startPrank(gakarot);

        console.log("Gakarot total balance before liquidating:", weth.balanceOf(gakarot));

        token.approve(address(engine), 1000e18);
        engine.liquidate(user, 1000e18);

        console.log("Gakarot total balance after liquidating:", weth.balanceOf(gakarot));

        vm.stopPrank();
    }

    function testCollateralNotEnoughToCoverFullDebt() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        console.log("User Health Factor before minting:", engine.getHealthFactor(user));

        engine.mintDsc(4545e18);
        console.log("User Health Factor after minting:", engine.getHealthFactor(user));

        ethUsdPriceFeed.changeAnswer(500e8);
        console.log("User Health Factor after price dropped:", engine.getHealthFactor(user));

        vm.stopPrank();

        vm.startPrank(address(engine));

        token.mint(gakarot, 4545e18);
        assertEq(token.balanceOf(gakarot), 4545e18);
        vm.stopPrank();

        vm.startPrank(gakarot);

        console.log("Gakarot total balance before liquidating:", weth.balanceOf(gakarot));

        token.approve(address(engine), engine.getCollateralBalanceOfUser(user, address(weth)));
        engine.liquidate(user, engine.getCollateralBalanceOfUser(user, address(weth)));

        console.log("Gakarot total balance after liquidating:", weth.balanceOf(gakarot));
        console.log("User Health Factor after liquidation:", engine.getHealthFactor(user));

        vm.stopPrank();
    }

    function testMintBurnAndThenMintAgain() external {
        vm.startPrank(user);

        weth.approve(address(engine), 5e18);
        engine.depositCollateral(address(weth), 5e18);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 5e18);
        console.log("User Health Factor before minting:", engine.getHealthFactor(user));

        engine.mintDsc(4545e18);

        console.log("User Health Factor after minting:", engine.getHealthFactor(user));

        vm.expectRevert();
        engine.mintDsc(4545e18);

        vm.stopPrank();
    }

    /////////////////
    // Fuzz Test ////
    /////////////////

    function testDepositCollaterals(uint256 _amount) external {
        vm.startPrank(user);
        vm.assume(_amount >= 0.0001 ether && _amount <= 1e50);
        weth.mint(user, _amount);
        weth.approve(address(engine), _amount);
        engine.depositCollateral(address(weth), _amount);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), _amount);
        vm.stopPrank();
    }

    function testFuzzMintDsc(uint256 _amount) external {
        vm.startPrank(user);
        vm.assume(_amount >= 0.0001 ether && _amount <= 1e50);
        weth.mint(user, _amount);
        weth.approve(address(engine), _amount);
        engine.depositCollateral(address(weth), _amount);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), _amount);
        uint256 oldHealthFactor = engine.getHealthFactor(user);
        engine.mintDsc(_amount);
        uint256 newHealthFactor = engine.getHealthFactor(user);
        assertGt(oldHealthFactor, newHealthFactor);
        vm.stopPrank();
    }

    function testFuzzDepositAndRedeemCollateral(uint256 _amount) external {
        vm.startPrank(user);
        vm.assume(_amount >= 0.0001 ether && _amount <= 1e50);
        weth.mint(user, _amount);
        weth.approve(address(engine), _amount);
        engine.depositCollateral(address(weth), _amount);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), _amount);
        engine.redeemCollateral(address(weth), _amount);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 0);
        vm.stopPrank();
    }

    function testFuzzDepositMintBurnRedeem(uint256 _amount) external {
        vm.startPrank(user);
        vm.assume(_amount >= 0.0001 ether && _amount <= 1e50);
        weth.mint(user, _amount);

        weth.approve(address(engine), _amount);
        engine.depositCollateral(address(weth), _amount);
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), _amount);

        uint256 allowedAmount = (_amount * 40) / 100;
        engine.mintDsc(allowedAmount);

        token.approve(address(engine), token.balanceOf(user));
        engine.redeemCollateralForDsc(address(weth), _amount, token.balanceOf(user));
        assertEq(engine.getCollateralBalanceOfUser(user, address(weth)), 0);
        vm.stopPrank();
    }

    function testFuzzBurnRevertsIfExceedsBalance(uint256 _amount) external {
        vm.startPrank(user);
        vm.assume(_amount >= 0.0001 ether && _amount <= 1e50);
        weth.mint(user, _amount);
        weth.approve(address(engine), _amount);
        engine.depositCollateral(address(weth), _amount);
        engine.mintDsc(_amount / 2);
        token.approve(address(engine), _amount);
        vm.expectRevert();
        engine.burnDsc(_amount);
        vm.stopPrank();
    }

    function testFuzzDepositWBTC(uint256 _amount) external {
        vm.startPrank(user);
        vm.assume(_amount >= 0.0001 ether && _amount <= 1e50);
        wbtc.mint(user, _amount);
        wbtc.approve(address(engine), _amount);
        engine.depositCollateral(address(wbtc), _amount);
        assertEq(engine.getCollateralBalanceOfUser(user, address(wbtc)), _amount);
        vm.stopPrank();
    }

    ////////////////////
    // Invariant Test //
    ////////////////////

    function invariant_healthFactorAlwaysAboveOne() external view {
        assertGe(engine.getHealthFactor(handler.currentUser()), 1e18);
    }

    function invariant_depositMintBurnRedeemAfterThatBalanceShouldAlwaysBeZero() external view {
        assertEq(engine.getCollateralBalanceOfUser(handler.currentUser(), address(weth)), 0);
    }
}
