use dragark::models::position::Position;
use dragark::models::island::Resource;

#[dojo::interface]
trait IActions {
    // Function for user joining the game
    // Only callable for users who haven't joined the game
    fn join_game() -> bool;

    // Function for sending dragon to scout the map
    fn scout(dragon_id: usize, destination: Position) -> Position;

    // Function for finishing scout transport
    fn finish_scout(transport_id: felt252) -> bool;

    // Function for sending dragon to capture island
    fn capture_island(
        dragon_id: usize,
        island_capturing_id: usize,
        resources_island_id: usize,
        resources: Resource
    );

    // Function for finishing capturing island
    fn finish_capture_island(transport_id: felt252) -> bool;

    // Function for sending dragon to transport resources
    fn transport(dragon_id: usize, island_from_id: usize, island_to_id: usize, resources: Resource);

    // Function for finishing transport and updating model's state
    fn finish_transport(transport_id: felt252) -> bool;
}

#[dojo::contract]
mod actions {
    use alexandria_storage::list::{List, ListTrait};
    use core::integer::u32_sqrt;
    use core::integer::BoundedU32;
    use core::Zeroable;
    use dragark::constants::island::{MAX_FOOD_STAT, MAX_STONE_STAT};
    use dragark::constants::game::GAME_HASH;
    use dragark::constants::dragon::DRAGON_BONUS;
    use dragark::messages::error::Messages;
    use dragark::models::user::{User};
    use dragark::models::game::{Game};
    use dragark::models::dragon::{Dragon, DragonElement, DragonState, DragonTrait};
    use dragark::models::island::{
        Island, IslandType, IslandSubType, Resource, IslandState, IslandTrait
    };
    use dragark::models::island_dragon_defending::IslandDragonDefending;
    use dragark::models::user_island_owned::UserIslandOwned;
    use dragark::models::user_dragon_owned::UserDragonOwned;
    use dragark::models::position::Position;
    use dragark::models::dragon_island_transport::DragonIslandTransport;
    use dragark::models::dragon_scout_transport::DragonScoutTransport;
    use dragark::models::dragon_island_capture_transport::{
        DragonIslandCaptureTransport, AttackType, AttackResult
    };
    use super::IActions;
    use starknet::ContractAddress;
    use starknet::{get_caller_address, get_block_timestamp};

    #[derive(Drop, starknet::Event)]
    struct GameUpdate {
        game_id: usize, // Game's ID
        total_user: u32, // Game's total user
        total_island: u32, // Game's total island, used for Island's ID
        total_dragon: u32, // Game's total dragon, used for Dragon's ID
        total_transport: u32, // Game's total dragon transport, used for Transportation's ID
        is_full: bool, // Whether the game is full of players or not
    }

    #[derive(Drop, starknet::Event)]
    struct IslandDragonDefendingUpdate {
        island_id: usize, // Island's ID
        dragons_defending_id: u32,
        dragons_defending: usize,
    }

    #[derive(Drop, starknet::Event)]
    struct NewUser {
        player: ContractAddress,
        area_opened: u32,
        num_islands_owned: u32,
        num_dragons_owned: u32
    }

    #[derive(Drop, starknet::Event)]
    struct UserDragonOwnedUpdate {
        player: ContractAddress,
        dragons_owned_id: u32,
        dragons_owned: usize,
    }

    #[derive(Drop, starknet::Event)]
    struct UserIslandOwnedUpdate {
        player: ContractAddress,
        islands_owned_id: u32,
        islands_owned: usize,
    }

    #[derive(Drop, starknet::Event)]
    struct NewIsland {
        island_id: usize,
        owner: ContractAddress,
        position: Position,
        island_type: IslandType,
        island_sub_type: IslandSubType,
        max_resources: Resource,
        cur_resources: Resource,
        level: u8,
        num_dragons_defending: u32,
        state: IslandState
    }

    #[derive(Drop, starknet::Event)]
    struct NewDragon {
        dragon_id: usize,
        owner: ContractAddress,
        speed: u8,
        attack: u8,
        max_capacity: Resource,
        cur_capacity: Resource,
        element: DragonElement,
        island_defending: usize,
        island_attacking: usize,
        state: DragonState
    }

    #[derive(Drop, starknet::Event)]
    struct IslandTransport {
        transport_id: felt252,
        dragon: usize,
        owner: ContractAddress,
        resources: Resource,
        island_from: usize,
        island_to: usize,
        start_time: u64,
        end_time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct IslandTransportFinish {
        transport_id: felt252,
        status: bool
    }

    #[derive(Drop, starknet::Event)]
    struct ScoutTransport {
        transport_id: felt252,
        dragon: usize,
        owner: ContractAddress,
        island_from: usize,
        destination: Position,
        start_time: u64,
        end_time: u64
    }

    #[derive(Drop, starknet::Event)]
    struct ScoutTransportFinish {
        transport_id: felt252,
        destination: Position,
        status: bool
    }

    #[derive(Drop, starknet::Event)]
    struct IslandCaptureTransport {
        transport_id: felt252,
        dragon: usize,
        owner: ContractAddress,
        resources: Resource,
        resources_island: usize,
        island_capturing: usize,
        start_time: u64,
        end_time: u64,
        attack_type: AttackType
    }

    #[derive(Drop, starknet::Event)]
    struct IslandCaptureFinish {
        transport_id: felt252,
        attack_result: AttackResult,
        status: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        GameUpdate: GameUpdate,
        NewUser: NewUser,
        IslandDragonDefendingUpdate: IslandDragonDefendingUpdate,
        UserDragonOwnedUpdate: UserDragonOwnedUpdate,
        UserIslandOwnedUpdate: UserIslandOwnedUpdate,
        NewIsland: NewIsland,
        NewDragon: NewDragon,
        IslandTransport: IslandTransport,
        IslandTransportFinish: IslandTransportFinish,
        ScoutTransport: ScoutTransport,
        ScoutTransportFinish: ScoutTransportFinish,
        IslandCaptureTransport: IslandCaptureTransport,
        IslandCaptureFinish: IslandCaptureFinish
    }

    #[abi(embed_v0)]
    impl IActionsImpl of IActions<ContractState> {
        fn join_game(world: IWorldDispatcher) -> bool {
            let caller = get_caller_address();

            let player = get!(world, (caller), User);
            let game = get!(world, (GAME_HASH), Game);

            // Check whether the user has joined or not
            assert(player.area_opened == 0, Messages::PLAYER_EXISTED);

            let u32_max = BoundedU32::max();

            let data_island: Array<felt252> = array![(game.total_island + 1).into()];
            let mut island_id_u256: u256 = poseidon::poseidon_hash_span(data_island.span())
                .try_into()
                .unwrap();
            let island_id: usize = (island_id_u256 % u32_max.into()).try_into().unwrap();

            let data_dragon: Array<felt252> = array![(game.total_dragon + 1).into()];
            let mut dragon_id_u256: u256 = poseidon::poseidon_hash_span(data_dragon.span())
                .try_into()
                .unwrap();
            let dragon_id: usize = (dragon_id_u256 % u32_max.into()).try_into().unwrap();

            // Initialize island
            let mut island = IslandTrait::init_island(
                island_id, caller, IslandType::ResourceIsland
            );

            // Initialize dragon
            let mut dragon = DragonTrait::init_dragon(dragon_id, caller);

            // Save island
            set!(
                world,
                (IslandDragonDefending {
                    island_id: island_id,
                    dragons_defending_id: 0,
                    dragons_defending: dragon.dragon_id
                })
            );

            island.num_dragons_defending = 1;
            set!(world, (island));

            // Save dragon
            dragon.island_defending = island.island_id;
            set!(world, (dragon));

            // Save user
            set!(
                world,
                (UserDragonOwned {
                    player: caller, dragons_owned_id: 0, dragons_owned: dragon.dragon_id
                })
            );
            set!(
                world,
                (UserIslandOwned {
                    player: caller, islands_owned_id: 0, islands_owned: island.island_id
                })
            );

            set!(
                world,
                (User {
                    player: caller,
                    area_opened: player.area_opened + 1,
                    num_islands_owned: 1,
                    num_dragons_owned: 1
                })
            );

            // Save game
            set!(
                world,
                (Game {
                    game_id: GAME_HASH.try_into().unwrap(),
                    total_user: game.total_user + 1,
                    total_island: game.total_island + 1,
                    total_dragon: game.total_dragon + 1,
                    total_transport: game.total_transport,
                    is_full: false
                })
            );

            // Emit event new island created
            emit!(
                world,
                (Event::NewIsland(
                    NewIsland {
                        island_id: island.island_id,
                        owner: island.owner,
                        position: island.position,
                        island_type: island.island_type,
                        island_sub_type: island.island_sub_type,
                        max_resources: island.max_resources,
                        cur_resources: island.cur_resources,
                        level: island.level,
                        num_dragons_defending: island.num_dragons_defending,
                        state: island.state
                    }
                ))
            );

            // Emit event IslandDragonDefending model update
            emit!(
                world,
                (Event::IslandDragonDefendingUpdate(
                    IslandDragonDefendingUpdate {
                        island_id: island.island_id, // Island's ID
                        dragons_defending_id: 0,
                        dragons_defending: dragon.dragon_id,
                    }
                ))
            );

            // Emit event new dragon created
            emit!(
                world,
                (Event::NewDragon(
                    NewDragon {
                        dragon_id: dragon.dragon_id,
                        owner: dragon.owner,
                        speed: dragon.speed,
                        attack: dragon.attack,
                        max_capacity: dragon.max_capacity,
                        cur_capacity: dragon.cur_capacity,
                        element: dragon.element,
                        island_defending: island.island_id,
                        island_attacking: dragon.island_attacking,
                        state: dragon.state
                    }
                ))
            );

            // Emit event user update
            emit!(
                world,
                (Event::NewUser(
                    NewUser {
                        player: caller,
                        area_opened: player.area_opened + 1,
                        num_islands_owned: 1,
                        num_dragons_owned: 1
                    }
                ))
            );

            // Emit event UserDragonOwned model update
            emit!(
                world,
                (Event::UserDragonOwnedUpdate(
                    UserDragonOwnedUpdate {
                        player: caller, dragons_owned_id: 0, dragons_owned: dragon.dragon_id,
                    }
                ))
            );

            // Emit event UserIslandOwnedUpdate model update
            emit!(
                world,
                (Event::UserIslandOwnedUpdate(
                    UserIslandOwnedUpdate {
                        player: caller, islands_owned_id: 0, islands_owned: island.island_id,
                    }
                ))
            );

            // Emit event Game model update
            emit!(
                world,
                (Event::GameUpdate(
                    GameUpdate {
                        game_id: GAME_HASH.try_into().unwrap(),
                        total_user: game.total_user + 1,
                        total_island: game.total_island + 1,
                        total_dragon: game.total_dragon + 1,
                        total_transport: game.total_transport,
                        is_full: false
                    }
                ))
            );

            true
        }

        fn scout(world: IWorldDispatcher, dragon_id: usize, destination: Position) -> Position {
            let caller = get_caller_address();

            let game = get!(world, (GAME_HASH), Game);

            // Check if the player has the dragon
            let player = get!(world, (caller), User);
            let mut is_dragon_owned: bool = false;
            let mut i: u32 = 0;
            loop {
                if (i == player.num_dragons_owned.into()) {
                    break;
                }
                let dragon_owned = get!(world, (caller, i), UserDragonOwned).dragons_owned;
                if (dragon_owned == dragon_id) {
                    is_dragon_owned = true;
                    break;
                }
                i = i + 1;
            };
            assert(is_dragon_owned, Messages::NOT_OWN_DRAGON);

            // Check dragon is on idling state
            let mut dragon = get!(world, (dragon_id, caller), Dragon);
            assert(dragon.state == DragonState::Idling, Messages::DRAGON_IS_NOT_AVAILABLE);

            // Check if the player has the island the dragon is defending
            let island_defending = dragon.island_defending;
            let mut is_island_owned: bool = false;
            let mut j: u32 = 0;
            loop {
                if (j == player.num_islands_owned.into()) {
                    break;
                }
                let island_owned = get!(world, (caller, j), UserIslandOwned).islands_owned;
                if (island_owned == island_defending) {
                    is_island_owned = true;
                    break;
                }
                j = j + 1;
            };
            assert(is_island_owned, Messages::NOT_OWN_ISLAND);

            // Calculate the distance
            let island_defending_position = get!(world, (island_defending), Island).position;

            let mut x_distance = 0;
            if (destination.x >= island_defending_position.x) {
                x_distance = destination.x - island_defending_position.x;
            } else {
                x_distance = island_defending_position.x - destination.x;
            }

            let mut y_distance = 0;
            if (destination.y >= island_defending_position.y) {
                y_distance = destination.y - island_defending_position.y;
            } else {
                y_distance = island_defending_position.y - destination.y;
            }

            let distance = u32_sqrt(x_distance * x_distance + y_distance * y_distance);

            // Calculate the time for the dragon to fly
            let dragon_speed = dragon.speed;
            let time = distance / dragon_speed.into();

            let start_time = get_block_timestamp();
            let end_time = start_time + time.into();

            let transport_id_data: Array<felt252> = array![(game.total_transport + 1).into()];
            let transport_id = poseidon::poseidon_hash_span(transport_id_data.span());

            // Save the dragon state
            dragon.state == DragonState::Flying;
            set!(world, (dragon));

            // Save transport
            set!(
                world,
                (DragonScoutTransport {
                    transport_id: transport_id,
                    dragon: dragon_id,
                    owner: caller,
                    island_from: island_defending,
                    destination: destination,
                    start_time: start_time,
                    end_time: end_time,
                    status: false
                })
            );

            // Emit event
            emit!(
                world,
                (Event::ScoutTransport(
                    ScoutTransport {
                        transport_id: transport_id,
                        dragon: dragon_id,
                        owner: caller,
                        island_from: island_defending,
                        destination: destination,
                        start_time: start_time,
                        end_time: end_time
                    }
                ))
            );

            destination
        }

        // Function for finishing scout transport
        fn finish_scout(world: IWorldDispatcher, transport_id: felt252) -> bool {
            let mut transport_info = get!(world, transport_id, DragonScoutTransport);

            let mut game = get!(world, (GAME_HASH), Game);

            // Check time
            assert(
                get_block_timestamp() >= transport_info.end_time, Messages::TRANSPORT_IN_PROGRESS
            );

            // Check status
            assert(!transport_info.status, Messages::ALREADY_FINISHED);

            // Check dragon state
            let mut dragon = get!(world, (transport_info.dragon, transport_info.owner), Dragon);
            assert(dragon.state == DragonState::Flying, Messages::INVALID_DRAGON_STATE);

            // Update dragon state
            dragon.state = DragonState::Idling;
            set!(world, (dragon));

            // Update the transport status
            transport_info.status = true;
            set!(world, (transport_info));

            // Save game
            set!(
                world,
                (Game {
                    game_id: game.game_id,
                    total_user: game.total_user,
                    total_island: game.total_island,
                    total_dragon: game.total_dragon,
                    total_transport: game.total_transport + 1,
                    is_full: game.is_full
                })
            );

            // Emit event ScoutTransportFinish
            emit!(
                world,
                (Event::ScoutTransportFinish(
                    ScoutTransportFinish {
                        transport_id: transport_id,
                        destination: transport_info.destination,
                        status: true
                    }
                ))
            );

            // Emit event GameUpdate
            emit!(
                world,
                (Event::GameUpdate(
                    GameUpdate {
                        game_id: game.game_id,
                        total_user: game.total_user,
                        total_island: game.total_island,
                        total_dragon: game.total_dragon,
                        total_transport: game.total_transport + 1,
                        is_full: game.is_full
                    }
                ))
            );

            true
        }

        fn capture_island(
            world: IWorldDispatcher,
            dragon_id: usize,
            island_capturing_id: usize,
            resources_island_id: usize,
            resources: Resource
        ) {
            let caller = get_caller_address();

            let game = get!(world, (GAME_HASH), Game);

            // Check if the player has the dragon
            let player = get!(world, (caller), User);
            let mut is_dragon_owned: bool = false;
            let mut i: u32 = 0;
            loop {
                if (i == player.num_dragons_owned.into()) {
                    break;
                }
                let dragon_owned = get!(world, (caller, i), UserDragonOwned).dragons_owned;
                if (dragon_owned == dragon_id) {
                    is_dragon_owned = true;
                    break;
                }
                i = i + 1;
            };
            assert(is_dragon_owned, Messages::NOT_OWN_DRAGON);

            // Check if the player has the resources island
            let mut is_island_owned: bool = false;
            let mut j = 0;
            loop {
                if (j == player.num_islands_owned.into()) {
                    break;
                }
                let island_owned = get!(world, (caller, j), UserIslandOwned).islands_owned;
                if (island_owned == resources_island_id) {
                    is_island_owned = true;
                    break;
                }
                j = j + 1;
            };
            assert(is_island_owned, Messages::NOT_OWN_ISLAND);

            // Check the resources island is on idling state
            let resources_island = get!(world, (resources_island_id), Island);
            assert(resources_island.state == IslandState::Idling, Messages::ISLAND_IS_IN_WARRING);

            // Check the dragon is on idling state
            let mut dragon = get!(world, (dragon_id, caller), Dragon);
            assert(dragon.state == DragonState::Idling, Messages::DRAGON_IS_NOT_AVAILABLE);

            // Check the resources island has enough resources
            let resources_island_resources = resources_island.cur_resources;
            assert(resources.food <= resources_island_resources.food, Messages::NOT_ENOUGH_FOOD);
            assert(resources.stone <= resources_island_resources.stone, Messages::NOT_ENOUGH_STONE);

            // Check whether the island capturing exists
            let island_capturing = get!(world, (island_capturing_id), Island);
            assert(island_capturing.max_resources.food != 0, Messages::ISLAND_NOT_EXISTS);

            // Get the attack type (Attack the derelict island/Attack the user's island) based on island's owner
            let mut attack_type = AttackType::DerelictIslandAttack;
            if (island_capturing.owner != Zeroable::zero()) {
                attack_type = AttackType::UserIslandAttack;
            }

            // Calculate the distance between the two island
            let island_from_position = resources_island.position;
            let island_to_position = island_capturing.position;

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
            let end_time = start_time + time.into();

            let transport_id_data: Array<felt252> = array![(game.total_transport + 1).into()];
            let transport_id = poseidon::poseidon_hash_span(transport_id_data.span());

            // Save the dragon state
            dragon.state = DragonState::Flying;
            set!(world, (dragon));

            // Save transport
            set!(
                world,
                (DragonIslandCaptureTransport {
                    transport_id: transport_id,
                    dragon: dragon_id,
                    owner: caller,
                    resources: resources,
                    resources_island: resources_island_id,
                    island_capturing: island_capturing_id,
                    start_time: start_time,
                    end_time: end_time,
                    attack_type: attack_type,
                    attack_result: AttackResult::Unknown,
                    status: false
                })
            );

            // Emit event
            emit!(
                world,
                (Event::IslandCaptureTransport(
                    IslandCaptureTransport {
                        transport_id: transport_id,
                        dragon: dragon_id,
                        owner: caller,
                        resources: resources,
                        resources_island: resources_island_id,
                        island_capturing: island_capturing_id,
                        start_time: start_time,
                        end_time: end_time,
                        attack_type: attack_type,
                    }
                ))
            );
        }

        fn finish_capture_island(world: IWorldDispatcher, transport_id: felt252) -> bool {
            // Get transport info
            let mut transport_info = get!(world, transport_id, DragonIslandCaptureTransport);

            // Get island capturing & resources island
            let mut island_capturing = get!(world, transport_info.island_capturing, Island);
            let mut resources_island = get!(world, transport_info.resources_island, Island);

            // Get capturing user and captured user
            let mut capturing_user = get!(world, transport_info.owner, User);
            let mut captured_user = get!(world, island_capturing.owner, User);

            // Get game
            let mut game = get!(world, (GAME_HASH), Game);

            // Check time
            assert(
                get_block_timestamp() >= transport_info.end_time, Messages::TRANSPORT_IN_PROGRESS
            );

            // Check status
            assert(
                !transport_info.status && transport_info.attack_result == AttackResult::Unknown,
                Messages::ALREADY_FINISHED
            );

            // Check dragon state
            let mut dragon = get!(world, (transport_info.dragon, transport_info.owner), Dragon);
            assert(dragon.state == DragonState::Flying, Messages::INVALID_DRAGON_STATE);

            // Update the resources island state
            resources_island.cur_resources.food -= transport_info.resources.food;

            set!(world, (resources_island));

            // Calculate combat power
            let user_combat_power: u16 = transport_info.resources.food
                + (dragon.attack.into() * DRAGON_BONUS / 100);

            let mut island_combat_power: u16 = island_capturing.cur_resources.food;

            if (transport_info.attack_type == AttackType::UserIslandAttack) {
                let mut index: u32 = 0;
                loop {
                    if (index == island_capturing.num_dragons_defending.into()) {
                        break;
                    }

                    let dragon_defending = get!(
                        world, (transport_info.island_capturing, index), IslandDragonDefending
                    );

                    island_combat_power +=
                        get!(
                            world,
                            (dragon_defending.dragons_defending, island_capturing.owner),
                            Dragon
                        )
                        .attack
                        .into()
                        * DRAGON_BONUS
                        / 100;

                    index = index + 1;
                };
            }

            let mut attack_result = AttackResult::Unknown;
            // Decide whether user wins or loses and update state
            if (user_combat_power > island_combat_power) {
                // Set the attack result
                transport_info.attack_result = AttackResult::Win;
                attack_result = AttackResult::Win;

                // Set the owner of the captured island
                island_capturing.owner = transport_info.owner;

                // Set the captured island resources
                if (user_combat_power
                    - island_combat_power <= island_capturing.max_resources.food) {
                    island_capturing.cur_resources.food = user_combat_power - island_combat_power;
                } else {
                    island_capturing.cur_resources.food = island_capturing.max_resources.food;
                }

                // Update capturing user island owned
                let mut capturing_user_island_owned = get!(
                    world,
                    (capturing_user.player, capturing_user.num_islands_owned),
                    UserIslandOwned
                );
                capturing_user_island_owned.islands_owned = island_capturing.island_id;

                if (transport_info.attack_type == AttackType::UserIslandAttack) {
                    // Update captured user island owned
                    let mut i: u32 = 0;
                    loop {
                        if (i == captured_user.num_islands_owned.into()) {
                            break;
                        }
                        let island_owned = get!(world, (captured_user.player, i), UserIslandOwned)
                            .islands_owned;
                        if (island_owned == island_capturing.island_id) {
                            break;
                        }
                        i = i + 1;
                    }; // Get the island captured index

                    let mut captured_user_island_owned = get!(
                        world, (captured_user.player, i), UserIslandOwned
                    );
                    if (i == captured_user.num_islands_owned.into() - 1) {
                        captured_user_island_owned.islands_owned = 0;

                        // Emit event
                        emit!(
                            world,
                            (Event::UserIslandOwnedUpdate(
                                UserIslandOwnedUpdate {
                                    player: captured_user.player,
                                    islands_owned_id: i,
                                    islands_owned: 0
                                }
                            ))
                        );
                    } else {
                        let mut last_user_island_owned = get!(
                            world,
                            (captured_user.player, captured_user.num_islands_owned - 1),
                            UserIslandOwned
                        );
                        captured_user_island_owned
                            .islands_owned = last_user_island_owned
                            .islands_owned;

                        // Emit event
                        emit!(
                            world,
                            (Event::UserIslandOwnedUpdate(
                                UserIslandOwnedUpdate {
                                    player: captured_user.player,
                                    islands_owned_id: i,
                                    islands_owned: last_user_island_owned.islands_owned
                                }
                            ))
                        );

                        emit!(
                            world,
                            (Event::UserIslandOwnedUpdate(
                                UserIslandOwnedUpdate {
                                    player: captured_user.player,
                                    islands_owned_id: captured_user.num_islands_owned - 1,
                                    islands_owned: 0
                                }
                            ))
                        );

                        last_user_island_owned.islands_owned = 0;
                    }

                    // Update captured island's dragon defending & number of dragons defending
                    let mut j: u32 = 0;
                    loop {
                        if (j == island_capturing.num_dragons_defending.into()) {
                            break;
                        }

                        let mut dragon_defending = get!(
                            world, (island_capturing.island_id, i), IslandDragonDefending
                        );

                        // Update Dragon model
                        let mut defending_dragon_model = get!(
                            world, dragon_defending.dragons_defending, Dragon
                        );
                        defending_dragon_model.island_defending = 0;
                        set!(world, (defending_dragon_model));

                        dragon_defending.dragons_defending = 0;
                        set!(world, (dragon_defending));

                        // Emit event
                        emit!(
                            world,
                            (Event::IslandDragonDefendingUpdate(
                                IslandDragonDefendingUpdate {
                                    island_id: island_capturing.island_id,
                                    dragons_defending_id: j,
                                    dragons_defending: 0
                                }
                            ))
                        );

                        j = j + 1;
                    };
                    island_capturing.num_dragons_defending = 0;

                    captured_user.num_islands_owned -= 1;

                    set!(world, (captured_user_island_owned));
                }

                // Emit event capturing user island owned update
                emit!(
                    world,
                    (Event::UserIslandOwnedUpdate(
                        UserIslandOwnedUpdate {
                            player: capturing_user.player,
                            islands_owned_id: capturing_user.num_islands_owned,
                            islands_owned: island_capturing.island_id
                        }
                    ))
                );
                capturing_user.num_islands_owned += 1;

                set!(world, (capturing_user_island_owned));
            } else {
                // Set the attack result
                transport_info.attack_result = AttackResult::Lose;
                attack_result = AttackResult::Lose;

                // Set the captured island resources
                if (island_combat_power > user_combat_power && island_combat_power
                    - user_combat_power <= island_capturing.max_resources.food) {
                    island_capturing.cur_resources.food -= island_combat_power - user_combat_power;
                } else if (island_combat_power
                    - user_combat_power > island_capturing.max_resources.food) {
                    island_capturing.cur_resources.food = island_capturing.max_resources.food;
                } else {
                    island_capturing.cur_resources.food = 0;
                }
            }
            set!(world, (island_capturing));
            set!(world, (capturing_user));
            set!(world, (captured_user));

            // Update dragon state
            dragon.state = DragonState::Idling;
            set!(world, (transport_info));

            // Update the transport status
            transport_info.status = true;
            set!(world, (transport_info));

            // Save world
            set!(
                world,
                (Game {
                    game_id: game.game_id,
                    total_user: game.total_user,
                    total_island: game.total_island,
                    total_dragon: game.total_dragon,
                    total_transport: game.total_transport + 1,
                    is_full: game.is_full
                })
            );

            // Emit event IslandCaptureFinish
            emit!(
                world,
                (Event::IslandCaptureFinish(
                    IslandCaptureFinish {
                        transport_id: transport_id, attack_result: attack_result, status: true
                    }
                ))
            );

            // Emit event GameUpdate
            emit!(
                world,
                (Event::GameUpdate(
                    GameUpdate {
                        game_id: game.game_id,
                        total_user: game.total_user,
                        total_island: game.total_island,
                        total_dragon: game.total_dragon,
                        total_transport: game.total_transport + 1,
                        is_full: game.is_full
                    }
                ))
            );

            true
        }

        fn transport(
            world: IWorldDispatcher,
            dragon_id: usize,
            island_from_id: usize,
            island_to_id: usize,
            resources: Resource
        ) {
            let caller = get_caller_address();

            let game = get!(world, (GAME_HASH), Game);

            // Check that the island_from is different from island_to
            assert(island_from_id != island_to_id, Messages::TRANSPORT_TO_THE_SAME_ISLAND);

            // Check if the player has the dragon
            let player = get!(world, (caller), User);
            let mut is_dragon_owned: bool = false;
            let mut i: u32 = 0;
            loop {
                if (i == player.num_dragons_owned.into()) {
                    break;
                }
                let dragon_owned = get!(world, (caller, i), UserDragonOwned).dragons_owned;
                if (dragon_owned == dragon_id) {
                    is_dragon_owned = true;
                    break;
                }
                i = i + 1;
            };
            assert(is_dragon_owned, Messages::NOT_OWN_DRAGON);

            // Check if the player has the island
            let mut is_island_from_owned: bool = false;
            let mut is_island_to_owned: bool = false;
            let mut j: u32 = 0;
            loop {
                if (j == player.num_islands_owned.into()) {
                    break;
                }
                let island_owned = get!(world, (caller, j), UserIslandOwned).islands_owned;
                if (island_owned == island_from_id) {
                    is_island_from_owned = true;
                } else if (island_owned == island_to_id) {
                    is_island_to_owned = true;
                }
                if (is_island_from_owned && is_island_to_owned) {
                    break;
                }
                j = j + 1;
            };
            assert(is_island_from_owned && is_island_to_owned, Messages::NOT_OWN_ISLAND);

            // Check the island is on idling state
            let island_from = get!(world, (island_from_id), Island);
            let island_to = get!(world, (island_to_id), Island);
            assert(
                island_from.state == IslandState::Idling && island_to.state == IslandState::Idling,
                Messages::ISLAND_IS_IN_WARRING
            );

            // Check the dragon is on idling state
            let mut dragon = get!(world, (dragon_id, caller), Dragon);
            assert(dragon.state == DragonState::Idling, Messages::DRAGON_IS_NOT_AVAILABLE);

            // Check the island_from has enough resources
            let island_from_resources = island_from.cur_resources;
            assert(resources.food <= island_from_resources.food, Messages::NOT_ENOUGH_FOOD);
            assert(resources.stone <= island_from_resources.stone, Messages::NOT_ENOUGH_STONE);

            // Check the island_to has enough capacity to receive resources
            let island_to_resources = island_to.cur_resources;
            assert(
                island_to_resources.food + resources.food <= MAX_FOOD_STAT,
                Messages::NOT_ENOUGH_RESOURCES_CAPACITY
            );
            assert(
                island_to_resources.stone + resources.stone <= MAX_STONE_STAT,
                Messages::NOT_ENOUGH_RESOURCES_CAPACITY
            );

            // Calculate the distance between the two island
            let island_from_position = island_from.position;
            let island_to_position = island_to.position;

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
            let end_time = start_time + time.into();

            let transport_id_data: Array<felt252> = array![(game.total_transport + 1).into()];
            let transport_id = poseidon::poseidon_hash_span(transport_id_data.span());

            // Save the dragon state
            dragon.state == DragonState::Flying;
            set!(world, (dragon));

            // Save transport
            set!(
                world,
                (DragonIslandTransport {
                    transport_id: transport_id,
                    dragon: dragon_id,
                    owner: caller,
                    resources: resources,
                    island_from: island_from_id,
                    island_to: island_to_id,
                    start_time: start_time,
                    end_time: end_time,
                    status: false,
                })
            );

            // Emit event
            emit!(
                world,
                (Event::IslandTransport(
                    IslandTransport {
                        transport_id: transport_id,
                        dragon: dragon_id,
                        owner: caller,
                        resources: resources,
                        island_from: island_from_id,
                        island_to: island_to_id,
                        start_time: start_time,
                        end_time: end_time,
                    }
                ))
            );
        }

        fn finish_transport(world: IWorldDispatcher, transport_id: felt252) -> bool {
            let mut transport_info = get!(world, transport_id, DragonIslandTransport);

            let mut game = get!(world, (GAME_HASH), Game);

            // Check time
            assert(
                get_block_timestamp() >= transport_info.end_time, Messages::TRANSPORT_IN_PROGRESS
            );

            // Check status
            assert(!transport_info.status, Messages::ALREADY_FINISHED);

            // Check dragon state
            let mut dragon = get!(world, (transport_info.dragon, transport_info.owner), Dragon);
            assert(dragon.state == DragonState::Flying, Messages::INVALID_DRAGON_STATE);

            // Update island resources state
            let mut island_from = get!(world, (transport_info.island_from), Island);
            let mut island_to = get!(world, (transport_info.island_to), Island);

            island_from.cur_resources.food -= transport_info.resources.food;
            island_from.cur_resources.stone -= transport_info.resources.stone;

            island_to.cur_resources.food += transport_info.resources.food;
            island_to.cur_resources.stone += transport_info.resources.stone;

            // Update island_from's dragons defending state
            let mut i: u32 = 0;
            loop {
                if (i == island_from.num_dragons_defending.into()) {
                    break;
                }
                let dragon_defending = get!(
                    world, (transport_info.island_from, i), IslandDragonDefending
                )
                    .dragons_defending;
                if (dragon_defending == transport_info.dragon) {
                    break;
                }
                i = i + 1;
            }; // Get the id of the dragon defending on the island_from

            let mut island_from_dragon_defending_update = get!(
                world, (transport_info.island_from, i), IslandDragonDefending
            );
            if (i == (island_from.num_dragons_defending - 1).into()) {
                island_from_dragon_defending_update.dragons_defending = 0;

                // Emit event
                emit!(
                    world,
                    (Event::IslandDragonDefendingUpdate(
                        IslandDragonDefendingUpdate {
                            island_id: transport_info.island_from,
                            dragons_defending_id: i,
                            dragons_defending: 0
                        }
                    ))
                );
            } else {
                let mut last_dragon_defending = get!(
                    world,
                    (transport_info.island_from, island_from.num_dragons_defending - 1),
                    IslandDragonDefending
                );
                island_from_dragon_defending_update
                    .dragons_defending = last_dragon_defending
                    .dragons_defending; // Set the current dragon id to the last dragon id

                // Emit event
                emit!(
                    world,
                    (Event::IslandDragonDefendingUpdate(
                        IslandDragonDefendingUpdate {
                            island_id: transport_info.island_from,
                            dragons_defending_id: i,
                            dragons_defending: last_dragon_defending.dragons_defending
                        }
                    ))
                );

                emit!(
                    world,
                    (Event::IslandDragonDefendingUpdate(
                        IslandDragonDefendingUpdate {
                            island_id: transport_info.island_from,
                            dragons_defending_id: island_from.num_dragons_defending - 1,
                            dragons_defending: 0
                        }
                    ))
                );

                last_dragon_defending.dragons_defending = 0;
                set!(world, (last_dragon_defending));
            }
            island_from.num_dragons_defending -= 1;
            set!(world, (island_from_dragon_defending_update));
            set!(world, (island_from));

            // Update island_to's dragons defending state
            let mut island_to_dragon_defending_update = get!(
                world,
                (transport_info.island_to, island_to.num_dragons_defending),
                IslandDragonDefending
            );
            island_to_dragon_defending_update.dragons_defending = transport_info.dragon;

            // Emit event
            emit!(
                world,
                (Event::IslandDragonDefendingUpdate(
                    IslandDragonDefendingUpdate {
                        island_id: transport_info.island_to,
                        dragons_defending_id: island_to.num_dragons_defending,
                        dragons_defending: transport_info.dragon
                    }
                ))
            );

            island_to.num_dragons_defending += 1;
            set!(world, (island_to_dragon_defending_update));
            set!(world, (island_to));

            // Update dragon state
            dragon.island_defending = transport_info.island_to;
            dragon.state = DragonState::Idling;
            set!(world, (dragon));

            // Update the transport status
            transport_info.status = true;
            set!(world, (transport_info));

            // Save world
            set!(
                world,
                (Game {
                    game_id: game.game_id,
                    total_user: game.total_user,
                    total_island: game.total_island,
                    total_dragon: game.total_dragon,
                    total_transport: game.total_transport + 1,
                    is_full: game.is_full
                })
            );

            // Emit event IslandTransportIsland
            emit!(
                world,
                (Event::IslandTransportFinish(
                    IslandTransportFinish { transport_id: transport_id, status: true }
                ))
            );

            // Emit event GameUpdate
            emit!(
                world,
                (Event::GameUpdate(
                    GameUpdate {
                        game_id: game.game_id,
                        total_user: game.total_user,
                        total_island: game.total_island,
                        total_dragon: game.total_dragon,
                        total_transport: game.total_transport + 1,
                        is_full: game.is_full
                    }
                ))
            );

            true
        }
    }
}
