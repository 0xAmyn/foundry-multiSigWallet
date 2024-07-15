/* a wallet that allows multiple signers to sign a message
   and then verifies that a set number of signers have signed the message
   everyone can add funds
   * signers should be able :
      - request withdrawal of funds 
      - initiate a transfer of funds
      - sign the message
      - withdraw funds
      - change the required number of signers
   
   TODO:
      remove require in favor of error messages
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

error MultiSigWallet__NotSigner();
error MultiSigWallet__TransactionDoesNotExist();
error MultiSigWallet__SignerAlreadySigned();
error MultiSigWallet__TransactionAlreadyFinished();
error MultiSigWallet__TransactionNeedMoreSigns();
error MultiSigWallet__TransactionTypeNotSupported();
error MultiSigWallet__TransactionCompletelySigned();

contract MultiSigWallet {
   /**
    * @notice the number of signers required to sign a message to perform a transfer
    * @dev this is the number of signers that must sign the message before it is considered valid
    */
   uint256 private s_requiredSigners;

   /**
    * @notice list of signers that may sign a message
    * @dev this is the list of signers that may sign a message
    */
   mapping(address => bool) private s_signers;
   address[] private s_signersArray;

   mapping(address to => uint256 amount) private s_transferHistory;

   enum TransactionType {
      AddSigner,
      RemoveSigner,
      ChangeRequiredSigners,
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

   struct ChangeRequiredSignersData {
      uint256 count;
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

   function initilizeTransaction(TransactionType _type, bytes memory _data) internal returns (Transaction memory) {
      address[] memory signers = new address[](0);

      Transaction memory newTransaction = Transaction({
         isFinished: false,
         transactionType: _type,
         signersCount: 0,
         signers: signers,
         data: _data
      });

      s_transactions.push(newTransaction);
      return newTransaction;
   }

   // ---------------------------- REQUESTS -----------------------------

   function addSignerRequest(address _signer) public onlySigner {
      require(_signer != address(0), "MultiSigWallet__SignerCannotBeZeroAddress()");
      require(_signer != msg.sender, "MultiSigWallet__SignerCannotAddSelf()");
      require(!s_signers[_signer], "MultiSigWallet__SignerAlreadyAdded()");
      
      AddSignerData memory addSignerData = AddSignerData(_signer);
      initilizeTransaction(TransactionType.AddSigner, abi.encode(addSignerData));
   }

   function removeSignerRequest(address _signer) public onlySigner {
      require(_signer != address(0), "MultiSigWallet__SignerCannotBeZeroAddress()");
      require(_signer != msg.sender, "MultiSigWallet__SignerCannotRemoveSelf()");
      require(s_signers[_signer], "MultiSigWallet__SignerDoesNotExist()");
      require(s_signersArray.length > s_requiredSigners, "MultiSigWallet__CannotRemoveLastSigner()");

      RemoveSignerData memory data = RemoveSignerData(_signer);
      initilizeTransaction(TransactionType.RemoveSigner, abi.encode(data));
   }

   function changeRequiredSignersRequest(uint256 _requiredSigners) public onlySigner {
      require(_requiredSigners > 0, "MultiSigWallet__RequiredSignersMustBeGreaterThanZero()");
      require(_requiredSigners <= s_signersArray.length, "MultiSigWallet__RequiredSignersExceedSignerCount()");
      require(_requiredSigners!= s_requiredSigners, "MultiSigWallet__RequiredSignersMustChange()");

      ChangeRequiredSignersData memory data = ChangeRequiredSignersData(_requiredSigners);
      initilizeTransaction(TransactionType.ChangeRequiredSigners, abi.encode(data));
   }

   // function transferFundsRequest(address _to, uint256 _amount) public onlySigner{
   //    TransferData memory data = TransferData(_to, _amount);
   //    initilizeTransaction(TransactionType.Transfer, abi.encode(data));
   // }

   // ----------------------------- VERIFY ------------------------------

   function signTransaction(uint256 _transactionIndex) public onlySigner {
      // make sure transaction exists
      require(_transactionIndex < s_transactions.length, "MultiSigWallet__TransactionDoesNotExist()");

      Transaction storage transaction = s_transactions[_transactionIndex];

      // make sure transaction is not already finished
      require(transaction.isFinished == false, "MultiSigWallet__TransactionAlreadyFinished()");

      // make sure transaction is not already signed by msg.sender
      // start from 1 since 0 is the original transaction issuer
      for (uint i = 0; i < transaction.signers.length; i++) {
         if (transaction.signers[i] == msg.sender) {
            revert MultiSigWallet__SignerAlreadySigned();
         }
      }
      // make sure transaction is not fully signed
      if (transaction.signersCount >= s_requiredSigners) {
         revert MultiSigWallet__TransactionCompletelySigned();
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
      else if (transaction.transactionType == TransactionType.RemoveSigner) {
         RemoveSignerData memory data = abi.decode(transaction.data, (RemoveSignerData));
         s_requiredSigners--;
         s_signers[data.signerToRemove] = false;

         // remove signer from the array
         uint256 deleteIndex;
         for (uint256 i = 0; i < s_signersArray.length; i++) {
            if (s_signersArray[i] == data.signerToRemove) {
               deleteIndex = i;  
            }
         }
         delete s_signersArray[deleteIndex];
      }
      else if (transaction.transactionType == TransactionType.ChangeRequiredSigners) {
         ChangeRequiredSignersData memory data = abi.decode(transaction.data, (ChangeRequiredSignersData));
         s_requiredSigners = data.count;
      }
      else {
         revert MultiSigWallet__TransactionTypeNotSupported();
      }

      transaction.isFinished = true;

   }

   // ------------------------------ VIEWs ------------------------------

   function getBalance() public view returns (uint256) {
      return address(this).balance;
   }

   function getSigners() public view returns (address[] memory) {
      return s_signersArray;
   }

   function getSigner(uint256 index) public view returns (address) {
      return s_signersArray[index];
   }

   function getSignerCount() public view returns (uint256) {
      return s_signersArray.length;
   }

   function getTransaction(uint256 _transactionIndex) public view returns (Transaction memory) {
      return s_transactions[_transactionIndex];
   }

   function getRequiredSigners() public view returns (uint256) {
      return s_requiredSigners;
   }

   // function getTransfer(address _to) public view returns (uint256 amount) {
   //    return s_transferHistory[_to];
   // }

}
