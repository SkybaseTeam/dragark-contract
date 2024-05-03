use alexandria_storage::list::{List, ListTrait};
use starknet::ContractAddress;
use dragark::models::position::Position;
use core::{array::{SpanTrait, ArrayTrait}, integer::{u256_try_as_non_zero, U256DivRem},};

#[derive(Model, Drop, Serde, PartialEq)]
struct UserDragonOwned {
    #[key]
    player: ContractAddress,
    #[key]
    dragons_owned_id: u32,
    dragons_owned: usize,
}
