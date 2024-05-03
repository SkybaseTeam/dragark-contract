use dragark::models::position::Position;
use starknet::ContractAddress;

#[derive(Model, Copy, Drop, Serde)]
struct DragonScoutTransport {
    #[key]
    transport_id: felt252,
    dragon: usize,
    owner: ContractAddress,
    island_from: usize,
    destination: Position,
    start_time: u64,
    end_time: u64,
    status: bool
}
