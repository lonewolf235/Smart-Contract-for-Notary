/*
    ----------------------------------------------------------------------------
        Author: Prakash Veer Singh Tomar
                October 6, 2023
                github.com/prakashveersinghtomar
    ----------------------------------------------------------------------------
    
    Smart Contract serving as Notary Public where you can protect an document 
    or a file in general by storing its hash value on the Ethereum blockchain.
    
    Every record besides file hash has parties associated with the record (can be 
    any number of parties) which can come handy if you are using this as a medium 
    to store real contracts.
    
    Every party associated with the record has to accept it before the record becomes
    valid. This stands as a protection for all parties involved.
    
    Creation of a new record starts with providing:
        - Hash value of the file that is being protected (uint256)
        - Parties associated with the record (address[])
        - Unix Timestamp for record expiration (uint256) 
            -> current timestamp can be found at: https://www.unixtimestamp.com/
        
        -> Creation of the record returns a unique record ID that has to be remembered by parties
            if they want to access that record ever again.
        
    Example of record creation:
        createRecord(2142131241, ["address#1", "address#2", "address#3"], 2523910141)
    
    Parties accept a record by calling the function acceptRecord from their address. 
    The function takes the record ID as an argument.
        
    A file can be verified by calling the verify function. The function can be called only from
    an address that is a party on a particular record. The function takes the record ID and hash value that
    we want to verify as arguments and returns a boolean value, true if the provided hash value
    matches one on the record.

*/
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

contract Notary{
    
    /*
        Mapping holding the records
    */
    mapping( uint256 => Record ) private records;
    
    /*
        Records counter, unique ID for every record
    */
    uint256 private currentId;
    
    struct Record{
        
        // Hash of the file that this record is protecting
        uint256 hash;
        
        // Indicate which address is a party on this record
        address [] parties;
        
        // Store acknowledgment of this record by the party
        mapping( address => bool ) parties_approvals;
        
        // Store the timestamp of record creation
        uint256 createdAt;
        
        // Record is valid if now < validUntil
        uint256 validUntil;
        
        // Guard against brute-force attacks
        uint256 lastFailedTest;
        
    }
    
    event NewRecordCreated(uint256 recordId);
    
    /*
        Only parties that are associated with the record can call the function
    */
    modifier onlyParty(uint256 recordId){
        
        // Iterate over parties and check if their sender of the 
        // message is a party on this record
        for(uint i = 0; i < records[recordId].parties.length; i++){
            if(records[recordId].parties[i] == msg.sender){
                _;
                return;   
            }
        }
        // If the sender is not a party on this record, revert
        revert();
    }
    
    /*
        Only valid records can be accessed
    */
  modifier onlyValid(uint256 recordId){
    require(records[recordId].validUntil >= block.timestamp);
    _;
}

    
    /*
        Constructor, initialize the record counter
    */
    constructor() payable{
        currentId = 0;
    }
    
    /*
        Create a new record and add parties associated with this record and set its validity time
        uint256 hash, address[] _parties, uint256 validUntil
    */
    function createRecord(uint256 hash, address[] memory _parties)

        external
        returns (uint256 _recordId)
    {	
		
		// Limit the max number of parties to 10
		
        // Create a new record
        Record storage newRecord = records[currentId]; 
        newRecord.hash = hash;
		newRecord.validUntil =  block.timestamp + 1 hours;  
		
        // Add parties and init values to true
        
        // indicating that an address is a party on this record
        for(uint8 i = 0; i < _parties.length; i++){
			newRecord.parties.push(_parties[i]);
		}
		
        _recordId = currentId;
        // Uncomment if you want to trigger an event when a new record is created
        //emit NewRecordCreated(currentId);
        currentId = currentId + 1;
        
    }
    
    
    /*
        Every party associated with the record has to accept the record to make it valid.
        Accepting the record is done by calling this function (acceptRecord) from the address of the
        involved party.
    */
    function acceptRecord(uint256 recordId)
        onlyParty(recordId)
        onlyValid(recordId)
        external
    {   
        records[recordId].parties_approvals[msg.sender] = true;
    }
    
    // Return the record hash 
    function getRecordInfo(uint256 recordId) 
        external 
        view
        returns (uint256, uint256)
    {
        return (records[recordId].createdAt, records[recordId].validUntil);
    }
    
    function getParties(uint256 recordId)
    onlyParty(recordId)
    external
    view
    returns (address[] memory)

    {
        return records[recordId].parties;   
    }
    
	// Checks if the given hash matches the recorded hash
    function verify(uint256 recordId, uint256 test_hash)
        onlyParty(recordId)
        external
        view
        returns (bool _res)
    {	
		/* 
			Prevent brute-force attacks, after every failed test
			wait 30s before testing again.
		*/
		//require(records[recordId].lastFailedTest + 30 seconds < now);
		
		// Iterate over all parties associated with this record and check for
		// their approval
		for(uint i=0; i < records[recordId].parties.length; i++){
		    if (records[recordId].parties_approvals[records[recordId].parties[i]] == false){
		        // If one of the parties didn't approve this record, revert
		        revert();
		    }
		}
         /*
        Update the lastFailedTest value for a record.
    */
		function updateLastFailedTest(uint256 recordId) external onlyParty(recordId) onlyValid(recordId) {
        records[recordId].lastFailedTest = block.timestamp;
    }
		// Compare the testing hash with the recorded hash
        if(test_hash == records[recordId].hash){
            _res = true;
        }else{
			records[recordId].lastFailedTest =  block.timestamp;

            _res = false;
        }
    }
}