/* a wallet that allows multiple signers to sign a message
   and then verifies that a set number of signers have signed the message
   everyone can add funds
   * signers should be able :
      - request withdrawal of funds 
      - initiate a transfer of funds
      - sign the message
      - withdraw funds
      - change the required number of signers
      
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

error MultiSigWallet__NotSigner();
error MultiSigWallet__TransactionDoesNotExist();
error MultiSigWallet__SignerAlreadySigned();
error MultiSigWallet__TransactionAlreadyFinished();
error MultiSigWallet__TransactionNeedMoreSigns();
error MultiSigWallet__TransactionTypeNotSupported();

contract MultiSigWallet {
   /**
    * @notice the number of signers required to sign a message to perform a transfer
    * @dev this is the number of signers that must sign the message before it is considered valid
    * @return uint256
    */
   uint256 public s_requiredSigners;

   /**
    * @notice list of signers that may sign a message
    * @dev this is the list of signers that may sign a message
    */
   mapping(address => bool) public s_signers;
   address[] s_signersArray;

   enum TransactionType {
      AddSigner,
      RemoveSigner,
      Withdraw,
      Transfer
   }

   struct Transaction {
      bool isFinished;
      TransactionType transactionType;
      uint256 signersCount;
      address[] signers;
      bytes data; // To store specific transaction data
   }

   struct AddSignerData {
      address newSigner;
   }

   struct RemoveSignerData {
      address signerToRemove;
   }

   struct WithdrawData {
      uint256 amount;
   }

   struct TransferData {
      address to;
      uint256 amount;
   }

   Transaction[] public s_transactions;

   /**
    * @param _signers initial list of signers that may sign a message
    */
   constructor(address[] memory _signers, uint256 _requiredSigners) {
      require(_signers.length >= _requiredSigners, "MultiSigWallet__InitialSignersExceedRequiredSigners()");
      // add all initial signers
      for (uint256 i = 0; i < _signers.length; i++) {
         s_signers[_signers[i]] = true;
         s_signersArray.push(_signers[i]);
      }
      // set the number of signers based on the initial list
      s_requiredSigners = _requiredSigners;
   }

   /**
    * @notice modifier to require that the caller is a signer
    */
   modifier onlySigner() {
      require(s_signers[msg.sender], "MultiSigWallet__NotSigner()");
      _;
   }

   function initilizeTransaction(bytes memory data) internal {
      address[] memory signers = new address[](1);
      signers[0] = msg.sender;

      Transaction memory newTransaction = Transaction({
         isFinished: false,
         transactionType: TransactionType.AddSigner,
         signersCount: 1,
         signers: signers,
         data: data
      });
      s_transactions.push(newTransaction);
   }

   // ---------------------------- REQUESTS -----------------------------

   function addSignerRequest(address _signer) public onlySigner {
      AddSignerData memory addSignerData = AddSignerData(_signer);
      initilizeTransaction(abi.encode(addSignerData));
   }

   // function removeSignerRequest(address signer) public onlySigner {}

   // function changeRequiredSignersRequest(uint256 requiredSigners) public {}

   // function getRequiredSigners() public view returns (uint256) {}

   // function withdrawalRequest(uint256 amount) public {}

   // function transferFundsRequest(address to, uint256 amount) public {}

   // ----------------------------- VERIFY ------------------------------

   function signTransaction(uint256 _transactionIndex) public onlySigner {
      // make sure transaction exists
      require(_transactionIndex < s_transactions.length, "MultiSigWallet__TransactionDoesNotExist()");

      Transaction storage transaction = s_transactions[_transactionIndex];

      // make sure transaction is not already finished
      require(transaction.isFinished == false, "MultiSigWallet__TransactionAlreadyFinished()");

      // make sure transaction is not already signed by msg.sender
      for (uint i = 0; i < transaction.signers.length; i++) {
         if (transaction.signers[i] == msg.sender) {
            revert MultiSigWallet__SignerAlreadySigned();
         }
      }
      
      // make sure transaction is not fully signed
      if (transaction.signersCount >= s_requiredSigners) {
         executeTransaction(_transactionIndex);
      }
      else {
         transaction.signersCount++;
         transaction.signers.push(msg.sender);
      }
   }

   function executeTransaction(uint256 _transactionIndex) public onlySigner {
      require(_transactionIndex < s_transactions.length, "MultiSigWallet__TransactionDoesNotExist()");

      Transaction storage transaction = s_transactions[_transactionIndex];

      require(transaction.isFinished == false, "MultiSigWallet__TransactionAlreadyFinished()");
      require(transaction.signersCount >= s_requiredSigners, "MultiSigWallet__TransactionNeedMoreSigns()");

      if (transaction.transactionType == TransactionType.AddSigner) {
         AddSignerData memory data = abi.decode(transaction.data, (AddSignerData));
         s_requiredSigners++;
         s_signers[data.newSigner] = true;
         s_signersArray.push(data.newSigner);
      }
      else {
         revert MultiSigWallet__TransactionTypeNotSupported();
      }

      transaction.isFinished = true;

   }

   // ------------------------------ VIEWs ------------------------------

   // function getBalance() public view returns (uint256) {}

   function getSigners() public view returns (address[] memory) {
      return s_signersArray;
   }

   // function getSigner(uint256 index) public view returns (address) {}

   function getSignerCount() public view returns (uint256) {
      return s_signersArray.length;
   }

   // function getWithdrawalCount() public view returns (uint256) {}

   // function getWithdrawal(
   //     uint256 index
   // ) public view returns (uint256, address) {}

   // function getTransferCount() public view returns (uint256) {}

   // function getTransfer(
   //     uint256 index
   // ) public view returns (uint256, address, address) {}

   // function getMessageCount() public view returns (uint256) {}

   // function getMessage(
   //     uint256 index
   // ) public view returns (string memory, uint256, address) {}

   // function getSignerIndex(address signer) public view returns (uint256) {}
}
