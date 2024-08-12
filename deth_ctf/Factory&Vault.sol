// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Factory {
    error AlreadyDeployed();

    address public lastDeployed;
    
    function deployVault() external {
        address vaultAddress = computeAddress();

        if (vaultAddress.codehash != bytes32(0)) {
            revert AlreadyDeployed();
        } 

        bytes32 salt = bytes32(uint256(uint160(msg.sender)));
        vaultAddress = address(new Vault{salt: salt}(msg.sender));
    }

    function computeAddress() public view returns (address) {
        bytes32 salt = bytes32(uint256(uint160(msg.sender)));
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(this),
            salt,
            keccak256(type(Vault).creationCode)
        )))));
    }
}

contract Vault {
    bool public locked = true;
    address public owner;

    mapping(address => uint256) public balances;

    event Deposited(address user, uint256 amount);
    event Withdrawn(address user, uint256 amount);
    event Unlocked(address owner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function unlock() external onlyOwner {
        locked = false;
        emit Unlocked(msg.sender);
    }

    function deposit() external payable {
        require(!locked, "Vault is locked");
        balances[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        require(!locked, "Vault is locked");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success);
        emit Withdrawn(msg.sender, amount);
    }
}