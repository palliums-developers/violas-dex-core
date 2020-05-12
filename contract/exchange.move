address 0x7257c2417e4d1038e1817c8f283ace2e:

module Exchange {
    use 0x0::Vector;
    use 0x0::Transaction;
    use 0x0::LibraAccount;
    use 0x0::LBR;
    use 0x0::Libra;
    use 0x7257c2417e4d1038e1817c8f283ace2e::ViolasToken;
    use 0x7257c2417e4d1038e1817c8f283ace2e::ExBase;

    resource struct T {
        reserves: vector<Reserve>,
    }

    resource struct Reserve{
        liquidity_total_supply: u64,

        token: ViolasToken::T,
        violas: Libra::T<LBR::T>,
    }

    resource struct LQTokens {
	    ts: ExBase::T,
        // Event handle for exchange event
        exchange_events: LibraAccount::EventHandle<ExchangeEvent>,
    }

    // Message for sent events
    struct ExchangeEvent {
        etype: u64,
        value1: u64,
        value2: u64,
        value3: u64,
        value4: u64,
    }

    public fun emit_events(etype: u64, v1: u64, v2: u64, v3: u64, v4: u64) acquires LQTokens {
        let sender = Transaction::sender();
        let lqtoken = borrow_global_mut<LQTokens>(sender);
        LibraAccount::emit_event<ExchangeEvent>(
            &mut lqtoken.exchange_events, 
            ExchangeEvent {
                etype: etype,
                value1: v1,
                value2: v2,
                value3: v3,
                value4: v4,
            }
        );
    }

    // This can only be invoked by the Association address, and only a single time.
    public fun initialize() {
        // Only callable by the Association address
        Transaction::assert(Transaction::sender() == ExBase::contract_address(), 216);
        move_to_sender<T>(T{reserves: Vector::empty() });
    }

    public fun publish() acquires LQTokens{
        let sender = Transaction::sender();
        Transaction::assert(!exists<LQTokens>(sender), 214);
        move_to_sender<LQTokens>(LQTokens { 
            ts: ExBase::create_tokens(),
            exchange_events:  LibraAccount::new_event_handle<ExchangeEvent>(),
            }
        );
        emit_events(0, 0, 0, 0, 0);
    }

    public fun require_published(addr: address) {
	    Transaction::assert(exists<LQTokens>(addr), 215);
    }

    fun deposit(payee: address, to_deposit: ExBase::Token) acquires LQTokens {
        require_published(payee);
        let lq_tokens = borrow_global_mut<LQTokens>(payee);
        ExBase::deposit(&mut lq_tokens.ts, to_deposit);
    }

    fun withdraw(index: u64, amount: u64): ExBase::Token acquires LQTokens{
        let sender = Transaction::sender();
        require_published(sender);
        let lq_tokens = borrow_global_mut<LQTokens>(sender);
        ExBase::withdraw(&mut lq_tokens.ts, index, amount)
    }

    fun mint(index: u64, amount: u64) acquires LQTokens {
        let payee = Transaction::sender();
        if(!exists<LQTokens>(payee)){
            publish();
        };
        let t = ExBase::mint(index, amount);
        deposit(payee, t);
    }

    fun destroy(index: u64, amount: u64) acquires LQTokens {
        let sender = Transaction::sender();
        require_published(sender);
        let lq_tokens = borrow_global_mut<LQTokens>(sender);
        ExBase::destroy(&mut lq_tokens.ts, index, amount);
    }

    public fun balance(index: u64, addr: address): u64  acquires LQTokens {
        require_published(addr);
        let lq_tokens = borrow_global_mut<LQTokens>(addr);
        ExBase::balance(&mut lq_tokens.ts, index)
    }

    public fun transfer(payee: address, index: u64, amount: u64) acquires LQTokens {
        let t = withdraw(index, amount);
        deposit(payee, t);
    }

    fun fill_reserves(idx: u64, reserves: &mut vector<Reserve>){
        let total_cnt = ViolasToken::token_count();
        Transaction::assert(idx < total_cnt, 217);
        let len = Vector::length(reserves);
        loop {
            if(len >= total_cnt) break;
            Vector::push_back(reserves, Reserve{ liquidity_total_supply: 0, token: ViolasToken::zero(len), violas: Libra::zero<LBR::T>()});
            len = len + 1;
	    }
    }

    public fun get_reserve(tokenidx: u64): (u64, u64, u64) acquires T{
        let pool = borrow_global_mut<T>(ExBase::contract_address());
        fill_reserves(tokenidx, &mut pool.reserves);
        let reserve = Vector::borrow_mut(&mut pool.reserves, tokenidx);
        (reserve.liquidity_total_supply, ViolasToken::value(&reserve.token), Libra::value<LBR::T>(&reserve.violas))
    }

    fun get_reserve_internal(idx: u64, reserves: &mut vector<Reserve>): (u64, u64) {
        fill_reserves(idx, reserves);
        let reserve = Vector::borrow_mut(reserves, idx);
        (ViolasToken::value(&reserve.token), Libra::value<LBR::T>(&reserve.violas))
    }
    
    public fun add_liquidity(tokenidx: u64, min_liquidity: u64, max_token_amount: u64, violas_amount: u64, deadline: u64) acquires T, LQTokens {
        ExBase::assert_deadline(deadline);
        let addr = ExBase::contract_address();
        let pool = borrow_global_mut<T>(addr);
        let (token_reserve, violas_reserve) = get_reserve_internal(tokenidx, &mut pool.reserves);
        let reserve = Vector::borrow_mut(&mut pool.reserves, tokenidx);
        let total_liquidity = reserve.liquidity_total_supply;

        let (liquidity_token_minted, token_amount, new_total_liquidity) = ExBase::calculate_token_mint(min_liquidity, violas_amount, max_token_amount, total_liquidity, token_reserve, violas_reserve);

        reserve.liquidity_total_supply = new_total_liquidity;
        mint(tokenidx, liquidity_token_minted);
        ExBase::deposit_violas(&mut reserve.violas, violas_amount);
        ExBase::deposit_token(&mut reserve.token, tokenidx, token_amount);
        emit_events(1, tokenidx, liquidity_token_minted, violas_amount, token_amount);
    }

    public fun remove_liquidity(amount: u64, tokenidx: u64, min_violas: u64, min_tokens: u64, deadline: u64) acquires T, LQTokens{
        ExBase::assert_deadline(deadline);
        Transaction::assert(amount > 0 && min_violas > 0 && min_tokens > 0, 219);
        let pool = borrow_global_mut<T>(ExBase::contract_address());
        let (token_reserve, violas_reserve) = get_reserve_internal(tokenidx, &mut pool.reserves);
        let reserve = Vector::borrow_mut(&mut pool.reserves, tokenidx);
        let total_liquidity = reserve.liquidity_total_supply;
        Transaction::assert(total_liquidity > 0, 220);
        let (violas_amount, token_amount) = ExBase::calculate_token_remove(amount, violas_reserve, token_reserve, min_violas, min_tokens, total_liquidity);
        reserve.liquidity_total_supply = total_liquidity - amount;
        destroy(tokenidx, amount);
        ExBase::withdraw_token(&mut reserve.token, token_amount);
        ExBase::withdraw_violas(&mut reserve.violas, violas_amount);
        emit_events(2, tokenidx, amount, violas_amount, token_amount);
    }

    // @notice convert violas to tokens.
    // @dev user specifies exact input (violas_sold) and minimum output.
    // @param violas_sold--exact violas amount sold.
    // @param min_tokens--minimum tokens bought.
    // @param deadline--time after which this transaction can no longer be executed.
    // @return amount of tokens bought.
    fun _violas_to_token_swap_input(violas_sold: u64, tokenidx: u64, min_tokens: u64, deadline: u64): u64 acquires T{
        ExBase::assert_deadline(deadline);
        Transaction::assert(violas_sold > 0 && min_tokens > 0, 221);
        let pool = borrow_global_mut<T>(ExBase::contract_address());
        let (token_reserve, violas_reserve) = get_reserve_internal(tokenidx, &mut pool.reserves);
        let reserve = Vector::borrow_mut(&mut pool.reserves, tokenidx);
        let tokens_bought = ExBase::get_input_price(tokenidx, violas_sold, violas_reserve, token_reserve);
        Transaction::assert(tokens_bought >= min_tokens, 222);
        ExBase::deposit_violas(&mut reserve.violas, violas_sold);
        ExBase::withdraw_token(&mut reserve.token, tokens_bought);
        tokens_bought
    }

    public fun violas_to_token_swap_input(violas_sold: u64, tokenidx: u64, min_tokens: u64, deadline: u64) acquires T, LQTokens {
        let tokens_bought = _violas_to_token_swap_input(violas_sold, tokenidx, min_tokens, deadline);
        emit_events(3, tokenidx, 0, violas_sold, tokens_bought);
    }

    // @notice convert tokens to violas.
    // @dev user specifies exact input and minimum output.
    // @param tokens_sold--amount of tokens  sold.
    // @param min_violas--minimum violas purchased.
    // @param deadline--time after which this transaction can no longer be executed.
    // @return amount of violas bought.
    public fun _token_to_violas_swap_input(tokens_sold: u64, tokenidx: u64, min_violas: u64, deadline: u64): u64 acquires T{
        ExBase::assert_deadline(deadline);
        Transaction::assert(tokens_sold > 0 && min_violas > 0, 225);
        let pool = borrow_global_mut<T>(ExBase::contract_address());
        let (token_reserve, violas_reserve) = get_reserve_internal(tokenidx, &mut pool.reserves);
        let reserve = Vector::borrow_mut(&mut pool.reserves, tokenidx);
        let violas_bought = ExBase::get_input_price(tokenidx, tokens_sold, token_reserve, violas_reserve);
        Transaction::assert(violas_bought >= min_violas, 226);
        ExBase::withdraw_violas(&mut reserve.violas, violas_bought);
        ExBase::deposit_token(&mut reserve.token, tokenidx, tokens_sold);
        violas_bought
    }
    public fun token_to_violas_swap_input(tokens_sold: u64, tokenidx: u64, min_violas: u64, deadline: u64) acquires T, LQTokens{
        let violas_bought = _token_to_violas_swap_input(tokens_sold, tokenidx, min_violas, deadline);
        emit_events(4, tokenidx, 0, tokens_sold, violas_bought);
    }

    // @notice convert tokens (input) to tokens (output).
    // @dev user specifies exact input and minimum output.
    // @param tokens_sold amount of tokens sold.
    // @param min_tokens_bought minimum tokens purchased.
    // @param min_violas_bought minimum violas purchased as intermediary.
    // @param deadline time after which this transaction can no longer be executed.
    // @return amount of tokens (output) bought.
    public fun token_to_token_swap_input(tokens_sold: u64, token_sold_idx: u64, min_tokens_bought: u64, token_bought_idx: u64, min_violas_bought: u64, deadline: u64) acquires T, LQTokens {
        ExBase::assert_deadline(deadline);
        Transaction::assert(tokens_sold > 0 && min_tokens_bought > 0 && min_violas_bought > 0, 229);
        let pool = borrow_global_mut<T>(ExBase::contract_address());
        let (token_reserve, violas_reserve) = get_reserve_internal(token_sold_idx, &mut pool.reserves);
        let reserve = Vector::borrow_mut(&mut pool.reserves, token_sold_idx);
        let violas_bought = ExBase::get_input_price(token_sold_idx, tokens_sold, token_reserve, violas_reserve);
        Transaction::assert(violas_bought >= min_violas_bought, 230);
        ExBase::deposit_token(&mut reserve.token, token_sold_idx, tokens_sold);
        ExBase::withdraw_violas(&mut reserve.violas, violas_bought);
        let tokens_bought = _violas_to_token_swap_input(violas_bought, token_bought_idx, min_tokens_bought, deadline);
        emit_events(5, token_sold_idx, token_bought_idx, tokens_sold, tokens_bought);
    }

    //flag = 0: input, flag = 1: output
    public fun get_violas_to_token_price(idx: u64, flag: u8, value: u64): u64 acquires T{
        let (_, t_r, v_r) = get_reserve(idx);
        if(flag == 0){
            ExBase::get_input_price(idx, value, v_r, t_r)
        }
        else{
            ExBase::get_output_price(idx, value, v_r, t_r)
        }
    }

    //flag = 0: input, flag = 1: output
    public fun get_token_to_violas_price(idx: u64, flag: u8, value: u64): u64 acquires T{
        let (_, t_r, v_r) = get_reserve(idx);
        if(flag == 0){
            ExBase::get_input_price(idx, value, t_r, v_r)
        }
        else{
            ExBase::get_output_price(idx, value, t_r, v_r)
        }
    }
}
