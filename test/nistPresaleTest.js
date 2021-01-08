const { expect } = require("chai");
const {
    expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');

describe("PresaleContract", async function() {

    // Contracts
    let NistPreSaleContract;
    let DegenLamboTokenContract
    let NistTokenContract

    // Accounts
    let testAccountPrimary
    let testAccountSecondary

    let provider

    // Transaction configuration
    let gasLimit = 1800000;
    let gasPrice

    beforeEach(async function () {
        provider = ethers.getDefaultProvider();

        gasPrice = await provider.getGasPrice();

        const accounts = await ethers.getSigners();
        testAccountPrimary = accounts[0]
        testAccountSecondary = accounts[1]

        // Deploy dummy token contract
        // Contract send entire balance to contract creator
        const TokenDecimals = 18
        let DegenLamboToken = await ethers.getContractFactory("DegenLamboToken");
        DegenLamboTokenContract = await DegenLamboToken.deploy("DegenLambo", TokenDecimals);
        await DegenLamboTokenContract.deployed();

        // Deploy NIST token contract
        let NistToken = await ethers.getContractFactory("NistToken");
        NistTokenContract = await NistToken.deploy("NistToken", TokenDecimals);
        await NistTokenContract.deployed();

        // Deploy pre-sale distribution contract
        let _presale = await ethers.getContractFactory("NistPresaleContract");
        NistPreSaleContract = await _presale.deploy(DegenLamboTokenContract.address, NistTokenContract.address , TokenDecimals);
        await NistPreSaleContract.deployed();

        // send some Lambo tokens to secondary account
        await DegenLamboTokenContract.transfer(testAccountSecondary.address, 1000, {from:testAccountPrimary.address})

        // send entire token balance to pre-sale contract
        let tokenBalance = await NistTokenContract.balanceOf(testAccountPrimary.address);
        await NistTokenContract.transfer(NistPreSaleContract.address, tokenBalance, {from: testAccountPrimary.address})

    });

    it("If presale is active, should be able to send Lambo and get NIST", async function () {
        await NistPreSaleContract.startPresalePhase1()

        await DegenLamboTokenContract.connect(testAccountSecondary).approve(NistPreSaleContract.address , 1000)
        await NistPreSaleContract.connect(testAccountSecondary).investLamboForNist(1000)

        let NistTokenBalance = await NistTokenContract.balanceOf(testAccountSecondary.address);
        expect(NistTokenBalance).to.equal("1000")
    });

    it("If phase 2 presale is active, pre-sale should accept ETH", async function () {
        await NistPreSaleContract.startPresalePhase1()
        await NistPreSaleContract.startPresalePhase2()

        await testAccountSecondary.sendTransaction({
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            to: NistPreSaleContract.address,
            value: ethers.utils.parseEther("0.5")
        });

        let NistTokenBalance = await NistTokenContract.balanceOf(testAccountSecondary.address);
        expect(NistTokenBalance).to.equal("1000000000000000000")

    });

    it("If phase 2 presale is NOT active, pre-sale NOT should accept ETH", async function () {
        await NistPreSaleContract.startPresalePhase1()
        // await NistPreSaleContract.startPresalePhase2()

        await expect(
            testAccountSecondary.sendTransaction({
                gasLimit: gasLimit,
                gasPrice: gasPrice,
                to: NistPreSaleContract.address,
                value: ethers.utils.parseEther("0.5")
            })).to.be.revertedWith('Presale is currently only accepting Lambo tokens');
    });

    it("If phase 1 and 2 of presale is NOT active, pre-sale NOT should accept any investments", async function () {
        // await NistPreSaleContract.startPresalePhase1()
        // await NistPreSaleContract.startPresalePhase2()
        await DegenLamboTokenContract.connect(testAccountSecondary).approve(NistPreSaleContract.address , 1000)

        await expect(
            NistPreSaleContract.connect(testAccountSecondary).investLamboForNist(1000))
            .to.be.revertedWith('Presale is currently not active');

        await expect(
            testAccountSecondary.sendTransaction({
                gasLimit: gasLimit,
                gasPrice: gasPrice,
                to: NistPreSaleContract.address,
                value: ethers.utils.parseEther("0.5")
            })).to.be.revertedWith('Presale is currently not active');
    });
})