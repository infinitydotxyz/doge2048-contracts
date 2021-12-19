// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.4;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract InfinityMockERC20 is ERC20('InfinityMock', 'INFTMOCK') {
  constructor() {
    _mint(msg.sender, 100_000_000 * (10**decimals()));
  }
}
