use alexandria_storage::list::{List, ListTrait};
use starknet::ContractAddress;
use dragark::models::position::Position;
use core::{array::{SpanTrait, ArrayTrait}, integer::{u256_try_as_non_zero, U256DivRem},};

#[derive(Model, Drop, Serde, PartialEq)]
struct UserIslandOwned {
    #[key]
    player: ContractAddress,
    #[key]
    islands_owned_id: u32,
    islands_owned: usize,
}
