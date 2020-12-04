//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract PresaleContract is Ownable {
  using SafeMath for uint256;

  IERC20 public DegenLamboToken;

  mapping(address => uint256) public investments; // total WEI invested per address (1ETH = 1e18WEI)
  mapping (uint256=> address) public investors;   // list of participating investor addresses
  uint256 private _investorCount = 0;             // number of unique addresses that have invested

  mapping(address => bool) public whitelistAddresses; // all addresses eligible for presale
  mapping(address => bool) public devAddresses;       // all addresses that are devs

  uint256 public constant INVESTMENT_LIMIT_PRESALE   = 1.5  ether; // 1.5 ETH is maximum investment limit for pre-sale
  uint256 public constant INVESTMENT_LIMIT_DEVELOPER = 2.88 ether; // 2.88 ETH is maximum investment limit for developer pre-sale

  uint256 public constant INVESTMENT_RATIO_PRESALE   = 0.28 * 1 ether; // pre-sale rate is 0.28 ETH/$LAMBO
  uint256 public constant INVESTMENT_RATIO_DEVELOPER = 0.18 * 1 ether; // developer pre-sale rate is 0.18 ETH/$LAMBO

  bool public isPresaleActive = false; // investing is only allowed if presale is active

  constructor() {

  }

  function getPresaleInvestmentLimit() view public returns (uint256) {
    return INVESTMENT_LIMIT_PRESALE;
  }

  function getDeveloperPresaleInvestmentLimit() view public returns (uint256) {
    return INVESTMENT_LIMIT_DEVELOPER;
  }

  function startPresale() public onlyOwner {
    isPresaleActive = true;
  }

  function endPresale() public onlyOwner {
    isPresaleActive = false;
    payable(owner()).transfer(address(this).balance);
    DegenLamboToken.transfer(address(DegenLamboToken), DegenLamboToken.balanceOf(address(this)));
  }

  function setToken(address tokenAddress) public {
    DegenLamboToken = IERC20(tokenAddress);
  }

  function addWhitelistAddresses(address[] calldata _whitelistAddresses) external onlyOwner {
    for (uint256 i = 0; i < _whitelistAddresses.length; i++) {
      whitelistAddresses[_whitelistAddresses[i]] = true;
    }
  }

  function addDevAddresses(address[] calldata _devlistAddresses) external onlyOwner {
    for (uint256 i = 0; i < _devlistAddresses.length; i++) {
      devAddresses[_devlistAddresses[i]] = true;
    }
  }

  function refundInvestors() external onlyOwner {
    for (uint256 i = 0; i < _investorCount; i++) {
      address addressToRefund = investors[i];
      uint256 refundAmount = investments[investors[i]];

//      console.log("addressToRefund: '%s'", addressToRefund);
//      console.log("refundAmount: '%s'", refundAmount);

      payable(addressToRefund).transfer(refundAmount);
      investments[investors[i]].sub(refundAmount);
    }
  }

  modifier presaleActive() {
    require(isPresaleActive, "Presale is currently not active.");
    _;
  }

  modifier eligibleForPresale() {
    require(whitelistAddresses[_msgSender()], "Your address is not whitelisted.");
    _;
  }

  receive() payable
    external
    presaleActive
    eligibleForPresale
  {
    uint256 addressTotalInvestment = investments[_msgSender()].add(msg.value);

    if (isDevAddress(_msgSender())){
      require(addressTotalInvestment <= INVESTMENT_LIMIT_DEVELOPER, "Max investment per dev pre-sale address is 2.88 ETH.");
    } else {
      require(addressTotalInvestment <= INVESTMENT_LIMIT_PRESALE, "Max investment per pre-sale address is 1.5 ETH.");
    }

    uint256 amountOfTokens;

    if (isDevAddress(_msgSender())){
      amountOfTokens = msg.value.mul(10 ** 18).div(INVESTMENT_RATIO_DEVELOPER);
    } else {
      amountOfTokens = msg.value.mul(10 ** 18).div(INVESTMENT_RATIO_PRESALE);
    }
//    console.log("msg.value: '%s'", msg.value);
//    console.log("INVESTMENT_RATIO_DEVELOPER: '%s'", INVESTMENT_RATIO_DEVELOPER);
//    console.log("amountOfTokens: '%s'", amountOfTokens);
//    console.log("msg.value: '%s'", msg.value);
//    console.log("addressTotalInvestment: '%s'", addressTotalInvestment);
//    console.log("investments[_msgSender()]: '%s'", investments[_msgSender()]);

    DegenLamboToken.transfer(_msgSender(), amountOfTokens);

    investors[_investorCount] = msg.sender;
    _investorCount++;

    investments[_msgSender()] = addressTotalInvestment;

  }

  function isWhitelisted(address adr) public view returns (bool){
    return whitelistAddresses[adr];
  }

  function isDevAddress(address adr) public view returns (bool){
    return devAddresses[adr];
  }

  function getInvestedAmount(address adr) public view returns (uint256){
      return investments[adr];
  }

  function getInvestorCount() public view returns (uint256){
    return _investorCount;
  }

}
