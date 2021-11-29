// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ERC20Vault} from '../ERC20Vault.sol';
import {ERC2981} from '../utils/ERC2981.sol';
import {OwnableByERC721} from '../utils/OwnableByERC721.sol';
import {Initializable} from '@openzeppelin/contracts/proxy/utils/Initializable.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {TransferHelper} from '@uniswap/lib/contracts/libraries/TransferHelper.sol';

contract Doge2048 is ERC20Vault, Initializable {
  uint32 public score;
  uint32 public numPlays;

  mapping(address => uint256) public gameTokenBalances;

  /* modifiers */
  // set to the minting factory's owner
  modifier onlyGame() {
    require(msg.sender == factoryOwner(), 'only game');
    _;
  }

  /* initialization functions */

  function initialize(uint256 tokenId) external virtual override initializer {
    OwnableByERC721._setNFT(msg.sender, tokenId);
  }

  /* reads */

  function factoryOwner() public view returns (address) {
    return Ownable(nftFactory()).owner();
  }

  function getTokenBalance(address token) public view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
  }

  /** ONLY OWNER **/

  function topupGameTokenBalance(address gameToken, uint256 amount) external onlyOwner {
    require(
      IERC20(gameToken).balanceOf(address(this)) >= gameTokenBalances[gameToken] + amount,
      'ERC20Vault: insufficient balance'
    );
    gameTokenBalances[gameToken] = gameTokenBalances[gameToken] + amount;
  }

  function reduceGameTokenBalance(address gameToken, uint256 amount) external onlyOwner {
    require(gameTokenBalances[gameToken] >= amount, 'insufficient game token balance');
    gameTokenBalances[gameToken] = gameTokenBalances[gameToken] - amount;
  }

  /** ONLY GAME **/

  function initializeGameTokenBalance(address gameToken, uint256 amount) external onlyGame {
    require(
      IERC20(gameToken).balanceOf(address(this)) >= gameTokenBalances[gameToken] + amount,
      'ERC20Vault: insufficient balance'
    );
    require(numPlays == 0, 'game already played');
    gameTokenBalances[gameToken] = gameTokenBalances[gameToken] + amount;
  }

  function saveState(
    address gameToken,
    uint256 gameTokensPerPlay,
    uint32 newScore,
    address pool
  ) external onlyGame {
    // check for sufficient balance required to play
    require(IERC20(gameToken).balanceOf(address(this)) >= gameTokensPerPlay, 'ERC20Vault: insufficient balance');
    require(gameTokenBalances[gameToken] >= gameTokensPerPlay, 'insufficient game token balance');
    require(pool != address(0), 'pool address is null');

    // update score only if best score
    if (newScore > score) {
      score = newScore;
    }
    // update num plays
    numPlays++;
    // update game balances
    gameTokenBalances[gameToken] = gameTokenBalances[gameToken] - gameTokensPerPlay;

    // deduct tokens required to play
    TransferHelper.safeTransfer(gameToken, pool, gameTokensPerPlay);
  }
}
