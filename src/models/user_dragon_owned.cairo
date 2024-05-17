use starknet::ContractAddress;

#[derive(Model, Drop, Serde, PartialEq)]
struct UserDragonOwned {
    #[key]
    game_id: usize,
    #[key]
    player: ContractAddress,
    #[key]
    index: u32,
    dragon_id: usize,
}
