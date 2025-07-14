// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import "forge-std/Test.sol";

contract Handler is Test {
    DSCEngine public engine;
    DecentralizedStableCoin public token;
    ERC20Mock public weth;

    address public currentUser;

    constructor(DSCEngine _engine, DecentralizedStableCoin _dsc, ERC20Mock _weth) {
        engine = _engine;
        token = _dsc;
        weth = _weth;
    }

    function deposit(uint256 amount) public {
        currentUser = msg.sender;
        weth.mint(msg.sender, amount);
        weth.approve(address(engine), amount);
        engine.depositCollateral(address(weth), amount);
    }

    function mint(uint256 amount) public {
        currentUser = msg.sender;
        engine.mintDsc(amount);
    }

    function testFuzzDepositMintBurnRedeem(uint256 _amount) external {
        currentUser = msg.sender;
        vm.assume(_amount >= 0.0001 ether && _amount <= 1e50);
        weth.mint(currentUser, _amount);

        weth.approve(address(engine), _amount);
        engine.depositCollateral(address(weth), _amount);

        uint256 allowedAmount = (_amount * 40) / 100;
        engine.mintDsc(allowedAmount);

        token.approve(address(engine), token.balanceOf(currentUser));
        engine.redeemCollateralForDsc(address(weth), _amount, token.balanceOf(currentUser));
    }

    function testFuzzDepositAndRedeemCollateral(uint256 _amount) external {
        currentUser = msg.sender;
        vm.assume(_amount >= 0.0001 ether && _amount <= 1e50);
        weth.mint(currentUser, _amount);
        weth.approve(address(engine), _amount);
        engine.depositCollateral(address(weth), _amount);
        assertEq(engine.getCollateralBalanceOfUser(currentUser, address(weth)), _amount);
        engine.redeemCollateral(address(weth), _amount);
        assertEq(engine.getCollateralBalanceOfUser(currentUser, address(weth)), 0);
    }
}
