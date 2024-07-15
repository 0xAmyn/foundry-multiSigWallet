// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {MultiSigWallet} from "../src/MultiSigWallet.sol";

contract DeployMultiSigWallet is Script {
    address[] internal initialSigners;
    uint256 internal requiredSigners;

    constructor(address[] memory _initialSigners, uint256 _requiredSigners) {
        initialSigners = _initialSigners;
        requiredSigners = _requiredSigners;
    }

    function run() external returns (MultiSigWallet) {
        vm.startBroadcast();
        MultiSigWallet wallet = new MultiSigWallet(initialSigners, requiredSigners);
        vm.stopBroadcast();

        return wallet;
    }
}