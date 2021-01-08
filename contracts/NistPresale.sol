//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract NistPresaleContract is Ownable {
  using SafeMath for uint256;

  IERC20 public LamboToken;
  IERC20 public NistToken;
  uint256 public TokenDecimals;

  mapping(address => uint256) public investments; // total WEI invested per address (1ETH = 1e18WEI)
  mapping (uint256=> address) public investors;   // list of participating investor addresses
  uint256 private _investorCount = 0;             // number of unique addresses that have invested

  uint256 public constant INVESTMENT_LIMIT_PRESALE   = 0.5 ether; // 1.5 ETH is maximum investment limit for pre-sale
  uint256 public constant INVESTMENT_RATIO_PRESALE   = 0.5 ether; // pre-sale rate is 0.5 ETH/Nist
  uint256 public constant PRESALE_ETH_HARDCAP = 50 ether;
  uint256 public constant PRESALE_ETH_CURRENT = 0 ether;


  bool public isPresaleActive  = false; // during activation, only Lambo is accepted for investment
  bool public isAcceptingEth = false; // when true, contact will accept ETH

  constructor(address LamboTokenAddress, address NistTokenAddress, uint256 tokenDecimals) {
    LamboToken = IERC20(LamboTokenAddress);
    NistToken = IERC20(NistTokenAddress);
    TokenDecimals = tokenDecimals;
  }

  function startPresalePhase1() public onlyOwner {
    isPresaleActive = true;
  }

  function startPresalePhase2() public onlyOwner {
    isAcceptingEth = true;
  }

  function removePresaleEthLimits() public onlyOwner {
    INVESTMENT_LIMIT_PRESALE = 1000 ether;
  }

  function endPresale() public onlyOwner {
    isPresaleActive = false;
    isAcceptingEth = false;
    payable(owner()).transfer(address(this).balance);
    LamboToken.transfer(owner(), LamboToken.balanceOf(address(this)));
    NistToken.transfer(owner(), NistToken.balanceOf(address(this)));
  }

  function investLamboForNist(uint256 amount) presaleActive hasApprovedLamboTransfer public {
    uint approvedTokenAmount = LamboToken.allowance(msg.sender, address(this));
//    console.log("approve amount", approvedTokenAmount);
//    console.log("amount to transfer", amount);
    require(approvedTokenAmount >= amount, "Not enough Lambo approved for transfer");
    require(LamboToken.transferFrom(msg.sender, address(this), amount));
    NistToken.transfer(msg.sender, amount);
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

  modifier hasApprovedLamboTransfer() {
    require(LamboToken.allowance(msg.sender, address(this)) > 0, "Lambo token not approved for transfer");
    _;
  }

  modifier hardcapLimited() {
    require(PRESALE_ETH_CURRENT < PRESALE_ETH_HARDCAP, "Presale hardcape reached");
    _;
  }

  modifier acceptingEth() {
    require(isAcceptingEth, "Presale is currently only accepting Lambo tokens");
    _;
  }

  modifier presaleActive() {
    require(isPresaleActive, "Presale is currently not active.");
    _;
  }

  receive()
    external
    payable
    presaleActive
    acceptingEth
    hardcapLimited
  {
    uint256 addressTotalInvestment = investments[_msgSender()].add(msg.value);

    require(addressTotalInvestment <= INVESTMENT_LIMIT_PRESALE, "Max investment per pre-sale address is 0.5 ETH.");

    uint256 amountOfTokens;

     amountOfTokens = msg.value.mul(10 ** TokenDecimals).div(INVESTMENT_RATIO_PRESALE);
     console.log("amountOfTokens FOR ETHER: '%s'", amountOfTokens);


//    console.log("msg.value: '%s'", msg.value);
//    console.log("INVESTMENT_RATIO_DEVELOPER: '%s'", INVESTMENT_RATIO_DEVELOPER);
//    console.log("amountOfTokens: '%s'", amountOfTokens);
//    console.log("msg.value: '%s'", msg.value);
//    console.log("addressTotalInvestment: '%s'", addressTotalInvestment);
//    console.log("investments[_msgSender()]: '%s'", investments[_msgSender()]);

    NistToken.transfer(_msgSender(), amountOfTokens);

    investors[_investorCount] = msg.sender;
    _investorCount++;

    investments[_msgSender()] = addressTotalInvestment;

  }

  function getInvestedAmount(address adr) public view returns (uint256){
      return investments[adr];
  }

  function getInvestorCount() public view returns (uint256){
    return _investorCount;
  }

}
