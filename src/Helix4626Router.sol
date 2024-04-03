// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.18;

import "./Helix4626RouterBase.sol";
import {IHelix4626Router, IHelixV1} from "./interfaces/IHelix4626Router.sol";

/**
 * @title Helix4626Router contract
 * @notice
 *  Router that is meant to be used with Helix vaults and strategies
 *  for deposits, withdraws and migrations.
 *
 *  The router was developed from the original router by FEI protocol
 *  https://github.com/fei-protocol/ERC4626
 *
 *  The router is designed to be used with permit and multicall for the
 *  optimal experience.
 *
 *  NOTE: It is important to never leave tokens in the router at the
 *  end of a call, otherwise they can be swept by anyone.
 */
contract Helix4626Router is IHelix4626Router, Helix4626RouterBase {
    using SafeTransferLib for ERC20;

    // Store name as bytes so it can be immutable
    bytes32 private immutable _name;

    constructor(string memory _name_, IWETH9 weth) PeripheryPayments(weth) {
        _name = bytes32(abi.encodePacked(_name_));
    }

    // Getter function to unpack stored name.
    function name() external view returns (string memory) {
        return string(abi.encodePacked(_name));
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT
    //////////////////////////////////////////////////////////////*/

    // For the below, no approval needed, assumes vault is already max approved

    /// @inheritdoc IHelix4626Router
    function depositToVault(
        IHelix4626 vault,
        uint256 amount,
        address to,
        uint256 minSharesOut
    ) public payable override returns (uint256) {
        pullToken(ERC20(vault.asset()), amount, address(this));
        return deposit(vault, amount, to, minSharesOut);
    }

    //-------- DEPOSIT FUNCTIONS WITH DEFAULT VALUES --------\\

    /**
     @notice See {depositToVault} in IHelix4626Router.
     @dev Uses msg.sender as the default for `to`.
    */
    function depositToVault(IHelix4626 vault, uint256 amount, uint256 minSharesOut) external payable returns (uint256) {
        return depositToVault(vault, amount, msg.sender, minSharesOut);
    }

    /**
     @notice See {depositToVault} in IHelix4626Router.
     @dev Uses msg.sender as the default for `to` and their full 
     balance of msg.sender as `amount`.
    */
    function depositToVault(IHelix4626 vault, uint256 minSharesOut) external payable returns (uint256) {
        uint256 amount = ERC20(vault.asset()).balanceOf(msg.sender);
        return depositToVault(vault, amount, msg.sender, minSharesOut);
    }

    /**
     @notice See {depositToVault} in IHelix4626Router.
     @dev Uses msg.sender as the default for `to`, their full balance 
     of msg.sender as `amount` and 1 Basis point for `maxLoss`.
     
     NOTE: The slippage tollerance is only useful if {previewDeposit}
     cannot be manipulated for the `vault`.
    */
    function depositToVault(IHelix4626 vault) external payable returns (uint256) {
        uint256 assets = ERC20(vault.asset()).balanceOf(msg.sender);
        // This give a default 1Basis point acceptance for loss. This is only
        // considered safe if the vaults PPS can not be manipulated.
        uint256 minSharesOut = (vault.previewDeposit(assets) * 9_999) / 10_000;
        return depositToVault(vault, assets, msg.sender, minSharesOut);
    }

    /*//////////////////////////////////////////////////////////////
                            REDEEM
    //////////////////////////////////////////////////////////////*/

    //-------- REDEEM FUNCTIONS WITH DEFAULT VALUES --------\\

    /**
     @notice See {redeem} in IHelix4626RouterBase.
     @dev Uses msg.sender as `receiver`.
    */
    function redeem(IHelix4626 vault, uint256 shares, uint256 maxLoss) external payable returns (uint256) {
        return redeem(vault, shares, msg.sender, maxLoss);
    }

    /**
     @notice See {redeem} in IHelix4626RouterBase.
     @dev Uses msg.sender as `receiver` and their full balance as `shares`.
    */
    function redeem(IHelix4626 vault, uint256 maxLoss) external payable returns (uint256) {
        uint256 shares = vault.balanceOf(msg.sender);
        return redeem(vault, shares, msg.sender, maxLoss);
    }

    /**
     @notice See {redeem} in IHelix4626RouterBase.
     @dev Uses msg.sender as `receiver`, their full balance as `shares`
     and 1 Basis Point for `maxLoss`.
    */
    function redeem(IHelix4626 vault) external payable returns (uint256) {
        uint256 shares = vault.balanceOf(msg.sender);
        return redeem(vault, shares, msg.sender, 1);
    }

    /*//////////////////////////////////////////////////////////////
                            MIGRATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHelix4626Router
    function migrate(
        IHelix4626 fromVault,
        IHelix4626 toVault,
        uint256 shares,
        address to,
        uint256 minSharesOut
    ) public payable override returns (uint256) {
        // amount out passes through so only one slippage check is needed
        uint256 amount = redeem(fromVault, shares, address(this), 10_000);
        return deposit(toVault, amount, to, minSharesOut);
    }

    //-------- MIGRATE FUNCTIONS WITH DEFAULT VALUES --------\\

    /**
     @notice See {migrate} in IHelix4626Router.
     @dev Uses msg.sender as `to`.
    */
    function migrate(
        IHelix4626 fromVault,
        IHelix4626 toVault,
        uint256 shares,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        return migrate(fromVault, toVault, shares, msg.sender, minSharesOut);
    }

    /**
     @notice See {migrate} in IHelix4626Router.
     @dev Uses msg.sender as `to` and their full balance for `shares`.
    */
    function migrate(
        IHelix4626 fromVault,
        IHelix4626 toVault,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        uint256 shares = fromVault.balanceOf(msg.sender);
        return migrate(fromVault, toVault, shares, msg.sender, minSharesOut);
    }

    /**
     @notice See {migrate} in IHelix4626Router.
     @dev Uses msg.sender as `to`, their full balance for `shares` and no `minamountOut`.

     NOTE: Using this will enforce no slippage checks and should be used with care.
    */
    function migrate(IHelix4626 fromVault, IHelix4626 toVault) external payable returns (uint256) {
        uint256 shares = fromVault.balanceOf(msg.sender);
        return migrate(fromVault, toVault, shares, msg.sender, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        V2 MIGRATION
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IHelix4626Router
    function migrateFromV2(
        IHelixV1 fromVault,
        IHelix4626 toVault,
        uint256 shares,
        address to,
        uint256 minSharesOut
    ) public payable override returns (uint256) {
        // V2 can't specify owner so we need to first pull the shares
        fromVault.transferFrom(msg.sender, address(this), shares);
        // amount out passes through so only one slippage check is needed
        uint256 redeemed = fromVault.withdraw(shares, address(this));
        return deposit(toVault, redeemed, to, minSharesOut);
    }

    //-------- migrateFromV2 FUNCTIONS WITH DEFAULT VALUES --------\\

    /**
     @notice See {migrateFromV2} in IHelix4626Router.
     @dev Uses msg.sender as `to`.
    */
    function migrateFromV2(
        IHelixV1 fromVault,
        IHelix4626 toVault,
        uint256 shares,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        return migrateFromV2(fromVault, toVault, shares, msg.sender, minSharesOut);
    }

    /**
     @notice See {migrateFromV2} in IHelix4626Router.
     @dev Uses msg.sender as `to` and their full balance as `shares`.
    */
    function migrateFromV2(
        IHelixV1 fromVault,
        IHelix4626 toVault,
        uint256 minSharesOut
    ) external payable returns (uint256) {
        uint256 shares = fromVault.balanceOf(msg.sender);
        return migrateFromV2(fromVault, toVault, shares, msg.sender, minSharesOut);
    }

    /**
     @notice See {migrate} in IHelix4626Router.
     @dev Uses msg.sender as `to`, their full balance for `shares` and no `minamountOut`.

     NOTE: Using this will enforce no slippage checks and should be used with care.
    */
    function migrateFromV2(IHelixV1 fromVault, IHelix4626 toVault) external payable returns (uint256 sharesOut) {
        uint256 shares = fromVault.balanceOf(msg.sender);
        return migrateFromV2(fromVault, toVault, shares, msg.sender, 0);
    }
}
