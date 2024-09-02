// Graphql Enum Type Variants
type enumType<'a> = {
  name: string,
  variants: array<'a>,
}

let mkEnum = (~name, ~variants) => {
  name,
  variants,
}

module type Enum = {
  type t
  let enum: enumType<t>
}

module ContractType = {
  @genType
  type t = 
    | @as("PancakeFactory") PancakeFactory
    | @as("PancakePair") PancakePair

  let schema = 
    S.union([
      S.literal(PancakeFactory), 
      S.literal(PancakePair), 
    ])

  let name = "CONTRACT_TYPE"
  let variants = [
    PancakeFactory,
    PancakePair,
  ]
  let enum = mkEnum(~name, ~variants)
}

module EntityType = {
  @genType
  type t = 
    | @as("Pair") Pair
    | @as("PancakeFactory") PancakeFactory
    | @as("PancakeFactory_PairCreated") PancakeFactory_PairCreated
    | @as("PancakePair_Swap") PancakePair_Swap
    | @as("PancakePair_Sync") PancakePair_Sync
    | @as("Token") Token

  let schema = S.union([
    S.literal(Pair), 
    S.literal(PancakeFactory), 
    S.literal(PancakeFactory_PairCreated), 
    S.literal(PancakePair_Swap), 
    S.literal(PancakePair_Sync), 
    S.literal(Token), 
  ])

  let name = "ENTITY_TYPE"
  let variants = [
    Pair,
    PancakeFactory,
    PancakeFactory_PairCreated,
    PancakePair_Swap,
    PancakePair_Sync,
    Token,
  ]

  let enum = mkEnum(~name, ~variants)
}


let allEnums: array<module(Enum)> = [
  module(ContractType), 
  module(EntityType),
]
