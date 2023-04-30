// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./FiatTokenV2.sol";

contract FiatTokenV3 is FiatTokenV2_1 {
    using SafeMath for uint256;

    mapping(address => bool) public whitelist;

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "not whitelisted");
        _;
    }

    function addToWhiteList(address _addr) external {
        whitelist[_addr] = true;
    }

    function isWhiteListed(address _addr) external view returns (bool) {
        return whitelist[_addr];
    }

    /// @dev Since transfer in V2 is not virtual, we can't override it. Create a new function instead.
    function newTransfer(
        address _to,
        uint256 _value
    ) external onlyWhitelisted returns (bool) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /// @dev Since mint in V2 is not virtual, we can't override it. Create a new function instead.
    function newMint(
        address _to,
        uint256 _amount
    ) external onlyWhitelisted returns (bool) {
        require(_to != address(0), "FiatTokenV3: mint to the zero address");
        require(_amount > 0, "FiatTokenV3: mint amount not greater than 0");

        totalSupply_ = totalSupply_.add(_amount);
        balances[_to] = balances[_to].add(_amount);
        emit Mint(msg.sender, _to, _amount);
        emit Transfer(address(0), _to, _amount);
        return true;
    }
}
