address 0x7257c2417e4d1038e1817c8f283ace2e:

module ExBase {
    use 0x0::Transaction;
    use 0x0::LibraTransactionTimeout;
    use 0x0::LibraAccount;
    use 0x0::LBR;
    use 0x0::Libra;
    use 0x0::Vector;
    use 0x7257c2417e4d1038e1817c8f283ace2e::ViolasToken;

    resource struct T {
        tokens: vector<Token>,
    }

    resource struct Token {
        index: u64,
        value: u64,
    }

    public fun create_tokens(): T {
        T{ tokens: Vector::empty() }
    }

    public fun balance(res: &mut T, index: u64): u64 {
        Transaction::assert(index < Vector::length(&res.tokens), 200);
        let t = Vector::borrow_mut(&mut res.tokens, index);
        t.value
    }

    public fun deposit(res: &mut T, to_deposit: Token){
        extend_tokens(res);
        let Token { index, value } = to_deposit;
        Transaction::assert(index < Vector::length(&res.tokens), 201);
        let t = Vector::borrow_mut(&mut res.tokens, index);
        t.value = t.value + value;
    }

    public fun withdraw(res: &mut T, index: u64, amount: u64): Token {
        Transaction::assert(index < Vector::length(&res.tokens), 202);
        let t = Vector::borrow_mut(&mut res.tokens, index);
        Transaction::assert(t.value >= amount, 203);
        t.value = t.value - amount;
        Token { index: index, value: amount }
    }

    fun extend_tokens(res: &mut T) {
        let tokencnt = Vector::length(&res.tokens);
        let total_cnt = ViolasToken::token_count();
        loop {
            if(tokencnt >= total_cnt) break;
            Vector::push_back(&mut res.tokens, Token{ index: tokencnt, value: 0});
            tokencnt = tokencnt + 1;
        }
    }

    public fun mint(index: u64, amount: u64): Token {
        Token { index: index, value: amount }
    }

    public fun destroy(res: &mut T, index: u64, amount: u64) {
        Transaction::assert(index < Vector::length(&res.tokens), 204);
        let t = Vector::borrow_mut(&mut res.tokens, index);
        Transaction::assert(t.value >= amount, 205);
        t.value = t.value - amount;
    }

    public fun contract_address() : address {
	    0x7257c2417e4d1038e1817c8f283ace2e
    }

    public fun assert_deadline(deadline: u64){
        Transaction::assert(LibraTransactionTimeout::is_valid_transaction_timestamp(deadline), 207); 
    }

    public fun calculate_token_mint(min_liquidity:u64, violas_amount: u64, max_token_amount: u64, total_liquidity: u64, token_reserve: u64, violas_reserve: u64): (u64, u64, u64){
        if (total_liquidity > 0) {
            Transaction::assert(min_liquidity > 0, 208);
            let big_num:u128 = (violas_amount as u128) * (token_reserve as u128);
            let token_amount:u64 = ((big_num / (violas_reserve as u128) + 1) as u64);
            //Transaction::assert(false, 555);
            big_num = (violas_amount as u128) * (total_liquidity as u128);
            let liquidity_token_minted:u64 = (big_num / (violas_reserve as u128) as u64);
            Transaction::assert(max_token_amount >= token_amount && liquidity_token_minted >= min_liquidity, 209);
            min_liquidity = liquidity_token_minted;
            max_token_amount = token_amount;
            total_liquidity = total_liquidity + liquidity_token_minted
        }
        else{
            Transaction::assert(violas_amount >= 100000, 210);
            let token_amount = max_token_amount;
            let liquidity_token_minted = violas_amount;
            min_liquidity = liquidity_token_minted;
            max_token_amount = token_amount;
            total_liquidity = liquidity_token_minted
        };
        (min_liquidity, max_token_amount, total_liquidity)
    }

    public fun calculate_token_remove(amount: u64, violas_reserve: u64, token_reserve: u64, min_violas: u64, min_tokens: u64, total_liquidity: u64): (u64, u64) {
        let big_amount:u128 = (amount as u128);
        let big_violas_reserve:u128 = (violas_reserve as u128);
        let big_token_reserve:u128 = (token_reserve as u128);
        let big_total_liquidity:u128 = (total_liquidity as u128);
        let violas_amount:u64 = ((big_amount * big_violas_reserve / big_total_liquidity) as u64);
        let token_amount:u64 = ((big_amount * big_token_reserve / big_total_liquidity) as u64);
        Transaction::assert(violas_amount >= min_violas && token_amount >= min_tokens, 211);
        (violas_amount, token_amount)
    }

    // @dev pricing function for converting between violas and tokens.
    // @param token_idx--index of tokens in exchange reserves.
    // @param input_amount--amount of violas or tokens being sold.
    // @param input_reserve amount of violas or tokens (input type) in exchange reserves.
    // @param output_reserve Amount of violas or tokens (output type) in exchange reserves.
    // @return amount of violas or token bought.
    public fun get_input_price(tokenidx: u64, input_amount: u64, input_reserve: u64, output_reserve: u64): u64 {
        Transaction::assert(input_reserve > 0 && output_reserve > 0, 212);
        let input_amount_with_fee = (input_amount as u128) * 997;
        let numerator = input_amount_with_fee * (output_reserve as u128);
        let denominator = ((input_reserve as u128) * 1000) + input_amount_with_fee;
        ((numerator / denominator) as u64)
    }

    // @dev pricing function for converting between violas and tokens.
    // @param token_idx--index of tokens in exchange reserves.
    // @param output_amount--amount of violas or tokens being bought.
    // @param input_reserve amount of violas or tokens (input type) in exchange reserves.
    // @param output_reserve Amount of violas or tokens (output type) in exchange reserves.
    // @return amount of violas or token sold.
    public fun get_output_price(tokenidx: u64, output_amount: u64, input_reserve: u64, output_reserve: u64): u64 {
        Transaction::assert(input_reserve > 0 && output_reserve > 0, 213);
        let numerator = (input_reserve as u128) * (output_amount as u128) * 1000;
        let denominator = ((output_reserve - output_amount) as u128) * 997;
        ((numerator / denominator + 1) as u64)
    }
    
    public fun deposit_token(token_ref: &mut ViolasToken::T, tokenidx: u64, amount: u64){
        let token1 = ViolasToken::withdraw(tokenidx, amount);
        ViolasToken::join2(token_ref, token1);
    }

    public fun deposit_violas(coin_ref: &mut Libra::T<LBR::T>, amount: u64){
        let coin1 =  LibraAccount::withdraw_from_sender<LBR::T>(amount);
        Libra::deposit<LBR::T>(coin_ref, coin1);
    }

    public fun withdraw_token(token_ref: &mut ViolasToken::T, amount: u64){
        let token1 = ViolasToken::split(token_ref, amount);
        let sender = Transaction::sender();
        ViolasToken::deposit(sender, token1);
    }

    public fun withdraw_violas(coin_ref: &mut Libra::T<LBR::T>, amount: u64){
        let coin1 = Libra::withdraw<LBR::T>(coin_ref, amount);
        LibraAccount::deposit_to_sender(coin1);
    }
}