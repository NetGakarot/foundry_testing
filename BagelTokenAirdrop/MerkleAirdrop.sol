// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    error MerkleAirdrop_InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    bytes32 private constant MERKLE_ROOT = 0xbbaee090ecea8ec3e5b792ddf25166d86a42439b02f01c462e4eb5b78df3357c;
    IERC20 private immutable i_token;
    mapping(address => bool) private s_hasClaimed;

    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account,uint256 amount)");

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    event Claimed(address _account, uint256 _amount);

    constructor(IERC20 _token) EIP712("Merkle Airdrop", "1.0.0") {
        i_token = _token;
    }

    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }

        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        bytes32 leaf = keccak256(abi.encodePacked(keccak256(abi.encodePacked(account, amount))));
        if (!MerkleProof.verify(merkleProof, MERKLE_ROOT, leaf)) {
            revert MerkleAirdrop_InvalidProof();
        }

        s_hasClaimed[account] = true;
        emit Claimed(account, amount);
        i_token.safeTransfer(account, amount);
    }

    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount}))));
    }

    function getMerkleRoot() external pure returns (bytes32) {
        return MERKLE_ROOT;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_token;
    }

    function _isValidSignature(address signer, bytes32 digest, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (bool)
    {
        (
            address actualSigner,
            /*ECDSA.RecoverError recoverError*/
            ,
            /*bytes32 signatureLength*/
        ) = ECDSA.tryRecover(digest, _v, _r, _s);
        return (actualSigner == signer);
    }
}
