use starknet::ContractAddress;

#[derive(Model, Drop, Serde, PartialEq)]
struct User {
    #[key]
    game_id: usize,
    #[key]
    player: ContractAddress,
    is_joined_game: u8,
    area_opened: u32,
    energy: u32,
    num_islands_owned: u32,
    num_dragons_owned: u32
}
