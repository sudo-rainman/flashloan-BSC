pragma solidity 0.8.1;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/IPancakeFactory.sol';
import './interfaces/IPancakeRouter.sol';
import './interfaces/IPancakePair.sol';

import './interfaces/IBiswapCallee.sol';
import './interfaces/IBiswapFactory.sol';
import './interfaces/IBiswapRouter02.sol';
import './interfaces/IBiswapPair.sol';

contract FlashLoan is IBiswapCallee {

    IPancakeFactory factory;
    IPancakeRouter02 router2;

    IBiswapRouter02 BiswapRouter;
    IBiswapFactory BiswapFactory;

    address owner;

    receive() external payable {}
    
    constructor (){
        owner = msg.sender;
        BiswapFactory = IBiswapFactory(0x858E3312ed3A876947EA49d572A7C42DE08af7EE);
        BiswapRouter = IBiswapRouter02(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8);

        router2 = IPancakeRouter02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        factory = IPancakeFactory(0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73);
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    event Log(string message, uint val);

    function testFlashSwap(address[] memory _tokenBorrowPool,address _tokenSwap ,uint _amount, uint _from, address[] calldata _path, uint _amountOutminFrom, uint _amountOutminTo) external {
        require(_tokenBorrowPool.length == 2,'suc dic');      
        address _tokenBorrow = _tokenBorrowPool[0];
        address _toToken = _tokenBorrowPool[1];

        address pair = BiswapFactory.getPair(_tokenBorrow, _toToken);
        require(pair != address(0), "!pair");

        address from = _from == 1 ? 0x10ED43C718714eb63d5aA57B78B54704E256024E: 0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8 ;
        
        address token0 = IBiswapPair(pair).token0();
        address token1 = IBiswapPair(pair).token1();

        uint amount0Out = _tokenBorrow == token0 ? _amount : 0;
        uint amount1Out = _tokenBorrow == token1 ? _amount : 0;

        // need to pass some data to trigger PancakeCall
        bytes memory data = abi.encode(_tokenBorrow, _amount,_tokenSwap, from, _path, _amountOutminFrom, _amountOutminTo);

        IBiswapPair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    function BiswapCall(address _sender, uint amount0, uint amount1, bytes calldata _data) external override {
        address token0 = IBiswapPair(msg.sender).token0();
        address token1 = IBiswapPair(msg.sender).token1();
        address pair = BiswapFactory.getPair(token0, token1);
        require(msg.sender == pair, "!pair");
        require(_sender == address(this), "!sender");
        (address tokenBorrow, uint amount, address tokenSwap, address from, address[] calldata path, uint amountOutminFrom ,uint amountOutminTo ) = abi.decode(_data, (address, uint, address, address, address[], uint,uint));
        // about 0.1%
        uint fee = ((amount * 1) / 999) + 1;
        uint amountToRepay = amount + fee;
        
        // do stuff here
        emit Log("amount", amount);
        emit Log("amount0", amount0);
        emit Log("amount1", amount1);
        emit Log("fee", fee);
        emit Log("amount to repay", amountToRepay);

        if (from == 0x10ED43C718714eb63d5aA57B78B54704E256024E) {
            IERC20(tokenBorrow).approve(from, amount);
            uint[] memory amounts = router2.swapExactTokensForTokens(amount,amountOutminFrom,path,address(this),block.timestamp);
            address[] memory pathTo = new address[](2);
            pathTo[0] = path[path.length-1];
            pathTo[1] = path[0];
            IERC20(path[path.length-1]).approve(0x3a6d8cA21D1CF76F653A67577FA0D27453350dD8, amounts[amounts.length-1]);
            BiswapRouter.swapExactTokensForTokens(amounts[amounts.length-1], amountOutminTo, pathTo, address(this), block.timestamp);

        }

        IERC20(tokenBorrow).transfer(pair, amountToRepay);

    }

    function withdraw(address _tokenWithdraw) public onlyOwner {
        IERC20 token = IERC20(_tokenWithdraw);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}