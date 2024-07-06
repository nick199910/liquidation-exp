// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Test, console} from "forge-std/Test.sol";

interface ILendingPool {
    function liquidationCall(
        address collateralAsset,
        address debtAsset,
        address user,
        uint256 debtToCover,
        bool receiveAToken
    ) external;

    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

interface IERC20 {
    function balanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with USDT

    function transfer(address to, uint256 value) external returns (bool);
}

interface IWETH is IERC20 {
    // Convert the wrapped token back to Ether.
    function withdraw(uint256) external;
}

interface IUniswapV2Callee {
    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

interface IUniswapV2Factory {
    // Returns the address of the pair for tokenA and tokenB, if it has been created, else address(0).
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

interface IPriceOracleGetter {
    function getAssetPrice(address _asset) external view returns (uint256);

    function getAssetsPrices(
        address[] calldata _assets
    ) external view returns (uint256[] memory);

    function getSourceOfAsset(address _asset) external view returns (address);

    function getFallbackOracle() external view returns (address);
}

interface IUniswapV2Pair {
    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external;

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

// ----------------------IMPLEMENTATION------------------------------

contract LiquidationDeep is IUniswapV2Callee {
    uint8 public constant health_factor_decimals = 18;

    address oracle = 0xA50ba011c48153De246E5192C8f9258A2ba79Ca9;
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    // SushiSwap Pairs
    IUniswapV2Pair usdc_weth_sushi_pair =
        IUniswapV2Pair(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0);
    IUniswapV2Pair weth_usdt_sushi_pair =
        IUniswapV2Pair(0x06da0fd433C1A5d7a4faa01111c044910A184553);

    // Uniswap Pairs
    IUniswapV2Pair weth_usdt_pair =
        IUniswapV2Pair(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852);
    IUniswapV2Pair wbtc_weth_pair =
        IUniswapV2Pair(0xBb2b8038a1640196FbE3e38816F3e67Cba72D940);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(
            reserveIn > 0 && reserveOut > 0,
            "UniswapV2Library: INSUFFICIENT_LIQUIDITY"
        );
        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    constructor() {
        // TODO: (optional) initialize your contract
        //   *** Your code here ***
        // END TODO
    }

    function operate() external {
        (uint112 weth_reserve, uint112 usdt_reserve, ) = weth_usdt_pair
            .getReserves();
        console.log("weth_reserve: ", weth_reserve / 1e18);
        console.log("usdt_reserve: ", usdt_reserve / 1e6);
        console.log("\n");

        (
            uint112 sushi1_usdc_reserve,
            uint112 sushi1_weth_reserve,

        ) = usdc_weth_sushi_pair.getReserves();

        console.log("sushi1_weth_reserve: ", sushi1_weth_reserve / 1e18);
        console.log("sushi1_usdc_reserve: ", sushi1_usdc_reserve / 1e6);
        console.log("\n");

        (
            uint112 sushi2_weth_reserve,
            uint112 sushi2_usdt_reserve,

        ) = weth_usdt_sushi_pair.getReserves();
        console.log("sushi_weth_reserve: ", sushi2_weth_reserve / 1e18);
        console.log("sushi_usdt_reserve: ", sushi2_usdt_reserve / 1e6);
    }

    // required by the swap
    function uniswapV2Call(
        address,
        uint256,
        uint256,
        bytes calldata data
    ) external override {}
}
