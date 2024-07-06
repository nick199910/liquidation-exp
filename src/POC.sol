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

interface AToken {
    function POOL() external view returns (address);

    function RESERVE_TREASURY_ADDRESS() external view returns (address);

    function UNDERLYING_ASSET_ADDRESS() external view returns (address);

    function _nonces(address) external view returns (uint256);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address user) external view returns (uint256);

    function burn(
        address user,
        address receiverOfUnderlying,
        uint256 amount,
        uint256 index
    ) external;

    function decimals() external view returns (uint8);

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool);

    function getIncentivesController() external view returns (address);

    function getScaledUserBalanceAndSupply(
        address user
    ) external view returns (uint256, uint256);

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool);

    function initialize(
        uint8 underlyingAssetDecimals,
        string memory tokenName,
        string memory tokenSymbol
    ) external;

    function mint(
        address user,
        uint256 amount,
        uint256 index
    ) external returns (bool);

    function mintToTreasury(uint256 amount, uint256 index) external;

    function name() external view returns (string memory);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function scaledBalanceOf(address user) external view returns (uint256);

    function scaledTotalSupply() external view returns (uint256);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferOnLiquidation(
        address from,
        address to,
        uint256 value
    ) external;

    function transferUnderlyingTo(
        address target,
        uint256 amount
    ) external returns (uint256);
}

interface IERC20 {
    // Returns the account balance of another account with address _owner.
    function balanceOf(address owner) external view returns (uint256);

    function approve(address spender, uint256 value) external; // return type is deleted to be compatible with

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

interface ICurve3Pool {
    function get_virtual_price() external view returns (uint);

    function exchange(
        int128 from,
        int128 to,
        uint256 _from_amount,
        uint256 _min_to_amount
    ) external;

    function calc_token_amount(
        uint256[3] calldata amounts,
        bool deposit
    ) external view returns (uint);
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

contract POC is IUniswapV2Callee {
    uint8 public constant health_factor_decimals = 18;
    IERC20 awbtc = IERC20(0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656);
    address be_liquided = 0x59CE4a2AC5bC3f5F225439B2993b86B42f6d3e9F;
    ILendingPool lending_pool =
        ILendingPool(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    address oracle = 0xA50ba011c48153De246E5192C8f9258A2ba79Ca9;
    IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 wbtc = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    uint borrow_usdt = 2919000000000;

    uint256 usdt_out1 = (borrow_usdt * 3) / 4;
    uint256 usdt_out2 = (borrow_usdt) / 4;

    ICurve3Pool curve_3pool =
        ICurve3Pool(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    uint cnt = 0;

    uint256 pair2_weth_borrow = 0;
    uint256 pair1_weth_borrow = 0;

    event log_named_decimal_uint(string key, uint256 val, uint256 decimals);

    // SushiSwap Pairs
    IUniswapV2Pair usdc_weth_sushi_pair =
        IUniswapV2Pair(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0);
    IUniswapV2Pair weth_usdt_sushi_pair =
        IUniswapV2Pair(0x06da0fd433C1A5d7a4faa01111c044910A184553);

    IUniswapV2Pair wbtc_weth_pair =
        IUniswapV2Pair(0xCEfF51756c56CeFFCA006cD410B03FFC46dd3a58);

    // Price
    // IPriceOracleGetter oracle =
    //     IPriceOracleGetter(0xA50ba011c48153De246E5192C8f9258A2ba79Ca9);

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
        uint256 atoken_bal = awbtc.balanceOf(be_liquided);

        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = lending_pool.getUserAccountData(be_liquided);
        require(healthFactor < 1 ether, "health factor too high");

        // console.log("totalCollateralETH", totalCollateralETH);
        // console.log("totalDebtETH", totalDebtETH);
        // console.log("availableBorrowsETH", availableBorrowsETH);
        // console.log("currentLiquidationThreshold", currentLiquidationThreshold);
        // console.log("ltv", ltv);
        // console.log("healthFactor", healthFactor);

        (
            uint112 pair1_usdc_reserve,
            uint112 pair1_weth_reserve,

        ) = usdc_weth_sushi_pair.getReserves();

        uint256 amount0Out = 0;

        pair1_weth_borrow = getAmountIn(
            usdt_out1,
            pair1_weth_reserve,
            pair1_usdc_reserve
        );

        emit log_named_decimal_uint(
            "pair1_weth_borrow: ",
            pair1_weth_borrow,
            18
        );

        (
            uint112 pair2_weth_reserve,
            uint112 pair2_usdt_reserve,

        ) = weth_usdt_sushi_pair.getReserves();

        pair2_weth_borrow = getAmountIn(
            usdt_out2,
            pair2_weth_reserve,
            pair2_usdt_reserve
        );

        emit log_named_decimal_uint(
            "pair2_weth_borrow: ",
            pair2_weth_borrow,
            18
        );

        bytes memory data = abi.encodePacked(
            weth_usdt_sushi_pair,
            pair2_weth_borrow
        );
        usdc_weth_sushi_pair.swap(usdt_out1, amount0Out, address(this), data);
    }

    // required by the swap
    function uniswapV2Call(
        address,
        uint256,
        uint256,
        bytes calldata data
    ) external override {
        cnt += 1;
        if (cnt == 1) {
            usdc.approve(address(curve_3pool), usdt_out1);
            curve_3pool.exchange(1, 2, usdt_out1, 0);
            console.log("");
            weth_usdt_sushi_pair.swap(0, usdt_out2, address(this), data);
        } else {
            uint256 usdt_bal = usdt.balanceOf(address(this));
            usdt.approve(address(lending_pool), usdt_bal);

            emit log_named_decimal_uint(
                "before liquidate liquidator usdt balance is: ",
                usdt_bal,
                6
            );
            uint256 wbtc_before = wbtc.balanceOf(address(this));
            emit log_named_decimal_uint(
                "before liquidate liquidator wbtc balance is: ",
                wbtc_before,
                6
            );
            lending_pool.liquidationCall(
                address(wbtc),
                address(usdt),
                be_liquided,
                usdt_bal,
                false
            );
            emit log_named_decimal_uint(
                "after liquidate liquidator usdt balance is: ",
                usdt.balanceOf(address(this)),
                6
            );
            uint256 wbtc_after = wbtc.balanceOf(address(this));
            emit log_named_decimal_uint(
                "after liquidate liquidator wbtc balance is: ",
                wbtc_after,
                6
            );

            // 拆分wbtc -> swap -> 不同的pair对

            (uint256 wbtc_reserve, uint256 weth_reserve, ) = wbtc_weth_pair
                .getReserves();

            uint256 weth_get = getAmountOut(
                wbtc_after,
                wbtc_reserve,
                weth_reserve
            );

            wbtc.transfer(address(wbtc_weth_pair), wbtc_after);
            wbtc_weth_pair.swap(0, weth_get, address(this), "");

            weth.transfer(address(usdc_weth_sushi_pair), pair1_weth_borrow);
            weth.transfer(address(weth_usdt_sushi_pair), pair2_weth_borrow);
            emit log_named_decimal_uint(
                "ETH Profit: ",
                weth.balanceOf(address(this)),
                18
            );
        }
    }
}
