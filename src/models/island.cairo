use core::Zeroable;
use starknet::ContractAddress;
use starknet::get_block_timestamp;
use dragark_20::constants::island::MAX_LEVEL;
use dragark_20::models::position::{Position, PositionTrait};
use dragark_20::messages::error::Messages;

#[derive(Model, Copy, Drop, Serde)]
struct Island {
    #[key]
    game_id: usize,
    #[key]
    island_id: usize, // Island's ID
    owner: ContractAddress, // Island's owner address
    position: Position, // Island's position (x: [0, 998], y: [0, 998])
    element: IslandElement,
    title: IslandTitle,
    island_type: IslandType, // Island's type
    level: u8, // Island's level
    max_resources: Resource, // Island's max capable resources
    cur_resources: Resource, // Island's current resources
    food_mining_speed: u32,
    stone_mining_speed: u32,
    defense: u8,
    last_resources_update: u64, // The last timestamp the island updated its resources
}

#[derive(Copy, Drop, Serde, Introspect)]
enum IslandElement {
    Fire,
    Water,
    Forest
}

#[derive(Copy, Drop, Serde, Introspect)]
enum IslandTitle {
    HomeLand,
    DeadLake,
    IpruhIsle,
    Itotaki,
    Taiheyo
}

#[derive(Copy, Drop, Serde, Introspect)]
struct Resource {
    food: u32,
    stone: u32
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum IslandType {
    Normal,
    Event
}

trait IslandTrait {
    fn init_island(
        game_id: usize,
        island_id: usize,
        sub_block_pos_id: u32,
        block_coordinates: Position,
        island_type: IslandType
    ) -> Island;
}

impl IslandImpl of IslandTrait {
    fn init_island(
        game_id: usize,
        island_id: usize,
        sub_block_pos_id: u32,
        block_coordinates: Position,
        island_type: IslandType
    ) -> Island {
        // Randomize position in block
        let position_in_sub_block = PositionTrait::init_position(island_id, 3);

        // Calculate x & y coordinates of the island in the map
        let mut x: u32 = block_coordinates.x + position_in_sub_block.x;
        let mut y: u32 = block_coordinates.y + position_in_sub_block.y;
        if (sub_block_pos_id == 1) {
            x += 3;
            y += 3;
        } else if (sub_block_pos_id == 2) {
            x += 2 * 3;
            y += 3;
        } else if (sub_block_pos_id == 3) {
            x += 2 * 3;
            y += 0;
        } else if (sub_block_pos_id == 4) {
            x += 3;
            y += 0;
        } else if (sub_block_pos_id == 5) {
            x += 0;
            y += 0;
        } else if (sub_block_pos_id == 6) {
            x += 0;
            y += 3;
        } else if (sub_block_pos_id == 7) {
            x += 0;
            y += 2 * 3;
        } else if (sub_block_pos_id == 8) {
            x += 3;
            y += 2 * 3;
        } else if (sub_block_pos_id == 9) {
            x += 2 * 3;
            y += 2 * 3;
        } else {
            panic_with_felt252(Messages::INVALID_CASE);
        }

        // Randomize element
        let data_element: Array<felt252> = array![
            island_id.into(), 'data_element', get_block_timestamp().into()
        ];
        let hash_element: u256 = poseidon::poseidon_hash_span(data_element.span()).into();
        let element_num: u8 = (hash_element % 3).try_into().unwrap();
        let mut element: IslandElement = IslandElement::Fire;
        if (element_num == 1) {
            element = IslandElement::Water;
        } else if (element_num == 2) {
            element = IslandElement::Forest;
        }

        // Randomize title
        let data_title: Array<felt252> = array![
            island_id.into(), 'data_title', get_block_timestamp().into()
        ];
        let hash_tite: u256 = poseidon::poseidon_hash_span(data_title.span()).into();
        let title_num: u8 = (hash_tite % 5).try_into().unwrap();
        let mut title: IslandTitle = IslandTitle::HomeLand;
        if (title_num == 1) {
            title = IslandTitle::DeadLake;
        } else if (title_num == 2) {
            title = IslandTitle::IpruhIsle;
        } else if (title_num == 3) {
            title = IslandTitle::Itotaki;
        } else if (title_num == 4) {
            title = IslandTitle::Taiheyo;
        }

        // Randomize level
        let data_level: Array<felt252> = array![
            island_id.into(), 'data_level', get_block_timestamp().into()
        ];
        let hash_level: u256 = poseidon::poseidon_hash_span(data_level.span()).into();
        let mut level: u8 = (hash_level % MAX_LEVEL.into()).try_into().unwrap();
        level = level + 1;

        let mut max_food: u32 = 0;
        let mut max_stone: u32 = 0;

        let mut food_mining_speed: u32 = 0;
        let mut stone_mining_speed: u32 = 0;

        // Init stats based on the island's level
        if (level == 1) {
            max_food = 100;
            food_mining_speed = 50;
            max_stone = 25;
            stone_mining_speed = 5;
        } else if (level == 2) {
            max_food = 400;
            food_mining_speed = 100;
            max_stone = 100;
            stone_mining_speed = 10;
        } else if (level == 3) {
            max_food = 700;
            food_mining_speed = 150;
            max_stone = 175;
            stone_mining_speed = 15;
        } else if (level == 4) {
            max_food = 1000;
            food_mining_speed = 200;
            max_stone = 250;
            stone_mining_speed = 20;
        } else if (level == 5) {
            max_food = 4000;
            food_mining_speed = 250;
            max_stone = 1000;
            stone_mining_speed = 25;
        } else if (level == 6) {
            max_food = 5500;
            food_mining_speed = 300;
            max_stone = 1375;
            stone_mining_speed = 30;
        } else if (level == 7) {
            max_food = 7000;
            food_mining_speed = 350;
            max_stone = 1750;
            stone_mining_speed = 35;
        } else if (level == 8) {
            max_food = 8500;
            food_mining_speed = 400;
            max_stone = 2125;
            stone_mining_speed = 40;
        } else if (level == 9) {
            max_food = 10000;
            food_mining_speed = 450;
            max_stone = 2500;
            stone_mining_speed = 45;
        } else if (level == 10) {
            max_food = 20000;
            food_mining_speed = 600;
            max_stone = 5000;
            stone_mining_speed = 60;
        }

        // Randomize food
        let data_food: Array<felt252> = array![
            island_id.into(), 'data_food', get_block_timestamp().into()
        ];
        let mut hash_food: u256 = poseidon::poseidon_hash_span(data_food.span()).into();
        let mut food: u32 = (hash_food % max_food.into()).try_into().unwrap();
        food = food + 1;

        // Randomize stone
        let data_stone: Array<felt252> = array![
            island_id.into(), 'data_stone', get_block_timestamp().into()
        ];
        let mut hash_stone: u256 = poseidon::poseidon_hash_span(data_stone.span()).into();
        let mut stone: u32 = (hash_stone % max_stone.into()).try_into().unwrap();
        stone = stone + 1;

        let last_resources_update = get_block_timestamp();

        return Island {
            game_id,
            island_id,
            owner: Zeroable::zero(),
            position: Position { x, y },
            element,
            title,
            island_type,
            level,
            max_resources: Resource { food: max_food, stone: max_stone },
            cur_resources: Resource { food, stone },
            food_mining_speed,
            stone_mining_speed,
            defense: 0,
            last_resources_update
        };
    }
}
