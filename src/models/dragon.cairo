use starknet::ContractAddress;
use starknet::get_block_timestamp;
use dragark_20::models::island::Resource;

#[derive(Model, Copy, Drop, Serde)]
struct Dragon {
    #[key]
    game_id: usize,
    #[key]
    dragon_id: usize, // Dragon's ID
    owner: ContractAddress, // Dragon's owner
    model_id: DragonModelId,
    rarity: DragonRarity,
    element: DragonElement,
    title: DragonTitle,
    speed: u16, // Dragon's speed stat
    attack: u16, // Dragon's attack stat
    carrying_capacity: Resource, // Dragon's capacity stat
    state: DragonState, // Dragon's state
}

#[derive(Copy, Drop, Serde, Introspect)]
enum DragonModelId {
    r11111,
    b11111,
    n11111
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum DragonRarity {
    Common,
    Uncommon,
    Rare,
    Epic,
    Legendary
}

#[derive(Copy, Drop, Serde, Introspect)]
enum DragonElement {
    Fire,
    Water,
    Lightning,
    Darkness
}

#[derive(Copy, Drop, Serde, Introspect)]
enum DragonTitle {
    FireDragon,
    WaterDragon,
    GroundDragon
}

#[derive(Copy, Drop, Serde, Introspect, PartialEq)]
enum DragonState {
    Idling,
    Flying,
}

trait DragonTrait {
    fn init_dragon(game_id: usize, dragon_id: usize, owner: ContractAddress) -> Dragon;
}

impl DragonImpl of DragonTrait {
    fn init_dragon(game_id: usize, dragon_id: usize, owner: ContractAddress) -> Dragon {
        // Randomize model id
        let data_model_id: Array<felt252> = array![
            dragon_id.into(), 'data_model_id', get_block_timestamp().into()
        ];
        let hash_model: u256 = poseidon::poseidon_hash_span(data_model_id.span()).into();
        let model_id_num: u8 = (hash_model % 3).try_into().unwrap();
        let mut model_id: DragonModelId = DragonModelId::r11111;
        if (model_id_num == 1) {
            model_id = DragonModelId::b11111;
        } else if (model_id_num == 2) {
            model_id = DragonModelId::n11111;
        }

        // Randomize rarity
        let data_rarity: Array<felt252> = array![
            dragon_id.into(), 'data_rarity', get_block_timestamp().into()
        ];
        let hash_rarity: u256 = poseidon::poseidon_hash_span(data_rarity.span()).into();
        let rarity_num: u8 = (hash_rarity % 5).try_into().unwrap();
        let mut rarity: DragonRarity = DragonRarity::Common;
        if (rarity_num == 1) {
            rarity = DragonRarity::Uncommon;
        } else if (rarity_num == 2) {
            rarity = DragonRarity::Rare;
        } else if (rarity_num == 3) {
            rarity = DragonRarity::Epic;
        } else if (rarity_num == 4) {
            rarity = DragonRarity::Legendary;
        }

        let mut speed: u16 = 0;
        let data_speed: Array<felt252> = array![
            dragon_id.into(), 'data_speed', get_block_timestamp().into()
        ];
        let mut hash_speed: u256 = poseidon::poseidon_hash_span(data_speed.span()).into();

        let mut attack: u16 = 0;
        let data_attack: Array<felt252> = array![
            dragon_id.into(), 'data_attack', get_block_timestamp().into()
        ];
        let mut hash_attack: u256 = poseidon::poseidon_hash_span(data_attack.span()).into();

        let mut food_cap: u32 = 0;
        let data_food_cap: Array<felt252> = array![
            dragon_id.into(), 'data_food_cap', get_block_timestamp().into()
        ];
        let mut hash_food_cap: u256 = poseidon::poseidon_hash_span(data_food_cap.span()).into();

        let mut stone_cap: u32 = 0;
        let data_stone_cap: Array<felt252> = array![
            dragon_id.into(), 'data_stone_cap', get_block_timestamp().into()
        ];
        let mut hash_stone_cap: u256 = poseidon::poseidon_hash_span(data_stone_cap.span()).into();

        // Init stats based on the dragon's rarity
        if (rarity == DragonRarity::Common) {
            speed = 5 + ((hash_speed % ((9 - 5) + 1)).try_into().unwrap());
            attack = 10 + ((hash_attack % ((30 - 10) + 1)).try_into().unwrap());
            food_cap = 200 + ((hash_food_cap % ((250 - 200) + 1)).try_into().unwrap());
            stone_cap = 200 + ((hash_stone_cap % ((250 - 200) + 1)).try_into().unwrap());
        } else if (rarity == DragonRarity::Uncommon) {
            speed = 10 + ((hash_speed % ((14 - 10) + 1)).try_into().unwrap());
            attack = 35 + ((hash_attack % ((55 - 35) + 1)).try_into().unwrap());
            food_cap = 300 + ((hash_food_cap % ((350 - 300) + 1)).try_into().unwrap());
            stone_cap = 300 + ((hash_stone_cap % ((350 - 300) + 1)).try_into().unwrap());
        } else if (rarity == DragonRarity::Rare) {
            speed = 15 + ((hash_speed % ((19 - 15) + 1)).try_into().unwrap());
            attack = 60 + ((hash_attack % ((80 - 60) + 1)).try_into().unwrap());
            food_cap = 400 + ((hash_food_cap % ((450 - 400) + 1)).try_into().unwrap());
            stone_cap = 400 + ((hash_stone_cap % ((450 - 400) + 1)).try_into().unwrap());
        } else if (rarity == DragonRarity::Epic) {
            speed = 20 + ((hash_speed % ((29 - 20) + 1)).try_into().unwrap());
            attack = 85 + ((hash_attack % ((100 - 85) + 1)).try_into().unwrap());
            food_cap = 500 + ((hash_food_cap % ((600 - 500) + 1)).try_into().unwrap());
            stone_cap = 500 + ((hash_stone_cap % ((600 - 500) + 1)).try_into().unwrap());
        } else if (rarity == DragonRarity::Legendary) {
            speed = 30 + ((hash_speed % ((50 - 30) + 1)).try_into().unwrap());
            attack = 105 + ((hash_attack % ((125 - 105) + 1)).try_into().unwrap());
            food_cap = 650 + ((hash_food_cap % ((800 - 650) + 1)).try_into().unwrap());
            stone_cap = 650 + ((hash_stone_cap % ((800 - 650) + 1)).try_into().unwrap());
        }

        // Randomize element
        let data_element: Array<felt252> = array![
            dragon_id.into(), 'data_element', get_block_timestamp().into()
        ];
        let hash_element: u256 = poseidon::poseidon_hash_span(data_element.span()).into();
        let element_num: u8 = (hash_element % 4).try_into().unwrap();
        let mut element: DragonElement = DragonElement::Fire;
        if (element_num == 1) {
            element = DragonElement::Water;
        } else if (element_num == 2) {
            element = DragonElement::Lightning;
        } else if (element_num == 3) {
            element = DragonElement::Darkness;
        }

        // Randomize title
        let data_title: Array<felt252> = array![
            dragon_id.into(), 'data_title', get_block_timestamp().into()
        ];
        let hash_title: u256 = poseidon::poseidon_hash_span(data_title.span()).into();
        let title_num: u8 = (hash_title % 3).try_into().unwrap();
        let mut title: DragonTitle = DragonTitle::FireDragon;
        if (title_num == 1) {
            title = DragonTitle::WaterDragon;
        } else if (title_num == 2) {
            title = DragonTitle::GroundDragon;
        }

        return Dragon {
            game_id,
            dragon_id,
            owner,
            model_id,
            rarity,
            element,
            title,
            speed,
            attack,
            carrying_capacity: Resource { food: food_cap, stone: stone_cap },
            state: DragonState::Idling
        };
    }
}
