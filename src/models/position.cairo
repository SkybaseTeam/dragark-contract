#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
struct Position {
    x: u32,
    y: u32
}

trait PositionTrait {
    fn init_position(id: usize, size: u32) -> Position;
}

impl PositionImpl of PositionTrait {
    fn init_position(id: usize, size: u32) -> Position {
        let mut data: Array<felt252> = array![id.into()];

        // Randomize x coordinates
        let mut hash_x: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let x: u32 = (hash_x % size.into()).try_into().unwrap();

        // Randomize y coordinates
        let mut hash_y: u256 = poseidon::poseidon_hash_span(data.span()).into();
        let y: u32 = (hash_y % size.into()).try_into().unwrap();

        return Position { x, y };
    }
}
