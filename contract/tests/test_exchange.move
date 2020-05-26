//! account: a0
//! account: a1, 100000000000000LBR
//! account: a2, 100000000000000LBR
//! account: a3, 100000000000000LBR

//! sender: a0

module Exchange {
    use 0x0::LBR;
    use 0x0::Libra;
    use 0x0::Event;
    use 0x0::Transaction;
    use 0x0::LibraTransactionTimeout;
    use 0x0::LibraAccount;
    use 0x0::Debug;
    use 0x0::Vector;

    // The liquidity token has a `CoinType` color that tells us what currency the
    // `value` inside represents.
    resource struct T<Token> { value: u64 }

    resource struct Reserve<Token> {
        liquidity_total_supply: u64,

        token: Libra::T<Token>,
        violas: Libra::T<LBR::T>,
    }

    struct MintEvent {
        // funds added to the system
        mint_amount: u64,
        token_amount: u64,
        violas_amount: u64,
        currency_code: vector<u8>,
        mint_address: address,
    }

    struct BurnEvent {
        // funds removed from the system
        burn_amount: u64,
        token_amount: u64,
        violas_amount: u64,
        currency_code: vector<u8>,
        burn_address: address,
    }

    struct SwapEvent {
        input_amount: u64,
        input_currency_code: vector<u8>,
        output_amount: u64,
        output_currency_code: vector<u8>,
        sender: address,
    }

    resource struct RegisteredCurrencies {
        currency_codes: vector<vector<u8>>,
    }

    resource struct ExchangeInfo {
        mint_events: Event::EventHandle<MintEvent>,
        burn_events: Event::EventHandle<BurnEvent>,
        swap_events: Event::EventHandle<SwapEvent>,
    }

    public fun initialize() {
        Transaction::assert(Transaction::sender() == singleton_addr(), 3000);
        move_to_sender(RegisteredCurrencies {
            currency_codes: Vector::empty()
        });
        move_to_sender(ExchangeInfo {
            mint_events: Event::new_event_handle<MintEvent>(),
            burn_events: Event::new_event_handle<BurnEvent>(),
            swap_events: Event::new_event_handle<SwapEvent>()
        });
    }

    public fun publish_reserve<CoinType>() acquires RegisteredCurrencies {
        let sender = Transaction::sender();
        Transaction::assert( sender == singleton_addr(), 3001);
        let currency_code = Libra::currency_code<CoinType>();
        let registered_currencies = borrow_global_mut<RegisteredCurrencies>(sender);
        Vector::push_back(&mut registered_currencies.currency_codes, currency_code);

        move_to_sender<Reserve<CoinType>>(Reserve<CoinType> {
            liquidity_total_supply: 0,
            token: Libra::zero<CoinType>(),
            violas: Libra::zero<LBR::T>()
        });
    }

    fun register_token<CoinType>() {
        let sender = Transaction::sender();
        Transaction::assert(!exists<T<CoinType>>(sender), 3002);
        move_to_sender<T<CoinType>>(T<CoinType> { 
                value: 0
            }
        );
    }

    public fun require_published<CoinType>(addr: address) {
	    Transaction::assert(exists<T<CoinType>>(addr), 3003);
    }

    fun deposit<CoinType>(payee: address, to_deposit: T<CoinType>) acquires T {
        require_published<CoinType>(payee);
        let token = borrow_global_mut<T<CoinType>>(payee);
        let T { value } = to_deposit;
        token.value = token.value + value;
    }

    fun withdraw<CoinType>(amount: u64): T<CoinType> acquires T{
        let sender = Transaction::sender();
        require_published<CoinType>(sender);
        let token = borrow_global_mut<T<CoinType>>(sender);
        // Check that `amount` is less than the coin's value
        Transaction::assert(token.value >= amount, 3004);
        token.value = token.value - amount;
        T { value: amount }
    }

    fun mint<CoinType>(amount: u64) acquires T {
        let payee = Transaction::sender();
        if(!exists<T<CoinType>>(payee)){
            register_token<CoinType>();
        };
        let token = T<CoinType> { value: amount };
        deposit(payee, token);
    }

    fun destroy<CoinType>(amount: u64) acquires T {
        let sender = Transaction::sender();
        require_published<CoinType>(sender);
        let token = borrow_global_mut<T<CoinType>>(sender);
        Transaction::assert(token.value >= amount, 3005);
        token.value = token.value - amount;
    }

    public fun balance<CoinType>(addr: address): u64  acquires T {
        require_published<CoinType>(addr);
        let token = borrow_global_mut<T<CoinType>>(addr);
        token.value
    }

    public fun get_reserve<CoinType>(): (u64, u64, u64) acquires Reserve{
        let reserve = borrow_global_mut<Reserve<CoinType>>(singleton_addr());
        let token_reserve = Libra::value<CoinType>(&reserve.token);
        let violas_reserve = Libra::value<LBR::T>(&reserve.violas);
        (reserve.liquidity_total_supply, token_reserve, violas_reserve)
    }

    public fun get_currencys() : vector<vector<u8>> acquires RegisteredCurrencies {
        let registered_currencies = borrow_global_mut<RegisteredCurrencies>(singleton_addr());
        *&registered_currencies.currency_codes
    }

    public fun add_liquidity<CoinType>(min_liquidity: u64, max_token_amount: u64, violas_amount: u64, deadline: u64) acquires T, Reserve, ExchangeInfo {
        assert_deadline(deadline);
        let reserve = borrow_global_mut<Reserve<CoinType>>(singleton_addr());
        let token_reserve = Libra::value<CoinType>(&reserve.token);
        let violas_reserve = Libra::value<LBR::T>(&reserve.violas);
        let total_liquidity = reserve.liquidity_total_supply;
        let (token_amount, liquidity_token_minted) = if (total_liquidity > 0) {
            Transaction::assert(min_liquidity > 0, 3006);
            let big_num:u128 = (violas_amount as u128) * (token_reserve as u128);
            let token_amount:u64 = ((big_num / (violas_reserve as u128) + 1) as u64);
            big_num = (violas_amount as u128) * (total_liquidity as u128);
            let liquidity_token_minted:u64 = (big_num / (violas_reserve as u128) as u64);
            Transaction::assert(max_token_amount >= token_amount && liquidity_token_minted >= min_liquidity, 3007);
            (token_amount, liquidity_token_minted)
        }
        else{
            Transaction::assert(violas_amount >= 100000, 3008);
            let token_amount = max_token_amount;
            let liquidity_token_minted = violas_amount;
            (token_amount, liquidity_token_minted)
        };
        reserve.liquidity_total_supply = total_liquidity + liquidity_token_minted;
        mint<CoinType>(liquidity_token_minted);
        let token = LibraAccount::withdraw_from_sender<CoinType>(token_amount);
        let violas = LibraAccount::withdraw_from_sender<LBR::T>(violas_amount);
        Libra::deposit<CoinType>(&mut reserve.token, token);
        Libra::deposit<LBR::T>(&mut reserve.violas, violas);
        let currency_code = Libra::currency_code<CoinType>();
        let info = borrow_global_mut<ExchangeInfo>(singleton_addr());
        let mint_event = MintEvent{
                mint_amount: liquidity_token_minted,
                token_amount: token_amount,
                violas_amount: violas_amount,
                currency_code: currency_code,
                mint_address: Transaction::sender()
            };
        Debug::print(&mint_event);
        Event::emit_event(
            &mut info.mint_events,
            mint_event
        );
    }

    public fun remove_liquidity<CoinType>(amount: u64, min_violas: u64, min_tokens: u64, deadline: u64) acquires T, Reserve, ExchangeInfo{
        assert_deadline(deadline);
        Transaction::assert(amount > 0 && min_violas > 0 && min_tokens > 0, 3009);
        let addr = singleton_addr();
        let reserve = borrow_global_mut<Reserve<CoinType>>(addr);
        let token_reserve = Libra::value<CoinType>(&reserve.token);
        let violas_reserve = Libra::value<LBR::T>(&reserve.violas);
        let total_liquidity = reserve.liquidity_total_supply;
        Transaction::assert(total_liquidity > 0, 3010);

        let big_amount:u128 = (amount as u128);
        let big_violas_reserve:u128 = (violas_reserve as u128);
        let big_token_reserve:u128 = (token_reserve as u128);
        let big_total_liquidity:u128 = (total_liquidity as u128);
        let violas_amount:u64 = ((big_amount * big_violas_reserve / big_total_liquidity) as u64);
        let token_amount:u64 = ((big_amount * big_token_reserve / big_total_liquidity) as u64);
        Transaction::assert(violas_amount >= min_violas && token_amount >= min_tokens, 3011);
        reserve.liquidity_total_supply = total_liquidity - amount;
        destroy<CoinType>(amount);
        let sender = Transaction::sender();
        let token = Libra::withdraw<CoinType>(&mut reserve.token, token_amount);
        LibraAccount::deposit<CoinType>(sender, token);
        let violas = Libra::withdraw<LBR::T>(&mut reserve.violas, violas_amount);
        LibraAccount::deposit<LBR::T>(sender, violas);
        let currency_code = Libra::currency_code<CoinType>();
        let info = borrow_global_mut<ExchangeInfo>(singleton_addr());
        let burn_event =  BurnEvent{
                burn_amount: amount,
                token_amount: token_amount,
                violas_amount: violas_amount,
                currency_code: currency_code,
                burn_address: sender
            };
        Debug::print(&burn_event);
        Event::emit_event(
            &mut info.burn_events,
            burn_event
        );
    }

    fun get_input_price(input_amount: u64, input_reserve: u64, output_reserve: u64): u64 {
        Transaction::assert(input_reserve > 0 && output_reserve > 0, 3012);
        let input_amount_with_fee = (input_amount as u128) * 997;
        let numerator = input_amount_with_fee * (output_reserve as u128);
        let denominator = ((input_reserve as u128) * 1000) + input_amount_with_fee;
        ((numerator / denominator) as u64)
    }

    fun _violas_to_token_swap_input<CoinType>(violas_sold: u64, min_tokens: u64): u64 acquires Reserve{
        Transaction::assert(violas_sold > 0 && min_tokens > 0, 3013);
        let reserve = borrow_global_mut<Reserve<CoinType>>(singleton_addr());
        let token_reserve = Libra::value<CoinType>(&reserve.token);
        let violas_reserve = Libra::value<LBR::T>(&reserve.violas);
        let tokens_bought = get_input_price(violas_sold, violas_reserve, token_reserve);
        Transaction::assert(tokens_bought >= min_tokens, 3014);
        let violas = LibraAccount::withdraw_from_sender<LBR::T>(violas_sold);
        Libra::deposit<LBR::T>(&mut reserve.violas, violas);
        let token = Libra::withdraw<CoinType>(&mut reserve.token, tokens_bought);
        LibraAccount::deposit<CoinType>(Transaction::sender(), token);
        tokens_bought
    }

    public fun violas_to_token_swap_input<CoinType>(violas_sold: u64, min_tokens: u64, deadline: u64) acquires Reserve, ExchangeInfo{
        assert_deadline(deadline);
        let tokens_bought = _violas_to_token_swap_input<CoinType>(violas_sold, min_tokens);
        let input_currency_code = Libra::currency_code<LBR::T>();
        let output_currency_code = Libra::currency_code<CoinType>();
        let info = borrow_global_mut<ExchangeInfo>(singleton_addr());
        let swap_event =  SwapEvent{
                input_amount: violas_sold,
                input_currency_code: input_currency_code,
                output_amount: tokens_bought,
                output_currency_code: output_currency_code,
                sender: Transaction::sender()
            };
        Debug::print(&swap_event);
        Event::emit_event(
            &mut info.swap_events,
            swap_event
        );
    }

    fun _token_to_violas_swap_input<CoinType>(tokens_sold: u64, min_violas: u64): u64 acquires Reserve{
        Transaction::assert(tokens_sold > 0 && min_violas > 0, 3015);
        let reserve = borrow_global_mut<Reserve<CoinType>>(singleton_addr());
        let token_reserve = Libra::value<CoinType>(&reserve.token);
        let violas_reserve = Libra::value<LBR::T>(&reserve.violas);
        let violas_bought = get_input_price(tokens_sold, token_reserve, violas_reserve);
        Transaction::assert(violas_bought >= min_violas, 3016);
        let token = LibraAccount::withdraw_from_sender<CoinType>(tokens_sold);
        Libra::deposit<CoinType>(&mut reserve.token, token);
        let violas = Libra::withdraw<LBR::T>(&mut reserve.violas, violas_bought);
        LibraAccount::deposit<LBR::T>(Transaction::sender(), violas);
        violas_bought
    }

    public fun token_to_violas_swap_input<CoinType>(tokens_sold: u64, min_violas: u64, deadline: u64) acquires Reserve, ExchangeInfo{
        assert_deadline(deadline);
        let violas_bought = _token_to_violas_swap_input<CoinType>(tokens_sold, min_violas);
        let input_currency_code = Libra::currency_code<CoinType>();
        let output_currency_code = Libra::currency_code<LBR::T>();
        let info = borrow_global_mut<ExchangeInfo>(singleton_addr());
        let swap_event =  SwapEvent{
                input_amount: tokens_sold,
                input_currency_code: input_currency_code,
                output_amount: violas_bought,
                output_currency_code: output_currency_code,
                sender: Transaction::sender()
            };
        Debug::print(&swap_event);
        Event::emit_event(
            &mut info.swap_events,
            swap_event
        ); 
    }

    public fun token_to_token_swap_input<SoldCoinType, BoughtCoinType>(tokens_sold: u64, min_tokens_bought: u64, min_violas_bought: u64, deadline: u64) acquires Reserve, ExchangeInfo {
        assert_deadline(deadline);
        Transaction::assert(tokens_sold > 0 && min_tokens_bought > 0 && min_violas_bought > 0, 3017);
        let reserve = borrow_global_mut<Reserve<SoldCoinType>>(singleton_addr());
        let token_reserve = Libra::value<SoldCoinType>(&reserve.token);
        let violas_reserve = Libra::value<LBR::T>(&reserve.violas);
        let violas_bought = get_input_price(tokens_sold, token_reserve, violas_reserve);
        Transaction::assert(violas_bought >= min_violas_bought, 3018);
        let token = LibraAccount::withdraw_from_sender<SoldCoinType>(tokens_sold);
        Libra::deposit<SoldCoinType>(&mut reserve.token, token);
        let violas = Libra::withdraw<LBR::T>(&mut reserve.violas, violas_bought);
        LibraAccount::deposit<LBR::T>(Transaction::sender(), violas);
        let tokens_bought = _violas_to_token_swap_input<BoughtCoinType>(violas_bought, min_tokens_bought);
        
        let input_currency_code = Libra::currency_code<SoldCoinType>();
        let output_currency_code = Libra::currency_code<BoughtCoinType>();
        let info = borrow_global_mut<ExchangeInfo>(singleton_addr());
        let swap_event =  SwapEvent{
                input_amount: tokens_sold,
                input_currency_code: input_currency_code,
                output_amount: tokens_bought,
                output_currency_code: output_currency_code,
                sender: Transaction::sender()
            };
        Debug::print(&swap_event);
        Event::emit_event(
            &mut info.swap_events,
            swap_event
        );
    }

    fun singleton_addr(): address {
        //0xA550C18
        {{a0}}
    }

    fun assert_deadline(deadline: u64) {
        Transaction::assert(LibraTransactionTimeout::is_valid_transaction_timestamp(deadline), 30100); 
    }
}

// check: EXECUTED



//! new-transaction
//! sender: a0
script {
use {{a0}}::Exchange;
use 0x0::Coin1;
use 0x0::Coin2;
fun main() {
    Exchange::initialize();
    Exchange::publish_reserve<Coin1::T>();
    Exchange::publish_reserve<Coin2::T>();
    let _ = Exchange::get_currencys();
}
}
// check: EXECUTED

//! new-transaction
//! sender: a1
script {
use 0x0::LibraAccount;
use 0x0::Coin1;
use 0x0::Coin2;
use 0x0::Debug;
use {{a0}}::Exchange;
fun main() {
    LibraAccount::add_currency<Coin1::T>();
    LibraAccount::add_currency<Coin2::T>();
    let currencys = Exchange::get_currencys();
    Debug::print(&currencys);
}
}

// check: EXECUTED

//! new-transaction
//! sender: a2
script {
use 0x0::LibraAccount;
use 0x0::Coin1;
use 0x0::Coin2;
fun main() {
    LibraAccount::add_currency<Coin1::T>();
    LibraAccount::add_currency<Coin2::T>();
}
}

// check: EXECUTED

//! new-transaction
//! sender: a3
script {
use 0x0::LibraAccount;
use 0x0::Coin1;
use 0x0::Coin2;
fun main() {
    LibraAccount::add_currency<Coin1::T>();
    LibraAccount::add_currency<Coin2::T>();
}
}

// check: EXECUTED


//! new-transaction
//! sender: association
script {
use 0x0::LibraAccount;
use 0x0::Coin1;
use 0x0::Coin2;
fun main() {
    LibraAccount::mint_to_address<Coin1::T>({{a1}}, 40*10000000000000);
    LibraAccount::mint_to_address<Coin2::T>({{a1}}, 40*10000000000000);
    LibraAccount::mint_to_address<Coin1::T>({{a2}}, 40*10000000000000);
    LibraAccount::mint_to_address<Coin2::T>({{a3}}, 40*10000000000000);
}
}
// check: MintEvent
// check: MintEvent
// check: MintEvent
// check: MintEvent
// check: EXECUTED


//! new-transaction
//! sender: a1
script {
use {{a0}}::Exchange;
use 0x0::Coin1;
use 0x0::Coin2;
use 0x0::Transaction;

fun main() {
    Exchange::add_liquidity<Coin1::T>(0, 10*10000000000000, 5*10000000000000, 1000);
    let liq_amt = Exchange::balance<Coin1::T>({{a1}});
    Transaction::assert(liq_amt == 5*10000000000000, 101);
    Exchange::add_liquidity<Coin2::T>(0, 20*10000000000000, 5*10000000000000, 1000);
    liq_amt = Exchange::balance<Coin2::T>({{a1}});
    Transaction::assert(liq_amt == 5*10000000000000, 102);
}
}

// check: MintEvent
// check: MintEvent
// check: EXECUTED

//! new-transaction
//! sender: a1
script {
use {{a0}}::Exchange;
use 0x0::Coin1;
use 0x0::Coin2;
use 0x0::Transaction;
fun main() {
    Exchange::remove_liquidity<Coin1::T>(5*10000000000000, 1, 1, 1000);
    let liq_amt = Exchange::balance<Coin1::T>({{a1}});
    Transaction::assert(liq_amt == 0, 103);
    Exchange::remove_liquidity<Coin2::T>(5*10000000000000, 1, 1, 1000);
    liq_amt = Exchange::balance<Coin2::T>({{a1}});
    Transaction::assert(liq_amt == 0, 104);
}
}


// VIOLAS_RESERVE = 5*10000000000000
// C1_RESERVE = 10*10000000000000
// C2_RESERVE = 20*10000000000000

// VIOLAS_SOLD = 1*10000000000000
// MIN_C1_BOUGHT = 1

// HAY_BOUGHT = 16624979156244
// MAX_VIOLAS_SOLD = 2*10000000000000

// HAY_SOLD = 2*10000000000000
// MIN_VIOLAS_BOUGHT = 1

// VIOLAS_BOUGHT = 8312489578122
// MAX_C1_SOLD = 3*10000000000000

// MIN_C2_BOUGHT = 1
// C2_BOUGHT = 28436782158340


//! new-transaction
//! sender: a1
script {
use {{a0}}::Exchange;
use 0x0::Coin1;
use 0x0::Coin2;
use 0x0::Transaction;

fun main() {
    Exchange::add_liquidity<Coin1::T>(0, 10*10000000000000, 5*10000000000000, 1000);
    let liq_amt = Exchange::balance<Coin1::T>({{a1}});
    Transaction::assert(liq_amt == 5*10000000000000, 105);
    Exchange::add_liquidity<Coin2::T>(0, 20*10000000000000, 5*10000000000000, 1000);
    liq_amt = Exchange::balance<Coin2::T>({{a1}});
    Transaction::assert(liq_amt == 5*10000000000000, 106);

    let (v0, v1, v2) = Exchange::get_reserve<Coin1::T>();
    Transaction::assert(v0 == 5*10000000000000 && v1 == 10*10000000000000 && v2 == 5*10000000000000, 107);

    (v0, v1, v2) = Exchange::get_reserve<Coin2::T>();
    Transaction::assert(v0 == 5*10000000000000 && v1 == 20*10000000000000 && v2 == 5*10000000000000, 108);
}
}



//! new-transaction
//! sender: a2
script {
use {{a0}}::Exchange;
use 0x0::Coin1;

fun main() {
   Exchange::violas_to_token_swap_input<Coin1::T>(1*10000000000000, 0, 1000);
}
}

// check: ABORTED 3013

//! new-transaction
//! sender: a2
script {
use {{a0}}::Exchange;
use 0x0::Coin1;

fun main() {
   Exchange::violas_to_token_swap_input<Coin1::T>(1*10000000000000, 16624979156244 + 1, 1000);
}
}

// check: ABORTED 3014

//! new-transaction
//! sender: a2
script {
use {{a0}}::Exchange;
use 0x0::LBR;
use 0x0::Coin1;
use 0x0::Transaction;
use 0x0::LibraAccount;
fun main() {
    let lbr_0 = LibraAccount::balance<LBR::T>(Transaction::sender());
    let c1_0 = LibraAccount::balance<Coin1::T>(Transaction::sender());
    Exchange::violas_to_token_swap_input<Coin1::T>(1*10000000000000, 1, 1000);
    let (_, v1, v2) = Exchange::get_reserve<Coin1::T>();
    Transaction::assert(v1 == 10*10000000000000 - 16624979156244, 109);
    Transaction::assert(v2 == 5*10000000000000 + 1*10000000000000, 110);
    let lbr_1 = LibraAccount::balance<LBR::T>(Transaction::sender());
    let c1_1 = LibraAccount::balance<Coin1::T>(Transaction::sender());
    Transaction::assert(lbr_0 == lbr_1 + 1*10000000000000, 111);
    Transaction::assert(c1_0 == c1_1 - 16624979156244, 112);
}
}

// check: EXECUTED


//! new-transaction
//! sender: a1
script {
use {{a0}}::Exchange;
use 0x0::Transaction;
use 0x0::Coin1;
fun main() {
    let liq_amt = Exchange::balance<Coin1::T>(Transaction::sender());
    Exchange::remove_liquidity<Coin1::T>(liq_amt, 1, 1, 1000);
    Exchange::add_liquidity<Coin1::T>(0, 10*10000000000000, 5*10000000000000, 1000);
}
}
// check: EXECUTED

//! new-transaction
//! sender: a2
script {
use {{a0}}::Exchange;
use 0x0::Coin1;
fun main() {
    Exchange::token_to_violas_swap_input<Coin1::T>(2*10000000000000,0, 1000);
}
}
// check: ABORTED 3015

//! new-transaction
//! sender: a2
script {
use {{a0}}::Exchange;
use 0x0::Coin1;
fun main() {
    Exchange::token_to_violas_swap_input<Coin1::T>(2*10000000000000, 8312489578122 + 1, 1000);
}
}
// check: ABORTED 3016


//! new-transaction
//! sender: a2
script {
use {{a0}}::Exchange;
use 0x0::LBR;
use 0x0::Coin1;
use 0x0::Transaction;
use 0x0::LibraAccount;
fun main() {
    let lbr_0 = LibraAccount::balance<LBR::T>(Transaction::sender());
    let c1_0 = LibraAccount::balance<Coin1::T>(Transaction::sender());
    Exchange::token_to_violas_swap_input<Coin1::T>(2*10000000000000, 1, 1000);
    let (_, v1, v2) = Exchange::get_reserve<Coin1::T>();
    Transaction::assert(v1 == 10*10000000000000 + 2*10000000000000, 113);
    Transaction::assert(v2 == 5*10000000000000 - 8312489578122, 114);
    let lbr_1 = LibraAccount::balance<LBR::T>(Transaction::sender());
    let c1_1 = LibraAccount::balance<Coin1::T>(Transaction::sender());
    Transaction::assert(lbr_0 == lbr_1 - 8312489578122, 115);
    Transaction::assert(c1_0 == c1_1 + 2*10000000000000, 116);
}
}
// check: EXECUTED


//! new-transaction
//! sender: a1
script {
use {{a0}}::Exchange;
use 0x0::Transaction;
use 0x0::Coin1;
use 0x0::Coin2;
fun main() {
    let liq_amt = Exchange::balance<Coin1::T>(Transaction::sender());
    Exchange::remove_liquidity<Coin1::T>(liq_amt, 1, 1, 1000);
    liq_amt = Exchange::balance<Coin2::T>(Transaction::sender());
    Exchange::remove_liquidity<Coin2::T>(liq_amt, 1, 1, 1000);
    Exchange::add_liquidity<Coin1::T>(0, 10*10000000000000, 5*10000000000000, 1000);
    Exchange::add_liquidity<Coin2::T>(0, 20*10000000000000, 5*10000000000000, 1000);
}
}
// check: EXECUTED


//! new-transaction
//! sender: a2

script {
use {{a0}}::Exchange;
use 0x0::Transaction;
use 0x0::LibraAccount;
use 0x0::LBR;
use 0x0::Coin1;
use 0x0::Coin2;

fun main() {
    let lbr_0 = LibraAccount::balance<LBR::T>(Transaction::sender());
    let c1_0 = LibraAccount::balance<Coin1::T>(Transaction::sender());
    let c2_0 = LibraAccount::balance<Coin2::T>(Transaction::sender());

    Exchange::token_to_token_swap_input<Coin1::T, Coin2::T>(2*10000000000000, 1, 1, 1000);
    let (_, v01, v02) = Exchange::get_reserve<Coin1::T>();
    Transaction::assert(v01 == 10*10000000000000 + 2*10000000000000, 911);
    Transaction::assert(v02 == 5*10000000000000 - 8312489578122, 912);

    let (_, v11, v12) = Exchange::get_reserve<Coin2::T>();
    Transaction::assert(v11 == 20*10000000000000 - 28436782158339, 913);
    Transaction::assert(v12 == 5*10000000000000 + 8312489578122, 914);

    let lbr_1 = LibraAccount::balance<LBR::T>(Transaction::sender());
    let c1_1 = LibraAccount::balance<Coin1::T>(Transaction::sender());
    let c2_1 = LibraAccount::balance<Coin2::T>(Transaction::sender());
    Transaction::assert(lbr_0 == lbr_1, 915);
    Transaction::assert(c1_0 == c1_1 + 2*10000000000000, 916);
    Transaction::assert(c2_0 == c2_1 - 28436782158339, 917);
}
}