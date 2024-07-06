### How to Maximize Liquidation Profit Given a Fixed Liquidation Amount

In this example, the debt token is USDT. Therefore, to maximize liquidation profit, we need to optimize the following two operations:

1. **Borrowing as Much USDT as Possible from DEX**
   Since DEXs use CPMM (Constant Product Market Maker), borrowing large amounts of USDT can result in significant slippage. One way to reduce the impact of slippage is to borrow different amounts of USDT from various pools with larger liquidity.

   You can try using the Lagrange multiplier method to quantitatively solve for the optimal amount to borrow from each DEX given a fixed total borrowing amount.

   In this solution, SuShiSwap's `usdc_weth_sushi_pair` and `weth_usdt_sushi_pair` are used as simple examples.

2. **Selling as Much Liquidated Token as Possible on DEX**
   The optimization goal here is to sell as much WBTC as possible on DEX to maximize liquidation profit.

3. **Liquidation POC Execution**
   Execute the liquidation POC as follows:
   ```sh
   forge test --mp test/TestPoc.t.sol -vvv 
   ```