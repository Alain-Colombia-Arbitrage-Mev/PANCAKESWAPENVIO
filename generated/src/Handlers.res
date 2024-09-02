  @genType
module PancakeFactory = {
  module PairCreated = Types.MakeRegister(Types.PancakeFactory.PairCreated)
}

  @genType
module PancakePair = {
  module Swap = Types.MakeRegister(Types.PancakePair.Swap)
  module Sync = Types.MakeRegister(Types.PancakePair.Sync)
}

