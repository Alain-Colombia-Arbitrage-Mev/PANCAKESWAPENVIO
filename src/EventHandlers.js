const ZERO_BI = BigInt(0);
const ONE_BI = BigInt(1);
const ZERO_BD = '0';
const BI_18 = BigInt(18);

const GLOBAL_EVENTS_SUMMARY_KEY = "GlobalEventsSummary";

function exponentToBigDecimal(decimals) {
  let bd = '1';
  for (let i = 0; i < Number(decimals); i++) {
    bd = (BigInt(bd) * BigInt(10)).toString();
  }
  return bd;
}

function convertTokenToDecimal(tokenAmount, exchangeDecimals) {
  if (exchangeDecimals === ZERO_BI) {
    return tokenAmount.toString();
  }
  return (BigInt(tokenAmount) * BigInt(exponentToBigDecimal(exchangeDecimals))).toString();
}

async function getOrCreateEventsSummary(context) {
  let summary = await context.EventsSummary.get(GLOBAL_EVENTS_SUMMARY_KEY);
  if (!summary) {
    summary = {
      id: GLOBAL_EVENTS_SUMMARY_KEY,
      pancakeFactory_PairCreatedCount: ZERO_BI.toString(),
      pancakePair_SwapCount: ZERO_BI.toString(),
      pancakePair_SyncCount: ZERO_BI.toString(),
      pancakePair_MintCount: ZERO_BI.toString(),
      pancakePair_BurnCount: ZERO_BI.toString(),
    };
    await context.EventsSummary.set(summary);
  }
  return summary;
}

async function updateEventsSummary(context, eventType) {
  let summary = await getOrCreateEventsSummary(context);
  summary[eventType] = (BigInt(summary[eventType]) + ONE_BI).toString();
  await context.EventsSummary.set(summary);
}

async function getOrCreateToken(context, tokenAddress) {
  let token = await context.Token.get(tokenAddress);
  if (!token) {
    const tokenContract = context.ERC20.createInstance(tokenAddress);
    const [name, symbol, decimals, totalSupply] = await Promise.all([
      tokenContract.name().catch(() => "Unknown"),
      tokenContract.symbol().catch(() => "UNKNOWN"),
      tokenContract.decimals().catch(() => "18"),
      tokenContract.totalSupply().catch(() => "0"),
    ]);

    token = {
      id: tokenAddress,
      symbol: symbol,
      name: name,
      decimals: decimals.toString(),
      totalSupply: totalSupply.toString(),
      tradeVolume: ZERO_BD,
      tradeVolumeUSD: ZERO_BD,
      untrackedVolumeUSD: ZERO_BD,
      txCount: ZERO_BI.toString(),
      totalLiquidity: ZERO_BD,
      derivedBNB: ZERO_BD,
    };
    await context.Token.set(token);
  }
  return token;
}

async function handlePairCreated(event, context) {
  await updateEventsSummary(context, 'pancakeFactory_PairCreatedCount');

  const token0 = await getOrCreateToken(context, event.params.token0);
  const token1 = await getOrCreateToken(context, event.params.token1);

  const pair = {
    id: event.params.pair,
    factory: event.address,
    token0: token0.id,
    token1: token1.id,
    reserve0: ZERO_BD,
    reserve1: ZERO_BD,
    totalSupply: ZERO_BI.toString(),
    reserveBNB: ZERO_BD,
    reserveUSD: ZERO_BD,
    trackedReserveBNB: ZERO_BD,
    token0Price: ZERO_BD,
    token1Price: ZERO_BD,
    volumeToken0: ZERO_BD,
    volumeToken1: ZERO_BD,
    volumeUSD: ZERO_BD,
    untrackedVolumeUSD: ZERO_BD,
    txCount: ZERO_BI.toString(),
    createdAtTimestamp: event.blockTimestamp.toString(),
    createdAtBlockNumber: event.blockNumber.toString(),
    liquidityProviderCount: ZERO_BI.toString(),
  };
  await context.Pair.set(pair);

  const factory = await context.PancakeFactory.get(event.address);
  const pairCount = factory ? (BigInt(factory.pairCount) + ONE_BI).toString() : ONE_BI.toString();

  await context.PancakeFactory.set({
    id: event.address,
    pairCount: pairCount,
    totalVolumeUSD: factory ? factory.totalVolumeUSD : ZERO_BD,
    totalLiquidityUSD: factory ? factory.totalLiquidityUSD : ZERO_BD,
    totalLiquidityBNB: factory ? factory.totalLiquidityBNB : ZERO_BD,
    txCount: factory ? (BigInt(factory.txCount) + ONE_BI).toString() : ONE_BI.toString(),
  });

  await context.PancakeFactory_PairCreated.set({
    id: event.transactionHash + '-' + event.logIndex.toString(),
    token0: token0.id,
    token1: token1.id,
    pair: pair.id,
    blockNumber: event.blockNumber.toString(),
    blockTimestamp: event.blockTimestamp.toString(),
    transactionHash: event.transactionHash,
  });
}

async function handleSync(event, context) {
  await updateEventsSummary(context, 'pancakePair_SyncCount');

  const pair = await context.Pair.get(event.address);
  if (pair) {
    const token0 = await context.Token.get(pair.token0);
    const token1 = await context.Token.get(pair.token1);

    if (token0 && token1) {
      pair.reserve0 = convertTokenToDecimal(event.params.reserve0, token0.decimals);
      pair.reserve1 = convertTokenToDecimal(event.params.reserve1, token1.decimals);

      if (BigInt(pair.reserve1) !== ZERO_BI) 
        pair.token0Price = (BigInt(pair.reserve0) * BigInt(10) ** 18n / BigInt(pair.reserve1)).toString();
      else 
        pair.token0Price = ZERO_BD;
      
      if (BigInt(pair.reserve0) !== ZERO_BI) 
        pair.token1Price = (BigInt(pair.reserve1) * BigInt(10) ** 18n / BigInt(pair.reserve0)).toString();
      else 
        pair.token1Price = ZERO_BD;

      await context.Pair.set(pair);
    }
  }

  await context.PancakePair_Sync.set({
    id: event.transactionHash + '-' + event.logIndex.toString(),
    pair: event.address,
    reserve0: convertTokenToDecimal(event.params.reserve0, BI_18),
    reserve1: convertTokenToDecimal(event.params.reserve1, BI_18),
    blockNumber: event.blockNumber.toString(),
    blockTimestamp: event.blockTimestamp.toString(),
    transactionHash: event.transactionHash,
  });
}

async function handleMint(event, context) {
  await updateEventsSummary(context, 'pancakePair_MintCount');

  const pair = await context.Pair.get(event.address);
  if (pair) {
    pair.txCount = (BigInt(pair.txCount) + ONE_BI).toString();
    await context.Pair.set(pair);

    const token0 = await context.Token.get(pair.token0);
    const token1 = await context.Token.get(pair.token1);

    if (token0 && token1) {
      const amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals);
      const amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals);

      await context.PancakePair_Mint.set({
        id: event.transactionHash + '-' + event.logIndex.toString(),
        pair: event.address,
        sender: event.params.sender,
        amount0: amount0,
        amount1: amount1,
        logIndex: event.logIndex.toString(),
        amountUSD: ZERO_BD, // Implement price oracle to calculate this
        blockNumber: event.blockNumber.toString(),
        blockTimestamp: event.blockTimestamp.toString(),
        transactionHash: event.transactionHash,
      });
    }
  }
}

async function handleBurn(event, context) {
  await updateEventsSummary(context, 'pancakePair_BurnCount');

  const pair = await context.Pair.get(event.address);
  if (pair) {
    pair.txCount = (BigInt(pair.txCount) + ONE_BI).toString();
    await context.Pair.set(pair);

    const token0 = await context.Token.get(pair.token0);
    const token1 = await context.Token.get(pair.token1);

    if (token0 && token1) {
      const amount0 = convertTokenToDecimal(event.params.amount0, token0.decimals);
      const amount1 = convertTokenToDecimal(event.params.amount1, token1.decimals);

      await context.PancakePair_Burn.set({
        id: event.transactionHash + '-' + event.logIndex.toString(),
        pair: event.address,
        sender: event.params.sender,
        amount0: amount0,
        amount1: amount1,
        to: event.params.to,
        logIndex: event.logIndex.toString(),
        amountUSD: ZERO_BD, // Implement price oracle to calculate this
        blockNumber: event.blockNumber.toString(),
        blockTimestamp: event.blockTimestamp.toString(),
        transactionHash: event.transactionHash,
      });
    }
  }
}

async function handleSwap(event, context) {
  await updateEventsSummary(context, 'pancakePair_SwapCount');

  const pair = await context.Pair.get(event.address);
  if (pair) {
    pair.txCount = (BigInt(pair.txCount) + ONE_BI).toString();
    
    const token0 = await context.Token.get(pair.token0);
    const token1 = await context.Token.get(pair.token1);

    if (token0 && token1) {
      const amount0In = convertTokenToDecimal(event.params.amount0In, token0.decimals);
      const amount1In = convertTokenToDecimal(event.params.amount1In, token1.decimals);
      const amount0Out = convertTokenToDecimal(event.params.amount0Out, token0.decimals);
      const amount1Out = convertTokenToDecimal(event.params.amount1Out, token1.decimals);

      pair.volumeToken0 = (BigInt(pair.volumeToken0) + BigInt(amount0In) + BigInt(amount0Out)).toString();
      pair.volumeToken1 = (BigInt(pair.volumeToken1) + BigInt(amount1In) + BigInt(amount1Out)).toString();
      
      await context.Pair.set(pair);

      await context.PancakePair_Swap.set({
        id: event.transactionHash + '-' + event.logIndex.toString(),
        pair: event.address,
        sender: event.params.sender,
        amount0In: amount0In,
        amount1In: amount1In,
        amount0Out: amount0Out,
        amount1Out: amount1Out,
        to: event.params.to,
        logIndex: event.logIndex.toString(),
        amountUSD: ZERO_BD, // Implement price oracle to calculate this
        blockNumber: event.blockNumber.toString(),
        blockTimestamp: event.blockTimestamp.toString(),
        transactionHash: event.transactionHash,
      });
    }
  }
}

module.exports = {
  handlePairCreated,
  handleSync,
  handleMint,
  handleBurn,
  handleSwap,
};