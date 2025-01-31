pragma solidity 0.8.18;

import {ERC20, MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {MockVaultV3} from "./mocks/MockVaultV3.sol";
import {MockHelixV1} from "./mocks/MockHelixV1.sol";
import {WETH} from "solmate/tokens/WETH.sol";

import {IHelix4626Router, Helix4626Router, IHelixV1} from "../Helix4626Router.sol";
import {IHelix4626RouterBase, Helix4626RouterBase, IWETH9, IHelix4626, SelfPermit, PeripheryPayments} from "../Helix4626RouterBase.sol";

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {console} from "./utils/Console.sol";

interface Assume {
    function assume(bool) external;
}

contract ERC4626Test is DSTestPlus {
    MockERC20 underlying;
    IHelix4626 vault;
    IHelix4626 toVault;
    Helix4626Router router;
    IWETH9 weth;
    IHelix4626 wethVault;

    bytes32 public PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    receive() external payable {}

    function setUp() public {
        underlying = new MockERC20("Mock Token", "TKN", 18);

        vault = IHelix4626(address(new MockVaultV3(underlying)));
        toVault = IHelix4626(address(new MockVaultV3(underlying)));

        weth = IWETH9(address(new WETH()));

        wethVault = IHelix4626(address(new MockVaultV3(weth)));

        router = new Helix4626Router("TestHelix4626Router", weth);
    }

    function testMint(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.pullToken(underlying, amount, address(router));

        router.mint(IHelix4626(address(vault)), amount, address(this), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testDeposit(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.pullToken(underlying, amount, address(router));

        router.deposit(IHelix4626(address(vault)), amount, address(this), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testDepositMax(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        Assume(address(hevm)).assume(amount < type(uint256).max / 10_000);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)));

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testDepositToVault(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testDepositToVaultNoTo(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testDepositToVaultNoToOrAmount(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testDepositWithPermit(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.mint(owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    underlying.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        underlying.permit(owner, address(router), amount, block.timestamp, v, r, s);

        router.approve(underlying, address(vault), amount);

        hevm.prank(owner);
        router.depositToVault(vault, amount, owner, amount);

        require(vault.balanceOf(owner) == amount);
        require(underlying.balanceOf(owner) == 0);
    }

    function testDepositWithPermitViaMulticall(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.mint(owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    underlying.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        bytes[] memory data = new bytes[](3);
        data[0] = abi.encodeWithSelector(SelfPermit.selfPermit.selector, underlying, amount, block.timestamp, v, r, s);
        data[1] = abi.encodeWithSelector(PeripheryPayments.approve.selector, underlying, address(vault), amount);
        data[2] = abi.encodeWithSelector(IHelix4626Router.depositToVault.selector, vault, amount, owner, amount);

        hevm.prank(owner);
        router.multicall(data);

        require(vault.balanceOf(owner) == amount);
        require(underlying.balanceOf(owner) == 0);
    }

    function testDepositTo(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        address to = address(1);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, to, amount);

        require(vault.balanceOf(address(this)) == 0);
        require(vault.balanceOf(to) == amount);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testDepositBelowMinOutReverts(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0 && amount != type(uint256).max);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        hevm.expectRevert("!MinShares");
        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount + 1);
    }

    function testMigrateTo(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), type(uint256).max);

        router.approve(underlying, address(vault), amount);
        router.approve(underlying, address(toVault), amount);

        router.depositToVault(vault, amount, address(this), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        vault.approve(address(router), type(uint256).max);

        router.migrate(vault, toVault, amount, address(this), amount);

        require(toVault.balanceOf(address(this)) == amount);
        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testMigrateNoTo(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), type(uint256).max);

        router.approve(underlying, address(vault), amount);
        router.approve(underlying, address(toVault), amount);

        router.depositToVault(vault, amount, address(this), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        vault.approve(address(router), type(uint256).max);

        router.migrate(vault, toVault, amount, amount);

        require(toVault.balanceOf(address(this)) == amount);
        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testMigrateNoToOrAmount(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), type(uint256).max);

        router.approve(underlying, address(vault), amount);
        router.approve(underlying, address(toVault), amount);

        router.depositToVault(vault, amount, address(this), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        vault.approve(address(router), type(uint256).max);

        router.migrate(vault, toVault, amount);

        require(toVault.balanceOf(address(this)) == amount);
        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testMigrateMaxNoMin(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), type(uint256).max);

        router.approve(underlying, address(vault), amount);
        router.approve(underlying, address(toVault), amount);

        router.depositToVault(vault, amount, address(this), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        vault.approve(address(router), type(uint256).max);

        router.migrate(vault, toVault);

        require(toVault.balanceOf(address(this)) == amount);
        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testMigrateToBelowMinOutReverts(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0 && amount != type(uint128).max);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), type(uint256).max);

        router.approve(underlying, address(vault), amount);
        router.approve(underlying, address(toVault), amount);

        router.depositToVault(vault, amount, address(this), amount);

        require(vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        vault.approve(address(router), type(uint256).max);

        hevm.expectRevert("!MinShares");
        router.migrate(vault, toVault, amount, address(this), amount + 1);
    }

    function testmigrateFromV2To(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        MockHelixV1 v1Vault = new MockHelixV1(underlying);

        underlying.approve(address(v1Vault), type(uint256).max);

        v1Vault.deposit(amount, address(this));

        require(v1Vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        router.approve(underlying, address(toVault), amount);

        v1Vault.approve(address(router), type(uint256).max);

        router.migrateFromV2(IHelixV1(address(v1Vault)), toVault, amount, address(this), amount);

        require(toVault.balanceOf(address(this)) == amount);
        require(v1Vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testmigrateFromV2NoTo(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        MockHelixV1 v1Vault = new MockHelixV1(underlying);

        underlying.approve(address(v1Vault), type(uint256).max);

        v1Vault.deposit(amount, address(this));

        require(v1Vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        router.approve(underlying, address(toVault), amount);

        v1Vault.approve(address(router), type(uint256).max);

        router.migrateFromV2(IHelixV1(address(v1Vault)), toVault, amount, amount);

        require(toVault.balanceOf(address(this)) == amount);
        require(v1Vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testmigrateFromV2NoToOrAmount(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        MockHelixV1 v1Vault = new MockHelixV1(underlying);

        underlying.approve(address(v1Vault), type(uint256).max);

        v1Vault.deposit(amount, address(this));

        require(v1Vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        router.approve(underlying, address(toVault), amount);

        v1Vault.approve(address(router), type(uint256).max);

        router.migrateFromV2(IHelixV1(address(v1Vault)), toVault, amount);

        require(toVault.balanceOf(address(this)) == amount);
        require(v1Vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testmigrateFromV2MaxNoMin(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        MockHelixV1 v1Vault = new MockHelixV1(underlying);

        underlying.approve(address(v1Vault), type(uint256).max);

        v1Vault.deposit(amount, address(this));

        require(v1Vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        router.approve(underlying, address(toVault), amount);

        v1Vault.approve(address(router), type(uint256).max);

        router.migrateFromV2(IHelixV1(address(v1Vault)), toVault);

        require(toVault.balanceOf(address(this)) == amount);
        require(v1Vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testmigrateFromV2ToBelowMinOutReverts(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0 && amount != type(uint128).max);
        underlying.mint(address(this), amount);

        MockHelixV1 v1Vault = new MockHelixV1(underlying);

        underlying.approve(address(v1Vault), type(uint256).max);

        v1Vault.deposit(amount, address(this));

        require(v1Vault.balanceOf(address(this)) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        router.approve(underlying, address(toVault), amount);

        v1Vault.approve(address(router), type(uint256).max);

        hevm.expectRevert("!MinShares");
        router.migrateFromV2(IHelixV1(address(v1Vault)), toVault, amount, address(this), amount + 1);
    }

    function testmigrateFromV2WithPermitViaMulticall(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        MockHelixV1 v1Vault = new MockHelixV1(underlying);

        underlying.approve(address(v1Vault), type(uint256).max);

        v1Vault.deposit(amount, owner);

        require(v1Vault.balanceOf(owner) == amount);
        require(underlying.balanceOf(address(this)) == 0);

        router.approve(underlying, address(toVault), amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    v1Vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(SelfPermit.selfPermit.selector, v1Vault, amount, block.timestamp, v, r, s);
        data[1] = abi.encodeWithSelector(
            IHelix4626Router.migrateFromV2.selector,
            IHelixV1(address(v1Vault)),
            toVault,
            amount,
            owner,
            amount
        );

        hevm.prank(owner);
        router.multicall(data);

        require(toVault.balanceOf(owner) == amount);
        require(v1Vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(address(this)) == 0);
    }

    function testWithdraw(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        vault.approve(address(router), amount);
        router.withdraw(vault, amount, address(this), 0);

        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == amount);
    }

    function testWithdrawDefault(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        vault.approve(address(router), amount);
        router.withdrawDefault(vault, amount, address(this), amount);

        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == amount);
    }

    function testWithdrawWithPermit(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        vault.permit(owner, address(router), amount, block.timestamp, v, r, s);

        hevm.prank(owner);
        router.withdraw(vault, amount, owner, 0);

        require(vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(owner) == amount);
    }

    function testWithdrawDefaultWithPermit(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        vault.permit(owner, address(router), amount, block.timestamp, v, r, s);

        hevm.prank(owner);
        router.withdrawDefault(vault, amount, owner, amount);

        require(vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(owner) == amount);
    }

    function testWithdrawWithPermitViaMulticall(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(SelfPermit.selfPermit.selector, vault, amount, block.timestamp, v, r, s);
        data[1] = abi.encodeWithSelector(IHelix4626RouterBase.withdraw.selector, vault, amount, owner, 0);

        hevm.prank(owner);
        router.multicall(data);

        require(vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(owner) == amount);
    }

    function testWithdrawDefaultWithPermitViaMulticall(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(SelfPermit.selfPermit.selector, vault, amount, block.timestamp, v, r, s);
        data[1] = abi.encodeWithSelector(IHelix4626RouterBase.withdrawDefault.selector, vault, amount, owner, amount);

        hevm.prank(owner);
        router.multicall(data);

        require(vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(owner) == amount);
    }

    function testFailWithdrawDefaultAboveMaxOut(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);
        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        vault.approve(address(router), amount);
        router.withdrawDefault(IHelix4626(address(vault)), amount, address(this), amount - 1);
    }

    function testRedeem(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        vault.approve(address(router), amount);
        router.redeem(vault, amount, address(this), 0);

        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == amount);
    }

    function testRedeemDefault(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        vault.approve(address(router), amount);
        router.redeemDefault(vault, amount, address(this), amount);

        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == amount);
    }

    function testRedeemNoTo(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        vault.approve(address(router), amount);
        router.redeem(vault, amount, 0);

        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == amount);
    }

    function testRedeemMax(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        vault.approve(address(router), amount);
        router.redeem(vault);

        require(vault.balanceOf(address(this)) == 0);
        require(underlying.balanceOf(address(this)) == amount);
    }

    function testRedeemWithPermit(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        vault.permit(owner, address(router), amount, block.timestamp, v, r, s);

        hevm.prank(owner);
        router.redeem(vault, amount, owner, 0);

        require(vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(owner) == amount);
    }

    function testRedeemdefaultWithPermit(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        vault.permit(owner, address(router), amount, block.timestamp, v, r, s);

        hevm.prank(owner);
        router.redeemDefault(vault, amount, owner, amount);

        require(vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(owner) == amount);
    }

    function testRedeemWithPermitViaMulticall(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(SelfPermit.selfPermit.selector, vault, amount, block.timestamp, v, r, s);
        data[1] = abi.encodeWithSelector(IHelix4626RouterBase.redeem.selector, vault, amount, owner, 0);

        hevm.prank(owner);
        router.multicall(data);

        require(vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(owner) == amount);
    }

    function testRedeemDefaultWithPermitViaMulticall(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0);
        underlying.mint(address(this), amount);

        uint256 privateKey = 0xBEEF;
        address owner = hevm.addr(privateKey);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, owner, amount);

        (uint8 v, bytes32 r, bytes32 s) = hevm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    vault.DOMAIN_SEPARATOR(),
                    keccak256(abi.encode(PERMIT_TYPEHASH, owner, address(router), amount, 0, block.timestamp))
                )
            )
        );

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(SelfPermit.selfPermit.selector, vault, amount, block.timestamp, v, r, s);
        data[1] = abi.encodeWithSelector(IHelix4626RouterBase.redeemDefault.selector, vault, amount, owner, amount);

        hevm.prank(owner);
        router.multicall(data);

        require(vault.balanceOf(owner) == 0);
        require(underlying.balanceOf(owner) == amount);
    }

    function testRedeemBelowMinOutReverts(uint128 amount) public {
        Assume(address(hevm)).assume(amount != 0 && amount != type(uint128).max);
        underlying.mint(address(this), amount);

        underlying.approve(address(router), amount);

        router.approve(underlying, address(vault), amount);

        router.depositToVault(IHelix4626(address(vault)), amount, address(this), amount);

        vault.approve(address(router), amount);

        hevm.expectRevert("!MinAmount");
        router.redeemDefault(IHelix4626(address(vault)), amount, address(this), amount + 1);
    }

    function testDepositETHToWETHVault(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0 && amount < 100 ether);
        underlying.mint(address(this), amount);

        router.approve(weth, address(wethVault), amount);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(PeripheryPayments.wrapWETH9.selector);
        data[1] = abi.encodeWithSelector(
            Helix4626RouterBase.deposit.selector,
            wethVault,
            amount,
            address(this),
            amount
        );

        router.multicall{value: amount}(data);

        require(wethVault.balanceOf(address(this)) == amount);
        require(weth.balanceOf(address(router)) == 0);
    }

    function testWithdrawETHFromWETHVault(uint256 amount) public {
        Assume(address(hevm)).assume(amount != 0 && amount < 100 ether);
        underlying.mint(address(this), amount);

        uint256 balanceBefore = address(this).balance;

        router.approve(weth, address(wethVault), amount);

        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(PeripheryPayments.wrapWETH9.selector);
        data[1] = abi.encodeWithSelector(
            Helix4626RouterBase.deposit.selector,
            wethVault,
            amount,
            address(this),
            amount
        );

        router.multicall{value: amount}(data);

        wethVault.approve(address(router), amount);

        bytes[] memory withdrawData = new bytes[](2);
        withdrawData[0] = abi.encodeWithSelector(
            Helix4626RouterBase.withdraw.selector,
            wethVault,
            amount,
            address(router),
            0
        );
        withdrawData[1] = abi.encodeWithSelector(PeripheryPayments.unwrapWETH9.selector, amount, address(this));

        router.multicall(withdrawData);

        require(wethVault.balanceOf(address(this)) == 0);
        require(address(this).balance == balanceBefore);
    }
}
