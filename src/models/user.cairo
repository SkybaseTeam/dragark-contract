use alexandria_storage::list::{List, ListTrait};
use starknet::ContractAddress;
use dragark::models::position::Position;
use core::{array::{SpanTrait, ArrayTrait}, integer::{u256_try_as_non_zero, U256DivRem},};

#[derive(Model, Drop, Serde, PartialEq)]
struct User {
    #[key]
    player: ContractAddress,
    area_opened: u32,
    num_islands_owned: u32,
    num_dragons_owned: u32
}
