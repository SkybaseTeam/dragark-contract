use starknet::get_block_timestamp;

#[derive(Model, Copy, Drop, Serde)]
struct SubBlockPos {
    #[key]
    game_id: usize,
    #[key]
    index: u8,
    pos_id: u32
}

#[derive(Model, Copy, Drop, Serde)]
struct NextBlockDirection {
    #[key]
    game_id: usize,
    right_1: u32,
    down_2: u32,
    left_3: u32,
    up_4: u32,
    right_5: u32,
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
struct Position {
    x: u32,
    y: u32
}

trait PositionTrait {
    fn init_position(id: usize, size: u32) -> Position;

    fn ran_sub_block_pos_id(block_coordinates: Position) -> Array<u32>;
}

impl PositionImpl of PositionTrait {
    fn init_position(id: usize, size: u32) -> Position {
        let data_x: Array<felt252> = array![id.into(), 'data_x', get_block_timestamp().into()];
        let data_y: Array<felt252> = array![id.into(), 'data_y', get_block_timestamp().into()];

        // Randomize x coordinates
        let mut hash_x: u256 = poseidon::poseidon_hash_span(data_x.span()).into();
        let x: u32 = (hash_x % size.into()).try_into().unwrap();

        // Randomize y coordinates
        let mut hash_y: u256 = poseidon::poseidon_hash_span(data_y.span()).into();
        let y: u32 = (hash_y % size.into()).try_into().unwrap();

        return Position { x, y };
    }

    fn ran_sub_block_pos_id(block_coordinates: Position) -> Array<u32> {
        let mut arr: Array<u32> = array![1, 2, 3, 4, 5, 6, 7, 8, 9];
        let mut id_1: u32 = 0;
        let mut id_2: u32 = 0;
        let mut id_3: u32 = 0;
        let mut id_4: u32 = 0;
        let mut id_5: u32 = 0;
        let mut id_6: u32 = 0;
        let mut id_7: u32 = 0;
        let mut id_8: u32 = 0;
        let mut id_9: u32 = 0;
        let mut i: u32 = 0;
        loop {
            if (i == 9) {
                break;
            }

            // Prepare data to randomize 
            let mut data_pos_id: Array<felt252> = array![
                block_coordinates.x.into(),
                block_coordinates.y.into(),
                i.into(),
                get_block_timestamp().into()
            ];

            // Randomize
            let mut hash_data_pos_id: u256 = poseidon::poseidon_hash_span(data_pos_id.span())
                .into();
            let index: u8 = (hash_data_pos_id % (9 - i.into())).try_into().unwrap();
            let id = *arr.at(index.into());

            if (i == 0) {
                id_1 = id;
            } else if (i == 1) {
                id_2 = id;
            } else if (i == 2) {
                id_3 = id;
            } else if (i == 3) {
                id_4 = id;
            } else if (i == 4) {
                id_5 = id;
            } else if (i == 5) {
                id_6 = id;
            } else if (i == 6) {
                id_7 = id;
            } else if (i == 7) {
                id_8 = id;
            } else if (i == 8) {
                id_9 = id;
            }

            // "Remove" the id out of the array
            arr = array![];
            let mut j = 0;
            loop {
                if (j == 9) {
                    break;
                }
                if ((j + 1) != id_1
                    && (j + 1) != id_2
                    && (j + 1) != id_3
                    && (j + 1) != id_4
                    && (j + 1) != id_5
                    && (j + 1) != id_6
                    && (j + 1) != id_7
                    && (j + 1) != id_8
                    && (j + 1) != id_9) {
                    arr.append(j + 1);
                }

                j = j + 1;
            };

            i = i + 1;
        };

        // array![id_1, id_2, id_3, id_4, id_5, id_6, id_7, id_8, id_9]
        array![1, 2, 3, 4, 5, 6, 7, 8, 9]
    }
}
