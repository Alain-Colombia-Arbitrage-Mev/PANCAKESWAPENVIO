@val external require: string => unit = "require"

let registerContractHandlers = (
  ~contractName,
  ~handlerPathRelativeToRoot,
  ~handlerPathRelativeToConfig,
) => {
  try {
    require("root/" ++ handlerPathRelativeToRoot)
  } catch {
  | exn =>
    let params = {
      "Contract Name": contractName,
      "Expected Handler Path": handlerPathRelativeToConfig,
      "Code": "EE500",
    }
    let logger = Logging.createChild(~params)

    let errHandler = exn->ErrorHandling.make(~msg="Failed to import handler file", ~logger)
    errHandler->ErrorHandling.log
    errHandler->ErrorHandling.raiseExn
  }
}

%%private(
  let makeGeneratedConfig = () => {
    let chains = [
      {
        let contracts = [
          {
            Config.name: "PancakeFactory",
            abi: Types.PancakeFactory.abi,
            addresses: [
              "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73"->Address.Evm.fromStringOrThrow
,
            ],
            events: [
              module(Types.PancakeFactory.PairCreated),
            ],
            sighashes: [
              Types.PancakeFactory.PairCreated.sighash,
            ],
          },
          {
            Config.name: "PancakePair",
            abi: Types.PancakePair.abi,
            addresses: [
            ],
            events: [
              module(Types.PancakePair.Swap),
              module(Types.PancakePair.Sync),
            ],
            sighashes: [
              Types.PancakePair.Swap.sighash,
              Types.PancakePair.Sync.sighash,
            ],
          },
        ]
        let chain = ChainMap.Chain.makeUnsafe(~chainId=56)
        {
          Config.confirmedBlockThreshold: 200,
          syncSource: 
            HyperSync({endpointUrl: "https://56.hypersync.xyz"})
,
          startBlock: 0,
          endBlock:  None ,
          chain,
          contracts,
          chainWorker:
            module(HyperSyncWorker.Make({
              let chain = chain
              let contracts = contracts
              let endpointUrl = "https://56.hypersync.xyz"
              let allEventSignatures = [
                Types.PancakeFactory.eventSignatures,
                Types.PancakePair.eventSignatures,
              ]->Belt.Array.concatMany
              let eventModLookup =
                contracts
                ->Belt.Array.flatMap(contract => contract.events)
                ->EventModLookup.fromArrayOrThrow(~chain)
              /*
                Determines whether to use HypersyncClient Decoder or Viem for parsing events
                Default is hypersync client decoder, configurable in config with:
                ```yaml
                event_decoder: "viem" || "hypersync-client"
                ```
              */
              let shouldUseHypersyncClientDecoder = Env.Configurable.shouldUseHypersyncClientDecoder->Belt.Option.getWithDefault(
                true,
              )
            }))
        }
      },
    ]

    Config.make(
      ~shouldRollbackOnReorg=true,
      ~shouldSaveFullHistory=false,
      ~isUnorderedMultichainMode=false,
      ~chains,
      ~enableRawEvents=false,
      ~entities=[
        module(Entities.Pair),
        module(Entities.PancakeFactory),
        module(Entities.PancakeFactory_PairCreated),
        module(Entities.PancakePair_Swap),
        module(Entities.PancakePair_Sync),
        module(Entities.Token),
      ],
    )
  }

  let config: ref<option<Config.t>> = ref(None)
)

let registerAllHandlers = () => {
  registerContractHandlers(
    ~contractName="PancakeFactory",
    ~handlerPathRelativeToRoot="src/EventHandlers.js",
    ~handlerPathRelativeToConfig="src/EventHandlers.js",
  )
  registerContractHandlers(
    ~contractName="PancakePair",
    ~handlerPathRelativeToRoot="src/EventHandlers.js",
    ~handlerPathRelativeToConfig="src/EventHandlers.js",
  )

  let generatedConfig = makeGeneratedConfig()
  config := Some(generatedConfig)
  generatedConfig
}

let getConfig = () => {
  switch config.contents {
  | Some(config) => config
  | None => registerAllHandlers()
  }
}
