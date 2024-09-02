open Types

/**
The context holds all the state for a given events loader and handler.
*/
type t<'eventArgs> = {
  logger: Pino.t,
  chain: ChainMap.Chain.t,
  addedDynamicContractRegistrations: array<TablesStatic.DynamicContractRegistry.t>,
  event: Types.eventLog<'eventArgs>,
}

let getUserLogger = (logger): Logs.userLogger => {
  info: (message: string) => logger->Logging.uinfo(message),
  debug: (message: string) => logger->Logging.udebug(message),
  warn: (message: string) => logger->Logging.uwarn(message),
  error: (message: string) => logger->Logging.uerror(message),
  errorWithExn: (exn: option<Js.Exn.t>, message: string) =>
    logger->Logging.uerrorWithExn(exn, message),
}

let makeEventIdentifier = (event: Types.eventLog<'a>): Types.eventIdentifier => {
  chainId: event.chainId,
  blockTimestamp: event.block.timestamp,
  blockNumber: event.block.number,
  logIndex: event.logIndex,
}

let getEventId = (event: Types.eventLog<'a>) => {
  EventUtils.packEventIndex(~blockNumber=event.block.number, ~logIndex=event.logIndex)
}

let make = (~chain, ~event: Types.eventLog<'eventArgs>, ~eventMod: module(Types.InternalEvent), ~logger) => {
  let {block, logIndex} = event
  let module(Event) = eventMod
  let logger = logger->(
    Logging.createChildFrom(
      ~logger=_,
      ~params={
        "context": `Event '${Event.name}' for contract '${Event.contractName}'`,
        "chainId": chain->ChainMap.Chain.toChainId,
        "block": block.number,
        "logIndex": logIndex,
      },
    )
  )

  {
    event,
    logger,
    chain,
    addedDynamicContractRegistrations: [],
  }
}

let getAddedDynamicContractRegistrations = (contextEnv: t<'eventArgs>) =>
  contextEnv.addedDynamicContractRegistrations

let makeDynamicContractRegisterFn = (~contextEnv: t<'eventArgs>, ~contractName, ~inMemoryStore) => (
  contractAddress: Address.t,
) => {
  // Even though it's the Address.t on ReScript side, for TS side it's a string.
  // So we need to ensure that it's a valid checksummed address.
  let contractAddress = contractAddress->Address.Evm.fromAddressOrThrow

  let {event, chain, addedDynamicContractRegistrations} = contextEnv

  let eventId = event->getEventId
  let chainId = chain->ChainMap.Chain.toChainId
  let dynamicContractRegistration: TablesStatic.DynamicContractRegistry.t = {
    chainId,
    eventId,
    blockTimestamp: event.block.timestamp,
    contractAddress,
    contractType: contractName,
  }

  addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

  inMemoryStore.InMemoryStore.dynamicContractRegistry->InMemoryTable.set(
    {chainId, contractAddress},
    dynamicContractRegistration,
  )
}

let makeWhereLoader = (loadLayer, ~entityMod, ~inMemoryStore, ~fieldName, ~fieldValueSchema, ~logger) => {
  Entities.eq: loadLayer->LoadLayer.makeWhereEqLoader(~entityMod, ~fieldName, ~fieldValueSchema, ~inMemoryStore, ~logger)
}

let makeEntityHandlerContext = (
  type entity,
  ~eventIdentifier,
  ~inMemoryStore,
  ~entityMod: module(Entities.Entity with type t = entity),
  ~logger,
  ~getKey,
  ~loadLayer,
): entityHandlerContext<entity> => {
  let inMemTable = inMemoryStore->InMemoryStore.getInMemTable(~entityMod)
  let shouldRollbackOnReorg = RegisterHandlers.getConfig()->Config.shouldRollbackOnReorg
  {
    set: entity => {
      inMemTable->InMemoryTable.Entity.set(
        Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId=getKey(entity)),
        ~shouldRollbackOnReorg,
      )
    },
    deleteUnsafe: entityId => {
      inMemTable->InMemoryTable.Entity.set(
        Delete->Types.mkEntityUpdate(~eventIdentifier, ~entityId),
        ~shouldRollbackOnReorg,
      )
    },
    get: loadLayer->LoadLayer.makeLoader(~entityMod, ~logger, ~inMemoryStore),
  }
}

let getContractRegisterContext = (contextEnv, ~inMemoryStore) => {
  //TODO only add contracts we've registered for the event in the config
  addPancakeFactory:  makeDynamicContractRegisterFn(~contextEnv, ~inMemoryStore, ~contractName=PancakeFactory),
  addPancakePair:  makeDynamicContractRegisterFn(~contextEnv, ~inMemoryStore, ~contractName=PancakePair),
}

let getLoaderContext = (contextEnv: t<'eventArgs>, ~inMemoryStore: InMemoryStore.t, ~loadLayer: LoadLayer.t): loaderContext => {
  let {logger} = contextEnv
  {
    log: logger->getUserLogger,
    pair: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Pair),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
        factory_id: loadLayer->makeWhereLoader(
          ~entityMod=module(Entities.Pair),
          ~inMemoryStore,
          ~fieldName="factory_id",
          ~fieldValueSchema=S.string,
          ~logger,
        ),
      
        token0_id: loadLayer->makeWhereLoader(
          ~entityMod=module(Entities.Pair),
          ~inMemoryStore,
          ~fieldName="token0_id",
          ~fieldValueSchema=S.string,
          ~logger,
        ),
      
      },
    },
    pancakeFactory: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.PancakeFactory),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    pancakeFactory_PairCreated: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.PancakeFactory_PairCreated),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    pancakePair_Swap: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.PancakePair_Swap),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
        pair_id: loadLayer->makeWhereLoader(
          ~entityMod=module(Entities.PancakePair_Swap),
          ~inMemoryStore,
          ~fieldName="pair_id",
          ~fieldValueSchema=S.string,
          ~logger,
        ),
      
      },
    },
    pancakePair_Sync: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.PancakePair_Sync),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
    token: {
      get: loadLayer->LoadLayer.makeLoader(
        ~entityMod=module(Entities.Token),
        ~inMemoryStore,
        ~logger,
      ),
      getWhere: {
        
      },
    },
  }
}

let getHandlerContext = (context, ~inMemoryStore: InMemoryStore.t, ~loadLayer) => {
  let {event, logger} = context

  let eventIdentifier = event->makeEventIdentifier
  {
    log: logger->getUserLogger,
    pair: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Pair),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    pancakeFactory: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.PancakeFactory),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    pancakeFactory_PairCreated: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.PancakeFactory_PairCreated),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    pancakePair_Swap: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.PancakePair_Swap),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    pancakePair_Sync: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.PancakePair_Sync),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
    token: makeEntityHandlerContext(
      ~eventIdentifier,
      ~inMemoryStore,
      ~entityMod=module(Entities.Token),
      ~getKey=entity => entity.id,
      ~logger,
      ~loadLayer,
    ),
  }
}

let getContractRegisterArgs = (contextEnv, ~inMemoryStore) => {
  Types.HandlerTypes.event: contextEnv.event,
  context: contextEnv->getContractRegisterContext(~inMemoryStore),
}

let getLoaderArgs = (contextEnv, ~inMemoryStore, ~loadLayer) => {
  Types.HandlerTypes.event: contextEnv.event,
  context: contextEnv->getLoaderContext(~inMemoryStore, ~loadLayer),
}

let getHandlerArgs = (contextEnv, ~inMemoryStore, ~loaderReturn, ~loadLayer) => {
  Types.HandlerTypes.event: contextEnv.event,
  context: contextEnv->getHandlerContext(~inMemoryStore, ~loadLayer),
  loaderReturn,
}
