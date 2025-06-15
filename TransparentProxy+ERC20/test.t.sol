// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "../src/Logic.sol";
import "../src/Proxy.sol";
import "forge-std/Test.sol";

interface ILogic {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function initialize(string memory, string memory, address owner) external;
    function owner() external view returns (address);
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
}

interface IProxyAdmin {
    function upgradeAndCall(
        ITransparentUpgradeableProxy proxy,
        address implementation,
        bytes memory data
    ) external;
}
contract Testing is Test {

    MyToken logic;
    MyProxy proxy;
    ILogic caller;
    address owner;
    address gakarot;
    address ironman;
    address thor;
    address admin;
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setUp() external {
        owner = makeAddr("owner");
        gakarot = makeAddr("gakarot");
        ironman = makeAddr("ironman");
        thor = makeAddr("thor");
        logic = new MyToken();
        proxy = new MyProxy(address(logic),"GAKAROT","GAK$",owner);
        caller = ILogic(address(proxy));
        address _admin = address(uint160(uint256(vm.load(address(proxy), ADMIN_SLOT))));
        if(_admin.code.length > 0) {
            admin = _admin;
            console.log("ProxyAdmin address is:",admin);
        } else{
            revert("Admin should be an contract");
        }
    }
    
    function testUpgrade() external {
        address oldImpl = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
        
        MyToken dummy = new MyToken();
        vm.startPrank(owner);
        IProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(dummy), "");
        address newImpl = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
        assertNotEq(oldImpl, newImpl);
        console.log("Old Impl:", oldImpl);
        console.log("New Impl:", newImpl);

        vm.expectRevert();
        caller.initialize("Dummy", "DUM$",address(this));
        vm.stopPrank();

        vm.expectRevert();
        IProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(dummy), "");


    }
    function testTransfer() external {
        vm.prank(owner);
        caller.mint(gakarot,100e18);
        vm.prank(gakarot);
        caller.transfer(ironman, 10e18);
        assertEq(caller.balanceOf(ironman), 10e18);
    }

    function testStateVariablesBeforeAndAfterUpgrade() external {
        vm.startPrank(owner);
        caller.mint(gakarot,100e18);
        console.log("Balance of gakarot is:",caller.balanceOf(gakarot));

        vm.startPrank(owner);
        address oldImpl = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
        MyToken dummy = new MyToken();
        IProxyAdmin(admin).upgradeAndCall(ITransparentUpgradeableProxy(address(proxy)), address(dummy), "");
        address newImpl = address(uint160(uint256(vm.load(address(proxy), IMPLEMENTATION_SLOT))));
        if(oldImpl != newImpl) {
            console.log("Balance of gakarot is:",caller.balanceOf(gakarot));
        } else {
            revert("Chala ja bhsdk madarchod");
        }
        vm.stopPrank();
    }

    // Rest test are common ERC20's only so skipping them.
}

