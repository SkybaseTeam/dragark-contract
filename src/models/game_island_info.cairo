#[derive(Model, Drop, Serde)]
struct GameIslandInfo {
    #[key]
    game_id: usize,
    #[key]
    index: u32,
    island_id: usize
}
