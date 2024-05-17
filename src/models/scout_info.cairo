use dragark_20::models::position::Position;
use starknet::ContractAddress;

#[derive(Model, Copy, Drop, Serde)]
struct ScoutInfo {
    #[key]
    game_id: usize,
    #[key]
    scout_id: felt252,
    #[key]
    player: ContractAddress,
    destination: Position,
    time: u64
}
