/***** TAKE NOTE ******
This is a hack to get genType to work!

In order for genType to produce recursive types, it needs to be at the 
root module of a file. If it's defined in a nested module it does not 
work. So all the MockDb types and internal functions are defined in TestHelpers_MockDb
and only public functions are recreated and exported from this module.

the following module:
```rescript
module MyModule = {
  @genType
  type rec a = {fieldB: b}
  @genType and b = {fieldA: a}
}
```

produces the following in ts:
```ts
// tslint:disable-next-line:interface-over-type-literal
export type MyModule_a = { readonly fieldB: b };

// tslint:disable-next-line:interface-over-type-literal
export type MyModule_b = { readonly fieldA: MyModule_a };
```

fieldB references type b which doesn't exist because it's defined
as MyModule_b
*/

module MockDb = {
  @genType
  let createMockDb = TestHelpers_MockDb.createMockDb
}

@genType
module Addresses = {
  include TestHelpers_MockAddresses
}

module EventFunctions = {
  //Note these are made into a record to make operate in the same way
  //for Res, JS and TS.

  /**
  The arguements that get passed to a "processEvent" helper function
  */
  @genType
  type eventProcessorArgs<'eventArgs> = {
    event: Types.eventLog<'eventArgs>,
    mockDb: TestHelpers_MockDb.t,
    chainId?: int,
  }

  /**
  A function composer to help create individual processEvent functions
  */
  let makeEventProcessor = (~eventMod: module(Types.Event with type eventArgs = 'eventArgs)) => {
    async args => {
      let eventMod = eventMod->Types.eventModToInternal
      let {event, mockDb, ?chainId} =
        args->(
          Utils.magic: eventProcessorArgs<'eventArgs> => eventProcessorArgs<Types.internalEventArgs>
        )
      let module(Event) = eventMod
      let config = RegisterHandlers.getConfig()

      // The user can specify a chainId of an event or leave it off
      // and it will default to the first chain in the config
      let chain = switch chainId {
      | Some(chainId) => config->Config.getChain(~chainId)
      | None =>
        switch config.defaultChain {
        | Some(chainConfig) => chainConfig.chain
        | None =>
          Js.Exn.raiseError(
            "No default chain Id found, please add at least 1 chain to your config.yaml",
          )
        }
      }

      //Create an individual logging context for traceability
      let logger = Logging.createChild(
        ~params={
          "Context": `Test Processor for "${Event.name}" event on contract "${Event.contractName}"`,
          "Chain ID": chain->ChainMap.Chain.toChainId,
          "event": event,
        },
      )

      //Deep copy the data in mockDb, mutate the clone and return the clone
      //So no side effects occur here and state can be compared between process
      //steps
      let mockDbClone = mockDb->TestHelpers_MockDb.cloneMockDb

      if !(Event.handlerRegister->Types.HandlerTypes.Register.hasRegistration) {
        Not_found->ErrorHandling.mkLogAndRaise(
          ~logger,
          ~msg=`No registered handler found for "${Event.name}" on contract "${Event.contractName}"`,
        )
      }
      //Construct a new instance of an in memory store to run for the given event
      let inMemoryStore = InMemoryStore.make()
      let loadLayer = LoadLayer.make(
        ~loadEntitiesByIds=TestHelpers_MockDb.makeLoadEntitiesByIds(mockDbClone),
        ~makeLoadEntitiesByField=(~entityMod) =>
          TestHelpers_MockDb.makeLoadEntitiesByField(mockDbClone, ~entityMod),
      )

      //No need to check contract is registered or return anything.
      //The only purpose is to test the registerContract function and to
      //add the entity to the in memory store for asserting registrations

      switch Event.handlerRegister->Types.HandlerTypes.Register.getContractRegister {
      | Some(contractRegister) =>
        switch contractRegister->EventProcessing.runEventContractRegister(
          ~logger,
          ~event,
          ~eventBatchQueueItem={
            event,
            eventMod,
            chain,
            logIndex: event.logIndex,
            timestamp: event.block.timestamp,
            blockNumber: event.block.number,
          },
          ~checkContractIsRegistered=(~chain as _, ~contractAddress as _, ~contractName as _) =>
            false,
          ~dynamicContractRegistrations=None,
          ~inMemoryStore,
        ) {
        | Ok(_) => ()
        | Error(e) => e->ErrorHandling.logAndRaise
        }
      | None => () //No need to run contract registration
      }

      let latestProcessedBlocks = EventProcessing.EventsProcessed.makeEmpty(~config)

      switch Event.handlerRegister->Types.HandlerTypes.Register.getLoaderHandler {
      | Some(loaderHandler) =>
        switch await event->EventProcessing.runEventHandler(
          ~inMemoryStore,
          ~loadLayer,
          ~loaderHandler,
          ~eventMod,
          ~chain,
          ~logger,
          ~latestProcessedBlocks,
          ~config,
        ) {
        | Ok(_) => ()
        | Error(e) => e->ErrorHandling.logAndRaise
        }
      | None => () //No need to run handler
      }

      //In mem store can still contatin raw events and dynamic contracts for the
      //testing framework in cases where either contract register or loaderHandler
      //is None
      mockDbClone->TestHelpers_MockDb.writeFromMemoryStore(~inMemoryStore)
      mockDbClone
    }
  }

  module MockBlock = {
    open Belt
    type t = {
      number?: int,
      timestamp?: int,
      hash?: string,
    }

    let toBlock = (mock: t): Types.Block.t => {
      number: mock.number->Option.getWithDefault(0),
      timestamp: mock.timestamp->Option.getWithDefault(0),
      hash: mock.hash->Option.getWithDefault("foo"),
    }
  }

  module MockTransaction = {
    type t = {
    }

    let toTransaction = (_mock: t): Types.Transaction.t => {
    }
  }

  @genType
  type mockEventData = {
    chainId?: int,
    srcAddress?: Address.t,
    logIndex?: int,
    block?: MockBlock.t,
    transaction?: MockTransaction.t,
  }

  /**
  Applies optional paramters with defaults for all common eventLog field
  */
  let makeEventMocker = (
    ~params: 'eventParams,
    ~mockEventData: option<mockEventData>,
  ): Types.eventLog<'eventParams> => {
    let {?block, ?transaction, ?srcAddress, ?chainId, ?logIndex} =
      mockEventData->Belt.Option.getWithDefault({})
    let block = block->Belt.Option.getWithDefault({})->MockBlock.toBlock
    let transaction = transaction->Belt.Option.getWithDefault({})->MockTransaction.toTransaction
    {
      params,
      transaction,
      chainId: chainId->Belt.Option.getWithDefault(1),
      block,
      srcAddress: srcAddress->Belt.Option.getWithDefault(Addresses.defaultAddress),
      logIndex: logIndex->Belt.Option.getWithDefault(0),
    }
  }
}


module PancakeFactory = {
  module PairCreated = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.PancakeFactory.PairCreated),
    )

    @genType
    type createMockArgs = {
      @as("token0")
      token0?: Address.t,
      @as("token1")
      token1?: Address.t,
      @as("pair")
      pair?: Address.t,
      @as("_3")
      _3?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?token0,
        ?token1,
        ?pair,
        ?_3,
        ?mockEventData,
      } = args

      let params: Types.PancakeFactory.PairCreated.eventArgs = 
      {
       token0: token0->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       token1: token1->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       pair: pair->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       _3: _3->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

}


module PancakePair = {
  module Swap = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.PancakePair.Swap),
    )

    @genType
    type createMockArgs = {
      @as("sender")
      sender?: Address.t,
      @as("amount0In")
      amount0In?: bigint,
      @as("amount1In")
      amount1In?: bigint,
      @as("amount0Out")
      amount0Out?: bigint,
      @as("amount1Out")
      amount1Out?: bigint,
      @as("to")
      to?: Address.t,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?sender,
        ?amount0In,
        ?amount1In,
        ?amount0Out,
        ?amount1Out,
        ?to,
        ?mockEventData,
      } = args

      let params: Types.PancakePair.Swap.eventArgs = 
      {
       sender: sender->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
       amount0In: amount0In->Belt.Option.getWithDefault(0n),
       amount1In: amount1In->Belt.Option.getWithDefault(0n),
       amount0Out: amount0Out->Belt.Option.getWithDefault(0n),
       amount1Out: amount1Out->Belt.Option.getWithDefault(0n),
       to: to->Belt.Option.getWithDefault(TestHelpers_MockAddresses.defaultAddress),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

  module Sync = {
    @genType
    let processEvent = EventFunctions.makeEventProcessor(
      ~eventMod=module(Types.PancakePair.Sync),
    )

    @genType
    type createMockArgs = {
      @as("reserve0")
      reserve0?: bigint,
      @as("reserve1")
      reserve1?: bigint,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?reserve0,
        ?reserve1,
        ?mockEventData,
      } = args

      let params: Types.PancakePair.Sync.eventArgs = 
      {
       reserve0: reserve0->Belt.Option.getWithDefault(0n),
       reserve1: reserve1->Belt.Option.getWithDefault(0n),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }

}

