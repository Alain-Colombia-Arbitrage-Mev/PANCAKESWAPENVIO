//*************
//***ENTITIES**
//*************
@genType.as("Id")
type id = string

@genType
type contractRegistrations = {
  // TODO: only add contracts we've registered for the event in the config
  addPancakeFactory: (Address.t) => unit,
  addPancakePair: (Address.t) => unit,
}

@genType
type entityLoaderContext<'entity, 'indexedFieldOperations> = {
  get: id => promise<option<'entity>>,
  getWhere: 'indexedFieldOperations,
}

@genType
type loaderContext = {
  log: Logs.userLogger,
  @as("Pair") pair: entityLoaderContext<Entities.Pair.t, Entities.Pair.indexedFieldOperations>,
  @as("PancakeFactory") pancakeFactory: entityLoaderContext<Entities.PancakeFactory.t, Entities.PancakeFactory.indexedFieldOperations>,
  @as("PancakeFactory_PairCreated") pancakeFactory_PairCreated: entityLoaderContext<Entities.PancakeFactory_PairCreated.t, Entities.PancakeFactory_PairCreated.indexedFieldOperations>,
  @as("PancakePair_Swap") pancakePair_Swap: entityLoaderContext<Entities.PancakePair_Swap.t, Entities.PancakePair_Swap.indexedFieldOperations>,
  @as("PancakePair_Sync") pancakePair_Sync: entityLoaderContext<Entities.PancakePair_Sync.t, Entities.PancakePair_Sync.indexedFieldOperations>,
  @as("Token") token: entityLoaderContext<Entities.Token.t, Entities.Token.indexedFieldOperations>,
}

@genType
type entityHandlerContext<'entity> = {
  get: id => promise<option<'entity>>,
  set: 'entity => unit,
  deleteUnsafe: id => unit,
}


@genType
type handlerContext = {
  log: Logs.userLogger,
  @as("Pair") pair: entityHandlerContext<Entities.Pair.t>,
  @as("PancakeFactory") pancakeFactory: entityHandlerContext<Entities.PancakeFactory.t>,
  @as("PancakeFactory_PairCreated") pancakeFactory_PairCreated: entityHandlerContext<Entities.PancakeFactory_PairCreated.t>,
  @as("PancakePair_Swap") pancakePair_Swap: entityHandlerContext<Entities.PancakePair_Swap.t>,
  @as("PancakePair_Sync") pancakePair_Sync: entityHandlerContext<Entities.PancakePair_Sync.t>,
  @as("Token") token: entityHandlerContext<Entities.Token.t>,
}

//Re-exporting types for backwards compatability
@genType.as("Pair")
type pair = Entities.Pair.t
@genType.as("PancakeFactory")
type pancakeFactory = Entities.PancakeFactory.t
@genType.as("PancakeFactory_PairCreated")
type pancakeFactory_PairCreated = Entities.PancakeFactory_PairCreated.t
@genType.as("PancakePair_Swap")
type pancakePair_Swap = Entities.PancakePair_Swap.t
@genType.as("PancakePair_Sync")
type pancakePair_Sync = Entities.PancakePair_Sync.t
@genType.as("Token")
type token = Entities.Token.t

type eventIdentifier = {
  chainId: int,
  blockTimestamp: int,
  blockNumber: int,
  logIndex: int,
}

type entityUpdateAction<'entityType> =
  | Set('entityType)
  | Delete

type entityUpdate<'entityType> = {
  eventIdentifier: eventIdentifier,
  shouldSaveHistory: bool,
  entityId: id,
  entityUpdateAction: entityUpdateAction<'entityType>,
}

let mkEntityUpdate = (~shouldSaveHistory=true, ~eventIdentifier, ~entityId, entityUpdateAction) => {
  entityId,
  shouldSaveHistory,
  eventIdentifier,
  entityUpdateAction,
}

type entityValueAtStartOfBatch<'entityType> =
  | NotSet // The entity isn't in the DB yet
  | AlreadySet('entityType)

type existingValueInDb<'entityType> =
  | Retrieved(entityValueAtStartOfBatch<'entityType>)
  // NOTE: We use an postgres function solve the issue of this entities previous value not being known.
  | Unknown

type updatedValue<'entityType> = {
  // Initial value within a batch
  initial: existingValueInDb<'entityType>,
  latest: entityUpdate<'entityType>,
  history: array<entityUpdate<'entityType>>,
}
@genType
type inMemoryStoreRowEntity<'entityType> =
  | Updated(updatedValue<'entityType>)
  | InitialReadFromDb(entityValueAtStartOfBatch<'entityType>) // This means there is no change from the db.

//*************
//**CONTRACTS**
//*************

module Log = {
  type t = {
    address: Address.t,
    data: string,
    topics: array<Ethers.EventFilter.topic>,
    logIndex: int,
  }

  let fieldNames = ["address", "data", "topics", "logIndex"]
}

module Transaction = {
  @genType
  type t = {
  }

  let schema: S.schema<t> = S.object((_s): t => {
  })

  let querySelection: array<HyperSyncClient.QueryTypes.transactionField> = [
  ]

  let nonOptionalFieldNames: array<string> = [
  ]
}

module Block = {
  type selectableFields = {
  }

  let schema: S.schema<selectableFields> = S.object((_s): selectableFields => {
  })

  @genType
  type t = {
    number: int,
    timestamp: int,
    hash: string,
    ...selectableFields,
  }

  let getSelectableFields = ({
    }: t): selectableFields => {
    }

  let querySelection: array<HyperSyncClient.QueryTypes.blockField> = [
    Number,
    Timestamp,
    Hash,
  ]

  let nonOptionalFieldNames: array<string> = [
    "number",
    "timestamp",
    "hash",
  ]
}

@genType.as("EventLog")
type eventLog<'a> = {
  params: 'a,
  chainId: int,
  srcAddress: Address.t,
  logIndex: int,
  transaction: Transaction.t,
  block: Block.t,
}

module HandlerTypes = {
  @genType
  type args<'eventArgs, 'context> = {
    event: eventLog<'eventArgs>,
    context: 'context,
  }

  @genType
  type contractRegisterArgs<'eventArgs> = args<'eventArgs, contractRegistrations>
  @genType
  type contractRegister<'eventArgs> = contractRegisterArgs<'eventArgs> => unit

  @genType
  type loaderArgs<'eventArgs> = args<'eventArgs, loaderContext>
  @genType
  type loader<'eventArgs, 'loaderReturn> = loaderArgs<'eventArgs> => promise<'loaderReturn>

  @genType
  type handlerArgs<'eventArgs, 'loaderReturn> = {
    event: eventLog<'eventArgs>,
    context: handlerContext,
    loaderReturn: 'loaderReturn,
  }

  @genType
  type handler<'eventArgs, 'loaderReturn> = handlerArgs<'eventArgs, 'loaderReturn> => promise<unit>

  @genType
  type loaderHandler<'eventArgs, 'loaderReturn> = {
    loader: loader<'eventArgs, 'loaderReturn>,
    handler: handler<'eventArgs, 'loaderReturn>,
  }

  type eventOptions = {
    wildcard: bool,
    topicSelections: array<LogSelection.topicSelection>,
  }

  let getDefaultEventOptions = (~topic0) => {
    wildcard: false,
    topicSelections: [LogSelection.makeTopicSelection(~topic0=[topic0])->Utils.unwrapResultExn],
  }

  type registeredEvent<'eventArgs, 'loaderReturn> = {
    loaderHandler?: loaderHandler<'eventArgs, 'loaderReturn>,
    contractRegister?: contractRegister<'eventArgs>,
    eventOptions: eventOptions,
  }

  module Register: {
    type t<'eventArgs>
    let make: (~topic0: string, ~contractName: string, ~eventName: string) => t<'eventArgs>
    let setLoaderHandler: (
      t<'eventArgs>,
      loaderHandler<'eventArgs, 'loaderReturn>,
      ~eventOptions: option<eventOptions>,
      ~logger: Pino.t=?,
    ) => unit
    let setContractRegister: (
      t<'eventArgs>,
      contractRegister<'eventArgs>,
      ~eventOptions: option<eventOptions>,
      ~logger: Pino.t=?,
    ) => unit
    let getLoaderHandler: t<'eventArgs> => option<loaderHandler<'eventArgs, 'loaderReturn>>
    let getContractRegister: t<'eventArgs> => option<contractRegister<'eventArgs>>
    let getEventOptions: t<'eventArgs> => eventOptions
    let hasRegistration: t<'eventArgs> => bool
  } = {
    type loaderReturn

    type t<'eventArgs> = {
      contractName: string,
      eventName: string,
      topic0: string,
      mutable loaderHandler: option<loaderHandler<'eventArgs, loaderReturn>>,
      mutable contractRegister: option<contractRegister<'eventArgs>>,
      mutable eventOptions: option<eventOptions>,
    }

    let getLoaderHandler = (t: t<'eventArgs>): option<loaderHandler<'eventArgs, 'loaderReturn>> =>
      t.loaderHandler->(
        Utils.magic: option<loaderHandler<'eventArgs, loaderReturn>> => option<
          loaderHandler<'eventArgs, 'loaderReturn>,
        >
      )

    let getContractRegister = (t: t<'eventArgs>): option<contractRegister<'eventArgs>> =>
      t.contractRegister

    let getEventOptions = ({eventOptions, topic0}: t<'eventArgs>): eventOptions =>
      switch eventOptions {
      | Some(eventOptions) => eventOptions
      | None => getDefaultEventOptions(~topic0)
      }

    let hasRegistration = ({loaderHandler, contractRegister}) =>
      loaderHandler->Belt.Option.isSome || contractRegister->Belt.Option.isSome

    let make = (~topic0, ~contractName, ~eventName) => {
      contractName,
      eventName,
      topic0,
      loaderHandler: None,
      contractRegister: None,
      eventOptions: None,
    }

    type eventNamespace = {contractName: string, eventName: string}
    exception DuplicateEventRegistration(eventNamespace)

    let setEventOptions = (t: t<'eventArgs>, value: eventOptions, ~logger=Logging.logger) => {
      switch t.eventOptions {
      | None => t.eventOptions = Some(value)
      | Some(_) =>
        let eventNamespace = {contractName: t.contractName, eventName: t.eventName}
        DuplicateEventRegistration(eventNamespace)->ErrorHandling.mkLogAndRaise(
          ~logger=Logging.createChildFrom(~logger, ~params=eventNamespace),
          ~msg="Duplicate eventOptions in handlers not allowed",
        )
      }
    }

    let setLoaderHandler = (
      t: t<'eventArgs>,
      value: loaderHandler<'eventArgs, 'loaderReturn>,
      ~eventOptions,
      ~logger=Logging.logger,
    ) => {
      switch t.loaderHandler {
      | None =>
        t.loaderHandler =
          value
          ->(Utils.magic: loaderHandler<'eventArgs, 'loaderReturn> => loaderHandler<
            'eventArgs,
            loaderReturn,
          >)
          ->Some
      | Some(_) =>
        let eventNamespace = {contractName: t.contractName, eventName: t.eventName}
        DuplicateEventRegistration(eventNamespace)->ErrorHandling.mkLogAndRaise(
          ~logger=Logging.createChildFrom(~logger, ~params=eventNamespace),
          ~msg="Duplicate registration of event handlers not allowed",
        )
      }

      switch eventOptions {
      | Some(eventOptions) => t->setEventOptions(eventOptions, ~logger)
      | None => ()
      }
    }

    let setContractRegister = (
      t: t<'eventArgs>,
      value: contractRegister<'eventArgs>,
      ~eventOptions,
      ~logger=Logging.logger,
    ) => {
      switch t.contractRegister {
      | None => t.contractRegister = Some(value)
      | Some(_) =>
        let eventNamespace = {contractName: t.contractName, eventName: t.eventName}
        DuplicateEventRegistration(eventNamespace)->ErrorHandling.mkLogAndRaise(
          ~logger=Logging.createChildFrom(~logger, ~params=eventNamespace),
          ~msg="Duplicate contractRegister handlers not allowed",
        )
      }
      switch eventOptions {
      | Some(eventOptions) => t->setEventOptions(eventOptions, ~logger)
      | None => ()
      }
    }
  }
}

type internalEventArgs

module type Event = {
  let sighash: string // topic0 for Evm and rb for Fuel receipts
  let name: string
  let contractName: string
  let chains: array<ChainMap.Chain.t>

  type eventArgs
  let eventArgsSchema: S.schema<eventArgs>
  let convertHyperSyncEventArgs: HyperSyncClient.Decoder.decodedEvent => eventArgs
  let decodeHyperFuelData: string => eventArgs
  let handlerRegister: HandlerTypes.Register.t<eventArgs>
}
module type InternalEvent = Event with type eventArgs = internalEventArgs

external eventToInternal: eventLog<'a> => eventLog<internalEventArgs> = "%identity"
external eventModToInternal: module(Event with type eventArgs = 'a) => module(InternalEvent) = "%identity"
external eventModWithoutArgTypeToInternal: module(Event) => module(InternalEvent) = "%identity"

module MakeRegister = (Event: Event) => {
  let handler = handler =>
    Event.handlerRegister->HandlerTypes.Register.setLoaderHandler(
      {
        loader: _ => Promise.resolve(),
        handler,
      },
      ~eventOptions=None,
    )

  let contractRegister: HandlerTypes.contractRegister<Event.eventArgs> => unit = contractRegister =>
    Event.handlerRegister->HandlerTypes.Register.setContractRegister(
      contractRegister,
      ~eventOptions=None,
    )

  let handlerWithLoader: HandlerTypes.loaderHandler<Event.eventArgs, 'loaderReturn> => unit = args =>
    Event.handlerRegister->HandlerTypes.Register.setLoaderHandler(args, ~eventOptions=None)
}

module PancakeFactory = {
let abi = Ethers.makeAbi((%raw(`[{"type":"event","name":"PairCreated","inputs":[{"name":"token0","type":"address","indexed":true},{"name":"token1","type":"address","indexed":true},{"name":"pair","type":"address","indexed":false},{"name":"","type":"uint256","indexed":false}],"anonymous":false}]`): Js.Json.t))
let eventSignatures = ["PairCreated(address indexed token0, address indexed token1, address pair, uint256 )"]
  let contractName = "PancakeFactory"
  let chains = [
  56,
  ]->Belt.Array.map(chainId => ChainMap.Chain.makeUnsafe(~chainId))
  module PairCreated = {
    let sighash = "0x0d3648bd0f6ba80134a33ba9275ac585d9d315f0ad8355cddefde31afa28d0e9"
    let name = "PairCreated"
    let contractName = contractName
    let chains = chains

    @genType
    type eventArgs = {token0: Address.t, token1: Address.t, pair: Address.t, _3: bigint}
    let eventArgsSchema = S.object(s => {token0: s.field("token0", Address.schema), token1: s.field("token1", Address.schema), pair: s.field("pair", Address.schema), _3: s.field("_3", BigInt.schema)})
    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        token0: decodedEvent.indexed->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        token1: decodedEvent.indexed->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        pair: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        _3: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
    let decodeHyperFuelData = (_) => Js.Exn.raiseError("HyperFuel decoder not implemented")

    let handlerRegister: HandlerTypes.Register.t<eventArgs> = HandlerTypes.Register.make(
      ~topic0=sighash,
      ~contractName,
      ~eventName=name,
    )

  }
}

module PancakePair = {
let abi = Ethers.makeAbi((%raw(`[{"type":"event","name":"Swap","inputs":[{"name":"sender","type":"address","indexed":true},{"name":"amount0In","type":"uint256","indexed":false},{"name":"amount1In","type":"uint256","indexed":false},{"name":"amount0Out","type":"uint256","indexed":false},{"name":"amount1Out","type":"uint256","indexed":false},{"name":"to","type":"address","indexed":true}],"anonymous":false},{"type":"event","name":"Sync","inputs":[{"name":"reserve0","type":"uint112","indexed":false},{"name":"reserve1","type":"uint112","indexed":false}],"anonymous":false}]`): Js.Json.t))
let eventSignatures = ["Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out, address indexed to)", "Sync(uint112 reserve0, uint112 reserve1)"]
  let contractName = "PancakePair"
  let chains = [
  56,
  ]->Belt.Array.map(chainId => ChainMap.Chain.makeUnsafe(~chainId))
  module Swap = {
    let sighash = "0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822"
    let name = "Swap"
    let contractName = contractName
    let chains = chains

    @genType
    type eventArgs = {sender: Address.t, amount0In: bigint, amount1In: bigint, amount0Out: bigint, amount1Out: bigint, to: Address.t}
    let eventArgsSchema = S.object(s => {sender: s.field("sender", Address.schema), amount0In: s.field("amount0In", BigInt.schema), amount1In: s.field("amount1In", BigInt.schema), amount0Out: s.field("amount0Out", BigInt.schema), amount1Out: s.field("amount1Out", BigInt.schema), to: s.field("to", Address.schema)})
    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        sender: decodedEvent.indexed->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        to: decodedEvent.indexed->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        amount0In: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        amount1In: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        amount0Out: decodedEvent.body->Js.Array2.unsafe_get(2)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        amount1Out: decodedEvent.body->Js.Array2.unsafe_get(3)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
    let decodeHyperFuelData = (_) => Js.Exn.raiseError("HyperFuel decoder not implemented")

    let handlerRegister: HandlerTypes.Register.t<eventArgs> = HandlerTypes.Register.make(
      ~topic0=sighash,
      ~contractName,
      ~eventName=name,
    )

  }
  module Sync = {
    let sighash = "0x1c411e9a96e071241c2f21f7726b17ae89e3cab4c78be50e062b03a9fffbbad1"
    let name = "Sync"
    let contractName = contractName
    let chains = chains

    @genType
    type eventArgs = {reserve0: bigint, reserve1: bigint}
    let eventArgsSchema = S.object(s => {reserve0: s.field("reserve0", BigInt.schema), reserve1: s.field("reserve1", BigInt.schema)})
    let convertHyperSyncEventArgs = (decodedEvent: HyperSyncClient.Decoder.decodedEvent): eventArgs => {
      {
        reserve0: decodedEvent.body->Js.Array2.unsafe_get(0)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
        reserve1: decodedEvent.body->Js.Array2.unsafe_get(1)->HyperSyncClient.Decoder.toUnderlying->Utils.magic,
      }
    }
    let decodeHyperFuelData = (_) => Js.Exn.raiseError("HyperFuel decoder not implemented")

    let handlerRegister: HandlerTypes.Register.t<eventArgs> = HandlerTypes.Register.make(
      ~topic0=sighash,
      ~contractName,
      ~eventName=name,
    )

  }
}

@genType
type chainId = int

type eventBatchQueueItem = {
  timestamp: int,
  chain: ChainMap.Chain.t,
  blockNumber: int,
  logIndex: int,
  event: eventLog<internalEventArgs>,
  eventMod: module(InternalEvent),
  //Default to false, if an event needs to
  //be reprocessed after it has loaded dynamic contracts
  //This gets set to true and does not try and reload events
  hasRegisteredDynamicContracts?: bool,
}
