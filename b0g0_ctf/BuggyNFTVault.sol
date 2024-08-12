// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BuggyNFTVault is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 depositRequired;

    uint256 public constant MIN_DEPOSIT = 0.1 ether;

    /// @notice Stores the amount of ETH deposited by each user.
    mapping(address => uint256) public deposits;

    /**
     * @dev Constructor that sets the required deposit amount to mint an NFT.
     */
    constructor(uint256 _depositAmount) ERC721("CtfNFT", "CNFT") {
        require(_depositAmount >= MIN_DEPOSIT, "Min deposit");
        depositRequired = _depositAmount;
    }

    /**
     * @notice Deposits ETH and mints an NFT in return.
     */
    function deposit() external payable {
        require(msg.value == depositRequired, "Incorrect ETH amount");

        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        deposits[msg.sender] += msg.value;

        _mint(msg.sender, newTokenId);
    }

    /**
     * @notice Withdraws ETH by burning the NFT.
     * @param tokenId The ID of the NFT to burn.
     */
    function withdraw(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Only the owner can withdraw");

        // Burn the NFT to complete the withdrawal process.
        _burn(tokenId);
        deposits[msg.sender] -= depositRequired;

        (bool success, ) = msg.sender.call{value: depositRequired}(" ");
        require(success, "Transfer failed");
    }
}
