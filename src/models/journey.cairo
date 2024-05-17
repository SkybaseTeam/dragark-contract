use dragark_20::models::island::Resource;
use starknet::ContractAddress;

#[derive(Model, Copy, Drop, Serde)]
struct Journey {
    #[key]
    game_id: usize,
    #[key]
    journey_id: felt252,
    owner: ContractAddress,
    dragon_id: usize,
    carrying_resources: Resource,
    island_from_id: usize,
    island_to_id: usize,
    start_time: u64,
    finish_time: u64,
    attack_type: AttackType,
    attack_result: AttackResult,
    status: bool
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum AttackType {
    Unknown,
    None,
    DerelictIslandAttack,
    UserIslandAttack
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum AttackResult {
    Unknown,
    None,
    Win,
    Lose
}
