//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import"https://github.com/aave/aave-v3-core/blob/master/contracts/interfaces/IPoolAddressesProvider.sol";
import "https://github.com/aave/aave-v3-core/blob/master/contracts/interfaces/IPool.sol";


interface IWalletProvider {
    function balanceOf(address user, address token) external view returns (uint256);

    function getUserWalletBalances(address provider, address user) external view returns (address[] memory, uint256[] memory);
}

interface WEthContract {
    function deposit() external payable;

    function transfer(address, uint256) external;

    function approve(address sender, uint256 value) external returns (bool);

    function withdraw(uint256 amount) external payable;

    function balanceOf(address sender) external view returns (uint balanace);
}


contract FlowWalletV2 {
    address payable owner;
    IPoolAddressesProvider provider; 
    address poolAddress;
    IPool lendingPool;
    IWalletProvider wallet;
    uint256 depositedFunds;

    uint256 public collateralDeposited;
    uint256 public availableToBorrow;
    uint256 public totalDebt;

    

    uint256 public recommendedBorrowAmount;

    address aavePoolAddressesProvider = 0xBA6378f1c1D046e9EB0F538560BA7558546edF3C;
    address aaveWalletBalanceProvider = 0x116674C3Efe4e31F192d855284619DEd6fE2a1b9;

    address wethTokenAddress= 0xd74047010D77c5901df5b0f9ca518aED56C85e8D;
    IERC20 wethTokenContract = IERC20(wethTokenAddress);
    WEthContract wethContract = WEthContract(wethTokenAddress);

    address awethTokenAddress = 0x608D11E704baFb68CfEB154bF7Fd641120e33aD4;
    IERC20 awethTokenContract = IERC20(0x608D11E704baFb68CfEB154bF7Fd641120e33aD4);

  modifier onlyOwner(){
    require(owner==msg.sender);
    _;
    }

constructor () payable {
        owner = payable(msg.sender);
        provider = IPoolAddressesProvider(aavePoolAddressesProvider);
        poolAddress= provider.getPool();
        lendingPool = IPool(poolAddress);
        wallet = IWalletProvider(aaveWalletBalanceProvider);
     
    }


function seeWEth() public view returns (uint256){
    return wallet.balanceOf(address(this),wethTokenAddress);
}

function seeAWeth() public view returns (uint256){
    return wallet.balanceOf(address(this),awethTokenAddress);
}

function depositToAave() public {
    wethTokenContract.approve(poolAddress,100000e18);
    wethTokenContract.approve(address(this),100000e18);
    depositedFunds += wethTokenContract.balanceOf(address(this));
    lendingPool.deposit(wethTokenAddress,wethTokenContract.balanceOf(address(this)),address(this),0);
    getAccountData();
}

function viewDeposits() public view returns (uint256 deposits){     
deposits = depositedFunds;
}

function viewProfit() public view returns(uint256 profit){
profit = awethTokenContract.balanceOf(address(this)) - depositedFunds;
}

function withdrawAaveFunds()public onlyOwner{
    wethTokenContract.approve(poolAddress,100000e18);
    wethTokenContract.approve(address(this),100000e18);
    depositedFunds = 0;
    lendingPool.withdraw(wethTokenAddress,awethTokenContract.balanceOf(address(this)),address(this));
    getAccountData();
}

function convertToETH() public onlyOwner{
    uint amountIn = wethContract.balanceOf(address(this));
    wethContract.approve(address(this),amountIn);
    wethContract.withdraw(amountIn);  
}

function convertToWETH()public onlyOwner{
    wethContract.deposit{value:address(this).balance}();
}

function recoverETH() public onlyOwner{
  owner.transfer(address(this).balance);
}

function seeEth()public view returns (uint256){
    return address(this).balance;
}



function borrowFunds() public onlyOwner{
    wethTokenContract.approve(poolAddress,100000e18);
    wethTokenContract.approve(address(this),100000e18);
    lendingPool.borrow(wethTokenAddress,recommendedBorrowAmount,2,0,address(this));
    getAccountData();
}

function currentDebt() public view returns (uint256 totalDebtBase) { 
    (,totalDebtBase,,,,)= lendingPool.getUserAccountData(address(this));
}

function repayLoan() public onlyOwner {
   wethTokenContract.approve(poolAddress,100000e18);
   wethTokenContract.approve(address(this),100000e18);
   require(wethTokenContract.balanceOf(address(this))>=currentDebt(),"not enough funds to pay back loan.");
   uint256 MAX_INT = 2**256 - 1;
   lendingPool.repay(wethTokenAddress,MAX_INT,2,address(this));
   getAccountData();
}

function getAccountData() internal {
        (uint256 totalCollateralBase, uint256 totalDebtBase, uint256 availableBorrowsBase,,,)= lendingPool.getUserAccountData(address(this));
        collateralDeposited = totalCollateralBase;
        availableToBorrow = availableBorrowsBase;
        totalDebt = totalDebtBase;
        recommendedBorrowAmount= (availableToBorrow*90)/10000;
        
    }

receive() external payable {
    if(msg.sender == owner){
         wethContract.deposit{value:address(this).balance}();
    }
    
}

fallback() external payable {
}



}
