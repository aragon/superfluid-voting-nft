// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {IGovernanceWrappedERC20} from "@aragon/osx/token/ERC20/governance/IGovernanceWrappedERC20.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";
import {ERC721Pausable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import {SuperTokenV1Library} from "@superfluid/apps/SuperTokenV1Library.sol";
import {IConstantFlowAgreementV1} from "@superfluid/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {ISuperfluid} from "@superfluid/interfaces/superfluid/ISuperfluid.sol";
import {ISuperToken} from "@superfluid/interfaces/superfluid/ISuperToken.sol";

contract SuperVotingNFT is ERC721, ERC721Burnable, Ownable, EIP712, ERC721Votes, ERC721Pausable {
    using SuperTokenV1Library for ISuperToken;

    // -----------------------------------------------------------------------------
    // Variables
    // -----------------------------------------------------------------------------

    /// @notice The next token ID to be minted.
    uint256 private _nextTokenId;

    /// @notice The SuperToken used for streaming subscription payments.
    ISuperToken public superToken;

    /// @notice The Superfluid Constant Flow Agreement used for streaming subscription payments.
    IConstantFlowAgreementV1 public cfa;

    /// @notice The minimum flow rate for the voter to be considered a member.
    int96 public minFlowRate;

    /// @notice The amount of ETH (Native Asset) that is staked by the voter.
    /// @dev This is used offered as an incentive for keepers to revoke voting rights if the voter is no longer a member.
    uint256 public stake;

    /// @notice The DAO that is accepting the stream of subscription payments.
    address public dao;

    // -----------------------------------------------------------------------------
    // Errors
    // -----------------------------------------------------------------------------

    /// @notice Error to be thrown when the DAO address is zero.
    error DaoCannotBeZeroAddress();

    /// @notice Error to be thrown when the minimum flow rate is zero or negative.
    error MinFlowRateCannotBeZeroOrNegative(int96 minFlowRate);

    /// @notice Error to be thrown when the provided stake is less than the required stake.
    error InsufficientStake(uint256 requiredStake, uint256 providedStake);

    /// @notice Error to be thrown when the token has already been minted to an address.
    error AlreadyMinted(address to);

    /// @notice Error to be thrown when the actual flow rate is less than the required flow rate.
    error InsufficientFlowRate(int96 required, int96 actual);

    /// @notice Error to be thrown when the actual flow rate is more than the required flow rate.
    error SufficientFlowRate(int96 required, int96 actual);

    /// @notice Error to be thrown when the token attempted to be transferred
    error NonTransferable();

    error FailedToTransferEther(address to, uint256 amount);

    // -----------------------------------------------------------------------------
    // Constructor
    // -----------------------------------------------------------------------------

    /// @notice Constructs a new SuperVotingNFT contract.
    /// @param _name The name of the NFT.
    /// @param _symbol The symbol of the NFT.
    /// @param _superToken The SuperToken used for streaming subscription payments.
    /// @param _minFlowRate The minimum flow rate for the voter to be considered a member.
    /// @param _stake The amount of ETH (Native Asset) that is staked by the voter.
    /// @param _cfa The Superfluid Constant Flow Agreement used for streaming subscription payments.
    constructor(
        string memory _name,
        string memory _symbol,
        ISuperToken _superToken,
        int96 _minFlowRate,
        uint256 _stake,
        IConstantFlowAgreementV1 _cfa
    ) ERC721(_name, _symbol) Ownable() EIP712(_name, "1") {
        superToken = _superToken;
        minFlowRate = _minFlowRate;
        stake = _stake;
        cfa = _cfa;
        _pause();
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @dev These interfaces need to be declared in order for the token voting setup to not create a new token.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId) public view virtual override returns (bool) {
        return
            _interfaceId == type(IERC20Upgradeable).interfaceId ||
            _interfaceId == type(IVotesUpgradeable).interfaceId ||
            _interfaceId == type(IGovernanceWrappedERC20).interfaceId ||
            super.supportsInterface(_interfaceId);
    }

    // -----------------------------------------------------------------------------
    // Admin functions
    // -----------------------------------------------------------------------------

    /// @notice Sets the DAO address and transfers ownership to it.
    /// @dev Can only be called by the contract owner.
    /// @dev This is a separate function from the constructor because the DAO address is not known at the time of deployment.
    /// @param _dao The address of the DAO.
    function setDao(address _dao) external onlyOwner {
        if (_dao == address(0)) revert DaoCannotBeZeroAddress();

        dao = _dao;
        transferOwnership(_dao);
        _unpause();
    }

    /// @notice Sets the minimum flow rate for the voter to be considered a member.
    /// @dev Can only be called by the contract owner.
    /// @param _minFlowRate The new minimum flow rate.
    function setMinFlowRate(int96 _minFlowRate) external onlyOwner {
        if (_minFlowRate <= 0) {
            revert MinFlowRateCannotBeZeroOrNegative({minFlowRate: _minFlowRate});
        }
        minFlowRate = _minFlowRate;
    }

    // -----------------------------------------------------------------------------
    // External functions
    // -----------------------------------------------------------------------------

    /// @notice Mints a new token to a given address.
    /// @dev Can only be called when the contract is not paused.
    /// @param to The address to mint the token to.
    function mint(address to) external payable whenNotPaused {
        // Check if the subscription is active and get the flow rate
        (bool isActive, int96 flowRate) = _isSubscriptionActive(to);
        // Check if the sent value is less than the stake
        if (msg.value < stake) {
            revert InsufficientStake({requiredStake: stake, providedStake: msg.value});
        }
        // Check if the address already has a token
        if (balanceOf(to) > 0) revert AlreadyMinted({to: to});
        // Check if the flow rate is sufficient
        if (!isActive) revert InsufficientFlowRate({required: minFlowRate, actual: flowRate});

        // Mint the token
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) public override(ERC721Burnable) whenNotPaused {
        (bool isMember, int96 flowRate) = _isSubscriptionActive(ownerOf(tokenId));
        if (isMember) revert SufficientFlowRate({required: minFlowRate, actual: flowRate});

        super.burn(tokenId);

        (bool sent, ) = _msgSender().call{value: stake}("");
        if (!sent) revert FailedToTransferEther({to: _msgSender(), amount: stake});
    }

    // -----------------------------------------------------------------------------
    // Internal functions
    // -----------------------------------------------------------------------------
    function _isSubscriptionActive(address member) internal view returns (bool, int96) {
        // TODO: im sure this is not correct
        (, int96 flowRate, , ) = cfa.getFlow(superToken, member, dao);
        return (flowRate >= minFlowRate, flowRate);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);

        // Disallow transfers between users
        if (from != address(0) && to != address(0)) revert NonTransferable();
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Votes) {
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);

        // Automatically turn on delegation on mint/transfer but only for the first time.
        if (to != address(0) && delegates(to) == address(0)) {
            _delegate(to, to);
        }
    }
}
