address 0x1 {
module ExDep {
    use 0x1::LibraAccount;
    use 0x1::Signer;
    use 0x1::LCS;
    use 0x1::Event::{Self, EventHandle};
    use 0x1::Vector;
    use 0x1::LibraTimestamp;
    use 0x1::VLS::VLS;

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
    }

    struct BurnEvent {
        coina: vector<u8>,
        withdraw_amounta: u64,
        coinb: vector<u8>,
        withdraw_amountb: u64,
        burn_amount: u64,
    }

    struct SwapEvent {
        input_name: vector<u8>,
        input_amount: u64,
        output_name: vector<u8>,
        output_amount: u64,
        data: vector<u8>,
        timestamp: u64
    }

    resource struct NextRewardPool<CoinA, CoinB> {
        init_balance: u64,
        start_time: u64,
        end_time: u64
    }

    resource struct CurrentRewardPool<CoinA, CoinB> {
        init_balance: u64,
        remain_balance: u64,
        start_time: u64,
        end_time: u64
    }

    resource struct AllMinersInfo<CoinA, CoinB> {
        total_lp_amount: u64,
        all_miners: vector<MinerInfo>,
    }

    struct MinerInfo {
        miner_addr: address,
        lp_amount: u64,
        mine_balance: u64,
        start_time: u64,
    }

    fun admin_addr(): address {
        0x7257c2417e4d1038e1817c8f283ace2e
    }

    public fun initialize(account: &signer) {
        move_to(account, EventInfo{ events: Event::new_event_handle<Event>(account),
                        factor1: 9997,
                        factor2: 10000 });
    }

    public fun add_mine_pool<CoinA, CoinB>(account: &signer) {
        assert(Signer::address_of(account)  == admin_addr(), 4007);
        // assert(!exists<CurrentRewardPool<CoinA, CoinB>>(admin_addr()), 4008);
        // assert(!exists<CurrentRewardPool<CoinB, CoinA>>(admin_addr()), 4009);

        move_to(account, AllMinersInfo<CoinA, CoinB>{ total_lp_amount: 0, all_miners: Vector::empty<MinerInfo>()});

        move_to(account, CurrentRewardPool<CoinA, CoinB>{ init_balance: 0,
                        remain_balance: 0,
                        start_time: 0,
                        end_time: 0 });
        move_to(account, NextRewardPool<CoinA, CoinB>{ init_balance: 0,
                        start_time: 0,
                        end_time: 0 })
    }

    fun update_current_rewardpool<CoinA, CoinB>(current_pool: &mut CurrentRewardPool<CoinA, CoinB> , next_pool: &mut NextRewardPool<CoinA, CoinB>) {
        let now_time = LibraTimestamp::now_microseconds();
        if(next_pool.start_time <= now_time && next_pool.start_time >= current_pool.end_time) {
            current_pool.remain_balance = current_pool.remain_balance + next_pool.init_balance;
            current_pool.init_balance = current_pool.remain_balance;
            current_pool.start_time = next_pool.start_time;
            current_pool.end_time = next_pool.end_time;
        };
    }

    public fun withdraw_mine_reward<CoinA, CoinB>(cap: &LibraAccount::WithdrawCapability, addr: address, new_lp_amount: u64): u64 acquires AllMinersInfo, CurrentRewardPool, NextRewardPool{
        assert(exists<CurrentRewardPool<CoinA, CoinB>>(admin_addr()), 4008);
        let current_reward_pool = borrow_global_mut<CurrentRewardPool<CoinA, CoinB>>(admin_addr());
        let next_reward_pool = borrow_global_mut<NextRewardPool<CoinA, CoinB>>(admin_addr());
        distribute<CoinA, CoinB>(current_reward_pool, next_reward_pool);

        let all_miners_info = borrow_global_mut<AllMinersInfo<CoinA, CoinB>>(admin_addr());
        let (total_lp_amount, miners_info) = (all_miners_info.total_lp_amount, &mut all_miners_info.all_miners);
        let len = Vector::length(miners_info);
        let old_lp_amount = 0;
        let withdraw_amount = 0;
        let miner_index = 0;
        let find = false;
        let i = 0;
        while (i < len) {
            let miner = Vector::borrow_mut(miners_info, i);
            if (miner.miner_addr == addr) {
                old_lp_amount = miner.lp_amount;
                withdraw_amount = miner.mine_balance;
                miner.mine_balance = 0;
                miner.lp_amount = new_lp_amount;
                miner_index = i;
                find = true;
                break
            };
            i = i + 1;
        };
        if(find) {
            if(new_lp_amount == 0) {
                Vector::remove(miners_info, miner_index);
            };
        } else if(new_lp_amount > 0){
            Vector::push_back(miners_info, MinerInfo{
                miner_addr: addr,
                lp_amount: new_lp_amount,
                mine_balance: 0,
                start_time: current_reward_pool.start_time
            })
        };
        if(withdraw_amount == 0){
            return 0
        };
        assert(old_lp_amount > 0, 4008);
        all_miners_info.total_lp_amount = total_lp_amount + new_lp_amount - old_lp_amount;
        withdraw<VLS>(cap, addr, withdraw_amount);
        withdraw_amount
    }

    fun distribute<CoinA, CoinB>(current_reward_pool: &mut CurrentRewardPool<CoinA, CoinB> , next_reward_pool: &mut NextRewardPool<CoinA, CoinB>) acquires AllMinersInfo {
        update_current_rewardpool(current_reward_pool, next_reward_pool);
        if (current_reward_pool.start_time == current_reward_pool.end_time) {
            return
        };
        let all_miners_info = borrow_global_mut<AllMinersInfo<CoinA, CoinB>>(admin_addr());
        let (total_lp_amount, miners_info) = (all_miners_info.total_lp_amount, &mut all_miners_info.all_miners);
        if(total_lp_amount == 0){
            return
        };
        let len = Vector::length(miners_info);
        let remain_balance = current_reward_pool.remain_balance;
        assert(remain_balance > 0, 3008);
        let tmp_now_time = LibraTimestamp::now_microseconds();
        let now_time = if(tmp_now_time > current_reward_pool.end_time) {
            current_reward_pool.end_time
        }else {
            tmp_now_time
        };
        let time_past = now_time - current_reward_pool.start_time;
        let time_span = current_reward_pool.end_time - current_reward_pool.start_time;
        let distrute_amount = 0;
        let i = 0;
        while (i < len) {
            let miner = Vector::borrow_mut(miners_info, i);
            let reward_amount =  (remain_balance * miner.lp_amount * time_past) / (total_lp_amount * time_span);
            distrute_amount = distrute_amount + reward_amount;
            miner.mine_balance = miner.mine_balance + reward_amount;
            miner.start_time = now_time;
            i = i + 1;
        };
        current_reward_pool.start_time = now_time;
        current_reward_pool.remain_balance = remain_balance - distrute_amount;
    }

    public fun set_next_rewardpool<CoinA, CoinB>(account: &signer, init_balance: u64, start_time: u64, end_time: u64) acquires AllMinersInfo, NextRewardPool, CurrentRewardPool {
        assert(exists<CurrentRewardPool<CoinA, CoinB>>(admin_addr()), 3001);
        assert(Signer::address_of(account)  == admin_addr(), 4008);
        assert(start_time < end_time, 4008);
        let current_reward_pool = borrow_global_mut<CurrentRewardPool<CoinA, CoinB>>(admin_addr());
        let next_reward_pool = borrow_global_mut<NextRewardPool<CoinA, CoinB>>(admin_addr());
        let now_time = LibraTimestamp::now_microseconds();
        assert(next_reward_pool.start_time < now_time && start_time >= next_reward_pool.end_time && start_time > now_time, 4009);
        distribute<CoinA, CoinB>(current_reward_pool, next_reward_pool);
        next_reward_pool.init_balance = init_balance;
        next_reward_pool.start_time = start_time;
        next_reward_pool.end_time = end_time;
        deposit<VLS>(account, init_balance);
    }

    public fun set_fee_factor(account: &signer, factor1: u128, factor2: u128) acquires EventInfo {
        assert(Signer::address_of(account)  == admin_addr(), 4010);
        let event_info_ref = borrow_global_mut<EventInfo>(admin_addr());
        event_info_ref.factor1 = factor1;
        event_info_ref.factor2 = factor2;
    }

    public fun deposit<Token>(account: &signer, amount: u64) {
        let sender_cap = LibraAccount::extract_withdraw_capability(account);
        LibraAccount::pay_from<Token>(
            &sender_cap,
            admin_addr(),
            amount,
            x"",
            x""
        );
        LibraAccount::restore_withdraw_capability(sender_cap);
    }

    public fun withdraw<Token>(cap: &LibraAccount::WithdrawCapability, payee: address, amount: u64) {
        LibraAccount::pay_from<Token>(
            cap,
            payee,
            amount,
            x"",
            x""
        )
    }

    public fun c_m_event(v1: vector<u8>, v2: u64, v3: vector<u8>, v4: u64, v5: u64) acquires EventInfo {
        let mint_event = MintEvent {
            coina: v1,
            deposit_amounta: v2,
            coinb: v3,
            deposit_amountb: v4,
            mint_amount: v5
        };
        let data = LCS::to_bytes<MintEvent>(&mint_event);
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

    public fun c_b_event(v1: vector<u8>, v2: u64,v3: vector<u8>, v4: u64, v5: u64) acquires EventInfo {
        let burn_event = BurnEvent {
            coina: v1,
            withdraw_amounta: v2,
            coinb: v3,
            withdraw_amountb: v4,
            burn_amount: v5
        };
        let data = LCS::to_bytes<BurnEvent>(&burn_event);
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

    public fun c_s_event(v1: vector<u8>, v2: u64, v3: vector<u8>, v4: u64, v5: vector<u8>) acquires EventInfo {
        let swap_event = SwapEvent {
            input_name: v1,
            input_amount: v2,
            output_name: v3,
            output_amount: v4,
            data: v5,
            timestamp: LibraTimestamp::now_microseconds()
        };
        let data = LCS::to_bytes<SwapEvent>(&swap_event);
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
}
}