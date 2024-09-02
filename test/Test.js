
const assert = require("assert");
const { TestHelpers } = require("generated");
const { MockDb, PancakeFactory, Addresses } = TestHelpers;

const { GLOBAL_EVENTS_SUMMARY_KEY } = require("../src/EventHandlers");

const MOCK_EVENTS_SUMMARY_ENTITY = {
  id: GLOBAL_EVENTS_SUMMARY_KEY,
  pancakeFactory_PairCreatedCount: BigInt(0),
};

describe("PancakeFactory contract PairCreated event tests", () => {
  // Create mock db
  const mockDbInitial = MockDb.createMockDb();

  // Add mock EventsSummaryEntity to mock db
  const mockDbFinal = mockDbInitial.entities.EventsSummary.set(
    MOCK_EVENTS_SUMMARY_ENTITY
  );

  // Creating mock PancakeFactory contract PairCreated event
  const mockPancakeFactoryPairCreatedEvent = PancakeFactory.PairCreated.createMockEvent({
    token0: Addresses.defaultAddress,
    token1: Addresses.defaultAddress,
    pair: Addresses.defaultAddress,
    _3: 0n,
    mockEventData: {
      chainId: 1,
      blockNumber: 0,
      blockTimestamp: 0,
      blockHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
      srcAddress: Addresses.defaultAddress,
      transactionHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
      transactionIndex: 0,
      logIndex: 0,
    },
  });

  // Processing the event
  const mockDbUpdated = PancakeFactory.PairCreated.processEvent({
    event: mockPancakeFactoryPairCreatedEvent,
    mockDb: mockDbFinal,
  });

  it("PancakeFactory_PairCreatedEntity is created correctly", () => {
    // Getting the actual entity from the mock database
    let actualPancakeFactoryPairCreatedEntity = mockDbUpdated.entities.PancakeFactory_PairCreated.get(
      mockPancakeFactoryPairCreatedEvent.transactionHash +
        mockPancakeFactoryPairCreatedEvent.logIndex.toString()
    );

    // Creating the expected entity
    const expectedPancakeFactoryPairCreatedEntity = {
      id:
        mockPancakeFactoryPairCreatedEvent.transactionHash +
        mockPancakeFactoryPairCreatedEvent.logIndex.toString(),
      token0: mockPancakeFactoryPairCreatedEvent.params.token0,
      token1: mockPancakeFactoryPairCreatedEvent.params.token1,
      pair: mockPancakeFactoryPairCreatedEvent.params.pair,
      _3: mockPancakeFactoryPairCreatedEvent.params._3,
      eventsSummary: "GlobalEventsSummary",
    };
    // Asserting that the entity in the mock database is the same as the expected entity
    assert.deepEqual(
      actualPancakeFactoryPairCreatedEntity,
      expectedPancakeFactoryPairCreatedEntity,
      "Actual PancakeFactoryPairCreatedEntity should be the same as the expectedPancakeFactoryPairCreatedEntity"
    );
  });

  it("EventsSummaryEntity is updated correctly", () => {
    // Getting the actual entity from the mock database
    let actualEventsSummaryEntity = mockDbUpdated.entities.EventsSummary.get(
      GLOBAL_EVENTS_SUMMARY_KEY
    );

    // Creating the expected entity
    const expectedEventsSummaryEntity = {
      ...MOCK_EVENTS_SUMMARY_ENTITY,
      pancakeFactory_PairCreatedCount: MOCK_EVENTS_SUMMARY_ENTITY.pancakeFactory_PairCreatedCount + BigInt(1),
    };
    // Asserting that the entity in the mock database is the same as the expected entity
    assert.deepEqual(
      actualEventsSummaryEntity,
      expectedEventsSummaryEntity,
      "Actual EventsSummaryEntity should be the same as the expected EventsSummaryEntity"
    );
  });
});
