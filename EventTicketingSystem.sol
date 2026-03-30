// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    Project:
    Decentralized Identity and Access Management dApp
    for Event Ticket Verification
*/

interface IDIDRegistry {
    function registerDID(string calldata didDocumentURI) external;
    function updateDID(string calldata newDidDocumentURI) external;
    function revokeDID() external;
    function isRegistered(address user) external view returns (bool);
}

interface IVerificationLog {
    function logVerification(
        uint256 ticketId,
        address verifier,
        bool success,
        string calldata notes
    ) external;
}

contract DIDRegistry is IDIDRegistry {
    struct DIDRecord {
        string didDocumentURI;
        uint256 registeredAt;
        bool active;
    }

    mapping(address => DIDRecord) private didRecords;

    function registerDID(string calldata didDocumentURI) external override {
        require(bytes(didDocumentURI).length > 0, "DID URI required");
        require(!didRecords[msg.sender].active, "Already registered");

        didRecords[msg.sender] = DIDRecord(didDocumentURI, block.timestamp, true);
    }

    function updateDID(string calldata newDidDocumentURI) external override {
        require(didRecords[msg.sender].active, "No active DID");
        didRecords[msg.sender].didDocumentURI = newDidDocumentURI;
    }

    function revokeDID() external override {
        require(didRecords[msg.sender].active, "No active DID");
        didRecords[msg.sender].active = false;
    }

    function isRegistered(address user) external view override returns (bool) {
        return didRecords[user].active;
    }
}

contract VerificationLog is IVerificationLog {
    struct VerificationEntry {
        uint256 ticketId;
        address verifier;
        uint256 timestamp;
        bool success;
        string notes;
    }

    mapping(uint256 => VerificationEntry[]) public logs;

    function logVerification(
        uint256 ticketId,
        address verifier,
        bool success,
        string calldata notes
    ) external override {
        logs[ticketId].push(
            VerificationEntry(ticketId, verifier, block.timestamp, success, notes)
        );
    }
}

contract TicketCredential {
    enum TicketStatus { Issued, Used, Revoked }

    struct Ticket {
        uint256 id;
        address holder;
        string eventId;
        string metadataHash;
        TicketStatus status;
    }

    IDIDRegistry public didRegistry;
    IVerificationLog public verificationLog;

    uint256 public nextId;
    mapping(uint256 => Ticket) public tickets;

    constructor(address _did, address _log) {
        didRegistry = IDIDRegistry(_did);
        verificationLog = IVerificationLog(_log);
    }

    function issueTicket(
        address holder,
        string calldata eventId,
        string calldata metadataHash
    ) external {
        require(didRegistry.isRegistered(holder), "No DID");

        tickets[nextId] = Ticket(nextId, holder, eventId, metadataHash, TicketStatus.Issued);
        nextId++;
    }

    function verifyTicket(uint256 ticketId) external returns (bool) {
        Ticket storage t = tickets[ticketId];

        if (t.status != TicketStatus.Issued) {
            verificationLog.logVerification(ticketId, msg.sender, false, "Invalid");
            return false;
        }

        t.status = TicketStatus.Used;
        verificationLog.logVerification(ticketId, msg.sender, true, "Valid");
        return true;
    }
}
