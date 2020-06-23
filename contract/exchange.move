address 0x7257c2417e4d1038e1817c8f283ace2e {

module Exchange {
    use 0x1::Transaction;
    use 0x1::LibraAccount;
    use 0x1::Libra;
    use 0x1::Vector;
    use 0x1::LCS;
    use 0x1::Debug;
    use 0x7257c2417e4d1038e1817c8f283ace2e::ExDep;

    resource struct Reserves {
        reserves: vector<Reserve>,
    }

    resource struct RegisteredCurrencies {
        currency_codes: vector<vector<u8>>,
    }

    resource struct Reserve{
        liquidity_total_supply: u64,
        coina: Token,
        coinb: Token,
    }

    resource struct Tokens {
        tokens: vector<Token>,
    }

    resource struct WithdrawCapability {
        cap: ExDep::WithdrawCapability,
    }

    resource struct Token {
        index: u64,
        value: u64,
    }

    fun singleton_addr(): address {
        0x7257c2417e4d1038e1817c8f283ace2e
    }

    public fun initialize(sender: &signer) {
        assert(Transaction::sender() == singleton_addr(), 5000);
        move_to_sender(Reserves {
            reserves: Vector::empty()
        });
        move_to_sender(RegisteredCurrencies {
            currency_codes: Vector::empty()
        });
        move_to_sender(WithdrawCapability {
            cap: ExDep::extract_withdraw_capability(sender)
        });
    }

    // Add a balance of `Token` type to the sending account.
    public fun add_currency<Token>(account: &signer) acquires RegisteredCurrencies {
        let currency_code = Libra::currency_code<Token>();
        let registered_currencies = borrow_global_mut<RegisteredCurrencies>(singleton_addr());
        Vector::push_back(&mut registered_currencies.currency_codes, currency_code);
        ExDep::add_currency<Token>(account);
    }

    // Return whether accepts `Token` type coins
    fun accepts_currency<Token>(): bool acquires RegisteredCurrencies {
        let _ = get_coin_id<Token>();
        LibraAccount::accepts_currency<Token>(singleton_addr())
    }

    public fun get_currencys(): vector<vector<u8>> acquires RegisteredCurrencies {
        let registered_currencies = borrow_global_mut<RegisteredCurrencies>(singleton_addr());
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
        let reserves = borrow_global_mut<Reserves>(singleton_addr());
        let reserve = get_reserve_internal(ida, idb, reserves);
        let va = ExDep::balance<CoinA>();
        let vb = ExDep::balance<CoinB>();
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

    fun deposit<Token>(account: &signer, to_deposit: u64, metadata: vector<u8>) acquires WithdrawCapability {
        let capability = borrow_global<WithdrawCapability>(singleton_addr());
        ExDep::deposit<Token>(account, &capability.cap, to_deposit, metadata);
    }

    public fun withdraw<Token>(account: &signer, amount: u64, metadata: vector<u8>) acquires WithdrawCapability{
        let capability = borrow_global<WithdrawCapability>(singleton_addr());
        ExDep::withdraw<Token>(account, &capability.cap, amount, metadata);
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

    fun mint<CoinA, CoinB>(account: &signer, ida: u64, idb: u64, amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64, reservea: u64, reserveb: u64, total_supply: u64): (u64, u64, u64) acquires Tokens, WithdrawCapability {
        let sender = Transaction::sender();
        if(!exists<Tokens>(sender)){
            move_to_sender<Tokens>(Tokens { tokens: Vector::empty() });
        };
        let id = (ida << 32) + idb;
        let tokens = borrow_global_mut<Tokens>(sender);
        let token = get_token(id, tokens);
        let (liquidity, amounta, amountb) = ExDep::get_mint_liquidity(amounta_desired, amountb_desired, amounta_min, amountb_min, reservea, reserveb, total_supply);
        token.value = token.value + liquidity;
        let coina = Libra::currency_code<CoinA>();
        let coinb = Libra::currency_code<CoinB>();
        let mint_event = ExDep::c_m_event(coina, amounta, coinb, amountb, liquidity);
        let metadata = LCS::to_bytes<ExDep::MintEvent>(&mint_event);
        Debug::print(&mint_event);
        deposit<CoinA>(account, amounta, metadata);
        deposit<CoinB>(account, amountb, x"");
        (total_supply + liquidity, amounta, amountb)
    }

    public fun add_liquidity<CoinA, CoinB>(account: &signer, amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64) acquires Reserves, RegisteredCurrencies, Tokens, WithdrawCapability {
        assert(accepts_currency<CoinA>() && accepts_currency<CoinB>(), 5060);
        let reserves = borrow_global_mut<Reserves>(singleton_addr());

        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let reserve = get_reserve_internal(ida, idb, reserves);

        let (total_supply, reservea, reserveb) = (reserve.liquidity_total_supply, reserve.coina.value, reserve.coinb.value);
        let (total_supply, amounta, amountb) = mint<CoinA, CoinB>(account, ida, idb, amounta_desired, amountb_desired, amounta_min, amountb_min, reservea, reserveb, total_supply);
        reserve.liquidity_total_supply = total_supply;
        reserve.coina.value = reservea + amounta;
        reserve.coinb.value = reserveb + amountb;
    }

    public fun remove_liquidity<CoinA, CoinB>(account: &signer, liquidity: u64, amounta_min: u64, amountb_min: u64) acquires Reserves, RegisteredCurrencies, Tokens, WithdrawCapability {
        let reserves = borrow_global_mut<Reserves>(singleton_addr());

        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let reserve = get_reserve_internal(ida, idb, reserves);
        let (total_supply, reservea, reserveb) = (reserve.liquidity_total_supply, reserve.coina.value, reserve.coinb.value);
        let tokens = borrow_global_mut<Tokens>(Transaction::sender());
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

        let burn_event = ExDep::c_b_event(coina, amounta, coinb, amountb, liquidity);
        let metadata = LCS::to_bytes<ExDep::BurnEvent>(&burn_event);
        Debug::print(&burn_event);
        withdraw<CoinA>(account, amounta, metadata);
        withdraw<CoinB>(account, amountb, x"");
    }

    public fun swap<CoinA, CoinB>(account: &signer, amount_in: u64, amount_out_min: u64, path: vector<u8>) acquires Reserves, RegisteredCurrencies, WithdrawCapability {
        let (ida, idb) = get_pair_indexs<CoinA, CoinB>();
        let len = Vector::length(&path);
        let (path0, pathn) = (*Vector::borrow(&path, 0), *Vector::borrow(&path, len - 1));
        if(path0 > pathn){
            (ida, idb) = (idb, ida);
        };
        assert(len > 1 && ida != idb && ida == (path0 as u64) && idb == (pathn as u64), 5080);
        let amounts = Vector::empty<u64>();
        Vector::push_back(&mut amounts, amount_in);
        let reserves = borrow_global_mut<Reserves>(singleton_addr());
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
                Debug::print(reserve);
            }
            else {
                let reserve = get_reserve_internal(id_out, id_in, reserves);
                let (reserve_in, reserve_out) = (reserve.coinb.value, reserve.coina.value);
                amount_out = ExDep::get_amount_out(amt_in, reserve_in, reserve_out);
                Vector::push_back(&mut amounts, amount_out);
                reserve.coina.value = reserve.coina.value - amount_out;
                reserve.coinb.value = reserve.coinb.value + amt_in;
                Debug::print(reserve);
            };

            i = i + 1;
        };
        assert(amount_out >= amount_out_min, 5081);
        let coina = Libra::currency_code<CoinA>();
        let coinb = Libra::currency_code<CoinB>();
        let swap_event =  ExDep::c_s_event(coina, amount_in, coinb, amount_out);
        let metadata = LCS::to_bytes<ExDep::SwapEvent>(&swap_event);
        Debug::print(&swap_event);
        if(path0 < pathn){
            deposit<CoinA>(account, amount_in, metadata);
            withdraw<CoinB>(account, amount_out, x"");
        }
        else
        {
            deposit<CoinB>(account, amount_in, metadata);
            withdraw<CoinA>(account, amount_out, x"");
        };
    }
}
}