#[derive(Model, Drop, Serde)]
struct Game {
    #[key]
    game_id: usize, // Game's ID
    total_user: u32, // Game's total user
    total_island: u32, // Game's total island, used for Island's ID
    total_dragon: u32, // Game's total dragon, used for Dragon's ID
    total_transport: u32, // Game's total dragon transport, used for Transportation's ID
    is_full: bool, // Whether the game is full of players or not
}
