use starknet::ContractAddress;
use dragark::constants::island::{MAX_FOOD_STAT, MAX_STONE_STAT};
use dragark::constants::map::{BLOCK_SIZE, PLAYER_MAP_SIZE, MAP_SIZE};
use dragark::models::position::{Position, PositionTrait};

#[derive(Model, Copy, Drop, Serde)]
struct Island {
    #[key]
    island_id: usize, // Island's ID
    owner: ContractAddress, // Island's owner address
    position: Position, // Island's position (x: [0, 998], y: [0, 998])
    island_type: IslandType, // Island's type
    island_sub_type: IslandSubType, // Island's sub-type. For example, if an island has a type of Resource, it will have a sub-type of Flora, Lava or Water
    max_resources: Resource, // Island's max capable resources
    cur_resources: Resource, // Island's current resources
    level: u8, // Island's level
    num_dragons_defending: u32,
    state: IslandState
}

#[derive(Copy, Drop, Serde, Introspect)]
struct Resource {
    food: u16,
    stone: u16
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum IslandType {
    ResourceIsland,
    DragonCemetery,
    MysticalIsland,
    EventIsland
}

#[derive(Copy, Drop, Serde, Introspect)]
enum IslandSubType {
    FloraIsland,
    LavaIsland,
    WaterIsland,
    None
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum IslandState {
    Idling,
    Warring
}

trait IslandTrait {
    fn init_island(id: usize, owner: ContractAddress, island_type: IslandType) -> Island;
}

impl IslandImpl of IslandTrait {
    fn init_island(id: usize, owner: ContractAddress, island_type: IslandType) -> Island {
        let mut data: Array<felt252> = array![id.into()];

        // Randomize position in block
        let position_in_block = PositionTrait::init_position(id, BLOCK_SIZE);

        // Randomize position in map
        let position_in_map = PositionTrait::init_position(id, MAP_SIZE);

        // Calculate x & y coordinates in the map
        let x: u32 = position_in_map.x * BLOCK_SIZE + position_in_block.x;
        let y: u32 = position_in_map.y * BLOCK_SIZE + position_in_block.y;

        // Ranzomize the sub_island_type if island_type is ResourceIsland
        let mut island_sub_type: IslandSubType = IslandSubType::None;
        if (island_type == IslandType::ResourceIsland) {
            let hash_island_sub_type: u256 = poseidon::poseidon_hash_span(data.span()).into();
            let island_sub_type_num: u8 = (hash_island_sub_type % 3).try_into().unwrap();
            if (island_sub_type_num == 0) {
                island_sub_type = IslandSubType::FloraIsland;
            } else if (island_sub_type_num == 1) {
                island_sub_type = IslandSubType::LavaIsland;
            } else if (island_sub_type_num == 2) {
                island_sub_type = IslandSubType::WaterIsland;
            }
        }

        // Randomize food
        let mut hash_food: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let mut food: u16 = (hash_food % MAX_FOOD_STAT.into()).try_into().unwrap();
        food = food + 1;

        // Randomize stone
        let mut hash_stone: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let mut stone: u16 = (hash_stone % MAX_STONE_STAT.into()).try_into().unwrap();
        stone = stone + 1;

        return Island {
            island_id: id,
            owner,
            position: Position { x, y },
            island_type,
            island_sub_type,
            max_resources: Resource { food: MAX_FOOD_STAT, stone: MAX_STONE_STAT },
            cur_resources: Resource { food, stone },
            level: 0,
            num_dragons_defending: 0,
            state: IslandState::Idling
        };
    }
}
