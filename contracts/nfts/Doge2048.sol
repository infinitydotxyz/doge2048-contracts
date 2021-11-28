// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20Vault} from '../ERC20Vault.sol';
import {ERC2981} from '../utils/ERC2981.sol';
import {OwnableByERC721} from '../utils/OwnableByERC721.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';

contract Doge2048 is ERC20Vault, Initializable {
  string public attribute;

  /* initialization function */

  /**
    @dev Should be called by a NFT minting contract as part of the mint function.
    */
  function initialize(uint256 tokenId) external virtual override initializer {
    OwnableByERC721._setNFT(msg.sender, tokenId);
    attribute = 'yo';
  }
}
