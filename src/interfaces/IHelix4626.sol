// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import {IERC4626} from "./IERC4626.sol";

/// @title Helix ERC4626 interface
/// @notice Extends the normal 4626 standard with some added Helix specific functionality
abstract contract IHelix4626 is IERC4626 {
    /*////////////////////////////////////////////////////////
                    Helix Specific Functions
    ////////////////////////////////////////////////////////*/

    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxLoss
    ) external virtual returns (uint256 shares);

    /// @notice Helix Specific "withdraw" with withdrawal stack included
    function withdraw(
        uint256 assets,
        address receiver,
        address owner,
        uint256 maxLoss,
        address[] memory strategies
    ) external virtual returns (uint256 shares);

    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 maxLoss
    ) external virtual returns (uint256 assets);

    /// @notice Helix Specific "redeem" with withdrawal stack included
    function redeem(
        uint256 shares,
        address receiver,
        address owner,
        uint256 maxLoss,
        address[] memory strategies
    ) external virtual returns (uint256 assets);
}
