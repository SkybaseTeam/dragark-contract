use dragark_3::models::position::{Position, PositionTrait};

// Model GameInfo
// All sizes are in sub-sub-block

// 1 block = 3 x 3 sub-blocks = 9 x 9 sub-sub-blocks
// 1 sub-block = 3 x 3 sub-sub blocks
// sub-sub block = 1 x 1
// Initial map sizes = 3 x 3 blocks = 9 x 9 sub-blocks = 27 x 27 sub-sub-blocks

#[derive(Model, Drop, Serde)]
struct GameInfo {
    #[key]
    game_id: usize, // GameInfo's ID
    is_initialized: u8, // The game is initialized or not
    total_user: u32, // GameInfo's total user
    total_island: u32, // GameInfo's total island, used for Island's ID
    total_dragon: u32, // GameInfo's total dragon, used for Dragon's ID
    total_scout: u32, // GameInfo's total scout
    total_journey: u32, // GameInfo's total journey
    cur_map_sizes: u32, // Current map size, in 2 dimensions (Initial map sizes = 27 => 27 x 27 = 729 sub-sub-blocks ~ 81 sub-blocks)
    cur_map_coordinates: Position, // Current map coordinates (bottom left)
    cur_sub_block_pos_id_index: u8, // Current game's sub-block position id, from 0 -> 8
    cur_block_coordinates: Position, // Current block coordinates (bottom left)
    cur_map_expanding_num: u16, // Current number of times the map has been expanded
}
