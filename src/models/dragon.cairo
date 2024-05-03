use starknet::ContractAddress;
use dragark::constants::dragon::{
    MAX_SPPED_STAT, MAX_ATTACK_STAT, MAX_FOOD_CAPACITY_STAT, MAX_STONE_CAPACITY_STAT
};
use dragark::models::island::Resource;

#[derive(Model, Copy, Drop, Serde)]
struct Dragon {
    #[key]
    dragon_id: usize, // Dragon's ID
    #[key]
    owner: ContractAddress, // Dragon's owner
    speed: u8, // Dragon's speed stat (100, 200, ...)
    attack: u8, // Dragon's attack stat (25, 50, ...)
    max_capacity: Resource, // Dragon's max capacity stat
    cur_capacity: Resource, // Dragon's current capacity stat
    element: DragonElement,
    island_defending: usize, // The island the dragon is defending
    island_attacking: usize, // The island the dragon is attacking
    state: DragonState, // Dragon's state
}

#[derive(Copy, Drop, Serde, Introspect)]
enum DragonElement {
    Fire,
    Water,
    Lightning,
    Darkness
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum DragonState {
    Idling,
    Flying,
}

trait DragonTrait {
    fn init_dragon(id: usize, owner: ContractAddress) -> Dragon;
}

impl DragonImpl of DragonTrait {
    fn init_dragon(id: usize, owner: ContractAddress) -> Dragon {
        let mut data: Array<felt252> = array![id.into()];

        // Randomize speed
        let mut hash_speed: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let mut speed: u8 = (hash_speed % MAX_SPPED_STAT.into()).try_into().unwrap();
        speed = speed + 1;

        // Randomize attack
        let mut hash_attack: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let mut attack: u8 = (hash_attack % MAX_ATTACK_STAT.into()).try_into().unwrap();
        attack = attack + 1;

        // Randomize food capacity
        let mut hash_capacity: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let mut food_capacity: u16 = (hash_capacity % MAX_FOOD_CAPACITY_STAT.into())
            .try_into()
            .unwrap();
        food_capacity = food_capacity + 1;

        // Randomize stone capacity
        let mut hash_capacity: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let mut stone_capacity: u16 = (hash_capacity % MAX_STONE_CAPACITY_STAT.into())
            .try_into()
            .unwrap();
        stone_capacity = stone_capacity + 1;

        // Randomize element
        let mut hash_element: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let mut element_num: u8 = (hash_element % 4).try_into().unwrap();
        let mut element: DragonElement = DragonElement::Fire;
        if (element_num == 1) {
            element = DragonElement::Water;
        } else if (element_num == 2) {
            element = DragonElement::Lightning;
        } else if (element_num == 3) {
            element = DragonElement::Darkness;
        }

        return Dragon {
            dragon_id: id,
            owner,
            speed,
            attack,
            max_capacity: Resource { food: food_capacity, stone: stone_capacity },
            cur_capacity: Resource { food: 0, stone: 0 },
            element,
            island_defending: 0,
            island_attacking: 0,
            state: DragonState::Idling
        };
    }
}
