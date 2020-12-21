address 0x1 {
module Exchange {
    use 0x1::Signer;
    use 0x1::DiemAccount;
    use 0x1::BCS;
    use 0x1::Diem;
    use 0x1::Vector;
    use 0x1::Event::{Self, EventHandle};
    use 0x1::DiemTimestamp;
    use 0x1::VLS::VLS;

    fun admin_addr(): address {
        0x7257c2417e4d1038e1817c8f283ace2e
    }

    resource struct RewardAdmin {
        addr: address
    }

    resource struct EventInfo {
        events: EventHandle<Event>,
        factor1: u128,
        factor2: u128,
    }

    struct Event {
        etype: u64,
        data: vector<u8>,
    }

    struct MintEvent {
        coina: vector<u8>,
        deposit_amounta: u64,
        coinb: vector<u8>,
        deposit_amountb: u64,
        mint_amount: u64,
        timestamp: u64
    }

    struct BurnEvent {
        coina: vector<u8>,
        withdraw_amounta: u64,
        coinb: vector<u8>,
        withdraw_amountb: u64,
        burn_amount: u64,
        timestamp: u64
    }

    struct SwapEvent {
        input_name: vector<u8>,
        input_amount: u64,
        output_name: vector<u8>,
        output_amount: u64,
        data: vector<u8>,
        timestamp: u64
    }

    struct RewardEvent {
        pool_id: u64,
        reward_amount: u64,
        timestamp: u64
    }

    /// Maximum u64 value.
    const MAX_U64: u64 = 18446744073709551615;

    struct PoolUserIndex {
        pool_id: u64,
        user_index: u64
    }

    resource struct PoolUserIndexs {
        pool_user_indexs: vector<PoolUserIndex>,
    }

    struct UserInfo {
        amount: u64,  //How many LP tokens the user has provided.
        reward_debt: u64 //Reward debt.
    }

    resource struct PoolInfo {
        id: u64,
        lp_supply: u64,
        alloc_point: u64, //How many allocation points assigned to this pool.
        acc_vls_per_share: u128, // Accumulated VLSs per share.
        users_info: vector<UserInfo>
    }

    resource struct RewardPools {
        start_time: u64,
        end_time: u64,
        last_reward_time: u64, // Last seconds that VLS distribution occurs.
        total_reward_balance: u64,
        total_alloc_point: u64,
        pool_infos: vector<PoolInfo>,
    }

    resource struct Reserves {
        reserves: vector<Reserve>,
    }

    resource struct WithdrawCapability {
        cap: DiemAccount::WithdrawCapability,
    }

    resource struct RegisteredCurrencies {
        currency_codes: vector<vector<u8>>,
    }

    resource struct Reserve {
        liquidity_total_supply: u64,
        coina: Token,
        coinb: Token,
    }

    resource struct Tokens {
        tokens: vector<Token>,
    }

    resource struct Token {
        index: u64,
        value: u64
    }

    fun mint_event(v1: vector<u8>, v2: u64, v3: vector<u8>, v4: u64, v5: u64) acquires EventInfo {
        let mint_event = MintEvent {
            coina: v1,
            deposit_amounta: v2,
            coinb: v3,
            deposit_amountb: v4,
            mint_amount: v5,
            timestamp: DiemTimestamp::now_seconds()
        };
        let data = BCS::to_bytes<MintEvent>(&mint_event);
        let event = Event {
            etype: 1,
            data: data
        };

        let event_info_ref = borrow_global_mut<EventInfo>(admin_addr());
        Event::emit_event<Event>(
            &mut event_info_ref.events,
            event,
        );
    }

    fun burn_event(v1: vector<u8>, v2: u64,v3: vector<u8>, v4: u64, v5: u64) acquires EventInfo {
        let burn_event = BurnEvent {
            coina: v1,
            withdraw_amounta: v2,
            coinb: v3,
            withdraw_amountb: v4,
            burn_amount: v5,
            timestamp: DiemTimestamp::now_seconds()
        };
        let data = BCS::to_bytes<BurnEvent>(&burn_event);
        let event = Event {
            etype: 2,
            data: data
        };

        let event_info_ref = borrow_global_mut<EventInfo>(admin_addr());
        Event::emit_event<Event>(
            &mut event_info_ref.events,
            event,
        );
    }

    fun swap_event(v1: vector<u8>, v2: u64, v3: vector<u8>, v4: u64, v5: vector<u8>) acquires EventInfo {
        let swap_event = SwapEvent {
            input_name: v1,
            input_amount: v2,
            output_name: v3,
            output_amount: v4,
            data: v5,
            timestamp: DiemTimestamp::now_seconds()
        };
        let data = BCS::to_bytes<SwapEvent>(&swap_event);
        let event = Event {
            etype: 3,
            data: data
        };

        let event_info_ref = borrow_global_mut<EventInfo>(admin_addr());
        Event::emit_event<Event>(
            &mut event_info_ref.events,
            event,
        );
    }

    fun reward_event(v1: u64, v2: u64) acquires EventInfo {
        let reward_event = RewardEvent {
            pool_id: v1,
            reward_amount: v2,
            timestamp: DiemTimestamp::now_seconds()
        };
        let data = BCS::to_bytes<RewardEvent>(&reward_event);
        let event = Event {
            etype: 4,
            data: data
        };

        let event_info_ref = borrow_global_mut<EventInfo>(admin_addr());
        Event::emit_event<Event>(
            &mut event_info_ref.events,
            event,
        );
    }

    fun min(x: u128, y: u128): u64 {
        if(x < y) {
            (x as u64)
        }
        else {
            (y as u64)
        }
    }

    fun sqrt(a: u64, b: u64): u64 {
        let y: u128 =  (a as u128) * (b as u128);
        let z: u128 = 1;
        if (y > 3) {
            z = y;
            let x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        };
        (z as u64)
    }

    public fun get_mint_liquidity(amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64, reservea: u64, reserveb: u64, total_supply: u64): (u64, u64, u64) {
        let (amounta, amountb) = if(reservea == 0 && reserveb == 0){
            (amounta_desired, amountb_desired)
        }
        else {
            let amountb_optimal = quote(amounta_desired, reservea, reserveb);
            if(amountb_optimal <= amountb_desired){
                assert(amountb_optimal >= amountb_min, 4030);
                (amounta_desired, amountb_optimal)
            }
            else {
                let amounta_optimal = quote(amountb_desired, reserveb, reservea);
                assert(amounta_optimal <= amounta_desired && amounta_optimal >= amounta_min, 4031);
                (amounta_optimal, amountb_desired)
            }
        };
        let big_amounta = (amounta as u128);
        let big_amountb = (amountb as u128);
        let big_total_supply = (total_supply as u128);
        let big_reservea = (reservea as u128);
        let big_reserveb = (reserveb as u128);
        let liquidity = if(total_supply == 0){
            sqrt(amounta, amountb)
        }
        else{
            min(big_amounta * big_total_supply / big_reservea, big_amountb * big_total_supply / big_reserveb)
        };
        assert(liquidity > 0, 4032);
        (liquidity, amounta, amountb)
    }

    fun quote(amounta: u64, reservea: u64, reserveb: u64): u64 {
        assert(amounta > 0 && reservea > 0 && reserveb > 0, 4040);
        let amountb: u64 = (((amounta as u128) * (reserveb as u128) / (reservea as u128)) as u64);
        amountb
    }

    public fun get_amount_out(amount_in: u64, reserve_in: u64, reserve_out: u64): u64 acquires EventInfo {
        assert(amount_in > 0 && reserve_in > 0 && reserve_out > 0, 4050);
        let event_info_ref = borrow_global_mut<EventInfo>(admin_addr());

        let amount_in_with_fee = (amount_in as u128) * event_info_ref.factor1;
        let numerator = amount_in_with_fee * (reserve_out as u128);
        let denominator = (reserve_in as u128) * event_info_ref.factor2 + amount_in_with_fee;
        ((numerator / denominator) as u64)
    }

    public fun initialize(sender: &signer, reward_admin: address) {
        assert(Signer::address_of(sender) == admin_addr(), 5000);
        move_to(sender, RewardPools {
            start_time: DiemTimestamp::now_seconds(),
            end_time: DiemTimestamp::now_seconds(),
            last_reward_time: DiemTimestamp::now_seconds(),
            total_reward_balance: 0,
            total_alloc_point: 0,
            pool_infos: Vector::empty()
        });
        move_to(sender, Reserves {
            reserves: Vector::empty()
        });
        move_to(sender, RegisteredCurrencies {
            currency_codes: Vector::empty()
        });
        move_to(sender, WithdrawCapability {
            cap: DiemAccount::extract_withdraw_capability(sender)
        });
        move_to(sender, EventInfo { 
            events: Event::new_event_handle<Event>(sender),
            factor1: 9997,
            factor2: 10000 }
        );
        move_to(sender, RewardAdmin {
            addr: reward_admin}
        );
    }

    public fun change_rewarder(account: &signer, reward_admin: address) acquires RewardAdmin {
        assert(Signer::address_of(account) == admin_addr(), 5000);
        let reward_admin_info = borrow_global_mut<RewardAdmin>(admin_addr());
        reward_admin_info.addr = reward_admin;
    }

    public fun set_fee_factor(account: &signer, factor1: u128, factor2: u128) acquires EventInfo {
        assert(Signer::address_of(account)  == admin_addr(), 4010);
        let event_info_ref = borrow_global_mut<EventInfo>(admin_addr());
        event_info_ref.factor1 = factor1;
        event_info_ref.factor2 = factor2;
    }

    // Add a balance of `Token` type to the sending account.
    public fun add_currency<Token>(account: &signer) acquires RegisteredCurrencies {
        assert(Signer::address_of(account)  == admin_addr(), 5001);
        let currency_code = Diem::currency_code<Token>();
        let registered_currencies = borrow_global_mut<RegisteredCurrencies>(admin_addr());

        if (Vector::contains(&registered_currencies.currency_codes, &currency_code)){
            return
        };
        Vector::push_back(&mut registered_currencies.currency_codes, currency_code);
        
        if (!DiemAccount::accepts_currency<Token>(admin_addr())) {
            DiemAccount::add_currency<Token>(account);
        };
    }

    // Return whether accepts `Token` type coins
    fun accepts_currency<Token>(): bool acquires RegisteredCurrencies {
        let _ = get_coin_id<Token>();
        DiemAccount::accepts_currency<Token>(admin_addr())
    }

    public fun get_currencys(): vector<vector<u8>> acquires RegisteredCurrencies {
        let registered_currencies = borrow_global_mut<RegisteredCurrencies>(admin_addr());
        *&registered_currencies.currency_codes
    }

    public fun get_coin_id<Token>(): u64 acquires RegisteredCurrencies {
        let code = Diem::currency_code<Token>();
        let currency_codes = get_currencys();
        let (exist, id) = Vector::index_of<vector<u8>>(&currency_codes, &code);
        assert(exist, 5010);
        id
    }

    public fun get_liquidity_balance<CoinA, CoinB>(addr: address): u64 acquires RegisteredCurrencies, Tokens {
        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let id = (ida << 32) + idb;
        let tokens = borrow_global_mut<Tokens>(addr);
        let token = get_token(id, tokens);
        assert(token.value > 0, 5020);
        token.value
    }

    public fun get_pair_indexs<CoinA, CoinB>(): (u64, u64) acquires RegisteredCurrencies {
        let (ida, idb) = (get_coin_id<CoinA>(), get_coin_id<CoinB>());
        assert(ida < idb, 5030);
        (ida, idb)
    }

    public fun get_reserve<CoinA, CoinB>(): (u64, u64, u64) acquires Reserves, RegisteredCurrencies, RewardPools {
        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let reserves = borrow_global_mut<Reserves>(admin_addr());
        let reserve = get_reserve_internal(ida, idb, reserves);
        let va = DiemAccount::balance<CoinA>(admin_addr());
        let vb = DiemAccount::balance<CoinB>(admin_addr());
        assert(va == reserve.coina.value && vb == reserve.coinb.value, 5040);
        (reserve.liquidity_total_supply, va, vb)
    }

    fun add_reward_pool(ida: u64, idb: u64, lp_supply: u64) acquires RewardPools {
        assert(exists<RewardPools>(admin_addr()), 4001);
        let reward_pools = borrow_global_mut<RewardPools>(admin_addr());
        let pool_infos = &mut reward_pools.pool_infos;
        let id = (ida << 32) + idb;
        let alloc_point = 1000;
        Vector::push_back<PoolInfo>(pool_infos, PoolInfo {
                        id: id,
                        lp_supply: lp_supply,
                        alloc_point: alloc_point,
                        acc_vls_per_share: 0,
                        users_info: Vector::empty()
                    });
        reward_pools.total_alloc_point = reward_pools.total_alloc_point + alloc_point;
    }

    fun get_reserve_internal(ida: u64, idb: u64, reserves: &mut Reserves): &mut Reserve acquires RewardPools {
        assert(ida < idb, 5050);
        let reserves = &mut reserves.reserves;
        let i = 0;
        let len = Vector::length(reserves);
        while (i < len) {
            let reserve = Vector::borrow_mut(reserves, i);
            if (reserve.coina.index == ida && reserve.coinb.index == idb) return reserve;
            i = i + 1;
        };
        add_reward_pool(ida, idb, 0);
        Vector::push_back<Reserve>(reserves, Reserve{
                        liquidity_total_supply: 0,
                        coina: Token{index: ida, value: 0},
                        coinb: Token{index: idb, value: 0}
                    });
        let reserve = Vector::borrow_mut(reserves, i);
        reserve
    }

    fun deposit<Token>(account: &signer, to_deposit: u64) {
        let sender_cap = DiemAccount::extract_withdraw_capability(account);
        DiemAccount::pay_from<Token>(
            &sender_cap,
            admin_addr(),
            to_deposit,
            x"",
            x""
        );
        DiemAccount::restore_withdraw_capability(sender_cap);
    }

    fun withdraw<Token>(payee: address, amount: u64) acquires WithdrawCapability {
        let cap = borrow_global<WithdrawCapability>(admin_addr());
        DiemAccount::pay_from<Token>(
            &cap.cap,
            payee,
            amount,
            x"",
            x""
        )
    }

    fun get_token(id: u64, tokens: &mut Tokens): &mut Token{
        let tokens = &mut tokens.tokens;
        let i = 0;
        let len = Vector::length(tokens);
        while (i < len) {
            let token = Vector::borrow_mut(tokens, i);
            if (token.index == id) return token;
            i = i + 1;
        };
        Vector::push_back(tokens, Token{
                index: id,
                value: 0
            });
        let token = Vector::borrow_mut(tokens, i);
        token
    }

    fun get_pool_user_index(id: u64, user: address): u64 acquires PoolUserIndexs{
        let pool_user_indexs = borrow_global<PoolUserIndexs>(user);
        let p_user_indexs = &pool_user_indexs.pool_user_indexs;
        let i = 0;
        let len = Vector::length(p_user_indexs);
        while (i < len) {
            let p_user_index = Vector::borrow(p_user_indexs, i);
            if (p_user_index.pool_id == id) return p_user_index.user_index;
            i = i + 1;
        };
        MAX_U64
    }

    fun get_or_add_pool_user_index(id: u64, pool_user_indexs: &mut PoolUserIndexs): &mut PoolUserIndex {
        let p_user_indexs = &mut pool_user_indexs.pool_user_indexs;
        let i = 0;
        let len = Vector::length(p_user_indexs);
        while (i < len) {
            let p_user_index = Vector::borrow_mut(p_user_indexs, i);
            if (p_user_index.pool_id == id) return p_user_index;
            i = i + 1;
        };
        Vector::push_back(p_user_indexs, PoolUserIndex {
                pool_id: id,
                user_index: MAX_U64
            });
        let p_user_index = Vector::borrow_mut(p_user_indexs, i);
        p_user_index
    }

    public fun set_pool_alloc_point(account: &signer, id: u64, new_alloc_point: u64) acquires RewardPools, RewardAdmin{
        assert(exists<RewardPools>(admin_addr()), 4001);
        let reward_admin_info = borrow_global_mut<RewardAdmin>(admin_addr());
        assert(Signer::address_of(account)  == reward_admin_info.addr, 4002);
        let reward_pools = borrow_global_mut<RewardPools>(admin_addr());
        let pool_infos = &mut reward_pools.pool_infos;
        let len = Vector::length(pool_infos);
        let pool_info = Vector::borrow_mut(pool_infos, 0);
        let i = 0;
        while (i < len) {
            pool_info = Vector::borrow_mut(pool_infos, i);
            if (pool_info.id == id) {
                break
            };
            i = i + 1;
        };
        let old_alloc_point = pool_info.alloc_point;
        pool_info.alloc_point = new_alloc_point;
        reward_pools.total_alloc_point = reward_pools.total_alloc_point - old_alloc_point + new_alloc_point;
    }

    public fun withdraw_mine_reward(account: &signer) acquires EventInfo, Tokens, PoolUserIndexs, RewardPools, WithdrawCapability {
        let sender = Signer::address_of(account);
        assert(exists<PoolUserIndexs>(sender), 4111);
        let rc_tokens = borrow_global_mut<Tokens>(sender);
        let tokens = &mut rc_tokens.tokens;
        update_pool();
        let i = 0;
        let len = Vector::length(tokens);
        while (i < len) {
            let token = Vector::borrow_mut(tokens, i);
            if(token.value == 0){
                continue
            };
            update_user_reward_info(account, token.index, token.value);
            i = i + 1;
        };
    }

    public fun set_next_rewards(account: &signer, init_balance: u64, start_time: u64, end_time: u64) acquires RewardPools, RewardAdmin {
        assert(exists<RewardPools>(admin_addr()), 4001);
        let reward_admin_info = borrow_global_mut<RewardAdmin>(admin_addr());
        assert(Signer::address_of(account)  == reward_admin_info.addr, 4002);
        let rc_reward_pools = borrow_global_mut<RewardPools>(admin_addr());
        rc_reward_pools.start_time = start_time;
        rc_reward_pools.end_time = end_time;
        rc_reward_pools.last_reward_time = start_time;
        rc_reward_pools.total_reward_balance = rc_reward_pools.total_reward_balance + init_balance;
        deposit<VLS>(account, init_balance);
    }

    const MULT_FACTOR: u128 = 1000000000;

    fun update_pool() acquires RewardPools {
        let reward_pools = borrow_global_mut<RewardPools>(admin_addr());
        let pool_infos = &mut reward_pools.pool_infos;
        let len = Vector::length(pool_infos);
        let now_time = DiemTimestamp::now_seconds();
        if(now_time > reward_pools.end_time){
            now_time = reward_pools.end_time
        };
        if(now_time > reward_pools.last_reward_time){
            let total_alloc_point = reward_pools.total_alloc_point;
            let i = 0;
            while (i < len) {
                let pool_info = Vector::borrow_mut(pool_infos, i);                
                i = i + 1;
                let lp_supply = pool_info.lp_supply;
                if (lp_supply > 0) {
                    let reward_per_seconds = reward_pools.total_reward_balance / (reward_pools.end_time - reward_pools.start_time);
                    let time_span = now_time - reward_pools.last_reward_time;
                    let vls_reward: u128 = (time_span as u128) * (reward_per_seconds as u128) * (pool_info.alloc_point as u128) / (total_alloc_point as u128);
                    pool_info.acc_vls_per_share = pool_info.acc_vls_per_share + vls_reward * MULT_FACTOR / (lp_supply as u128);
                };
            };
            reward_pools.last_reward_time = now_time;
        };
    }

    public fun pending_reward(user: address): u64 acquires RewardPools, PoolUserIndexs {
        let reward_pools = borrow_global<RewardPools>(admin_addr());
        let pool_infos = &reward_pools.pool_infos;
        let len = Vector::length(pool_infos);
        let now_time = DiemTimestamp::now_seconds();
        if(now_time > reward_pools.end_time){
            now_time = reward_pools.end_time
        };
        let pending = 0;
        if(now_time > reward_pools.last_reward_time){
            let total_alloc_point = reward_pools.total_alloc_point;
            let i = 0;
            while (i < len) {
                let acc_vls_per_share = 0;
                let pool_info = Vector::borrow(pool_infos, i); 
                i = i + 1;
                let lp_supply = pool_info.lp_supply;
                if (lp_supply > 0) {
                    let reward_per_seconds = reward_pools.total_reward_balance / (reward_pools.end_time - reward_pools.start_time);
                    let time_span = now_time - reward_pools.last_reward_time;
                    let vls_reward: u128 = (time_span as u128) * (reward_per_seconds as u128) * (pool_info.alloc_point as u128) / (total_alloc_point as u128);
                    acc_vls_per_share = pool_info.acc_vls_per_share + vls_reward * MULT_FACTOR / (lp_supply as u128);
                };
                let user_index = get_pool_user_index(pool_info.id, user);
                if(user_index == MAX_U64){
                    continue
                };
                let user_info = Vector::borrow(&pool_info.users_info, user_index);
                pending = pending + (((user_info.amount as u128) * acc_vls_per_share / MULT_FACTOR - (user_info.reward_debt as u128)) as u64);
            };
        };
        pending
    }

    fun update_user_reward_info(account: &signer, id: u64, new_liquidity: u64) acquires EventInfo, PoolUserIndexs, RewardPools, WithdrawCapability {
        let sender = Signer::address_of(account);
        if(!exists<PoolUserIndexs>(sender)){
            move_to(account, PoolUserIndexs { pool_user_indexs: Vector::empty() });
        };
        let pool_user_indexs = borrow_global_mut<PoolUserIndexs>(sender);
        let reward_pools = borrow_global_mut<RewardPools>(admin_addr());
        // let pool_info = get_pool_info(id, reward_pools);
        let pool_infos = &mut reward_pools.pool_infos;
        let len = Vector::length(pool_infos);

        let pool_info = Vector::borrow_mut(pool_infos, 0);
        let i = 0;
        while (i < len) {
            pool_info = Vector::borrow_mut(pool_infos, i);
            if (pool_info.id == id) {
                break
            };
            i = i + 1;
        };

        let p_user_index = get_or_add_pool_user_index(id, pool_user_indexs);
        if(p_user_index.user_index == MAX_U64){
            Vector::push_back(&mut pool_info.users_info, UserInfo {
                amount: 0,
                reward_debt: 0
            });
            p_user_index.user_index = Vector::length(&mut pool_info.users_info) - 1;
        };
        let user_info = Vector::borrow_mut(&mut pool_info.users_info, p_user_index.user_index);
        let old_liquidity = user_info.amount;
        if(old_liquidity > 0){
            let pending = (((old_liquidity as u128) * pool_info.acc_vls_per_share / MULT_FACTOR - (user_info.reward_debt as u128)) as u64);
            if(pending > 0) {
                reward_event(id, pending);
                withdraw<VLS>(sender, pending);
            };
        };
        user_info.amount = new_liquidity;
        pool_info.lp_supply = pool_info.lp_supply + new_liquidity - old_liquidity;
        user_info.reward_debt = (((user_info.amount as u128) * pool_info.acc_vls_per_share / MULT_FACTOR) as u64);
    }

    fun mint<CoinA, CoinB>(account: &signer, ida: u64, idb: u64, amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64, reservea: u64, reserveb: u64, total_supply: u64): (u64, u64, u64) acquires Tokens, EventInfo, PoolUserIndexs, RewardPools, WithdrawCapability {
        let sender = Signer::address_of(account);
        if(!exists<Tokens>(sender)) {
            move_to(account, Tokens { tokens: Vector::empty() });
        };

        let id = (ida << 32) + idb;
        let tokens = borrow_global_mut<Tokens>(sender);
        let token = get_token(id, tokens);
        let (liquidity, amounta, amountb) = get_mint_liquidity(amounta_desired, amountb_desired, amounta_min, amountb_min, reservea, reserveb, total_supply);
        token.value = token.value + liquidity;
        let coina = Diem::currency_code<CoinA>();
        let coinb = Diem::currency_code<CoinB>();
        mint_event(coina, amounta, coinb, amountb, liquidity);
        deposit<CoinA>(account, amounta);
        deposit<CoinB>(account, amountb);
        update_pool();
        update_user_reward_info(account, id, token.value);
        (total_supply + liquidity, amounta, amountb)
    }

    public fun add_liquidity<CoinA, CoinB>(account: &signer, amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64) acquires Reserves, RegisteredCurrencies, Tokens, RewardPools, WithdrawCapability, EventInfo, PoolUserIndexs {
        assert(accepts_currency<CoinA>() && accepts_currency<CoinB>(), 5060);
        let reserves = borrow_global_mut<Reserves>(admin_addr());

        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let reserve = get_reserve_internal(ida, idb, reserves);

        let (total_supply, reservea, reserveb) = (reserve.liquidity_total_supply, reserve.coina.value, reserve.coinb.value);
        let (total_supply, amounta, amountb) = mint<CoinA, CoinB>(account, ida, idb, amounta_desired, amountb_desired, amounta_min, amountb_min, reservea, reserveb, total_supply);
        reserve.liquidity_total_supply = total_supply;
        reserve.coina.value = reservea + amounta;
        reserve.coinb.value = reserveb + amountb;
    }

    public fun remove_liquidity<CoinA, CoinB>(account: &signer, liquidity: u64, amounta_min: u64, amountb_min: u64) acquires Reserves, RegisteredCurrencies, Tokens, WithdrawCapability, EventInfo, PoolUserIndexs, RewardPools {
        let reserves = borrow_global_mut<Reserves>(admin_addr());

        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let reserve = get_reserve_internal(ida, idb, reserves);
        let (total_supply, reservea, reserveb) = (reserve.liquidity_total_supply, reserve.coina.value, reserve.coinb.value);
        let tokens = borrow_global_mut<Tokens>(Signer::address_of(account));
        let id = (ida << 32) + idb;
        let token = get_token(id, tokens);
        let amounta = ((liquidity as u128) * (reservea as u128) / (total_supply  as u128) as u64);
        let amountb = ((liquidity as u128) * (reserveb as u128) / (total_supply  as u128) as u64);
        assert(amounta >= amounta_min && amountb >= amountb_min, 5070);
        reserve.liquidity_total_supply = total_supply - liquidity;
        reserve.coina.value = reservea - amounta;
        reserve.coinb.value = reserveb - amountb;
        assert(token.value >= liquidity, 5071);
        token.value = token.value - liquidity;
        update_pool();
        update_user_reward_info(account, id, token.value);
        let coina = Diem::currency_code<CoinA>();
        let coinb = Diem::currency_code<CoinB>();

        burn_event(coina, amounta, coinb, amountb, liquidity);
        withdraw<CoinA>(Signer::address_of(account), amounta);
        withdraw<CoinB>(Signer::address_of(account), amountb);
    }

    public fun swap<CoinA, CoinB>(account: &signer, payee: address, amount_in: u64, amount_out_min: u64, path: vector<u8>, data: vector<u8>) acquires Reserves, RegisteredCurrencies, WithdrawCapability, EventInfo, RewardPools {
        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let coina = Diem::currency_code<CoinA>();
        let coinb = Diem::currency_code<CoinB>();
        let len = Vector::length(&path);
        let (path0, pathn) = (*Vector::borrow(&path, 0), *Vector::borrow(&path, len - 1));
        if(path0 > pathn){
            (ida, idb) = (idb, ida);
            (coina, coinb) = (coinb, coina);
        };
        assert(len > 1 && ida != idb && ida == (path0 as u64) && idb == (pathn as u64), 5080);
        let amounts = Vector::empty<u64>();
        Vector::push_back(&mut amounts, amount_in);
        let reserves = borrow_global_mut<Reserves>(admin_addr());
        let i = 0;
        let amount_out = 0;
        while(i < len - 1) {
            let amt_in = *Vector::borrow(&amounts, i);
            let id_in = (*Vector::borrow(&path, i) as u64);
            let id_out = (*Vector::borrow(&path, i + 1) as u64);
            if(id_in < id_out){
                let reserve = get_reserve_internal(id_in, id_out, reserves);
                let (reserve_in, reserve_out) = (reserve.coina.value, reserve.coinb.value);
                amount_out = get_amount_out(amt_in, reserve_in, reserve_out);
                Vector::push_back(&mut amounts, amount_out);
                reserve.coina.value = reserve.coina.value + amt_in;
                reserve.coinb.value = reserve.coinb.value - amount_out;
            }
            else {
                let reserve = get_reserve_internal(id_out, id_in, reserves);
                let (reserve_in, reserve_out) = (reserve.coinb.value, reserve.coina.value);
                amount_out = get_amount_out(amt_in, reserve_in, reserve_out);
                Vector::push_back(&mut amounts, amount_out);
                reserve.coina.value = reserve.coina.value - amount_out;
                reserve.coinb.value = reserve.coinb.value + amt_in;
            };

            i = i + 1;
        };
        assert(amount_out >= amount_out_min, 5081);
        swap_event(coina, amount_in, coinb, amount_out, data);
        if(path0 < pathn){
            deposit<CoinA>(account, amount_in);
            withdraw<CoinB>(payee, amount_out);
        }
        else
        {
            deposit<CoinB>(account, amount_in);
            withdraw<CoinA>(payee, amount_out);
        };
    }
}
}