let executeSet = (
  sql: Postgres.sql,
  ~items: array<'a>,
  ~dbFunction: (Postgres.sql, array<'a>) => promise<unit>,
) => {
  if items->Array.length > 0 {
    sql->dbFunction(items)
  } else {
    Promise.resolve()
  }
}

let getEntityHistoryItems = (entityUpdates, ~entitySchema, ~entityType) => {
  let (_, entityHistoryItems) = entityUpdates->Belt.Array.reduce((None, []), (
    prev: (option<Types.eventIdentifier>, array<DbFunctions.entityHistoryItem>),
    entityUpdate: Types.entityUpdate<'a>,
  ) => {
    let (optPreviousEventIdentifier, entityHistoryItems) = prev

    let {eventIdentifier, shouldSaveHistory, entityUpdateAction, entityId} = entityUpdate
    let entityHistoryItems = if shouldSaveHistory {
      let mapPrev = Belt.Option.map(optPreviousEventIdentifier)
      let params = switch entityUpdateAction {
      | Set(entity) => Some(entity->S.serializeOrRaiseWith(entitySchema))

      | Delete => None
      }
      let historyItem: DbFunctions.entityHistoryItem = {
        chain_id: eventIdentifier.chainId,
        block_number: eventIdentifier.blockNumber,
        block_timestamp: eventIdentifier.blockTimestamp,
        log_index: eventIdentifier.logIndex,
        previous_chain_id: mapPrev(prev => prev.chainId),
        previous_block_timestamp: mapPrev(prev => prev.blockTimestamp),
        previous_block_number: mapPrev(prev => prev.blockNumber),
        previous_log_index: mapPrev(prev => prev.logIndex),
        entity_type: entityType,
        entity_id: entityId,
        params,
      }
      entityHistoryItems->Belt.Array.concat([historyItem])
    } else {
      entityHistoryItems
    }

    (Some(eventIdentifier), entityHistoryItems)
  })

  entityHistoryItems
}

let executeSetEntityWithHistory = (
  type entity,
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRowEntity<entity>>,
  ~entityMod: module(Entities.Entity with type t = entity),
): promise<unit> => {
  let module(EntityMod) = entityMod
  let {schema, table} = module(EntityMod)
  let (entitiesToSet, idsToDelete, entityHistoryItemsToSet) = rows->Belt.Array.reduce(
    ([], [], []),
    ((entitiesToSet, idsToDelete, entityHistoryItemsToSet), row) => {
      switch row {
      | Updated({latest, history}) =>
        let entityHistoryItems =
          history
          ->Belt.Array.concat([latest])
          ->getEntityHistoryItems(~entitySchema=schema, ~entityType=table.tableName)

        switch latest.entityUpdateAction {
        | Set(entity) => (
            entitiesToSet->Belt.Array.concat([entity]),
            idsToDelete,
            entityHistoryItemsToSet->Belt.Array.concat([entityHistoryItems]),
          )
        | Delete => (
            entitiesToSet,
            idsToDelete->Belt.Array.concat([latest.entityId]),
            entityHistoryItemsToSet->Belt.Array.concat([entityHistoryItems]),
          )
        }
      | _ => (entitiesToSet, idsToDelete, entityHistoryItemsToSet)
      }
    },
  )

  [
    sql->DbFunctions.EntityHistory.batchSet(
      ~entityHistoriesToSet=Belt.Array.concatMany(entityHistoryItemsToSet),
    ),
    if entitiesToSet->Array.length > 0 {
      sql->DbFunctionsEntities.batchSet(~entityMod)(entitiesToSet)
    } else {
      Promise.resolve()
    },
    if idsToDelete->Array.length > 0 {
      sql->DbFunctionsEntities.batchDelete(~entityMod)(idsToDelete)
    } else {
      Promise.resolve()
    },
  ]
  ->Promise.all
  ->Promise.thenResolve(_ => ())
}

let executeDbFunctionsEntity = (
  type entity,
  sql: Postgres.sql,
  ~rows: array<Types.inMemoryStoreRowEntity<entity>>,
  ~entityMod: module(Entities.Entity with type t = entity),
): promise<unit> => {
  let (entitiesToSet, idsToDelete) = rows->Belt.Array.reduce(([], []), (
    (accumulatedSets, accumulatedDeletes),
    row,
  ) =>
    switch row {
    | Updated({latest: {entityUpdateAction: Set(entity)}}) => (
        Belt.Array.concat(accumulatedSets, [entity]),
        accumulatedDeletes,
      )
    | Updated({latest: {entityUpdateAction: Delete, entityId}}) => (
        accumulatedSets,
        Belt.Array.concat(accumulatedDeletes, [entityId]),
      )
    | _ => (accumulatedSets, accumulatedDeletes)
    }
  )

  let promises =
    (
      entitiesToSet->Array.length > 0 ? [sql->DbFunctionsEntities.batchSet(~entityMod)(entitiesToSet)] : []
    )->Belt.Array.concat(
      idsToDelete->Array.length > 0 ? [sql->DbFunctionsEntities.batchDelete(~entityMod)(idsToDelete)] : [],
    )

  promises->Promise.all->Promise.thenResolve(_ => ())
}

let executeBatch = async (sql, ~inMemoryStore: InMemoryStore.t) => {
  let entityDbExecutionComposer =
    RegisterHandlers.getConfig()->Config.shouldRollbackOnReorg
      ? executeSetEntityWithHistory
      : executeDbFunctionsEntity

  let setEventSyncState = executeSet(
    _,
    ~dbFunction=DbFunctions.EventSyncState.batchSet,
    ~items=inMemoryStore.eventSyncState->InMemoryTable.values,
  )

  let setRawEvents = executeSet(
    _,
    ~dbFunction=DbFunctions.RawEvents.batchSet,
    ~items=inMemoryStore.rawEvents->InMemoryTable.values,
  )

  let setDynamicContracts = executeSet(
    _,
    ~dbFunction=DbFunctions.DynamicContractRegistry.batchSet,
    ~items=inMemoryStore.dynamicContractRegistry->InMemoryTable.values,
  )

  let setPairs = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.Pair),
    ~rows=inMemoryStore.pair->InMemoryTable.Entity.rows,
  )

  let setPancakeFactorys = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.PancakeFactory),
    ~rows=inMemoryStore.pancakeFactory->InMemoryTable.Entity.rows,
  )

  let setPancakeFactory_PairCreateds = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.PancakeFactory_PairCreated),
    ~rows=inMemoryStore.pancakeFactory_PairCreated->InMemoryTable.Entity.rows,
  )

  let setPancakePair_Swaps = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.PancakePair_Swap),
    ~rows=inMemoryStore.pancakePair_Swap->InMemoryTable.Entity.rows,
  )

  let setPancakePair_Syncs = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.PancakePair_Sync),
    ~rows=inMemoryStore.pancakePair_Sync->InMemoryTable.Entity.rows,
  )

  let setTokens = entityDbExecutionComposer(
    _,
    ~entityMod=module(Entities.Token),
    ~rows=inMemoryStore.token->InMemoryTable.Entity.rows,
  )

  //In the event of a rollback, rollback all meta tables based on the given
  //valid event identifier, where all rows created after this eventIdentifier should
  //be deleted
  let rollbackTables = switch inMemoryStore.rollBackEventIdentifier {
  | Some(eventIdentifier) =>
    [
      DbFunctions.EntityHistory.deleteAllEntityHistoryAfterEventIdentifier,
      DbFunctions.RawEvents.deleteAllRawEventsAfterEventIdentifier,
      DbFunctions.DynamicContractRegistry.deleteAllDynamicContractRegistrationsAfterEventIdentifier,
    ]->Belt.Array.map(fn => fn(_, ~eventIdentifier))
  | None => []
  }

  let res = await sql->Postgres.beginSql(sql => {
    Belt.Array.concat(
      //Rollback tables need to happen first in the traction
      rollbackTables,
      [
        setEventSyncState,
        setRawEvents,
        setDynamicContracts,
        setPairs,
        setPancakeFactorys,
        setPancakeFactory_PairCreateds,
        setPancakePair_Swaps,
        setPancakePair_Syncs,
        setTokens,
      ],
    )->Belt.Array.map(dbFunc => sql->dbFunc)
  })

  res
}

module RollBack = {
  exception DecodeError(S.error)
  let rollBack = async (~chainId, ~blockTimestamp, ~blockNumber, ~logIndex) => {
    let reorgData = switch await DbFunctions.sql->DbFunctions.EntityHistory.getRollbackDiff(
      ~chainId,
      ~blockTimestamp,
      ~blockNumber,
    ) {
    | Ok(v) => v
    | Error(exn) =>
      exn
      ->DecodeError
      ->ErrorHandling.mkLogAndRaise(~msg="Failed to get rollback diff from entity history")
    }

    let rollBackEventIdentifier: Types.eventIdentifier = {
      chainId,
      blockTimestamp,
      blockNumber,
      logIndex,
    }

    let inMemStore = InMemoryStore.makeWithRollBackEventIdentifier(Some(rollBackEventIdentifier))

    let shouldRollbackOnReorg = RegisterHandlers.getConfig()->Config.shouldRollbackOnReorg

    reorgData->Belt.Array.forEach(e => {
      switch e {
      //Where previousEntity is Some, 
      //set the value with the eventIdentifier that set that value initially
      | {previousEntity: Some({entity: Pair(entity), eventIdentifier}), entityId} =>
        inMemStore.pair->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: Some({entity: PancakeFactory(entity), eventIdentifier}), entityId} =>
        inMemStore.pancakeFactory->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: Some({entity: PancakeFactory_PairCreated(entity), eventIdentifier}), entityId} =>
        inMemStore.pancakeFactory_PairCreated->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: Some({entity: PancakePair_Swap(entity), eventIdentifier}), entityId} =>
        inMemStore.pancakePair_Swap->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: Some({entity: PancakePair_Sync(entity), eventIdentifier}), entityId} =>
        inMemStore.pancakePair_Sync->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: Some({entity: Token(entity), eventIdentifier}), entityId} =>
        inMemStore.token->InMemoryTable.Entity.set(
          Set(entity)->Types.mkEntityUpdate(~eventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      //Where previousEntity is None, 
      //delete it with the eventIdentifier of the rollback event
      | {previousEntity: None, entityType: Pair, entityId} =>
        inMemStore.pair->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: None, entityType: PancakeFactory, entityId} =>
        inMemStore.pancakeFactory->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: None, entityType: PancakeFactory_PairCreated, entityId} =>
        inMemStore.pancakeFactory_PairCreated->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: None, entityType: PancakePair_Swap, entityId} =>
        inMemStore.pancakePair_Swap->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: None, entityType: PancakePair_Sync, entityId} =>
        inMemStore.pancakePair_Sync->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      | {previousEntity: None, entityType: Token, entityId} =>
        inMemStore.token->InMemoryTable.Entity.set(
          Delete->Types.mkEntityUpdate(~eventIdentifier=rollBackEventIdentifier, ~entityId, ~shouldSaveHistory=false),
          ~shouldRollbackOnReorg,
        )
      }
    })

    inMemStore
  }
}
