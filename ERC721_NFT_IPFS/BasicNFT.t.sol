// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../script/Deploy.s.sol";
import "../src/BasicNFT.sol";

contract Testing is Test {
    BasicNFT nft;
    address public USER = makeAddr("USER");
    function setUp() public {
        nft = new Deploy().run();
    }

    function testNameIsCorrect() public view {
        assertEq(nft.name(), "Gakarot");
        assertEq(nft.symbol(), "GAK");
    }

    function testCanMintAndHaveABalance() public {
        vm.prank(USER);
        nft.mintNFT("ipfs://QmVMrgKFWorf4wNbjGKe5RLjmAk5ZERnxpVztRVLYXPR6X");
        assertEq(nft.balanceOf(USER),1);
        assertEq(nft.tokenURI(0), "ipfs://QmVMrgKFWorf4wNbjGKe5RLjmAk5ZERnxpVztRVLYXPR6X");
    }
}
