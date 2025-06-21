// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// ───── Ownable.sol (OpenZeppelin) ─────
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }
    function owner() public view virtual returns (address) {
        return _owner;
    }
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// ───── ILogAutomation.sol (Chainlink) ─────
interface ILogAutomation {
    struct Log {
        bytes32 topic0;
        bytes32[] topics;
        bytes data;
        address emitter;
    }

    function checkLog(Log calldata log, bytes calldata checkData)
        external
        returns (bool upkeepNeeded, bytes memory performData);

    function performUpkeep(bytes calldata performData) external;
}

// ───── Interface to Token ─────
interface IMyToken {
    function mint(address account, uint256 value) external;
}

// ───── Final Contract ─────
contract LogWatcher is ILogAutomation, Ownable {
    IMyToken immutable token;

    event Triggered(address _logSender);

    constructor(address _token, address _owner) Ownable(_owner) {
        token = IMyToken(_token);
    }

    function checkLog(
        Log calldata log,
        bytes memory
    ) external pure override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = true;
        address logSender = address(uint160(uint256(log.topics[1])));
        performData = abi.encode(logSender); 
    }

    function performUpkeep(bytes calldata performData) external override {
        token.mint(owner(), 1e18);
        address logSender = abi.decode(performData, (address));  
        emit Triggered(logSender);
    }
}
