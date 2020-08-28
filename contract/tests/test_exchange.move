//! account: super
//! account: aa, 120000000000000000
//! account: a0, 120000000000000000Coin1
//! account: a1, 80000000000000000Coin2
//! account: a2, 40000000000000000Coin2

//! new-transaction
//! sender: super
module ExDep {
    use 0x1::LibraAccount;
    use 0x1::Signer;
    use 0x1::Debug;
    use 0x1::LCS;
    use 0x1::Event::{Self, EventHandle};

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
    }

    fun admin_addr(): address {
        {{aa}}
    }

    public fun initialize(account: &signer) {
        move_to(account, EventInfo{ events: Event::new_event_handle<Event>(account),
                        factor1: 9997,
                        factor2: 10000 })
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
        Debug::print(&mint_event);
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
        Debug::print(&burn_event);
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
            data: v5
        };
        Debug::print(&swap_event);
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


//! new-transaction
//! sender: super
module Exchange {
    use 0x1::Signer;
    use 0x1::LibraAccount;
    use 0x1::Libra;
    use 0x1::Vector;
    use {{super}}::ExDep;

    resource struct Reserves {
        reserves: vector<Reserve>,
    }

    resource struct RegisteredCurrencies {
        currency_codes: vector<vector<u8>>,
    }

    resource struct WithdrawCapability {
        cap: LibraAccount::WithdrawCapability,
    }


    resource struct Reserve{
        liquidity_total_supply: u64,
        coina: Token,
        coinb: Token,
    }

    resource struct Tokens {
        tokens: vector<Token>,
    }

    resource struct Token {
        index: u64,
        value: u64,
    }

    fun admin_addr(): address {
        {{super}}
    }

    public fun initialize(sender: &signer) {
        assert(Signer::address_of(sender) == admin_addr(), 5000);
        move_to(sender, Reserves {
            reserves: Vector::empty()
        });
        move_to(sender, RegisteredCurrencies {
            currency_codes: Vector::empty()
        });
        move_to(sender, WithdrawCapability {
            cap: LibraAccount::extract_withdraw_capability(sender)
        });
        ExDep::initialize(sender);
    }

    // Add a balance of `Token` type to the sending account.
    public fun add_currency<Token>(account: &signer) acquires RegisteredCurrencies {
        assert(Signer::address_of(account)  == admin_addr(), 5001);
        let currency_code = Libra::currency_code<Token>();
        let registered_currencies = borrow_global_mut<RegisteredCurrencies>(admin_addr());

        if (Vector::contains(&registered_currencies.currency_codes, &currency_code)){
            return
        };
        Vector::push_back(&mut registered_currencies.currency_codes, currency_code);
        
        if (!LibraAccount::accepts_currency<Token>(admin_addr())) {
            LibraAccount::add_currency<Token>(account);
        };
    }

    // Return whether accepts `Token` type coins
    fun accepts_currency<Token>(): bool acquires RegisteredCurrencies {
        let _ = get_coin_id<Token>();
        LibraAccount::accepts_currency<Token>(admin_addr())
    }

    public fun get_currencys(): vector<vector<u8>> acquires RegisteredCurrencies {
        let registered_currencies = borrow_global_mut<RegisteredCurrencies>(admin_addr());
        *&registered_currencies.currency_codes
    }

    public fun get_coin_id<Token>(): u64 acquires RegisteredCurrencies {
        let code = Libra::currency_code<Token>();
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

    public fun get_reserve<CoinA, CoinB>(): (u64, u64, u64) acquires Reserves, RegisteredCurrencies {
        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let reserves = borrow_global_mut<Reserves>(admin_addr());
        let reserve = get_reserve_internal(ida, idb, reserves);
        let va = LibraAccount::balance<CoinA>(admin_addr());
        let vb = LibraAccount::balance<CoinB>(admin_addr());
        assert(va == reserve.coina.value && vb == reserve.coinb.value, 5040);
        (reserve.liquidity_total_supply, va, vb)
    }

    fun get_reserve_internal(ida: u64, idb: u64, reserves: &mut Reserves): &mut Reserve {
        assert(ida < idb, 5050);
        let reserves = &mut reserves.reserves;
        let i = 0;
        let len = Vector::length(reserves);
        while (i < len) {
            let reserve = Vector::borrow_mut(reserves, i);
            if (reserve.coina.index == ida && reserve.coinb.index == idb) return reserve;
            i = i + 1;
        };

        Vector::push_back<Reserve>(reserves, Reserve{
                        liquidity_total_supply: 0,
                        coina: Token{index: ida, value: 0},
                        coinb: Token{index: idb, value: 0}
                    });
        let reserve = Vector::borrow_mut(reserves, i);
        reserve
    }

    fun deposit<Token>(account: &signer, to_deposit: u64) {
        ExDep::deposit<Token>(account, to_deposit);
    }

    fun withdraw<Token>(payee: address, amount: u64) acquires WithdrawCapability{
        let cap = borrow_global<WithdrawCapability>(admin_addr());
        ExDep::withdraw<Token>(&cap.cap, payee, amount);
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

    fun mint<CoinA, CoinB>(account: &signer, ida: u64, idb: u64, amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64, reservea: u64, reserveb: u64, total_supply: u64): (u64, u64, u64) acquires Tokens {
        let sender = Signer::address_of(account);
        if(!exists<Tokens>(sender)){
            move_to(account, Tokens { tokens: Vector::empty() });
        };
        let id = (ida << 32) + idb;
        let tokens = borrow_global_mut<Tokens>(sender);
        let token = get_token(id, tokens);
        let (liquidity, amounta, amountb) = ExDep::get_mint_liquidity(amounta_desired, amountb_desired, amounta_min, amountb_min, reservea, reserveb, total_supply);
        token.value = token.value + liquidity;
        let coina = Libra::currency_code<CoinA>();
        let coinb = Libra::currency_code<CoinB>();
        ExDep::c_m_event(coina, amounta, coinb, amountb, liquidity);
        deposit<CoinA>(account, amounta);
        deposit<CoinB>(account, amountb);
        (total_supply + liquidity, amounta, amountb)
    }

    public fun add_liquidity<CoinA, CoinB>(account: &signer, amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64) acquires Reserves, RegisteredCurrencies, Tokens {
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

    public fun remove_liquidity<CoinA, CoinB>(account: &signer, liquidity: u64, amounta_min: u64, amountb_min: u64) acquires Reserves, RegisteredCurrencies, Tokens, WithdrawCapability {
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
        token.value = token.value - liquidity;

        let coina = Libra::currency_code<CoinA>();
        let coinb = Libra::currency_code<CoinB>();

        ExDep::c_b_event(coina, amounta, coinb, amountb, liquidity);
        withdraw<CoinA>(Signer::address_of(account), amounta);
        withdraw<CoinB>(Signer::address_of(account), amountb);
    }

    public fun swap<CoinA, CoinB>(account: &signer, payee: address, amount_in: u64, amount_out_min: u64, path: vector<u8>, data: vector<u8>) acquires Reserves, RegisteredCurrencies, WithdrawCapability {
        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let len = Vector::length(&path);
        let (path0, pathn) = (*Vector::borrow(&path, 0), *Vector::borrow(&path, len - 1));
        if(path0 > pathn){
            (ida, idb) = (idb, ida);
        };
        assert(len > 1 && ida != idb && ida == (path0 as u64) && idb == (pathn as u64), 5080);
        let amounts = Vector::empty<u64>();
        Vector::push_back(&mut amounts, amount_in);
        let reserves = borrow_global_mut<Reserves>(admin_addr());
        let i = 0;
        let amount_out = 0;
        while(i < len - 1){
            let amt_in = *Vector::borrow(&amounts, i);
            let id_in = (*Vector::borrow(&path, i) as u64);
            let id_out = (*Vector::borrow(&path, i + 1) as u64);
            if(id_in < id_out){
                let reserve = get_reserve_internal(id_in, id_out, reserves);
                let (reserve_in, reserve_out) = (reserve.coina.value, reserve.coinb.value);
                amount_out = ExDep::get_amount_out(amt_in, reserve_in, reserve_out);
                Vector::push_back(&mut amounts, amount_out);
                reserve.coina.value = reserve.coina.value + amt_in;
                reserve.coinb.value = reserve.coinb.value - amount_out;
            }
            else {
                let reserve = get_reserve_internal(id_out, id_in, reserves);
                let (reserve_in, reserve_out) = (reserve.coinb.value, reserve.coina.value);
                amount_out = ExDep::get_amount_out(amt_in, reserve_in, reserve_out);
                Vector::push_back(&mut amounts, amount_out);
                reserve.coina.value = reserve.coina.value - amount_out;
                reserve.coinb.value = reserve.coinb.value + amt_in;
            };

            i = i + 1;
        };
        assert(amount_out >= amount_out_min, 5081);
        let coina = Libra::currency_code<CoinA>();
        let coinb = Libra::currency_code<CoinB>();
        ExDep::c_s_event(coina, amount_in, coinb, amount_out, data);
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


//! new-transaction
//! sender: aa
script {
use {{super}}::Exchange;
use 0x1::LBR::LBR;
use 0x1::Coin1::Coin1;
use 0x1::Coin2::Coin2;
fun main(account: &signer) {
    Exchange::initialize(account);
    Exchange::add_currency<LBR>(account);
    Exchange::add_currency<Coin1>(account);
    Exchange::add_currency<Coin2>(account);
}
}
// check: EXECUTED

//! new-transaction
//! sender: a0
script {
use 0x1::LibraAccount;
use 0x1::LBR::LBR;
use 0x1::Coin2::Coin2;
fun main(account: &signer) {
    LibraAccount::add_currency<LBR>(account);
    LibraAccount::add_currency<Coin2>(account);
}
}
// check: EXECUTED

//! new-transaction
//! sender: a1
script {
use 0x1::LibraAccount;
use 0x1::Coin1::Coin1;
use 0x1::LBR::LBR;
fun main(account: &signer) {
    LibraAccount::add_currency<LBR>(account);
    LibraAccount::add_currency<Coin1>(account);
}
}
// check: EXECUTED

//! new-transaction
//! sender: a2
script {
use 0x1::LibraAccount;
use 0x1::LBR::LBR;
use 0x1::Coin1::Coin1;
fun main(account: &signer) {
    LibraAccount::add_currency<LBR>(account);
    LibraAccount::add_currency<Coin1>(account);
}
}
// check: EXECUTED

//! new-transaction
//! sender: aa
script {
use 0x1::LBR::LBR;
use 0x1::LibraAccount;
fun main(account: &signer) {
    let with_cap = LibraAccount::extract_withdraw_capability(account);
    LibraAccount::pay_from<LBR>(&with_cap, {{a0}}, 40000000000000000, x"", x"");
    let amt = LibraAccount::balance<LBR>({{a0}});
    assert(amt == 40000000000000000, 9001);

    LibraAccount::pay_from<LBR>(&with_cap, {{a1}}, 40000000000000000, x"", x"");
    amt = LibraAccount::balance<LBR>({{a1}});
    assert(amt == 40000000000000000, 9002);

    LibraAccount::pay_from<LBR>(&with_cap, {{a2}}, 40000000000000000, x"", x"");
    amt = LibraAccount::balance<LBR>({{a2}});
    assert(amt == 40000000000000000, 9003);
    LibraAccount::restore_withdraw_capability(with_cap);
}
}
// check: EXECUTED


//! new-transaction
//! sender: a0
script {
use 0x1::Coin1::Coin1;
use 0x1::LibraAccount;
use 0x1::Debug;
fun main(account: &signer) {
    let amt = LibraAccount::balance<Coin1>({{a0}});
    Debug::print(&amt);
    let with_cap = LibraAccount::extract_withdraw_capability(account);
    LibraAccount::pay_from<Coin1>(&with_cap, {{a1}}, 40000000000000000, x"", x"");
    LibraAccount::pay_from<Coin1>(&with_cap, {{a2}}, 40000000000000000, x"", x"");
    LibraAccount::restore_withdraw_capability(with_cap);
    amt = LibraAccount::balance<Coin1>({{a0}});
    assert(amt == 40000000000000000, 9004);
    amt = LibraAccount::balance<Coin1>({{a1}});
    assert(amt == 40000000000000000, 9005);
    amt = LibraAccount::balance<Coin1>({{a2}});
    assert(amt == 40000000000000000, 9006)
}
}
// check: EXECUTED


//! new-transaction
//! sender: a1
script {
use 0x1::Coin2::Coin2;
use 0x1::LibraAccount;
use 0x1::Debug;
fun main(account: &signer) {
    let amt = LibraAccount::balance<Coin2>({{a1}});
    Debug::print(&amt);
    let with_cap = LibraAccount::extract_withdraw_capability(account);
    LibraAccount::pay_from<Coin2>(&with_cap, {{a0}}, 40000000000000000, x"", x"");
    LibraAccount::restore_withdraw_capability(with_cap);
    amt = LibraAccount::balance<Coin2>({{a0}});
    assert(amt == 40000000000000000, 9005);
}
}
// check: EXECUTED


//! new-transaction
//! sender: a0
script {
use {{super}}::Exchange;
use 0x1::Coin1::Coin1;
use 0x1::Coin2::Coin2;
use 0x1::LibraAccount;

fun main(account: &signer) {
    let c1 = LibraAccount::balance<Coin1>({{a0}});
    let c2 = LibraAccount::balance<Coin2>({{a0}});
    let (_, c3, c4) = Exchange::get_reserve<Coin1, Coin2>();
    Exchange::add_liquidity<Coin1, Coin2>(account, 10000000000000, 40000000000000, 0, 0);
    let liq_ba = Exchange::get_liquidity_balance<Coin1, Coin2>({{a0}});
    assert(liq_ba == 20000000000000, 5001);
    let c11 = LibraAccount::balance<Coin1>({{a0}});
    let c22 = LibraAccount::balance<Coin2>({{a0}});
    let (_, c33, c44) = Exchange::get_reserve<Coin1, Coin2>();
    assert(c33 - c3 == 10000000000000 && c44 - c4 == 40000000000000, 6001);
    assert((c1 - 10000000000000) == c11 && (c2 - 40000000000000) == c22, 6000);
}
}

// check: EXECUTED



//! new-transaction
//! sender: a0
script {
use {{super}}::Exchange;
use 0x1::Coin1::Coin1;
use 0x1::Coin2::Coin2;
use 0x1::Debug;

fun main(account: &signer) {
    Exchange::add_liquidity<Coin1, Coin2>(account, 8000000000000, 100000000000000, 0, 0);
    let liq_ba = Exchange::get_liquidity_balance<Coin1, Coin2>({{a0}});
    Debug::print(&liq_ba);
    let (_, c33, c44) = Exchange::get_reserve<Coin1, Coin2>();
    Debug::print(&c33);
    Debug::print(&c44);
}
}

// check: EXECUTED


//! new-transaction
//! sender: a0
script {
use {{super}}::Exchange;
use 0x1::Coin1::Coin1;
use 0x1::Coin2::Coin2;
use 0x1::LibraAccount;
use 0x1::Debug;

fun main(account: &signer) {
    let liq_ba = Exchange::get_liquidity_balance<Coin1, Coin2>({{a0}});
    Debug::print(&liq_ba);
    let c1 = LibraAccount::balance<Coin1>({{a0}});
    let c2 = LibraAccount::balance<Coin2>({{a0}});
    let (total, c3, c4) = Exchange::get_reserve<Coin1, Coin2>();
    assert(liq_ba == total, 5010);

    Exchange::remove_liquidity<Coin1, Coin2>(account, liq_ba/2, 0, 0);
    Exchange::remove_liquidity<Coin1, Coin2>(account, liq_ba/2, 0, 0);
    let c11 = LibraAccount::balance<Coin1>({{a0}});
    let c22 = LibraAccount::balance<Coin2>({{a0}});
    let (total1, c33, c44) = Exchange::get_reserve<Coin1, Coin2>();
    assert(c33 == 0 && c44 == 0 && total1 == 0, 6001);
    assert((c1 + c3) == c11 && (c2 + c4) == c22, 6000);
}
}
// check: EXECUTED



//! new-transaction
//! sender: a0
script {
use {{super}}::Exchange;
use 0x1::Coin1::Coin1;
use 0x1::Coin2::Coin2;

fun main(account: &signer) {
    Exchange::add_liquidity<Coin1, Coin2>(account, 50000000000000, 100000000000000, 0, 0);
}
}

// check: EXECUTED



//! new-transaction
//! sender: a1
script {
use {{super}}::Exchange;
use 0x1::Coin1::Coin1;
use 0x1::Coin2::Coin2;
use 0x1::LibraAccount;
use 0x1::Vector;
use 0x1::Signer;

fun main(account: &signer) {
    let c1 = LibraAccount::balance<Coin1>({{a1}});
    let c2 = LibraAccount::balance<Coin2>({{a1}});
    let (_, c3, c4) = Exchange::get_reserve<Coin1, Coin2>();
    let path = Vector::empty<u8>();
    Vector::push_back(&mut path, 1);
    Vector::push_back(&mut path, 2);
    Exchange::swap<Coin1, Coin2>(account, Signer::address_of(account), 10000000000000, 0, path, Vector::empty<u8>());
    let liq_ba = Exchange::get_liquidity_balance<Coin1, Coin2>({{a0}});
    let c11 = LibraAccount::balance<Coin1>({{a1}});
    let c22 = LibraAccount::balance<Coin2>({{a1}});
    let (t1, c33, c44) = Exchange::get_reserve<Coin1, Coin2>();
    assert(liq_ba == t1, 7000);
    assert(c33 - c3 == 10000000000000 && c4 - c44 == 16662499791656, 7001);
    assert((c1 - 10000000000000) == c11 && (c2 + 16662499791656) == c22, 7002);
    let path1 = Vector::empty<u8>();
    Vector::push_back(&mut path1, 2);
    Vector::push_back(&mut path1, 1);
    Exchange::swap<Coin1, Coin2>(account, Signer::address_of(account), 10000000000000, 0, path1, Vector::empty<u8>());
    let c111 = LibraAccount::balance<Coin1>({{a1}});
    let c222 = LibraAccount::balance<Coin2>({{a1}});
    let (_, c333, c444) = Exchange::get_reserve<Coin1, Coin2>();
    assert(c33 - c333 == 6426562510765 && c444 - c44 == 10000000000000, 7011);
    assert((c22 - 10000000000000) == c222 && (c111 - 6426562510765) == c11, 7012);
}
}

// check: EXECUTED



//! new-transaction
//! sender: a0
script {
use {{super}}::Exchange;
use 0x1::Coin1::Coin1;
use 0x1::Coin2::Coin2;

fun main(account: &signer) {
    let (total, _, _) = Exchange::get_reserve<Coin1, Coin2>();
    Exchange::remove_liquidity<Coin1, Coin2>(account, total, 0, 0);
    let (t1, c33, c44) = Exchange::get_reserve<Coin1, Coin2>();
    assert(c33 == 0 && c44 == 0 && t1 == 0, 6001);
}
}
// check: EXECUTED


//! new-transaction
//! sender: a0
script {
use {{super}}::Exchange;
use 0x1::Coin1::Coin1;
use 0x1::Coin2::Coin2;
use 0x1::LBR::LBR;

fun main(account: &signer) {
    Exchange::add_liquidity<LBR, Coin1>(account, 40000000000000, 80000000000000, 0, 0);
    Exchange::add_liquidity<Coin1, Coin2>(account, 50000000000000, 50000000000000, 0, 0);
}
}

// check: EXECUTED


//! new-transaction
//! sender: a2
script {
use {{super}}::Exchange;
use 0x1::LBR::LBR;
use 0x1::Coin2::Coin2;
use 0x1::Vector;
use 0x1::Signer;

fun main(account: &signer) {
    let path = Vector::empty<u8>();
    Vector::push_back(&mut path, 0);
    Vector::push_back(&mut path, 1);
    Vector::push_back(&mut path, 2);
    Exchange::swap<LBR, Coin2>(account, Signer::address_of(account), 10000000000000, 0, path, Vector::empty<u8>());

    let path1 = Vector::empty<u8>();
    Vector::push_back(&mut path1, 2);
    Vector::push_back(&mut path1, 1);
    Vector::push_back(&mut path1, 0);
    Exchange::swap<LBR, Coin2>(account, Signer::address_of(account), 10000000000000, 0, path1, Vector::empty<u8>());

}
}

// check: EXECUTED