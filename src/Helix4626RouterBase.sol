// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import {IHelix4626RouterBase, IHelix4626} from "./interfaces/IHelix4626RouterBase.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {SelfPermit} from "./external/SelfPermit.sol";
import {Multicall} from "./external/Multicall.sol";
import {PeripheryPayments, IWETH9} from "./external/PeripheryPayments.sol";

/// @title ERC4626 Router Base Contract
abstract contract Helix4626RouterBase is IHelix4626RouterBase, SelfPermit, Multicall, PeripheryPayments {
    using SafeTransferLib for ERC20;

    /// @inheritdoc IHelix4626RouterBase
    function mint(
        IHelix4626 vault,
        uint256 shares,
        address to,
        uint256 maxAmountIn
    ) public payable virtual override returns (uint256 amountIn) {
        require((amountIn = vault.mint(shares, to)) <= maxAmountIn, "!MaxAmount");
    }

    /// @inheritdoc IHelix4626RouterBase
    function deposit(
        IHelix4626 vault,
        uint256 amount,
        address to,
        uint256 minSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        require((sharesOut = vault.deposit(amount, to)) >= minSharesOut, "!MinShares");
    }

    /// @inheritdoc IHelix4626RouterBase
    function withdraw(
        IHelix4626 vault,
        uint256 amount,
        address to,
        uint256 maxLoss
    ) public payable virtual override returns (uint256) {
        return vault.withdraw(amount, to, msg.sender, maxLoss);
    }

    /// @inheritdoc IHelix4626RouterBase
    function withdrawDefault(
        IHelix4626 vault,
        uint256 amount,
        address to,
        uint256 maxSharesOut
    ) public payable virtual override returns (uint256 sharesOut) {
        require((sharesOut = vault.withdraw(amount, to, msg.sender)) <= maxSharesOut, "!MaxShares");
    }

    /// @inheritdoc IHelix4626RouterBase
    function redeem(
        IHelix4626 vault,
        uint256 shares,
        address to,
        uint256 maxLoss
    ) public payable virtual override returns (uint256) {
        return vault.redeem(shares, to, msg.sender, maxLoss);
    }

    /// @inheritdoc IHelix4626RouterBase
    function redeemDefault(
        IHelix4626 vault,
        uint256 shares,
        address to,
        uint256 minAmountOut
    ) public payable virtual override returns (uint256 amountOut) {
        require((amountOut = vault.redeem(shares, to, msg.sender)) >= minAmountOut, "!MinAmount");
    }
}
