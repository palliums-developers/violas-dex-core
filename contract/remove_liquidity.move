use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;

fun main(tokenidx: u64, amount: u64, min_violas: u64, min_tokens: u64, deadline: u64) {
    Exchange::remove_liquidity(amount, tokenidx, min_violas, min_tokens, deadline);
}