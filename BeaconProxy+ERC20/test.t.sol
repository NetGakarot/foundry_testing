// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Logic.sol";
import "../src/FactoryBeacon.sol";

interface IFactory {
    function createProxy(string memory _name, string memory _symbol, address _owner) external returns (address);
}

interface IOwner {
    function owner() external view returns (address);
}

interface IUpgradeableBeacon  {
    function upgradeTo(address newImplementation) external;
}

interface ILogic {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract Testing is Test {

    MyToken logic;
    Factory factory;
    address gakarot;
    address ironman;
    address factoryBeacon;


    function setUp() external {
        gakarot = makeAddr("gakarot");
        ironman = makeAddr("ironman");
        logic = new MyToken();
        factory = new Factory(address(logic),gakarot);
        factoryBeacon = factory.beacon();
    }

    function testSetup() external view {
        assertEq(IBeacon(address(factoryBeacon)).implementation(), address(logic));
        assertEq(IOwner(address(factoryBeacon)).owner(), gakarot);
    }

    function testUpgrade() external {
        MyToken dummy = new MyToken();
        vm.prank(gakarot);
        IUpgradeableBeacon (address(factoryBeacon)).upgradeTo(address(dummy));
        assertEq(IBeacon(address(factoryBeacon)).implementation(), address(dummy));
    }

    function testCreateProxy() external {
        address proxy1 = IFactory(address(factory)).createProxy("GAKAROT","GAK$",gakarot);
        vm.prank(gakarot);
        ILogic(proxy1).mint(ironman, 10e18);
        assertEq(ILogic(proxy1).balanceOf(ironman), 10e18);
    }
}