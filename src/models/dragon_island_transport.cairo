use dragark::models::island::Resource;
use starknet::ContractAddress;

#[derive(Model, Copy, Drop, Serde)]
struct DragonIslandTransport {
    #[key]
    transport_id: felt252,
    dragon: usize,
    owner: ContractAddress,
    resources: Resource,
    island_from: usize,
    island_to: usize,
    start_time: u64,
    end_time: u64,
    status: bool
}
