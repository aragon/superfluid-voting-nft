// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;
import {console2} from "forge-std/console2.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {DaoUnauthorized} from "@aragon/osx/core/utils/auth.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";

import {SuperTokenV1Library} from "@superfluid/apps/SuperTokenV1Library.sol";
import {IConstantFlowAgreementV1} from "@superfluid/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {ISuperToken} from "@superfluid/interfaces/superfluid/ISuperToken.sol";
import {ISuperfluid} from "@superfluid/interfaces/superfluid/ISuperfluid.sol";

import {AragonE2E} from "./base/AragonE2E.sol";
import {SuperVotingNFT} from "../src/SuperVotingNFT.sol";

import {FoundrySuperfluidTester} from "lib/protocol-monorepo/packages/ethereum-contracts/test/foundry/FoundrySuperfluidTester.sol";

abstract contract SuperVotingTokenE2E is AragonE2E, FoundrySuperfluidTester {
    using SuperTokenV1Library for ISuperToken;

    IConstantFlowAgreementV1 internal cfa;
    ISuperToken internal USDCx;
    ERC20 internal USDC;
    address internal binance;

    SuperVotingNFT internal votingToken;
    int96 internal constant MIN_FLOW_RATE = 1 ether;
    uint256 internal constant STAKE = 1 ether;

    address internal unauthorised = account("unauthorised");
    // address internal alice = account("alice");
    // address internal bob = account("bob");
    address internal dao;

    constructor() FoundrySuperfluidTester(5) {}

    function setUp() public virtual override(AragonE2E, FoundrySuperfluidTester) {
        super.setUp();

        dao = account("dao");
        binance = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;

        // MAINNET SUPERFLUID
        cfa = IConstantFlowAgreementV1(0x2844c1BBdA121E9E43105630b9C8310e5c72744b);
        USDCx = ISuperToken(0x1BA8603DA702602A8657980e825A6DAa03Dee93a);
        USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        // SuperVotingNFT
        votingToken = new SuperVotingNFT({
            _name: "SuperVotingNFT",
            _symbol: "SVNFT",
            _superToken: USDCx,
            _minFlowRate: MIN_FLOW_RATE,
            _stake: STAKE,
            _cfa: cfa
        });
    }

    function rugUsdc(address to, uint256 amount) internal {
        console2.log("Rugging USDC");
        console2.log("USDC balance before: ", USDC.balanceOf(binance));
        vm.prank(binance);
        USDC.transfer(to, amount * 10 ** 6);
    }

    function createFlow(address sender, int96 flowRate) internal {
        vm.startPrank(sender);
        cfa.createFlow({token: USDCx, receiver: dao, flowRate: flowRate, ctx: ""});
        vm.stopPrank();
        // USDCx.createFlow(dao, flowRate);
    }
}

contract SuperVoting__Initialise is SuperVotingTokenE2E {
    function setUp() public override {
        super.setUp();
    }

    function test__Initialise() public {
        assertEq(votingToken.owner(), address(this));
        assertEq(address(votingToken.superToken()), address(USDCx));
        assertEq(votingToken.minFlowRate(), MIN_FLOW_RATE);
        assertEq(votingToken.stake(), STAKE);
        assertEq(address(votingToken.cfa()), address(cfa));
        assertEq(votingToken.paused(), true);
    }

    function test__SetDao() public {
        votingToken.setDao(dao);

        assertEq(votingToken.dao(), dao);
        assertEq(votingToken.owner(), dao);
        assertEq(votingToken.paused(), false);
    }

    function test__CannotSetDaoWhenNotOwner() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        votingToken.setDao(dao);
    }
}

contract SuperVoting__OwnerOnlyFunctions is SuperVotingTokenE2E {
    function setUp() public override {
        super.setUp();
    }

    function test__SetDaoByOwner() public {
        address newDao = address(2);
        votingToken.setDao(newDao);
        assertEq(votingToken.dao(), newDao);
        assertEq(votingToken.owner(), newDao);
    }

    function test__SetDaoByNonOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        votingToken.setDao(address(3));
        vm.stopPrank();
    }

    function test__SetMinFlowRateByOwner() public {
        int96 newMinFlowRate = 2 ether;
        votingToken.setMinFlowRate(newMinFlowRate);
        assertEq(votingToken.minFlowRate(), newMinFlowRate);
    }

    function test__SetMinFlowRateByNonOwner() public {
        vm.startPrank(alice);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        votingToken.setMinFlowRate(2 ether);
        vm.stopPrank();
    }
}

contract SuperVoting__MintFunctionality is SuperVotingTokenE2E {
    function setUp() public override {
        super.setUp();
        votingToken.setDao(dao);
    }

    function test__MintWithActiveSubscriptionAndSufficientStake() public {
        // rugUsdc(alice, 100_000);
        // vm.startPrank(alice);
        // console2.log("USDCx Host", USDCx.getHost());
        // function _helperCreateFlow(ISuperToken superToken_, address sender, address receiver, int96 flowRate) internal {
        _helperCreateFlow(USDCx, alice, dao, MIN_FLOW_RATE);
        // USDCx.approve(address(USDCx.getHost()), type(uint256).max);
        // cfa.createFlow({token: USDCx, receiver: dao, flowRate: MIN_FLOW_RATE, ctx: ""});
        // vm.stopPrank();
        votingToken.mint{value: 1 ether}(alice);
    }
}

// contract SuperVoting__BurnFunctionality is SuperVotingTokenE2E {
//     function setUp() public override {
//         super.setUp();
//         // Additional setup for burn tests if needed
//     }

//     function test__BurnWithNonMember() public {
//         // Implement test
//     }

//     function test__BurnWithMember() public {
//         // Implement test
//     }

//     function test__BurnWithFailedEtherTransfer() public {
//         // Implement test
//     }
// }
