pragma solidity ^0.4.23;

import "./ITransferManager.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

/////////////////////
// Module permissions
/////////////////////
//                                        Owner       WHITELIST      FLAGS
// changeIssuanceAddress                    X                          X
// changeAllowAllTransfers                  X                          X
// changeAllowAllWhitelistTransfers         X                          X
// changeAllowAllWhitelistIssuances         X                          X
// modifyWhitelist                          X             X
// modifyWhitelistMulti                     X             X

contract ManualApprovalTransferManager is ITransferManager {
    using SafeMath for uint256;

    //Address from which issuances come
    address public issuanceAddress = address(0);

    //Address which can sign whitelist changes
    address public signingAddress = address(0);

    bytes32 public constant TRANSFER_APPROVAL = "TRANSFER_APPROVAL";

    //Manual approval is an allowance (that has been approved) with an expiry time
    struct ManualApproval {
        uint256 allowance;
        uint256 expiryTime;
    }

    //Manual blocking allows you to specify a list of blocked address pairs with an associated expiry time for the block
    struct ManualBlocking {
        uint256 expiryTime;
    }

    //Store mappings of address => address with ManualApprovals
    mapping (address => mapping (address => ManualApproval)) public manualApprovals;

    //Store mappings of address => address with ManualBlockings
    mapping (address => mapping (address => ManualBlocking)) public manualBlockings;

    event LogAddManualApproval(
        address _from,
        address _to,
        uint256 _allowance,
        uint256 _expiryTime,
        address _addedBy
    );

    event LogAddManualBlocking(
        address _from,
        address _to,
        uint256 _expiryTime,
        address _addedBy
    );

    /**
     * @dev Constructor
     * @param _securityToken Address of the security token
     * @param _polyAddress Address of the polytoken
     */
    constructor (address _securityToken, address _polyAddress)
    public
    IModule(_securityToken, _polyAddress)
    {
    }

    /**
     * @notice This function returns the signature of configure function
     */
    function getInitFunction() public returns(bytes4) {
        return bytes4(0);
    }

    /**
    * @dev default implementation of verifyTransfer used by SecurityToken
    * If the transfer request comes from the STO, it only checks that the investor is in the whitelist
    * If the transfer request comes from a token holder, it checks that:
    * a) Both are on the whitelist
    * b) Seller's sale lockup period is over
    * c) Buyer's purchase lockup is over
    */
    function verifyTransfer(address _from, address _to, uint256 _amount, bool _isTransfer) public returns(Result) {
        // manual blocking takes precidence over manual approval
        if (!paused) {
            if (manualBlockings[_from][_to].expiryTime >= now) {
                return Result.INVALID;
            }
            if ((manualApprovals[_from][_to].expiryTime >= now) && (manualApprovals[_from][_to].allowance >= _amount)) {
                if (_isTransfer) {
                    manualApprovals[_from][_to].allowance = manualApprovals[_from][_to].allowance.sub(_amount);
                }
                return Result.VALID;
            }
        }
        return Result.NA;
    }

    /**
    * @dev adds or removes pairs of addresses from manual approvals
    * @param _from is the address from which transfers are approved
    * @param _to is the address to which transfers are approved
    * @param _allowance is the approved amount of tokens
    * @param _expiryTime is the time until which the transfer is allowed
    */
    function addManualApproval(address _from, address _to, uint256 _allowance, uint256 _expiryTime) public withPerm(TRANSFER_APPROVAL) {
        //Passing a _expiryTime == 0 into this function, is equivalent to removing the manual approval.
        /* ManualApproval storage approval = ManualApproval(_allowance, _expiryTime); */
        manualApprovals[_from][_to] = ManualApproval(_allowance, _expiryTime);
        emit LogAddManualApproval(_from, _to, _allowance, _expiryTime, msg.sender);
    }

    /**
    * @dev adds or removes pairs of addresses from manual blockings
    * @param _from is the address from which transfers are blocked
    * @param _to is the address to which transfers are blocked
    * @param _expiryTime is the time until which the transfer is blocked
    */
    function addManualBlocking(address _from, address _to, uint256 _expiryTime) public withPerm(TRANSFER_APPROVAL) {
        //Passing a _expiryTime == 0 into this function, is equivalent to removing the manual blocking.
        /* ManualBlocking storage blocking = ManualBlocking(_expiryTime); */
        manualBlockings[_from][_to] = ManualBlocking(_expiryTime);
        emit LogAddManualBlocking(_from, _to, _expiryTime, msg.sender);
    }

    /**
     * @notice Return the permissions flag that are associated with ManualApproval transfer manager
     */
    function getPermissions() public view returns(bytes32[]) {
        bytes32[] memory allPermissions = new bytes32[](1);
        allPermissions[0] = TRANSFER_APPROVAL;
        return allPermissions;
    }
}
