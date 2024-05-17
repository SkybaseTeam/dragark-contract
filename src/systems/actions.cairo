use dragark_20::models::position::Position;
use dragark_20::models::island::Resource;

#[dojo::interface]
trait IActions {
    ///////////////////
    // User Function //
    ///////////////////

    // Function for user joining the game
    // Only callable for users who haven't joined the game
    // # Argument
    // * game_id The game_id to join
    // # Return
    // * bool Whether the tx successful or not
    fn join_game(game_id: usize) -> bool;

    // Function for user scouting the map
    // # Argument
    // * game_id The game_id to init action
    // * destination Position to scout
    // # Return
    // * Position Position of destination
    fn scout(game_id: usize, destination: Position) -> Position;

    // Function for user to start a new journey
    // # Argument
    // * game_id The game_id to init action
    // * dragon_id ID of the specified dragon 
    // * island_from_id ID of the starting island
    // * island_to_id ID of the destination island
    // * resources Specified amount of resources to carry (including foods & stones)
    // # Return
    // * bool Whether the tx successful or not
    fn start_journey(
        game_id: usize,
        dragon_id: usize,
        island_from_id: usize,
        island_to_id: usize,
        resources: Resource
    ) -> bool;

    // Function to finish a started journey
    // # Argument
    // * game_id The game_id to init action
    // * journey_id ID of the started journey
    // # Return
    // * bool Whether the tx successful or not
    fn finish_journey(game_id: usize, journey_id: felt252) -> bool;

    ////////////////////
    // Admin Function //
    ////////////////////

    // Function for initializing a new game, only callable by admin
    // This function MUST BE CALLED FIRST in order to get the game operating
    // # Return
    // * usize The initialized game_id
    fn init_new_game() -> usize;

    // Function for initializing new derelict island, only callable by admin
    // # Argument
    // * game_id The game_id to init action
    // * num Number of islands to create
    // # Return
    // * bool Whether the tx successful or not
    fn init_derelict_island(game_id: usize, num: u16) -> bool;

    // Function for updating island resources PER MINUTE, onlly callable by admin
    // # Argument
    // * game_id The game_id to init action
    // * island_ids Array of island_ids to update resources
    // # Return
    // * bool Whether the tx successful or not
    fn update_resources(game_id: usize, island_ids: Array<usize>) -> bool;
}

#[dojo::contract]
mod actions {
    use core::integer::u32_sqrt;
    use core::integer::BoundedU32;
    use core::Zeroable;
    use dragark_20::constants::dragon::DRAGON_BONUS;
    use dragark_20::constants::game::ADMIN_ADDRESS;
    use dragark_20::messages::error::Messages;
    use dragark_20::models::user::{User};
    use dragark_20::models::game_info::{GameInfo};
    use dragark_20::models::game_island_info::GameIslandInfo;
    use dragark_20::models::dragon::{
        Dragon, DragonModelId, DragonRarity, DragonElement, DragonTitle, DragonState, DragonTrait
    };
    use dragark_20::models::island::{
        Island, IslandElement, IslandTitle, IslandType, Resource, IslandTrait
    };
    use dragark_20::models::user_island_owned::UserIslandOwned;
    use dragark_20::models::user_dragon_owned::UserDragonOwned;
    use dragark_20::models::position::{SubBlockPos, NextBlockDirection, Position, PositionTrait};
    use dragark_20::models::scout_info::ScoutInfo;
    use dragark_20::models::journey::{Journey, AttackType, AttackResult};
    use super::IActions;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    #[derive(Drop, starknet::Event)]
    struct EventGameUpdate {
        game_id: usize,
        is_initialized: u8,
        total_user: u32,
        total_island: u32,
        total_dragon: u32,
        total_scout: u32,
        total_journey: u32,
        cur_map_sizes: u32,
        cur_map_coordinates: Position,
        cur_sub_block_pos_id_index: u8,
        cur_block_coordinates: Position,
        cur_map_expanding_num: u16,
    }

    #[derive(Drop, starknet::Event)]
    struct EventGameIslandUpdate {
        game_id: usize,
        index: u32,
        island_id: usize
    }

    #[derive(Drop, starknet::Event)]
    struct EventNewUser {
        game_id: usize,
        player: ContractAddress,
        is_joined_game: u8,
        area_opened: u32,
        energy: u32,
        num_islands_owned: u32,
        num_dragons_owned: u32
    }

    #[derive(Drop, starknet::Event)]
    struct EventUserDragonOwnedUpdate {
        game_id: usize,
        player: ContractAddress,
        index: u32,
        dragon_id: usize,
    }

    #[derive(Drop, starknet::Event)]
    struct EventUserIslandOwnedUpdate {
        game_id: usize,
        player: ContractAddress,
        index: u32,
        island_id: usize,
    }

    #[derive(Drop, starknet::Event)]
    struct EventNewIsland {
        game_id: usize,
        island_id: usize,
        owner: ContractAddress,
        position: Position,
        element: IslandElement,
        title: IslandTitle,
        island_type: IslandType,
        level: u8,
        max_resources: Resource,
        cur_resources: Resource,
        food_mining_speed: u32,
        stone_mining_speed: u32,
        defense: u8,
        last_resources_update: u64
    }

    #[derive(Drop, starknet::Event)]
    struct EventNewDragon {
        game_id: usize,
        dragon_id: usize,
        owner: ContractAddress,
        model_id: DragonModelId,
        rarity: DragonRarity,
        element: DragonElement,
        title: DragonTitle,
        speed: u16,
        attack: u16,
        carrying_capacity: Resource,
        state: DragonState
    }

    #[derive(Drop, starknet::Event)]
    struct EventNewScout {
        game_id: usize,
        player: ContractAddress,
        destination: Position,
        area_opened: u32,
        energy_left: u32,
        time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct EventNewJourney {
        game_id: usize,
        journey_id: felt252,
        owner: ContractAddress,
        dragon_id: usize,
        carrying_resources: Resource,
        island_from_id: usize,
        island_to_id: usize,
        start_time: u64,
        finish_time: u64,
        attack_type: AttackType,
        attack_result: AttackResult
    }

    #[derive(Drop, starknet::Event)]
    struct EventJourneyFinish {
        game_id: usize,
        journey_id: felt252,
        status: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        EventGameUpdate: EventGameUpdate,
        EventGameIslandUpdate: EventGameIslandUpdate,
        EventNewUser: EventNewUser,
        EventUserDragonOwnedUpdate: EventUserDragonOwnedUpdate,
        EventUserIslandOwnedUpdate: EventUserIslandOwnedUpdate,
        EventNewIsland: EventNewIsland,
        EventNewDragon: EventNewDragon,
        EventNewScout: EventNewScout,
        EventNewJourney: EventNewJourney,
        EventJourneyFinish: EventJourneyFinish,
    }

    #[abi(embed_v0)]
    impl IActionsImpl of IActions<ContractState> {
        ///////////////////
        // User Function //
        ///////////////////

        // See IActions-join_game
        fn join_game(world: IWorldDispatcher, game_id: usize) -> bool {
            let caller = get_caller_address();

            let player = get!(world, (game_id, caller), User);
            let mut game = get!(world, (game_id), GameInfo);

            // Check whether the game is has been initialized or not
            assert(game.is_initialized == 1, Messages::GAME_NOT_INITIALIZED);

            // Check whether the user has joined or not
            assert(player.is_joined_game == 0, Messages::PLAYER_EXISTED);

            // Get u32 max
            let u32_max = BoundedU32::max();

            // Generate dragon id
            let data_dragon: Array<felt252> = array![
                (game.total_dragon + 1).into(), 'data_dragon', get_block_timestamp().into()
            ];
            let mut dragon_id_u256: u256 = poseidon::poseidon_hash_span(data_dragon.span())
                .try_into()
                .unwrap();
            let dragon_id: usize = (dragon_id_u256 % u32_max.into()).try_into().unwrap();

            // Initialize dragon
            let mut dragon = DragonTrait::init_dragon(game_id, dragon_id, caller);
            set!(world, (dragon));

            // Generate island id
            let data_island: Array<felt252> = array![
                (game.total_island + 1).into(), 'data_island', get_block_timestamp().into()
            ];
            let mut island_id_u256: u256 = poseidon::poseidon_hash_span(data_island.span())
                .try_into()
                .unwrap();
            let island_id: usize = (island_id_u256 % u32_max.into()).try_into().unwrap();

            // Get sub-block position id
            let sub_block_pos_id = get!(
                world, (game_id, game.cur_sub_block_pos_id_index), SubBlockPos
            )
                .pos_id;

            // Initialize normal island
            let mut island = IslandTrait::init_island(
                game_id, island_id, sub_block_pos_id, game.cur_block_coordinates, IslandType::Normal
            );
            island.owner = caller;
            set!(world, (island));

            // Increase sub-block position id index
            game.cur_sub_block_pos_id_index += 1;

            // Randomly skip some index
            if (game.cur_sub_block_pos_id_index < 8) {
                let data_index: Array<felt252> = array!['data_index', get_block_timestamp().into()];
                let hash_data_index: u256 = poseidon::poseidon_hash_span(data_index.span())
                    .try_into()
                    .unwrap();
                let residual_hash_data_index = hash_data_index % 9;
                if (residual_hash_data_index == 0
                    || residual_hash_data_index == 3
                    || residual_hash_data_index == 6) {
                    game.cur_sub_block_pos_id_index += 1;
                }
            }

            // Move current block & Rerandomize sub-block pos id when the current block is full of sub-block
            // Expand map sizes & coordinates when the current map is full of blocks
            if (game.cur_sub_block_pos_id_index == 9) {
                ////////////////////////
                // Move current block //
                ////////////////////////

                // Get next block direction
                let next_block_direction_model = get!(world, (game_id), NextBlockDirection);
                let mut right_1 = next_block_direction_model.right_1;
                let mut down_2 = next_block_direction_model.down_2;
                let mut left_3 = next_block_direction_model.left_3;
                let mut up_4 = next_block_direction_model.up_4;
                let mut right_5 = next_block_direction_model.right_5;
                if (right_1 != 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                    // Move the current block to the right
                    game.cur_block_coordinates.x += 3 * 3;
                    right_1 -= 1;
                } else if (right_1 == 0
                    && down_2 != 0
                    && left_3 != 0
                    && up_4 != 0
                    && right_5 != 0) {
                    // Move the current block down
                    game.cur_block_coordinates.y -= 3 * 3;
                    down_2 -= 1;
                } else if (right_1 == 0
                    && down_2 == 0
                    && left_3 != 0
                    && up_4 != 0
                    && right_5 != 0) {
                    // Move the current block to the left
                    game.cur_block_coordinates.x -= 3 * 3;
                    left_3 -= 1;
                } else if (right_1 == 0
                    && down_2 == 0
                    && left_3 == 0
                    && up_4 != 0
                    && right_5 != 0) {
                    // Move the current block up
                    game.cur_block_coordinates.y += 3 * 3;
                    up_4 -= 1;
                } else if (right_1 == 0
                    && down_2 == 0
                    && left_3 == 0
                    && up_4 == 0
                    && right_5 != 0) {
                    // Move the current block to the right
                    game.cur_block_coordinates.x += 3 * 3;
                    right_5 -= 1;
                } else if (right_1 == 0
                    && down_2 == 0
                    && left_3 == 0
                    && up_4 == 0
                    && right_5 == 0) {
                    ////////////////////
                    // Expand the map //
                    ////////////////////

                    // Increase map expanding num
                    game.cur_map_expanding_num += 1;

                    // Calculate new map sizes & coordinates
                    game.cur_map_sizes += 2 * 3 * 3;
                    game
                        .cur_map_coordinates =
                            Position {
                                x: game.cur_map_coordinates.x - 3 * 3,
                                y: game.cur_map_coordinates.y - 3 * 3
                            };
                    game.cur_block_coordinates.x += 3 * 3;

                    // Init next block direction
                    right_1 = 0;
                    down_2 = 1 + (game.cur_map_expanding_num.into() * 2);
                    left_3 = (game.cur_map_expanding_num.into() * 2) + 1;
                    up_4 = (game.cur_map_expanding_num.into() * 2) + 1;
                    right_5 = (game.cur_map_expanding_num.into() * 2) + 1;
                } else {
                    panic_with_felt252(Messages::INVALID_CASE);
                }

                // Reset current sub-block position id
                game.cur_sub_block_pos_id_index = 0;

                // Save NextBlockDirection model
                set!(
                    world, (NextBlockDirection { game_id, right_1, down_2, left_3, up_4, right_5 })
                );

                /////////////////////////////
                // Randomize sub-block pos //
                /////////////////////////////

                let sub_block_pos_ids = PositionTrait::ran_sub_block_pos_id(
                    game.cur_block_coordinates
                );
                let mut i: u8 = 0;
                loop {
                    if (i == 9) {
                        break;
                    }

                    // Save data to SubBlockPos model
                    set!(
                        world,
                        (SubBlockPos { game_id, index: i, pos_id: *sub_block_pos_ids.at(i.into()) })
                    );

                    i = i + 1;
                };
            }

            // Update game's data
            game.total_user += 1;
            game.total_island += 1;
            game.total_dragon += 1;

            // Save GameIslandInfo model
            set!(
                world,
                (GameIslandInfo { game_id, index: game.total_island, island_id: island.island_id })
            );

            // Save UserDragonOwned model
            set!(
                world,
                (UserDragonOwned { game_id, player: caller, index: 0, dragon_id: dragon.dragon_id })
            );

            // Save UserIslandOwned model
            set!(
                world,
                (UserIslandOwned { game_id, player: caller, index: 0, island_id: island.island_id })
            );

            // Save User model
            set!(
                world,
                (User {
                    game_id,
                    player: caller,
                    is_joined_game: 1,
                    area_opened: 0,
                    energy: 9000000, // 9_000_000
                    num_islands_owned: 1,
                    num_dragons_owned: 1
                })
            );

            // Scout the newly initialized island sub-sub block and 8 surrounding one (if possible)
            let map_coordinates = game.cur_map_coordinates;
            let map_sizes = game.cur_map_sizes;

            let island_position_x = island.position.x;
            let island_position_y = island.position.y;

            assert(
                island_position_x >= map_coordinates.x && island_position_x < map_coordinates.x
                    + map_sizes
                        && island_position_y >= map_coordinates.y
                        && island_position_y < map_coordinates.y
                    + map_sizes,
                Messages::INVALID_POSITION
            );

            self.scout(game_id, Position { x: island_position_x, y: island_position_y });
            if (island_position_x + 1 < map_coordinates.x + map_sizes) {
                self.scout(game_id, Position { x: island_position_x + 1, y: island_position_y });
            }
            if (island_position_x
                + 1 < map_coordinates.x
                + map_sizes && island_position_y
                - 1 >= map_coordinates.y) {
                self
                    .scout(
                        game_id, Position { x: island_position_x + 1, y: island_position_y - 1 }
                    );
            }
            if (island_position_y - 1 >= map_coordinates.y) {
                self.scout(game_id, Position { x: island_position_x, y: island_position_y - 1 });
            }
            if (island_position_x
                - 1 >= map_coordinates.x && island_position_y
                - 1 >= map_coordinates.y) {
                self
                    .scout(
                        game_id, Position { x: island_position_x - 1, y: island_position_y - 1 }
                    );
            }
            if (island_position_x - 1 >= map_coordinates.x) {
                self.scout(game_id, Position { x: island_position_x - 1, y: island_position_y });
            }
            if (island_position_x
                - 1 >= map_coordinates.x && island_position_y
                + 1 < map_coordinates.y
                + map_sizes) {
                self
                    .scout(
                        game_id, Position { x: island_position_x - 1, y: island_position_y + 1 }
                    );
            }
            if (island_position_y + 1 < map_coordinates.y + map_sizes) {
                self.scout(game_id, Position { x: island_position_x, y: island_position_y + 1 });
            }
            if (island_position_x
                + 1 < map_coordinates.x
                + map_sizes && island_position_y
                + 1 < map_coordinates.y
                + map_sizes) {
                self
                    .scout(
                        game_id, Position { x: island_position_x + 1, y: island_position_y + 1 }
                    );
            }

            // Emit EventNewUser
            emit!(
                world,
                (Event::EventNewUser(
                    EventNewUser {
                        game_id,
                        player: caller,
                        is_joined_game: 1,
                        area_opened: 0,
                        energy: 9000000,
                        num_islands_owned: 1,
                        num_dragons_owned: 1
                    }
                ))
            );

            // Emit EventGameUpdate
            emit!(
                world,
                (Event::EventGameUpdate(
                    EventGameUpdate {
                        game_id,
                        is_initialized: game.is_initialized,
                        total_user: game.total_user,
                        total_island: game.total_island,
                        total_dragon: game.total_dragon,
                        total_scout: game.total_scout,
                        total_journey: game.total_journey,
                        cur_map_sizes: game.cur_map_sizes,
                        cur_map_coordinates: game.cur_map_coordinates,
                        cur_sub_block_pos_id_index: game.cur_sub_block_pos_id_index,
                        cur_block_coordinates: game.cur_block_coordinates,
                        cur_map_expanding_num: game.cur_map_expanding_num
                    }
                ))
            );

            // Emit EventGameIslandUpdate
            emit!(
                world,
                (Event::EventGameIslandUpdate(
                    EventGameIslandUpdate {
                        game_id, index: game.total_island, island_id: island.island_id
                    }
                ))
            );

            // Emit EventNewIsland
            emit!(
                world,
                (Event::EventNewIsland(
                    EventNewIsland {
                        game_id,
                        island_id: island.island_id,
                        owner: island.owner,
                        position: island.position,
                        element: island.element,
                        title: island.title,
                        island_type: island.island_type,
                        level: island.level,
                        max_resources: island.max_resources,
                        cur_resources: island.cur_resources,
                        food_mining_speed: island.food_mining_speed,
                        stone_mining_speed: island.stone_mining_speed,
                        defense: island.defense,
                        last_resources_update: island.last_resources_update
                    }
                ))
            );

            // Emit EventNewDragon
            emit!(
                world,
                (Event::EventNewDragon(
                    EventNewDragon {
                        game_id,
                        dragon_id: dragon.dragon_id,
                        owner: dragon.owner,
                        model_id: dragon.model_id,
                        rarity: dragon.rarity,
                        element: dragon.element,
                        title: dragon.title,
                        speed: dragon.speed,
                        attack: dragon.attack,
                        carrying_capacity: dragon.carrying_capacity,
                        state: dragon.state
                    }
                ))
            );

            // Emit EventUserDragonOwnedUpdate
            emit!(
                world,
                (Event::EventUserDragonOwnedUpdate(
                    EventUserDragonOwnedUpdate {
                        game_id, player: caller, index: 0, dragon_id: dragon.dragon_id,
                    }
                ))
            );

            // Emit EventUserIslandOwnedUpdate
            emit!(
                world,
                (Event::EventUserIslandOwnedUpdate(
                    EventUserIslandOwnedUpdate {
                        game_id, player: caller, index: 0, island_id: island.island_id,
                    }
                ))
            );

            // Save GameInfo model
            set!(world, (game));

            true
        }

        // See IActions-scout
        fn scout(world: IWorldDispatcher, game_id: usize, destination: Position) -> Position {
            let caller = get_caller_address();
            let mut player = get!(world, (game_id, caller), User);
            let mut game = get!(world, (game_id), GameInfo);

            // Check whether the game is has been initialized or not
            assert(game.is_initialized == 1, Messages::GAME_NOT_INITIALIZED);

            // Check if player exists
            assert(player.is_joined_game == 1, Messages::PLAYER_NOT_EXIST);

            // Check if the player has enough energy
            assert(player.energy > 0, Messages::NOT_ENOUGH_ENERGY);

            // Get current map's coordinates & sizes
            let map_coordinates = game.cur_map_coordinates;
            let map_sizes = game.cur_map_sizes;

            // Check destination
            assert(
                destination.x >= map_coordinates.x && destination.x < map_coordinates.x
                    + map_sizes
                        && destination.y >= map_coordinates.y
                        && destination.y < map_coordinates.y
                    + map_sizes,
                Messages::INVALID_POSITION
            );

            player.area_opened += 1;
            player.energy -= 1;
            game.total_scout += 1;

            let scout_id_data: Array<felt252> = array![(game.total_scout).into()];
            let scout_id = poseidon::poseidon_hash_span(scout_id_data.span());

            let scout_info = ScoutInfo {
                game_id,
                scout_id: scout_id,
                player: player.player,
                destination: destination,
                time: get_block_timestamp()
            };

            // Emit EventNewScout
            emit!(
                world,
                (Event::EventNewScout(
                    EventNewScout {
                        game_id,
                        player: scout_info.player,
                        destination,
                        area_opened: player.area_opened,
                        energy_left: player.energy,
                        time: scout_info.time
                    }
                ))
            );

            // Emit EventGameUpdate
            emit!(
                world,
                (Event::EventGameUpdate(
                    EventGameUpdate {
                        game_id: game.game_id,
                        is_initialized: game.is_initialized,
                        total_user: game.total_user,
                        total_island: game.total_island,
                        total_dragon: game.total_dragon,
                        total_scout: game.total_scout,
                        total_journey: game.total_journey,
                        cur_map_sizes: map_sizes,
                        cur_map_coordinates: map_coordinates,
                        cur_sub_block_pos_id_index: game.cur_sub_block_pos_id_index,
                        cur_block_coordinates: game.cur_block_coordinates,
                        cur_map_expanding_num: game.cur_map_expanding_num
                    }
                ))
            );

            // Save models
            set!(world, (player));
            set!(world, (scout_info));
            set!(world, (game));

            destination
        }

        // See IActions-start_journey
        fn start_journey(
            world: IWorldDispatcher,
            game_id: usize,
            dragon_id: usize,
            island_from_id: usize,
            island_to_id: usize,
            resources: Resource
        ) -> bool {
            let caller = get_caller_address();
            let player = get!(world, (game_id, caller), User);
            let mut game = get!(world, (game_id), GameInfo);

            // Check whether the game is has been initialized or not
            assert(game.is_initialized == 1, Messages::GAME_NOT_INITIALIZED);

            let mut dragon = get!(world, (game_id, dragon_id), Dragon);
            let mut island_from = get!(world, (game_id, island_from_id), Island);
            let mut island_to = get!(world, (game_id, island_to_id), Island);

            // Check if player exists
            assert(player.area_opened > 0, Messages::PLAYER_NOT_EXIST);

            // Check if dragon exists
            assert(dragon.speed >= 5, Messages::DRAGON_NOT_EXISTS);

            // Check if island exists
            assert(
                island_from.food_mining_speed >= 50 && island_to.food_mining_speed >= 50,
                Messages::ISLAND_NOT_EXISTS
            );

            // Verify input
            assert(dragon_id.is_non_zero(), Messages::INVALID_DRAGON_ID);
            assert(island_from_id.is_non_zero(), Messages::INVALID_ISLAND_FROM);
            assert(island_to_id.is_non_zero(), Messages::INVALID_ISLAND_TO);

            // Check the 2 islands are different
            assert(island_from_id != island_to_id, Messages::JOURNEY_TO_THE_SAME_ISLAND);

            // Check if the player has the island_from & island_to
            let mut is_island_from_owned: bool = false;
            let mut is_island_to_owned: bool = false;
            if (island_from.owner == caller) {
                is_island_from_owned = true;
            }
            if (island_to.owner == caller) {
                is_island_to_owned = true;
            }
            assert(is_island_from_owned, Messages::NOT_OWN_ISLAND);

            // Check the player has the dragon
            let mut is_dragon_owned: bool = false;
            if (dragon.owner == caller) {
                is_dragon_owned = true;
            }
            assert(is_dragon_owned, Messages::NOT_OWN_DRAGON);

            // Check the dragon is on idling state
            assert(dragon.state == DragonState::Idling, Messages::DRAGON_IS_NOT_AVAILABLE);

            // Check the island_from has enough resources
            let island_from_resources = island_from.cur_resources;
            assert(resources.food <= island_from_resources.food, Messages::NOT_ENOUGH_FOOD);
            assert(resources.stone <= island_from_resources.stone, Messages::NOT_ENOUGH_STONE);

            // Check that the dragon has enough capacity
            assert(
                resources.food <= dragon.carrying_capacity.food,
                Messages::NOT_ENOUGH_FOOD_CAPACITY_ON_DRAGON
            );
            assert(
                resources.stone <= dragon.carrying_capacity.stone,
                Messages::NOT_ENOUGH_STONE_CAPACITY_ON_DRAGON
            );

            // Update the island_from resources
            island_from.cur_resources.food -= resources.food;
            island_from.cur_resources.stone -= resources.stone;

            // Calculate the distance between the 2 islands
            let island_from_position = island_from.position;
            let island_to_position = island_to.position;

            assert(
                island_from_position.x != island_to_position.x
                    || island_from_position.y != island_to_position.y,
                Messages::TRANSPORT_TO_THE_SAME_DESTINATION
            );

            let mut x_distance = 0;
            if (island_to_position.x >= island_from_position.x) {
                x_distance = island_to_position.x - island_from_position.x;
            } else {
                x_distance = island_from_position.x - island_to_position.x;
            }

            let mut y_distance = 0;
            if (island_to_position.y >= island_from_position.y) {
                y_distance = island_to_position.y - island_from_position.y;
            } else {
                y_distance = island_from_position.y - island_to_position.y;
            }

            let distance = u32_sqrt(x_distance * x_distance + y_distance * y_distance);

            // Calculate the time for the dragon to fly
            let dragon_speed = dragon.speed;
            let time = distance / dragon_speed.into();

            let start_time = get_block_timestamp();
            let finish_time = start_time + time.into();

            let journey_id_data: Array<felt252> = array![(game.total_journey + 1).into()];
            let journey_id = poseidon::poseidon_hash_span(journey_id_data.span());

            // Update the dragon's state and save Dragon model
            dragon.state = DragonState::Flying;
            set!(world, (dragon));

            // Save Journey
            set!(
                world,
                (Journey {
                    game_id,
                    journey_id,
                    owner: caller,
                    dragon_id,
                    carrying_resources: resources,
                    island_from_id,
                    island_to_id,
                    start_time,
                    finish_time,
                    attack_type: AttackType::Unknown,
                    attack_result: AttackResult::Unknown,
                    status: false,
                })
            );

            // Emit EventNewJourney
            emit!(
                world,
                (Event::EventNewJourney(
                    EventNewJourney {
                        game_id,
                        journey_id,
                        owner: caller,
                        dragon_id,
                        carrying_resources: resources,
                        island_from_id,
                        island_to_id,
                        start_time,
                        finish_time,
                        attack_type: AttackType::Unknown,
                        attack_result: AttackResult::Unknown,
                    }
                ))
            );

            // Update the game's total journey
            game.total_journey += 1;

            // Emit EventGameUpdate model
            emit!(
                world,
                (Event::EventGameUpdate(
                    EventGameUpdate {
                        game_id: game.game_id,
                        is_initialized: game.is_initialized,
                        total_user: game.total_user,
                        total_island: game.total_island,
                        total_dragon: game.total_dragon,
                        total_scout: game.total_scout,
                        total_journey: game.total_journey,
                        cur_map_sizes: game.cur_map_sizes,
                        cur_map_coordinates: game.cur_map_coordinates,
                        cur_sub_block_pos_id_index: game.cur_sub_block_pos_id_index,
                        cur_block_coordinates: game.cur_block_coordinates,
                        cur_map_expanding_num: game.cur_map_expanding_num
                    }
                ))
            );

            // Save models
            set!(world, (island_from));
            set!(world, (game));

            true
        }

        // See IActions-finish_journey
        fn finish_journey(world: IWorldDispatcher, game_id: usize, journey_id: felt252) -> bool {
            let game = get!(world, (game_id), GameInfo);

            // Check whether the game is has been initialized or not
            assert(game.is_initialized == 1, Messages::GAME_NOT_INITIALIZED);

            // Verify input
            assert(journey_id.is_non_zero(), Messages::INVALID_JOURNEY_ID);
            let mut journey_info = get!(world, (game_id, journey_id), Journey);
            let mut dragon = get!(world, (game_id, journey_info.dragon_id), Dragon);
            let mut island_to = get!(world, (game_id, journey_info.island_to_id), Island);
            let resources = journey_info.carrying_resources;

            // Get capturing user
            let mut capturing_user = get!(world, (game_id, journey_info.owner), User);

            // Check time
            assert(
                get_block_timestamp() >= journey_info.finish_time, Messages::JOURNEY_IN_PROGRESS
            );

            // Check status
            assert(!journey_info.status, Messages::JOURNEY_ALREADY_FINISHED);

            // Check dragon state
            assert(dragon.state == DragonState::Flying, Messages::DRAGON_SHOULD_BE_FLYING);

            // Decide whether the Journey is Transport/Attack
            if (island_to.owner == journey_info.owner) {
                journey_info.attack_type = AttackType::None;
            } else if (island_to.owner != Zeroable::zero()) {
                journey_info.attack_type = AttackType::UserIslandAttack;
            } else if (island_to.owner == Zeroable::zero()) {
                journey_info.attack_type = AttackType::DerelictIslandAttack;
            }

            // If the attack_type is none => Transport
            if (journey_info.attack_type == AttackType::None) {
                // Update island_to resources
                if (island_to.cur_resources.food
                    + resources.food <= island_to.max_resources.food
                        && island_to.cur_resources.stone
                    + resources.stone <= island_to.max_resources.stone) {
                    island_to.cur_resources.food += resources.food;
                    island_to.cur_resources.stone += resources.stone;
                } else if (island_to.cur_resources.food
                    + resources.food <= island_to.max_resources.food
                        && island_to.cur_resources.stone
                    + resources.stone > island_to.max_resources.stone) {
                    island_to.cur_resources.food += resources.food;
                    island_to.cur_resources.stone = island_to.max_resources.stone;
                } else if (island_to.cur_resources.food
                    + resources.food > island_to.max_resources.food && island_to.cur_resources.stone
                    + resources.stone <= island_to.max_resources.stone) {
                    island_to.cur_resources.food = island_to.max_resources.food;
                    island_to.cur_resources.stone += resources.stone;
                } else if (island_to.cur_resources.food
                    + resources.food > island_to.max_resources.food && island_to.cur_resources.stone
                    + resources.stone > island_to.max_resources.stone) {
                    island_to.cur_resources.food = island_to.max_resources.food;
                    island_to.cur_resources.stone = island_to.max_resources.stone;
                } else {
                    panic_with_felt252(Messages::INVALID_CASE);
                }

                journey_info.attack_result = AttackResult::None;
            } else { // Else => Capture
                // Check condition
                assert(
                    journey_info.attack_type == AttackType::DerelictIslandAttack
                        || journey_info.attack_type == AttackType::UserIslandAttack,
                    Messages::INVALID_ATTACK_TYPE
                );

                // Calculate power rating
                let user_power_rating: u32 = (journey_info.carrying_resources.food
                    + dragon.attack.into())
                    * DRAGON_BONUS
                    / 100;
                let island_power_rating: u32 = island_to.cur_resources.food;

                // Decide whether user wins or loses and update state
                if (user_power_rating > island_power_rating) {
                    // Set the attack result
                    journey_info.attack_result = AttackResult::Win;

                    // Set the captured island resources
                    if (user_power_rating - island_power_rating <= island_to.cur_resources.food) {
                        island_to.cur_resources.food = user_power_rating - island_power_rating;
                    }
                    if (island_to.cur_resources.stone
                        + resources.stone <= island_to.max_resources.stone) {
                        island_to.cur_resources.stone += resources.stone;
                    } else {
                        island_to.cur_resources.stone = island_to.max_resources.stone;
                    }

                    // Update capturing user island owned
                    let mut capturing_user_island_owned = get!(
                        world,
                        (game_id, capturing_user.player, capturing_user.num_islands_owned),
                        UserIslandOwned
                    );
                    capturing_user_island_owned.island_id = island_to.island_id;

                    if (journey_info.attack_type == AttackType::UserIslandAttack) {
                        let mut captured_user = get!(world, (game_id, island_to.owner), User);
                        assert(
                            captured_user.player.is_non_zero(), Messages::INVALID_PLAYER_ADDRESS
                        );

                        // Update captured user island owned
                        let mut i: u32 = 0;
                        loop {
                            if (i == captured_user.num_islands_owned.into()) {
                                break;
                            }
                            let island_owned_id = get!(
                                world, (game_id, captured_user.player, i), UserIslandOwned
                            )
                                .island_id;
                            if (island_owned_id == island_to.island_id) {
                                break;
                            }
                            i = i + 1;
                        }; // Get the island captured index

                        let mut captured_user_island_owned = get!(
                            world, (game_id, captured_user.player, i), UserIslandOwned
                        );

                        if (i == captured_user.num_islands_owned.into() - 1) {
                            captured_user_island_owned.island_id = 0;

                            // Emit event
                            emit!(
                                world,
                                (Event::EventUserIslandOwnedUpdate(
                                    EventUserIslandOwnedUpdate {
                                        game_id,
                                        player: captured_user.player,
                                        index: i,
                                        island_id: 0
                                    }
                                ))
                            );
                        } else {
                            let mut captured_user_last_island_owned = get!(
                                world,
                                (
                                    game_id,
                                    captured_user.player,
                                    captured_user.num_islands_owned - 1
                                ),
                                UserIslandOwned
                            );
                            captured_user_island_owned
                                .island_id = captured_user_last_island_owned
                                .island_id;

                            // Emit event
                            emit!(
                                world,
                                (Event::EventUserIslandOwnedUpdate(
                                    EventUserIslandOwnedUpdate {
                                        game_id,
                                        player: captured_user.player,
                                        index: i,
                                        island_id: captured_user_last_island_owned.island_id
                                    }
                                ))
                            );

                            emit!(
                                world,
                                (Event::EventUserIslandOwnedUpdate(
                                    EventUserIslandOwnedUpdate {
                                        game_id,
                                        player: captured_user.player,
                                        index: captured_user.num_islands_owned - 1,
                                        island_id: 0
                                    }
                                ))
                            );

                            captured_user_last_island_owned.island_id = 0;
                            set!(world, (captured_user_last_island_owned));
                        }

                        captured_user.num_islands_owned -= 1;
                        set!(world, (captured_user));
                        set!(world, (captured_user_island_owned));
                    }

                    // Set the owner of the captured island
                    island_to.owner = journey_info.owner;

                    // Emit event capturing user island owned update
                    emit!(
                        world,
                        (Event::EventUserIslandOwnedUpdate(
                            EventUserIslandOwnedUpdate {
                                game_id,
                                player: capturing_user.player,
                                index: capturing_user.num_islands_owned,
                                island_id: island_to.island_id
                            }
                        ))
                    );
                    capturing_user.num_islands_owned += 1;

                    set!(world, (capturing_user_island_owned));
                } else {
                    // Set the attack result
                    journey_info.attack_result = AttackResult::Lose;

                    // Set the captured island resources
                    if (island_power_rating > user_power_rating && island_power_rating
                        - user_power_rating <= island_to.cur_resources.food) {
                        island_to.cur_resources.food = island_power_rating - user_power_rating;
                    } else if (island_power_rating == user_power_rating) {
                        island_to.cur_resources.food = 0;
                    } else {
                        panic_with_felt252(Messages::INVALID_CASE);
                    }
                }
            }

            // Update the dragon's state
            dragon.state = DragonState::Idling;

            // Update the journey's status
            journey_info.status = true;

            // Emit EventJourneyFinish
            emit!(
                world,
                (Event::EventJourneyFinish(
                    EventJourneyFinish { game_id, journey_id, status: true }
                ))
            );

            // Save models
            set!(world, (island_to));
            set!(world, (dragon));
            set!(world, (capturing_user));
            set!(world, (journey_info));

            true
        }

        ////////////////////
        // Admin Function //
        ////////////////////

        // See IActions-init_new_game
        fn init_new_game(world: IWorldDispatcher) -> usize {
            // Check caller
            let caller = get_caller_address();
            assert(caller == ADMIN_ADDRESS.try_into().unwrap(), Messages::NOT_ADMIN);

            // Get u32 max
            let u32_max = BoundedU32::max();

            // Generate GAME_ID
            let mut data_game_id: Array<felt252> = array!['GAME_ID', get_block_timestamp().into()];
            let game_id_u256: u256 = poseidon::poseidon_hash_span(data_game_id.span())
                .try_into()
                .unwrap();
            let game_id: usize = (game_id_u256 % u32_max.into()).try_into().unwrap();

            // Check whether the game id is has been initialized or not
            assert(
                get!(world, (game_id), GameInfo).is_initialized == 0, Messages::GAME_INITIALIZED
            );

            // Init initial map size & coordinates
            let cur_map_sizes = 3 * 3 * 3; // 27 x 27 sub-sub-blocks
            let cur_block_coordinates = Position { x: (u32_max / 2) - 3, y: (u32_max / 2) - 3 };
            let cur_map_coordinates = Position {
                x: cur_block_coordinates.x - 3 * 3, y: cur_block_coordinates.y - 3 * 3
            };

            // Randomize sub-block position id
            let sub_block_pos_ids = PositionTrait::ran_sub_block_pos_id(cur_block_coordinates);
            let mut i: u8 = 0;
            loop {
                if (i == 9) {
                    break;
                }

                // Save data to SubBlockPos model
                set!(
                    world,
                    (SubBlockPos { game_id, index: i, pos_id: *sub_block_pos_ids.at(i.into()) })
                );

                i = i + 1;
            };

            // Init next block direction
            let cur_map_expanding_num: u16 = 0;
            set!(
                world,
                (NextBlockDirection {
                    game_id,
                    right_1: 1,
                    down_2: 1 + (cur_map_expanding_num.into() * 2),
                    left_3: 1 + (cur_map_expanding_num.into() * 2) + 1,
                    up_4: 1 + (cur_map_expanding_num.into() * 2) + 1,
                    right_5: 1 + (cur_map_expanding_num.into() * 2) + 1
                })
            );

            // Save GameInfo model
            set!(
                world,
                (GameInfo {
                    game_id,
                    is_initialized: 1,
                    total_user: 0,
                    total_island: 0,
                    total_dragon: 0,
                    total_scout: 0,
                    total_journey: 0,
                    cur_map_sizes,
                    cur_map_coordinates,
                    cur_sub_block_pos_id_index: 0,
                    cur_block_coordinates,
                    cur_map_expanding_num,
                })
            );

            game_id
        }

        // See IActions-init_derelict_island
        fn init_derelict_island(world: IWorldDispatcher, game_id: usize, num: u16) -> bool {
            let game = get!(world, (game_id), GameInfo);

            // Check whether the game is has been initialized or not
            assert(game.is_initialized == 1, Messages::GAME_NOT_INITIALIZED);

            // Check caller
            let caller = get_caller_address();
            assert(caller == ADMIN_ADDRESS.try_into().unwrap(), Messages::NOT_ADMIN);

            // Get u32 max
            let u32_max = BoundedU32::max();

            let mut i: u16 = 0;
            loop {
                if (i == num) {
                    break;
                }

                let mut game = get!(world, (game_id), GameInfo);

                // Generate island id
                let data_island: Array<felt252> = array![
                    (game.total_island + 1).into(), 'data_island', get_block_timestamp().into()
                ];
                let mut island_id_u256: u256 = poseidon::poseidon_hash_span(data_island.span())
                    .try_into()
                    .unwrap();
                let island_id: usize = (island_id_u256 % u32_max.into()).try_into().unwrap();

                // Get sub-block position_id
                let sub_block_pos_id = get!(
                    world, (game_id, game.cur_sub_block_pos_id_index), SubBlockPos
                )
                    .pos_id;

                // Initialize normal island
                let mut island = IslandTrait::init_island(
                    game_id,
                    island_id,
                    sub_block_pos_id,
                    game.cur_block_coordinates,
                    IslandType::Normal
                );
                set!(world, (island));

                // Increase sub-block position id index
                game.cur_sub_block_pos_id_index += 1;

                // Randomly skip some index
                if (game.cur_sub_block_pos_id_index < 8) {
                    let data_index: Array<felt252> = array![
                        'data_index', get_block_timestamp().into()
                    ];
                    let hash_data_index: u256 = poseidon::poseidon_hash_span(data_index.span())
                        .try_into()
                        .unwrap();
                    let residual_hash_data_index = hash_data_index % 9;
                    if (residual_hash_data_index == 0
                        || residual_hash_data_index == 3
                        || residual_hash_data_index == 6) {
                        game.cur_sub_block_pos_id_index += 1;
                    }
                }

                // Move current block & Rerandomize sub-block pos id when the current block is full of sub-block
                // Expand map sizes & coordinates when the current map is full of blocks
                if (game.cur_sub_block_pos_id_index == 9) {
                    ////////////////////////
                    // Move current block //
                    ////////////////////////

                    // Get next block direction
                    let next_block_direction_model = get!(world, (game_id), NextBlockDirection);
                    let mut right_1 = next_block_direction_model.right_1;
                    let mut down_2 = next_block_direction_model.down_2;
                    let mut left_3 = next_block_direction_model.left_3;
                    let mut up_4 = next_block_direction_model.up_4;
                    let mut right_5 = next_block_direction_model.right_5;
                    if (right_1 != 0 && down_2 != 0 && left_3 != 0 && up_4 != 0 && right_5 != 0) {
                        // Move the current block to the right
                        game.cur_block_coordinates.x += 3 * 3;
                        right_1 -= 1;
                    } else if (right_1 == 0
                        && down_2 != 0
                        && left_3 != 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block down
                        game.cur_block_coordinates.y -= 3 * 3;
                        down_2 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 != 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block to the left
                        game.cur_block_coordinates.x -= 3 * 3;
                        left_3 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 == 0
                        && up_4 != 0
                        && right_5 != 0) {
                        // Move the current block up
                        game.cur_block_coordinates.y += 3 * 3;
                        up_4 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 == 0
                        && up_4 == 0
                        && right_5 != 0) {
                        // Move the current block to the right
                        game.cur_block_coordinates.x += 3 * 3;
                        right_5 -= 1;
                    } else if (right_1 == 0
                        && down_2 == 0
                        && left_3 == 0
                        && up_4 == 0
                        && right_5 == 0) {
                        ////////////////////
                        // Expand the map //
                        ////////////////////

                        // Increase map expanding num
                        game.cur_map_expanding_num += 1;

                        // Calculate new map sizes & coordinates
                        game.cur_map_sizes += 2 * 3 * 3;
                        game
                            .cur_map_coordinates =
                                Position {
                                    x: game.cur_map_coordinates.x - 3 * 3,
                                    y: game.cur_map_coordinates.y - 3 * 3
                                };
                        game.cur_block_coordinates.x += 3 * 3;

                        // Init next block direction
                        right_1 = 0;
                        down_2 = 1 + (game.cur_map_expanding_num.into() * 2);
                        left_3 = (game.cur_map_expanding_num.into() * 2) + 1;
                        up_4 = (game.cur_map_expanding_num.into() * 2) + 1;
                        right_5 = (game.cur_map_expanding_num.into() * 2) + 1;
                    } else {
                        panic_with_felt252(Messages::INVALID_CASE);
                    }

                    // Reset current sub-block position id
                    game.cur_sub_block_pos_id_index = 0;

                    // Save NextBlockDirection model
                    set!(
                        world,
                        (NextBlockDirection { game_id, right_1, down_2, left_3, up_4, right_5 })
                    );

                    /////////////////////////////
                    // Randomize sub-block pos //
                    /////////////////////////////

                    let sub_block_pos_ids = PositionTrait::ran_sub_block_pos_id(
                        game.cur_block_coordinates
                    );
                    let mut i: u8 = 0;
                    loop {
                        if (i == 9) {
                            break;
                        }

                        // Save data to SubBlockPos model
                        set!(
                            world,
                            (SubBlockPos {
                                game_id, index: i, pos_id: *sub_block_pos_ids.at(i.into())
                            })
                        );

                        i = i + 1;
                    };
                }

                // Update game's total islands
                game.total_island += 1;

                // Save GameIslandInfo model
                set!(
                    world,
                    (GameIslandInfo {
                        game_id, index: game.total_island, island_id: island.island_id
                    })
                );

                // Emit EventGameUpdate
                emit!(
                    world,
                    (Event::EventGameUpdate(
                        EventGameUpdate {
                            game_id,
                            is_initialized: game.is_initialized,
                            total_user: game.total_user,
                            total_island: game.total_island,
                            total_dragon: game.total_dragon,
                            total_scout: game.total_scout,
                            total_journey: game.total_journey,
                            cur_map_sizes: game.cur_map_sizes,
                            cur_map_coordinates: game.cur_map_coordinates,
                            cur_sub_block_pos_id_index: game.cur_sub_block_pos_id_index,
                            cur_block_coordinates: game.cur_block_coordinates,
                            cur_map_expanding_num: game.cur_map_expanding_num
                        }
                    ))
                );

                // Emit EventGameIslandUpdate
                emit!(
                    world,
                    (Event::EventGameIslandUpdate(
                        EventGameIslandUpdate {
                            game_id, index: game.total_island, island_id: island.island_id
                        }
                    ))
                );

                // Save GameInfo model
                set!(world, (game));

                i = i + 1;
            };

            true
        }

        // See IActions-update_resources
        fn update_resources(
            world: IWorldDispatcher, game_id: usize, island_ids: Array<usize>
        ) -> bool {
            let game = get!(world, (game_id), GameInfo);

            // Check whether the game is has been initialized or not
            assert(game.is_initialized == 1, Messages::GAME_NOT_INITIALIZED);

            // Check caller
            let caller = get_caller_address();
            assert(caller == ADMIN_ADDRESS.try_into().unwrap(), Messages::NOT_ADMIN);

            // Verify the input array length
            assert(island_ids.len().is_non_zero(), Messages::INVALID_ARRAY_LENGTH);

            let epoch_timestamp: u64 = 1715247000; // 09/05/2024 09:30:00 GMT
            let cur_block_timestamp: u64 = get_block_timestamp();
            let mut i: u32 = 0;
            loop {
                if (i == island_ids.len()) {
                    break;
                }

                let island_id = *island_ids.at(i);
                let mut island = get!(world, (game_id, island_id), Island);
                let last_resources_update = island.last_resources_update;

                // Check if the island has reached its maximum resource capacity
                let island_cur_resources = island.cur_resources;
                let island_max_resources = island.max_resources;
                assert(
                    island_cur_resources.food < island_max_resources.food
                        || island_cur_resources.stone < island_max_resources.stone,
                    Messages::ISLAND_REACHED_MAX_RESOURCES_CAP
                );

                // Check if the time has passed to the next minute frames from the last resources update
                let last_resources_update_lower_minutes_bound = epoch_timestamp
                    + ((last_resources_update - epoch_timestamp) / 60) * 60;

                assert(
                    cur_block_timestamp >= last_resources_update_lower_minutes_bound + 60,
                    Messages::NOT_TIME_TO_UPDATE_YET
                );

                // Calculate the time passed and updating resources
                let cur_block_timestamp_lower_minutes_bound = epoch_timestamp
                    + ((cur_block_timestamp - epoch_timestamp) / 60) * 60;

                let sec_elapsed = cur_block_timestamp_lower_minutes_bound
                    - last_resources_update_lower_minutes_bound; // Get the seconds elapsed between the 2 bounds
                assert(sec_elapsed % 60 == 0, Messages::INVALID_SECS_ELAPSED);

                let min_elapsed: u32 = (sec_elapsed / 60)
                    .try_into()
                    .unwrap(); // Get the number of minutes elapsed between the 2 bounds

                let mining_foods = island.food_mining_speed * min_elapsed;
                let mining_stones = island.stone_mining_speed * min_elapsed;

                if (island_cur_resources.food + mining_foods >= island_max_resources.food) {
                    island.cur_resources.food = island_max_resources.food;
                } else {
                    island.cur_resources.food += mining_foods;
                }

                if (island_cur_resources.stone + mining_stones >= island_max_resources.stone) {
                    island.cur_resources.stone = island_max_resources.stone;
                } else {
                    island.cur_resources.stone += mining_stones;
                }

                island.last_resources_update = cur_block_timestamp;

                set!(world, (island));

                i = i + 1;
            };

            true
        }
    }
}
