// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import "./IHelix4626.sol";
import "./IHelixV1.sol";

/** 
 @title ERC4626Router Interface
 @notice Extends the ERC4626RouterBase with specific flows to save gas
 */
interface IHelix4626Router {
    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice deposit `amount` to an ERC4626 vault.
     @param vault The ERC4626 vault to deposit assets to.
     @param to The destination of ownership shares.
     @param amount The amount of assets to deposit to `vault`.
     @param minSharesOut The min amount of `vault` shares received by `to`.
     @return . the amount of shares received by `to`.
     @dev throws "!minShares" Error.
    */
    function depositToVault(
        IHelix4626 vault,
        uint256 amount,
        address to,
        uint256 minSharesOut
    ) external payable returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            MIGRATION
    //////////////////////////////////////////////////////////////*/

    /** 
     @notice will redeem `shares` from one vault and deposit amountOut to a different ERC4626 vault.
     @param fromVault The ERC4626 vault to redeem shares from.
     @param toVault The ERC4626 vault to deposit assets to.
     @param shares The amount of shares to redeem from fromVault.
     @param to The destination of ownership shares.
     @param minSharesOut The min amount of toVault shares received by `to`.
     @return . the amount of shares received by `to`.
     @dev throws "!minAmount", "!minShares" Errors.
    */
    function migrate(
        IHelix4626 fromVault,
        IHelix4626 toVault,
        uint256 shares,
        address to,
        uint256 minSharesOut
    ) external payable returns (uint256);

    /*//////////////////////////////////////////////////////////////
                            V2 MIGRATION
    //////////////////////////////////////////////////////////////*/

    /**
     @notice migrate from Helix V2 vault to a V3 vault'.
     @param fromVault The Helix V2 vault to withdraw from.
     @param toVault The Helix V3 vault to deposit assets to.
     @param shares The amount of V2 shares to redeem form 'fromVault'.
     @param to The destination of ownership shares
     @param minSharesOut The min amount of 'toVault' shares to be received by 'to'.
     @return . The actual amount of 'toVault' shares received by 'to'.
     @dev throws "!minAmount", "!minShares" Errors.
    */
    function migrateFromV2(
        IHelixV1 fromVault,
        IHelix4626 toVault,
        uint256 shares,
        address to,
        uint256 minSharesOut
    ) external payable returns (uint256);
}
