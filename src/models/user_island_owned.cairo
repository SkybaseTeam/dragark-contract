use starknet::ContractAddress;

#[derive(Model, Drop, Serde, PartialEq)]
struct UserIslandOwned {
    #[key]
    game_id: usize,
    #[key]
    player: ContractAddress,
    #[key]
    index: u32,
    island_id: usize,
}
