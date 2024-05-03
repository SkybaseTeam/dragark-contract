use dragark::models::island::Resource;
use starknet::ContractAddress;

#[derive(Model, Copy, Drop, Serde)]
struct DragonIslandCaptureTransport {
    #[key]
    transport_id: felt252,
    dragon: usize,
    owner: ContractAddress,
    resources: Resource,
    resources_island: usize,
    island_capturing: usize,
    start_time: u64,
    end_time: u64,
    attack_type: AttackType,
    attack_result: AttackResult,
    status: bool
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum AttackType {
    DerelictIslandAttack,
    UserIslandAttack
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum AttackResult {
    Unknown,
    Win,
    Lose
}
