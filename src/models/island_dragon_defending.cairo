use starknet::ContractAddress;

#[derive(Model, Copy, Drop, Serde)]
struct IslandDragonDefending {
    #[key]
    island_id: usize, // Island's ID
    #[key]
    dragons_defending_id: u32,
    dragons_defending: usize,
}
