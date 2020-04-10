use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;

fun main(tokenidx: u64, min_liquidity: u64, max_token_amount: u64, violas_amount: u64, deadline: u64) {
    Exchange::add_liquidity(tokenidx, min_liquidity, max_token_amount, violas_amount, deadline);
}