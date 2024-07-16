// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";
import {DeployMultiSigWallet} from "../script/DeployMultiSigWallet.s.sol";

contract TestAddSigner is Test {
    // MultiSigWallet wallet;
    uint256 constant requiredSigners = 2;

    address signer0 = makeAddr("signer0");
    address signer1 = makeAddr("signer1");
    address signer2 = makeAddr("signer2");
    address signerToBe = makeAddr("signerToBe");
    address unknown = makeAddr("unknown");

    address[] internal initialSigners;

    function setUp() external{
        initialSigners.push(signer0);
        initialSigners.push(signer1);
        initialSigners.push(signer2);

        vm.deal(signer0, 100 ether);
        vm.deal(signer1, 10 ether);
        vm.deal(signer2, 20 ether);
        vm.deal(signerToBe, 1 ether);
        vm.deal(unknown, 1 ether);

        
    }

    // -------------------------- Manual ---------------------------

    function deployWallet(uint256 _requiredSigners) public returns (MultiSigWallet wallet) {
        require(_requiredSigners <= 3, "Max 3 signers!");
        DeployMultiSigWallet deploy = new DeployMultiSigWallet(initialSigners, _requiredSigners);
        wallet = deploy.run();
        return wallet;
    }

    // -------------------------- TESTS ---------------------------

    function testGetSignersCount() public {
        MultiSigWallet wallet = deployWallet(2);
        uint256 signersCount = wallet.getSignerCount();
        assertEq(signersCount, 3);
    }

    function testMakeSureSignersAreProperlyAddedAtContractCreation() public {
        MultiSigWallet wallet = deployWallet(2);
        address[] memory signers = wallet.getSigners();
        assertEq(signers[0], signer0);
        assertEq(signers[1], signer1);
        assertEq(signers[2], signer2);
    }


    function testAddSigner__revert_nullAddress() public {
        MultiSigWallet wallet = deployWallet(1);

        vm.expectRevert();
        vm.prank(signer0);
        wallet.addSignerRequest(address(0));
    }

    function testAddSigner__revert_addSelf() public {
        MultiSigWallet wallet = deployWallet(1);

        vm.expectRevert();
        vm.prank(signer0);
        wallet.addSignerRequest(signer0);
    }

    function testAddSigner__revert_addAlreadySigner() public {
        MultiSigWallet wallet = deployWallet(1);

        vm.expectRevert();
        vm.prank(signer0);
        wallet.addSignerRequest(signer1);
    }

    function testAddSigner__SingleSigner() public {
        // Arrange
        MultiSigWallet wallet = deployWallet(1);

        // Act
        vm.prank(signer0);
        wallet.addSignerRequest(signerToBe);
        vm.prank(signer0);
        wallet.signTransaction(0);
        vm.prank(signer0);
        wallet.executeTransaction(0);

        // Assert
        assertEq(wallet.getTransaction(0).isFinished, true);
    }

    function testAddSigner__MultiSigners_AnotherSignerExecute() public {
        // Arrange
        MultiSigWallet wallet = deployWallet(2);

        // Act
        vm.prank(signer0);
        wallet.addSignerRequest(signerToBe);
        vm.prank(signer0);
        wallet.signTransaction(0);
        
        vm.prank(signer1);
        wallet.signTransaction(0);

        vm.prank(signer2);
        wallet.executeTransaction(0);

        // Assert
        assertEq(wallet.getTransaction(0).isFinished, true);
    }

    function testAddSigner__addManySigners() public {
        MultiSigWallet wallet = deployWallet(1);
        
        address signerToBe0 = makeAddr("signerToBe0");
        address signerToBe1 = makeAddr("signerToBe1");
        address signerToBe2 = makeAddr("signerToBe2");
        address signerToBe3 = makeAddr("signerToBe3");

        assertEq(wallet.getSignerCount(), 3); // inital number is 3

        vm.startPrank(signer0);
        wallet.addSignerRequest(signerToBe0);
        wallet.addSignerRequest(signerToBe1);
        wallet.addSignerRequest(signerToBe2);
        wallet.addSignerRequest(signerToBe3);

        assertEq(wallet.getSignerCount(), 3); // should still be 3

        wallet.signTransaction(0);
        wallet.signTransaction(1);
        wallet.signTransaction(2);
        wallet.signTransaction(3);

        assertEq(wallet.getSignerCount(), 3); // should still be 3

        wallet.executeTransaction(0);
        wallet.executeTransaction(1);
        wallet.executeTransaction(2);
        wallet.executeTransaction(3);

        assertEq(wallet.getSignerCount(), 7); // should still be 3 + 4

        vm.stopPrank();
    }

    function testAddSigner__addManySigners_WithTwoSigners() public {
        MultiSigWallet wallet = deployWallet(2);
        
        address signerToBe0 = makeAddr("signerToBe0");
        address signerToBe1 = makeAddr("signerToBe1");
        address signerToBe2 = makeAddr("signerToBe2");
        address signerToBe3 = makeAddr("signerToBe3");

        assertEq(wallet.getSignerCount(), 3); // inital number is 3

        // user 1 acts
        vm.startPrank(signer0);
        wallet.addSignerRequest(signerToBe0);
        wallet.addSignerRequest(signerToBe1);

        wallet.signTransaction(0);
        wallet.signTransaction(1);

        vm.stopPrank();
        
        // user 2 acts
        vm.startPrank(signer1);
        wallet.addSignerRequest(signerToBe2);
        wallet.addSignerRequest(signerToBe3);

        wallet.signTransaction(0);
        wallet.signTransaction(1);
        wallet.signTransaction(2);
        wallet.signTransaction(3);

        vm.stopPrank();

        // user 1 acts
        vm.startPrank(signer0);
        wallet.signTransaction(2);
        wallet.signTransaction(3);
        vm.stopPrank();

        // user 2 acts
        vm.startPrank(signer1);
        wallet.executeTransaction(3);
        wallet.executeTransaction(2);
        vm.stopPrank();

        // one of the new users act
        vm.startPrank(signerToBe3);
        wallet.executeTransaction(1);
        wallet.executeTransaction(0);
        vm.stopPrank();

        assertEq(wallet.getSignerCount(), 7); // should still be 3 + 4

    }

    function testAddSigner__addManySigners_WithTwoSigners_SignerBeforeConfirmTryExecute() public {
        MultiSigWallet wallet = deployWallet(2);
        
        address signerToBe0 = makeAddr("signerToBe0");
        address signerToBe1 = makeAddr("signerToBe1");
        address signerToBe2 = makeAddr("signerToBe2");
        address signerToBe3 = makeAddr("signerToBe3");

        assertEq(wallet.getSignerCount(), 3); // inital number is 3

        // user 1 acts
        vm.startPrank(signer0);
        wallet.addSignerRequest(signerToBe0);
        wallet.addSignerRequest(signerToBe1);

        wallet.signTransaction(0);
        wallet.signTransaction(1);

        vm.stopPrank();
        
        // user 2 acts
        vm.startPrank(signer1);
        wallet.addSignerRequest(signerToBe2);
        wallet.addSignerRequest(signerToBe3);

        wallet.signTransaction(0);
        wallet.signTransaction(1);
        wallet.signTransaction(2);
        wallet.signTransaction(3);

        vm.stopPrank();

        // user 1 acts
        vm.startPrank(signer0);
        wallet.signTransaction(2);
        wallet.signTransaction(3);
        vm.stopPrank();

        // user 2 acts
        vm.startPrank(signer1);
        wallet.executeTransaction(3);
        wallet.executeTransaction(2);
        vm.stopPrank();

        // one of the new users act
        // this user is not yet a signer
        // tries to sign his own addSigner Tx
        vm.startPrank(signerToBe0);
        vm.expectRevert();
        wallet.executeTransaction(1);
        vm.expectRevert();
        wallet.executeTransaction(0); // <---- this is the place when the user becomes a signer - should fail
        vm.stopPrank();

    }

        function testSign__revert_UnauthorizedSigner() public {
        MultiSigWallet wallet = deployWallet(2);

        vm.prank(signer0);
        wallet.addSignerRequest(signerToBe);
        vm.prank(signer0);
        wallet.signTransaction(0);
        
        vm.expectRevert();
        vm.prank(unknown);
        wallet.signTransaction(0);
    }

    function testSign__SignFinishedTransaction() public {
        // Arrange
        MultiSigWallet wallet = deployWallet(1);

        // Act
        vm.prank(signer0);
        wallet.addSignerRequest(signerToBe);
        vm.prank(signer0);
        wallet.signTransaction(0);
        vm.prank(signer0);
        wallet.executeTransaction(0);

        // Assert
        assertEq(wallet.getTransaction(0).isFinished, true);
        vm.expectRevert();
        wallet.signTransaction(0);
    }

    function testSign__SignerAlreadySigned() public {
        MultiSigWallet wallet = deployWallet(1);

        vm.prank(signer0);
        wallet.addSignerRequest(signerToBe);
        vm.prank(signer0);
        wallet.signTransaction(0);

        // s0 sign again.
        vm.expectRevert();
        vm.prank(signer0);
        wallet.signTransaction(0);

        // make sure tx is not finished.
        assertEq(wallet.getTransaction(0).isFinished, false);
    }



    function testExecute__revert_NotEnoughSignBeforeExecuteBySameSigner() public {
        MultiSigWallet wallet = deployWallet(2);

        vm.prank(signer0);
        wallet.addSignerRequest(signerToBe);
        vm.prank(signer0);
        wallet.signTransaction(0);
        // only 1 sign by signer0 when 2 reqired
        // signer0 try to execute

        vm.expectRevert();
        vm.prank(signer0);
        wallet.executeTransaction(0);
    }

    function testExecute__revert_NotEnoughSignBeforeExecuteByAnotherSigner() public {
        MultiSigWallet wallet = deployWallet(2);

        vm.prank(signer0);
        wallet.addSignerRequest(signerToBe);
        vm.prank(signer0);
        wallet.signTransaction(0);
        // only 1 sign by signer0 when 2 reqired
        // signer1 try to execute
        
        vm.expectRevert();
        vm.prank(signer1);
        wallet.executeTransaction(0);
    }

    function testExecute__revert_TransactionDoesNotExist() public {
        MultiSigWallet wallet = deployWallet(1);

        vm.prank(signer0);
        wallet.addSignerRequest(signerToBe);
        vm.prank(signer0);
        wallet.signTransaction(0);
  
        vm.expectRevert();
        vm.prank(signer0);
        wallet.executeTransaction(10000);
    }

    
    function testExecute__revert_TransactionNeedMoreSigns() public {
        MultiSigWallet wallet = deployWallet(3);

        vm.prank(signer1);
        wallet.addSignerRequest(signerToBe);

        vm.prank(signer2);
        wallet.signTransaction(0);
        vm.prank(signer0);
        wallet.signTransaction(0);
        // vm.prank(signer1);
        // wallet.signTransaction(0);

        vm.expectRevert();
        vm.prank(signer2);
        wallet.executeTransaction(0);
    }

    function testSign__revert_MoreSignsThanRequired() public {
        MultiSigWallet wallet = deployWallet(2);

        vm.prank(signer1);
        wallet.addSignerRequest(signerToBe);

        vm.prank(signer2);
        wallet.signTransaction(0);
        vm.prank(signer0);
        wallet.signTransaction(0);

        vm.expectRevert(); 
        vm.prank(signer1);
        wallet.signTransaction(0); // <-- Two Signs required but three was given

    }



}