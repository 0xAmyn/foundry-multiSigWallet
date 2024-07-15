// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {DeployTestMultiSigWallet} from "../script/DeployTestMultiSigWallet.s.sol";

contract TestMultiSigWallet is Test {
    MultiSigWallet wallet;
    uint256 requiredSigners = 2;

    address signer0 = makeAddr("signer0");
    address signer1 = makeAddr("signer1");
    address signer2 = makeAddr("signer2");
    address unknown = makeAddr("unknown");

    address[] internal initialSigners;

    function setUp() external{
        initialSigners.push(signer0);
        initialSigners.push(signer1);
        initialSigners.push(signer2);

        vm.deal(signer0, 100 ether);
        vm.deal(signer1, 10 ether);
        vm.deal(signer2, 20 ether);
        vm.deal(unknown, 1 ether);

        console.log("signer0: ", signer0);
        console.log("signer1: ", signer1);
        console.log("signer2: ", signer2);
        console.log("unknown: ", unknown);

        DeployTestMultiSigWallet deploy = new DeployTestMultiSigWallet(initialSigners, requiredSigners);
        wallet = deploy.run();
    }

    function testGetSignersCount() public view {
        uint256 signersCount = wallet.getSignerCount();
        assertEq(signersCount, 3);
    }

    function testMakeSureSignersAreProperlyAddedAtContractCreation() public view {
        address[] memory signers = wallet.getSigners();
        assertEq(signers[0], signer0);
        assertEq(signers[1], signer1);
        assertEq(signers[2], signer2);
    }

}