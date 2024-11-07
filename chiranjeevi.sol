// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract InsurancePlatform {

  address owner; 

  struct InsurancePolicy {
    address owner;
    uint id;
    string name;
    string description;
    uint coverageAmount;
    uint premium;
    address policyHolder;
    bool claimed;
    bool deleted;
    uint timestamp;
  }

  struct Claim {
    uint id;
    uint policyId;
    address claimant;
    uint amount;
    bool settled;
  }

  uint public processingFee;
  uint public taxPercent;
  uint public totalPolicies;

  mapping(uint => InsurancePolicy) policies;
  mapping(uint => Claim[]) claimsOf;
  mapping(uint => bool) policyExists;
  mapping(address => uint[]) userPurchasedPolicies;

  constructor(uint _taxPercent, uint _processingFee) {
    taxPercent = _taxPercent;
    processingFee = _processingFee;
  }

  function createInsurancePolicy(
    string memory name,
    string memory description,
    uint coverageAmount,
    uint premium
  ) public {
    require(bytes(name).length > 0, 'Name cannot be empty');
    require(bytes(description).length > 0, 'Description cannot be empty');
    require(coverageAmount > 0, 'Coverage amount cannot be zero');
    require(premium > 0 ether, 'Premium cannot be zero');

    totalPolicies++;
    InsurancePolicy storage policy = policies[totalPolicies];
    policy.id = totalPolicies;
    policy.name = name;
    policy.description = description;
    policy.coverageAmount = coverageAmount * 1 ether;
    policy.premium = premium * 1 ether;
    policy.policyHolder = msg.sender;
    policy.timestamp = currentTime();

    policyExists[policy.id] = true;
  }

  function purchaseInsurancePolicy(uint policyId) public payable {
    require(policyExists[policyId], 'Policy not found!');
    require(!policies[policyId].deleted, 'Policy is deleted');
    require(!userHasPurchasedPolicy(msg.sender, policyId), 'Policy already purchased');

    require(msg.value >= policies[policyId].premium, 'Insufficient fund!');

    userPurchasedPolicies[msg.sender].push(policyId);
  }

  function updateInsurancePolicy(
    uint id,
    string memory name,
    string memory description,
    uint coverageAmount,
    uint premium
  ) public {
    require(policyExists[id], 'Policy not found');
    require(msg.sender == policies[id].policyHolder, 'Unauthorized personnel, policy holder only');
    require(bytes(name).length > 0, 'Name cannot be empty');
    require(bytes(description).length > 0, 'Description cannot be empty');
    require(coverageAmount > 0, 'Coverage amount cannot be zero');
    require(premium > 0 ether, 'Premium cannot be zero');

    InsurancePolicy storage policy = policies[id];
    policy.name = name;
    policy.description = description;
    policy.coverageAmount = coverageAmount;
    policy.premium = premium;
  }

  function deleteInsurancePolicy(uint id) public {
    require(policyExists[id], 'Policy not found');
    require(policies[id].policyHolder == msg.sender, 'Unauthorized entity');

    policyExists[id] = false;
    policies[id].deleted = true;
  }

  function getInsurancePolicies() public view returns (InsurancePolicy[] memory) {
    uint256 available;
    for (uint i = 1; i <= totalPolicies; i++) {
      if (!policies[i].deleted) available++;
    }

    InsurancePolicy[] memory insurancePolicies = new InsurancePolicy[](available);

    uint256 index;
    for (uint i = 1; i <= totalPolicies; i++) {
      if (!policies[i].deleted) {
        insurancePolicies[index++] = policies[i];
      }
    }

    return insurancePolicies;
  }

  function getInsurancePolicy(uint id) public view returns (InsurancePolicy memory) {
    return policies[id];
  }

  function claimInsurance(uint policyId, uint amount) public payable {
    require(policyExists[policyId], 'Policy not found!');
    require(
      msg.value >= (policies[policyId].coverageAmount + (policies[policyId].coverageAmount * taxPercent) / 100),
      'Insufficient fund!'
    );
    require(!claimsExist(policyId), 'Claim already submitted for this policy');

    Claim memory newClaim;
    newClaim.id = claimsOf[policyId].length;
    newClaim.policyId = policyId;
    newClaim.claimant = msg.sender;
    newClaim.amount = amount;
    newClaim.settled = false;

    claimsOf[policyId].push(newClaim);
  }

  function settleClaim(uint policyId, uint claimId) public {
    require(msg.sender == owner, 'Unauthorized entity');
    require(!claimsOf[policyId][claimId].settled, 'Claim already settled');

    uint amountToSettle = claimsOf[policyId][claimId].amount;
    uint fee = (amountToSettle * processingFee) / 100;

    payable(claimsOf[policyId][claimId].claimant).transfer(amountToSettle - fee);
    payable(owner).transfer(fee);

    claimsOf[policyId][claimId].settled = true;
  }

  function claimsExist(uint policyId) internal view returns (bool) {
    return claimsOf[policyId].length > 0;
  }

  function getClaims(uint policyId) public view returns (Claim[] memory) {
    return claimsOf[policyId];
  }

  function getClaim(uint policyId, uint claimId) public view returns (Claim memory) {
    return claimsOf[policyId][claimId];
  }

  function currentTime() internal view returns (uint256) {
    return (block.timestamp * 1000) + 1000;
  }

  function userHasPurchasedPolicy(address user, uint policyId) internal view returns (bool) {
    uint[] memory purchasedPolicies = userPurchasedPolicies[user];
    for (uint i = 0; i < purchasedPolicies.length; i++) {
      if (purchasedPolicies[i] == policyId) {
        return true;
      }
    }
    return false;
  }
}
