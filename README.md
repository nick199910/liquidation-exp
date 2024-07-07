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

### How to Maximize Liquidation Profit In SaddleFinance 
SaddleFinance is a decentralized exchange (DEX) that fork curve. It provides a more efficient and transparent way to trade tokens compared to centralized exchanges.

1. **CPMM DEX Invariant**
In CPMM-type DEXs, a common invariant is observed:

During the token swap process, the liquidity of the pool should not change in the x->y and y->x processes.

For example:

- In Uniswap V2, V3, and their forked versions, their AMM curve X * Y >= K ensures that the K value should not change.
- In Curve and its forked versions, their AMM curve is given by:

   A * n * Σ(x_i) + D = A * n * D + (D^(n+1)) / (n^n * Π(x_i))


  which ensures that the D value should not change. 
  This transaction: [https://app.sentio.xyz/tx/1/0x2b023d65485c4bb68d781960c2196588d03b871dc9eb1c054f596b7ca6f7da56](https://app.sentio.xyz/tx/1/0x2b023d65485c4bb68d781960c2196588d03b871dc9eb1c054f596b7ca6f7da56) leverages an error in the MetaSwapUtils swap function during the Saddlepool swap process. This error leads to incorrect liquidity calculations in the pool, resulting in an excess amount of SUSD being swapped out. By exploiting this characteristic, it is possible to repeatedly swap and potentially drain the SUSD from the pool.
2. **attack POC Execution**
   Execute the attack POC as follows:
   ```sh
   forge test --mp test/SaddleFinance.sol -vv 
   ```