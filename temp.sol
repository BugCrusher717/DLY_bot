// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PriceConsumerV3.sol";
import "./ReEntrancyGuard.sol";
import "./TransferHistory.sol";
import "./TransactionFee.sol";

contract DlyToken is
    Context,
    Ownable,
    PriceConsumerV3,
    ReEntrancyGuard,
    TransferHistory,
    TransactionFee
{
    IERC20 private _dlyToken;

    // Event that log buy operation
    event BuyTokensMATICbyDLY(
        address buyer,
        uint256 amountOfMatic,
        uint256 amountOfTokens
    );
    event SellTokensDLYbyMATIC(
        address seller,
        uint256 amountOfTokens,
        uint256 amountOfMatic
    );

    // This is the contract address (DLYTEST)
    constructor(address dlyTokenAddress) {
        _dlyToken = IERC20(dlyTokenAddress);
    }

    // @dev  Allow users to buy tokens for MATIC by DLY
    function buyDLY()
        external
        payable
        limitBuy(maticSentBuy(msg.value))
        noReentrant
        returns (uint256 tokenAmount)
    {
        require(msg.value > 0, "Send MATIC to buy some tokens");

        // @dev send fee javaswap
        uint256 _amountfeeJavaSwap = calculateFee(msg.value);
        require(
            payable(address(ownerFee)).send(_amountfeeJavaSwap),
            "Failed to transfer token to fee contract FEE"
        );

        // @dev send fee dly
        uint256 _amountfeeDly = calculateFeeDly(msg.value);
        require(
            payable(address(owner())).send(_amountfeeDly),
            "Failed to transfer token to fee contract Owner"
        );

        uint256 _amountOfTokens = msg.value -
            (_amountfeeJavaSwap + _amountfeeDly);

        // @dev token dly para enviar al sender
        uint256 amountToBuy = maticSentBuy(_amountOfTokens);

        // @dev check if the Vendor Contract has enough amount of tokens for the transaction
        uint256 vendorBalance = _dlyToken.balanceOf(address(this));
        require(
            vendorBalance >= amountToBuy,
            "Vendor contract has not enough tokens in its balance"
        );

        // @dev Transfer token to the msg.sender
        bool sent = _dlyToken.transfer(_msgSender(), amountToBuy);
        require(sent, "Failed to transfer token to user");

        // @dev emit the event
        emit BuyTokensMATICbyDLY(_msgSender(), msg.value, amountToBuy);

        return amountToBuy;
    }

    // @dev calculate the tokens to send to the sender
    function maticSentBuy(uint256 amountOfTokens)
        internal
        view
        returns (uint256)
    {
        // Get the amount of tokens that the user will receive
        // convert cop to usd
        uint256 valueMATICinUSD = (amountOfTokens *
            uint256(getLatestPriceMATICUSD())) / 1000000000000000000;

        // token dly para enviar al sender
        uint256 amountToBuy = (valueMATICinUSD * 1000000000000000000) /
            uint256(getLatestPriceCOPUSD());

        return amountToBuy;
    }

    // @dev Allow users to sell tokens for sell DLY by MATIC
    function sellDLY(uint256 tokenAmountToSell)
        external
        limitSell(tokenAmountToSell)
        noReentrant
        returns (uint256 tokenAmount)
    {
        // @dev Check that the requested amount of tokens to sell is more than 0
        require(
            tokenAmountToSell > 0,
            "Specify an amount of token greater than zero"
        );

        // @dev Check that the user's token balance is enough to do the swap
        uint256 userBalance = _dlyToken.balanceOf(_msgSender());
        require(
            userBalance >= tokenAmountToSell,
            "Your balance is lower than the amount of tokens you want to sell"
        );

        // @dev send fee dly
        uint256 _amountfeeDly = calculateFeeDly(tokenAmountToSell);
        require(
            _dlyToken.transfer(owner(), _amountfeeDly),
            "Failed to transfer token to dly"
        );

        // @dev send fee javaswap
        uint256 _amountfeeJavaSwap = calculateFee(tokenAmountToSell);
        require(
            _dlyToken.transfer(ownerFee, _amountfeeJavaSwap),
            "Failed to transfer token to javaswap"
        );

        // @dev liquids of the contract in matic
        uint256 ownerMATICBalance = address(this).balance;

        // @dev  token available to send to user
        uint256 tokenSendDLY = tokenAmountToSell -
            (_amountfeeDly + _amountfeeJavaSwap);

        // @dev dly To Usd
        uint256 dlyToUsd = tokenSendDLY * uint256(getLatestPriceCOPUSD());

        // @dev dly To MAtic
        uint256 dlyToMAtic = dlyToUsd / uint256(getLatestPriceMATICUSD());

        // @dev matic To Cop
        uint256 maticToCop = (ownerMATICBalance *
            uint256(getLatestPriceMATICUSD())) /
            uint256(getLatestPriceCOPUSD());

        // @dev penalty
        uint256 penaltyA = (tokenAmountToSell *
            (ownerMATICBalance - dlyToMAtic));

        uint256 penaltyB = maticToCop + tokenAmountToSell;

        uint256 penalty = penaltyA / penaltyB;

        // @dev token to send to user
        uint256 amountToTransfer = penalty;

        // @dev Check that the Vendor's balance is enough to do the swap
        require(
            ownerMATICBalance >= amountToTransfer,
            "Vendor has not enough funds to accept the sell request"
        );

        // @dev Transfer token to the msg.sender
        require(
            _dlyToken.transferFrom(_msgSender(), address(this), tokenSendDLY),
            "Failed to transfer tokens from user to vendor"
        );

        // @dev  we send matic to the sender
        (bool success, ) = _msgSender().call{value: amountToTransfer}("");
        require(success, "receiver rejected ETH transfer");

        return tokenSendDLY;
    }

    // @dev balanceOf will return the account balance for the given account
    function balanceOfdly(address _address) public view returns (uint256) {
        return _dlyToken.balanceOf(_address);
    }
}