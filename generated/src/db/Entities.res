open Table
open Enums.EntityType
type id = string

type internalEntity
module type Entity = {
  type t
  let key: string
  let name: Enums.EntityType.t
  let schema: S.schema<t>
  let rowsSchema: S.schema<array<t>>
  let table: Table.table
}
module type InternalEntity = Entity with type t = internalEntity
external entityModToInternal: module(Entity with type t = 'a) => module(InternalEntity) = "%identity"

//shorthand for punning
let isPrimaryKey = true
let isNullable = true
let isArray = true
let isIndex = true

@genType
type whereOperations<'entity, 'fieldType> = {eq: 'fieldType => promise<array<'entity>>}

module Pair = {
  let key = "Pair"
  let name = Pair
  @genType
  type t = {
    createdAtBlockNumber: string,
    createdAtTimestamp: string,
    factory_id: id,
    id: id,
    reserve0: string,
    reserve1: string,
    reserveBNB: string,
    reserveUSD: string,
    
    token0_id: id,
    token0Price: string,
    token1_id: id,
    token1Price: string,
    totalSupply: string,
    trackedReserveBNB: string,
    txCount: string,
    untrackedVolumeUSD: string,
    volumeToken0: string,
    volumeToken1: string,
    volumeUSD: string,
  }

  let schema = S.object((s): t => {
    createdAtBlockNumber: s.field("createdAtBlockNumber", S.string),
    createdAtTimestamp: s.field("createdAtTimestamp", S.string),
    factory_id: s.field("factory_id", S.string),
    id: s.field("id", S.string),
    reserve0: s.field("reserve0", S.string),
    reserve1: s.field("reserve1", S.string),
    reserveBNB: s.field("reserveBNB", S.string),
    reserveUSD: s.field("reserveUSD", S.string),
    
    token0_id: s.field("token0_id", S.string),
    token0Price: s.field("token0Price", S.string),
    token1_id: s.field("token1_id", S.string),
    token1Price: s.field("token1Price", S.string),
    totalSupply: s.field("totalSupply", S.string),
    trackedReserveBNB: s.field("trackedReserveBNB", S.string),
    txCount: s.field("txCount", S.string),
    untrackedVolumeUSD: s.field("untrackedVolumeUSD", S.string),
    volumeToken0: s.field("volumeToken0", S.string),
    volumeToken1: s.field("volumeToken1", S.string),
    volumeUSD: s.field("volumeUSD", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
      @as("factory_id") factory_id: whereOperations<t, id>,
    
      @as("token0_id") token0_id: whereOperations<t, id>,
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "createdAtBlockNumber", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "createdAtTimestamp", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "factory", 
      Text,
      
      
      
      
      ~linkedEntity="PancakeFactory",
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "reserve0", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "reserve1", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "reserveBNB", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "reserveUSD", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "token0", 
      Text,
      
      
      
      
      ~linkedEntity="Token",
      ),
      mkField(
      "token0Price", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "token1", 
      Text,
      
      
      
      
      ~linkedEntity="Token",
      ),
      mkField(
      "token1Price", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "totalSupply", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "trackedReserveBNB", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "txCount", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "untrackedVolumeUSD", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "volumeToken0", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "volumeToken1", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "volumeUSD", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", TimestampWithoutTimezone, ~default="CURRENT_TIMESTAMP"),
      mkDerivedFromField(
      "swaps", 
      ~derivedFromEntity="PancakePair_Swap",
      ~derivedFromField="pair",
      ),
    ],
  )
}
 
module PancakeFactory = {
  let key = "PancakeFactory"
  let name = PancakeFactory
  @genType
  type t = {
    id: id,
    pairCount: string,
    
    totalLiquidityBNB: string,
    totalLiquidityUSD: string,
    totalVolumeUSD: string,
    txCount: string,
  }

  let schema = S.object((s): t => {
    id: s.field("id", S.string),
    pairCount: s.field("pairCount", S.string),
    
    totalLiquidityBNB: s.field("totalLiquidityBNB", S.string),
    totalLiquidityUSD: s.field("totalLiquidityUSD", S.string),
    totalVolumeUSD: s.field("totalVolumeUSD", S.string),
    txCount: s.field("txCount", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "pairCount", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "totalLiquidityBNB", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "totalLiquidityUSD", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "totalVolumeUSD", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "txCount", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", TimestampWithoutTimezone, ~default="CURRENT_TIMESTAMP"),
      mkDerivedFromField(
      "pairs", 
      ~derivedFromEntity="Pair",
      ~derivedFromField="factory",
      ),
    ],
  )
}
 
module PancakeFactory_PairCreated = {
  let key = "PancakeFactory_PairCreated"
  let name = PancakeFactory_PairCreated
  @genType
  type t = {
    blockNumber: string,
    blockTimestamp: string,
    id: id,
    pair_id: id,
    token0_id: id,
    token1_id: id,
    transactionHash: string,
  }

  let schema = S.object((s): t => {
    blockNumber: s.field("blockNumber", S.string),
    blockTimestamp: s.field("blockTimestamp", S.string),
    id: s.field("id", S.string),
    pair_id: s.field("pair_id", S.string),
    token0_id: s.field("token0_id", S.string),
    token1_id: s.field("token1_id", S.string),
    transactionHash: s.field("transactionHash", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "blockNumber", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "blockTimestamp", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "pair", 
      Text,
      
      
      
      
      ~linkedEntity="Pair",
      ),
      mkField(
      "token0", 
      Text,
      
      
      
      
      ~linkedEntity="Token",
      ),
      mkField(
      "token1", 
      Text,
      
      
      
      
      ~linkedEntity="Token",
      ),
      mkField(
      "transactionHash", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", TimestampWithoutTimezone, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module PancakePair_Swap = {
  let key = "PancakePair_Swap"
  let name = PancakePair_Swap
  @genType
  type t = {
    amount0In: string,
    amount0Out: string,
    amount1In: string,
    amount1Out: string,
    amountUSD: string,
    blockNumber: string,
    blockTimestamp: string,
    id: id,
    logIndex: string,
    pair_id: id,
    sender: string,
    to: string,
    transactionHash: string,
  }

  let schema = S.object((s): t => {
    amount0In: s.field("amount0In", S.string),
    amount0Out: s.field("amount0Out", S.string),
    amount1In: s.field("amount1In", S.string),
    amount1Out: s.field("amount1Out", S.string),
    amountUSD: s.field("amountUSD", S.string),
    blockNumber: s.field("blockNumber", S.string),
    blockTimestamp: s.field("blockTimestamp", S.string),
    id: s.field("id", S.string),
    logIndex: s.field("logIndex", S.string),
    pair_id: s.field("pair_id", S.string),
    sender: s.field("sender", S.string),
    to: s.field("to", S.string),
    transactionHash: s.field("transactionHash", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
      @as("pair_id") pair_id: whereOperations<t, id>,
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "amount0In", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "amount0Out", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "amount1In", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "amount1Out", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "amountUSD", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "blockNumber", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "blockTimestamp", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "logIndex", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "pair", 
      Text,
      
      
      
      
      ~linkedEntity="Pair",
      ),
      mkField(
      "sender", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "to", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "transactionHash", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", TimestampWithoutTimezone, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module PancakePair_Sync = {
  let key = "PancakePair_Sync"
  let name = PancakePair_Sync
  @genType
  type t = {
    blockNumber: string,
    blockTimestamp: string,
    id: id,
    pair_id: id,
    reserve0: string,
    reserve1: string,
    transactionHash: string,
  }

  let schema = S.object((s): t => {
    blockNumber: s.field("blockNumber", S.string),
    blockTimestamp: s.field("blockTimestamp", S.string),
    id: s.field("id", S.string),
    pair_id: s.field("pair_id", S.string),
    reserve0: s.field("reserve0", S.string),
    reserve1: s.field("reserve1", S.string),
    transactionHash: s.field("transactionHash", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "blockNumber", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "blockTimestamp", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "pair", 
      Text,
      
      
      
      
      ~linkedEntity="Pair",
      ),
      mkField(
      "reserve0", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "reserve1", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "transactionHash", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", TimestampWithoutTimezone, ~default="CURRENT_TIMESTAMP"),
    ],
  )
}
 
module Token = {
  let key = "Token"
  let name = Token
  @genType
  type t = {
    decimals: string,
    derivedBNB: string,
    id: id,
    name: string,
    
    symbol: string,
    totalLiquidity: string,
    totalSupply: string,
    tradeVolume: string,
    tradeVolumeUSD: string,
    txCount: string,
    untrackedVolumeUSD: string,
  }

  let schema = S.object((s): t => {
    decimals: s.field("decimals", S.string),
    derivedBNB: s.field("derivedBNB", S.string),
    id: s.field("id", S.string),
    name: s.field("name", S.string),
    
    symbol: s.field("symbol", S.string),
    totalLiquidity: s.field("totalLiquidity", S.string),
    totalSupply: s.field("totalSupply", S.string),
    tradeVolume: s.field("tradeVolume", S.string),
    tradeVolumeUSD: s.field("tradeVolumeUSD", S.string),
    txCount: s.field("txCount", S.string),
    untrackedVolumeUSD: s.field("untrackedVolumeUSD", S.string),
  })

  let rowsSchema = S.array(schema)

  @genType
  type indexedFieldOperations = {
    
  }

  let table = mkTable(
     (name :> string),
    ~fields=[
      mkField(
      "decimals", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "derivedBNB", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "id", 
      Text,
      ~isPrimaryKey,
      
      
      
      
      ),
      mkField(
      "name", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "symbol", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "totalLiquidity", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "totalSupply", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "tradeVolume", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "tradeVolumeUSD", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "txCount", 
      Text,
      
      
      
      
      
      ),
      mkField(
      "untrackedVolumeUSD", 
      Text,
      
      
      
      
      
      ),
      mkField("db_write_timestamp", TimestampWithoutTimezone, ~default="CURRENT_TIMESTAMP"),
      mkDerivedFromField(
      "pairs", 
      ~derivedFromEntity="Pair",
      ~derivedFromField="token0",
      ),
    ],
  )
}
 

type entity = 
  | Pair(Pair.t)
  | PancakeFactory(PancakeFactory.t)
  | PancakeFactory_PairCreated(PancakeFactory_PairCreated.t)
  | PancakePair_Swap(PancakePair_Swap.t)
  | PancakePair_Sync(PancakePair_Sync.t)
  | Token(Token.t)

let makeGetter = (schema, accessor) => json => json->S.parseWith(schema)->Belt.Result.map(accessor)

let getEntityParamsDecoder = (entityName: Enums.EntityType.t) =>
  switch entityName {
  | Pair => makeGetter(Pair.schema, e => Pair(e))
  | PancakeFactory => makeGetter(PancakeFactory.schema, e => PancakeFactory(e))
  | PancakeFactory_PairCreated => makeGetter(PancakeFactory_PairCreated.schema, e => PancakeFactory_PairCreated(e))
  | PancakePair_Swap => makeGetter(PancakePair_Swap.schema, e => PancakePair_Swap(e))
  | PancakePair_Sync => makeGetter(PancakePair_Sync.schema, e => PancakePair_Sync(e))
  | Token => makeGetter(Token.schema, e => Token(e))
  }

let allTables: array<table> = [
  Pair.table,
  PancakeFactory.table,
  PancakeFactory_PairCreated.table,
  PancakePair_Swap.table,
  PancakePair_Sync.table,
  Token.table,
]
let schema = Schema.make(allTables)

@get
external getEntityId: internalEntity => string = "id"

exception UnexpectedIdNotDefinedOnEntity
let getEntityIdUnsafe = (entity: 'entity): id =>
  switch Utils.magic(entity)["id"] {
  | Some(id) => id
  | None =>
    UnexpectedIdNotDefinedOnEntity->ErrorHandling.mkLogAndRaise(
      ~msg="Property 'id' does not exist on expected entity object",
    )
  }
