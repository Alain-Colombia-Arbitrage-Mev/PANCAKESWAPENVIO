
@genType
type rawEventsKey = {
  chainId: int,
  eventId: string,
}

let hashRawEventsKey = (key: rawEventsKey) =>
  EventUtils.getEventIdKeyString(~chainId=key.chainId, ~eventId=key.eventId)

@genType
type dynamicContractRegistryKey = {
  chainId: int,
  contractAddress: Address.t,
}

let hashDynamicContractRegistryKey = ({chainId, contractAddress}) =>
  EventUtils.getContractAddressKeyString(~chainId, ~contractAddress)

type t = {
  eventSyncState: InMemoryTable.t<int, TablesStatic.EventSyncState.t>,
  rawEvents: InMemoryTable.t<rawEventsKey, TablesStatic.RawEvents.t>,
  dynamicContractRegistry: InMemoryTable.t<
    dynamicContractRegistryKey,
    TablesStatic.DynamicContractRegistry.t,
  >,
  @as("Pair") 
  pair: InMemoryTable.Entity.t<Entities.Pair.t>,
  @as("PancakeFactory") 
  pancakeFactory: InMemoryTable.Entity.t<Entities.PancakeFactory.t>,
  @as("PancakeFactory_PairCreated") 
  pancakeFactory_PairCreated: InMemoryTable.Entity.t<Entities.PancakeFactory_PairCreated.t>,
  @as("PancakePair_Swap") 
  pancakePair_Swap: InMemoryTable.Entity.t<Entities.PancakePair_Swap.t>,
  @as("PancakePair_Sync") 
  pancakePair_Sync: InMemoryTable.Entity.t<Entities.PancakePair_Sync.t>,
  @as("Token") 
  token: InMemoryTable.Entity.t<Entities.Token.t>,
  rollBackEventIdentifier: option<Types.eventIdentifier>,
}

let makeWithRollBackEventIdentifier = (rollBackEventIdentifier): t => {
  eventSyncState: InMemoryTable.make(~hash=v => v->Belt.Int.toString),
  rawEvents: InMemoryTable.make(~hash=hashRawEventsKey),
  dynamicContractRegistry: InMemoryTable.make(~hash=hashDynamicContractRegistryKey),
  pair: InMemoryTable.Entity.make(),
  pancakeFactory: InMemoryTable.Entity.make(),
  pancakeFactory_PairCreated: InMemoryTable.Entity.make(),
  pancakePair_Swap: InMemoryTable.Entity.make(),
  pancakePair_Sync: InMemoryTable.Entity.make(),
  token: InMemoryTable.Entity.make(),
  rollBackEventIdentifier,
}

let make = () => makeWithRollBackEventIdentifier(None)

let clone = (self: t) => {
  eventSyncState: self.eventSyncState->InMemoryTable.clone,
  rawEvents: self.rawEvents->InMemoryTable.clone,
  dynamicContractRegistry: self.dynamicContractRegistry->InMemoryTable.clone,
  pair: self.pair->InMemoryTable.Entity.clone,
  pancakeFactory: self.pancakeFactory->InMemoryTable.Entity.clone,
  pancakeFactory_PairCreated: self.pancakeFactory_PairCreated->InMemoryTable.Entity.clone,
  pancakePair_Swap: self.pancakePair_Swap->InMemoryTable.Entity.clone,
  pancakePair_Sync: self.pancakePair_Sync->InMemoryTable.Entity.clone,
  token: self.token->InMemoryTable.Entity.clone,
  rollBackEventIdentifier: self.rollBackEventIdentifier->InMemoryTable.structuredClone,
}


let getInMemTable = (
  type entity,
  inMemoryStore: t,
  ~entityMod: module(Entities.Entity with type t = entity),
): InMemoryTable.Entity.t<entity> => {
  let module(Entity) = entityMod->Entities.entityModToInternal
  inMemoryStore->Utils.magic->Js.Dict.unsafeGet(Entity.key)
}
