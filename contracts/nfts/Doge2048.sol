// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {ERC20Vault} from '../ERC20Vault.sol';
import {ERC2981} from '../utils/ERC2981.sol';
import {OwnableByERC721} from '../utils/OwnableByERC721.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {TransferHelper} from '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import {IInfinityFactory} from '../InfinityFactory.sol';

contract Doge2048 is ERC20Vault, Initializable {
  string public name;
  uint32 public score;
  uint32 public numPlays;

  /* initialization functions */

  function initialize(uint256 tokenId) external virtual override initializer {
    name = 'doge2048';
    OwnableByERC721._setNFT(msg.sender, tokenId);
  }

  /* reads */

  function factoryOwner() public view returns (address) {
    return Ownable(nftFactory()).owner();
  }

  function getTokenBalance(address token) public view returns (uint256) {
    return ERC20(token).balanceOf(address(this));
  }

  function saveState(address gameToken, uint32 newScore) external onlyOwner {
    // check if token is valid
    require(IInfinityFactory(nftFactory()).isValidGameToken(name, gameToken), 'invalid game token');

    // check for sufficient balance required to play
    uint32 gameTokensPerPlay = IInfinityFactory(nftFactory()).gameTokensPerPlay(name, gameToken);
    uint8 decimals = ERC20(gameToken).decimals();
    uint256 numRequired = gameTokensPerPlay * (10**decimals);
    require(ERC20(gameToken).balanceOf(address(this)) >= numRequired, 'insufficient game token balance');

    // update score only if best score
    if (newScore > score) {
      score = newScore;
    }
    // update num plays
    numPlays++;

    // deduct tokens required to play
    address pool = IInfinityFactory(nftFactory()).getPrizePool(name);
    TransferHelper.safeTransfer(gameToken, pool, numRequired);
  }
}
