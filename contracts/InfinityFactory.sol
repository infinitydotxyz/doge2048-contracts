// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {ERC721Enumerable} from '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {ProxyFactory} from './factory/ProxyFactory.sol';
import {IVault} from './interfaces/IVault.sol';
import {TransferHelper} from '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import {ERC165Storage} from '@openzeppelin/contracts/utils/introspection/ERC165Storage.sol';
import './interfaces/IERC2981.sol';
import '@openzeppelin/contracts/utils/Counters.sol';

/// @title InfinityFactory
/// @dev Contract that mints NFTs of different variations of a collection
contract InfinityFactory is Ownable, ERC721Enumerable, ERC165Storage, IERC2981 {
  using SafeMath for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;
  using Counters for Counters.Counter;

  mapping(string => Counters.Counter) private _mintCounter;
  mapping(string => Counters.Counter) private _teamMintCounter;

  string[] public variationNames;
  mapping(string => address) public variations;
  mapping(string => uint256) public mintFee;
  mapping(string => bool) public isMinting;
  mapping(string => uint256) public maxMints;
  mapping(string => uint256) public maxTeamMints;
  mapping(uint256 => address) public tokenIdToInstance;
  mapping(string => Royalty) private _royalties;
  string public baseUri;
  struct Royalty {
    address royaltyAddress;
    uint8 percentage;
  }
  address public royaltyReceiver = address(this);
  uint8 public royaltyPercentage = 5;

  event VariationAdded(string name, address variation);
  event VariationRemoved(string name, address variation);
  event EtherReceived(address from, uint256 value);
  event Minted(address to, uint256 tokenId);
  event UpdatedBaseURI(string _old, string _new);
  event UpdatedMintingStatus(string variationName, bool oldStatus, bool newStatus);
  event UpdatedMintFee(string variationName, uint256 oldFee, uint256 mintFee);
  event UpdatedRoyalties(string variationName, address _royaltyAddress, uint256 _percentage);
  event UpdatedMintSize(string variationName, uint256 old, uint256 newSize);
  event UpdatedTeamMintSize(string variationName, uint256 old, uint256 newSize);

  // bytes4 constants for ERC165
  bytes4 private constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
  bytes4 private constant _INTERFACE_ID_IERC2981 = 0x2a55205a;

  constructor() ERC721('Doge 2048 NFT', 'Doge2048') {
    _registerInterface(_INTERFACE_ID_ERC721);
    _registerInterface(_INTERFACE_ID_IERC2981);
  }

  receive() external payable {
    emit EtherReceived(msg.sender, msg.value);
  }

  /* factory functions */

  /**
        @dev Mints a new NFT of the given variation
        @param variationName Name of the variation
        @param numItems num mints
    */
  function mint(string calldata variationName, uint256 numItems) public payable {
    require(isMinting[variationName], 'variation not minting');
    require(variations[variationName] != address(0), 'variation not found');
    require(_mintCounter[variationName].current().add(numItems) < maxMints[variationName], 'all minted');
    require(msg.value == mintFee[variationName].mul(numItems), 'incorrect mint fees');

    // create clone and initialize
    uint256 supply = totalSupply();
    for (uint256 i = 0; i < numItems; i++) {
      uint256 tokenId = supply.add(i);
      address instance = ProxyFactory._create(
        variations[variationName],
        abi.encodeWithSelector(IVault.initialize.selector, tokenId)
      );
      _safeMint(msg.sender, tokenId);
      // mappings
      tokenIdToInstance[tokenId] = instance;
      _mintCounter[variationName].increment();
      // emit event
      emit Minted(msg.sender, tokenId);
    }
  }

  /* getter functions */

  function numVariations() public view returns (uint256) {
    return variationNames.length;
  }

  function variationAt(uint256 index) public view returns (string memory) {
    return variationNames[index];
  }

  function getRoyaltyInfo(string calldata variationName) public view returns (address, uint8) {
    return (_royalties[variationName].royaltyAddress, _royalties[variationName].percentage);
  }

  // @notice solidity required override for _baseURI()
  function _baseURI() internal view override returns (string memory) {
    return baseUri;
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC165Storage, ERC721Enumerable, IERC165)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }

  // @notice will return current mint count
  function numMints(string calldata variationName) public view returns (uint256) {
    return _mintCounter[variationName].current();
  }

  // @notice will return mints left
  function mintsLeft(string calldata variationName) external view returns (uint256) {
    return maxMints[variationName] - numMints(variationName);
  }

  // @notice will return "team mints" count
  function numTeamMints(string calldata variationName) public view returns (uint256) {
    return _teamMintCounter[variationName].current();
  }

  // @notice will return "team mints" left
  function teamMintsLeft(string calldata variationName) external view returns (uint256) {
    return maxTeamMints[variationName] - numTeamMints(variationName);
  }

  // ERC165
  // Override for royaltyInfo(uint256, uint256)
  // royaltyInfo(uint256,uint256) => 0x2a55205a
  function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
    external
    view
    override(IERC2981)
    returns (address receiver, uint256 royaltyAmount)
  {
    receiver = address(this);
    // This sets percentages by price * percentage / 100
    royaltyAmount = _salePrice.mul(royaltyPercentage).div(100);
  }

  /***
   *     ██████╗ ██╗    ██╗███╗   ██╗███████╗██████╗
   *    ██╔═══██╗██║    ██║████╗  ██║██╔════╝██╔══██╗
   *    ██║   ██║██║ █╗ ██║██╔██╗ ██║█████╗  ██████╔╝
   *    ██║   ██║██║███╗██║██║╚██╗██║██╔══╝  ██╔══██╗
   *    ╚██████╔╝╚███╔███╔╝██║ ╚████║███████╗██║  ██║
   *     ╚═════╝  ╚══╝╚══╝ ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝
   * This section will have all the internals set to onlyOwner
   */

  function teamMint(
    string calldata variationName,
    address to,
    uint256 numItems
  ) external onlyOwner {
    require(isMinting[variationName], 'variation not minting');
    require(variations[variationName] != address(0), 'variation not found');
    require(_mintCounter[variationName].current().add(numItems) < maxMints[variationName], 'all minted');
    require(
      _teamMintCounter[variationName].current().add(numItems) < maxTeamMints[variationName],
      'all team supply minted'
    );

    // create clone and initialize
    uint256 supply = totalSupply();
    for (uint256 i = 0; i < numItems; i++) {
      uint256 tokenId = supply.add(i);
      address instance = ProxyFactory._create(
        variations[variationName],
        abi.encodeWithSelector(bytes4(keccak256('initialize(uint)')), tokenId)
      );
      _safeMint(to, tokenId);
      // mappings
      tokenIdToInstance[tokenId] = instance;
      _mintCounter[variationName].increment();
      _teamMintCounter[variationName].increment();
      // emit event
      emit Minted(to, tokenId);
    }
  }

  /**
        @dev Adds a new variation so that NFTs of the type become mintable.
        @param variationName Name of the variation
        @param variation Address of the variation
    */
  function addVariation(string calldata variationName, address variation) external onlyOwner {
    require(variations[variationName] == address(0), 'variation already exists');
    variations[variationName] = variation;
    variationNames.push(variationName);
    emit VariationAdded(variationName, variation);
  }

  function removeVariation(string calldata variationName) external onlyOwner {
    require(variations[variationName] != address(0), 'no variation');
    emit VariationRemoved(variationName, variations[variationName]);
    delete variations[variationName];
    // we dont care about removing varition name from variation names array
  }

  function setMintFee(string calldata variationName, uint256 amount) external onlyOwner {
    require(variations[variationName] != address(0), 'variation not found');
    uint256 old = mintFee[variationName];
    mintFee[variationName] = amount;
    emit UpdatedMintFee(variationName, old, mintFee[variationName]);
  }

  // @notice will set mint size
  function setMaxMints(string calldata variationName, uint256 amount) external onlyOwner {
    require(variations[variationName] != address(0), 'variation not found');
    uint256 old = maxMints[variationName];
    maxMints[variationName] = amount;
    emit UpdatedMintSize(variationName, old, maxMints[variationName]);
  }

  function setMaxTeamMints(string calldata variationName, uint256 amount) external onlyOwner {
    require(variations[variationName] != address(0), 'variation not found');
    uint256 old = maxTeamMints[variationName];
    maxTeamMints[variationName] = amount;
    emit UpdatedTeamMintSize(variationName, old, maxTeamMints[variationName]);
  }

  // @notice will update _baseURI()
  function setBaseURI(string memory uri) external onlyOwner {
    string memory old = baseUri;
    baseUri = uri;
    emit UpdatedBaseURI(old, baseUri);
  }

  function setRoyalty(
    address receiver,
    uint8 percentage
  ) external onlyOwner {
    royaltyReceiver = receiver;
    royaltyPercentage = percentage;
    emit UpdatedRoyalties('Global', receiver, percentage);
  }

  function setRoyaltyInfo(
    string calldata variationName,
    address royaltyAddress,
    uint8 percentage
  ) external onlyOwner {
    require(variations[variationName] != address(0), 'variation not found');
    _royalties[variationName] = Royalty(royaltyAddress, percentage);
    emit UpdatedRoyalties(variationName, royaltyAddress, percentage);
  }

  // @notice this will enable publicMint()
  function enableMinting(string calldata variationName) external onlyOwner {
    require(variations[variationName] != address(0), 'variation not found');
    bool old = isMinting[variationName];
    isMinting[variationName] = true;
    emit UpdatedMintingStatus(variationName, old, isMinting[variationName]);
  }

  // @notice this will disable publicMint()
  function disableMinting(string calldata variationName) external onlyOwner {
    require(variations[variationName] != address(0), 'variation not found');
    bool old = isMinting[variationName];
    isMinting[variationName] = false;
    emit UpdatedMintingStatus(variationName, old, isMinting[variationName]);
  }

  function transferETH(address to, uint256 amount) external payable onlyOwner {
    // perform transfer
    TransferHelper.safeTransferETH(to, amount);
  }

  /** 
        @dev Transfer ERC20 tokens out. Access control: only owner. Token transfer: transfer any ERC20 token.
        @param token Address of token being transferred.
        @param to Address of the recipient.
        @param amount Amount of tokens to transfer.
    */
  function transferERC20(
    address token,
    address to,
    uint256 amount
  ) external onlyOwner {
    // perform transfer
    TransferHelper.safeTransfer(token, to, amount);
  }
}
