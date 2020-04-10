use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;

fun main(tokenidx: u64, tokens_sold: u64, min_violas: u64, deadline: u64) {
    Exchange::token_to_violas_swap_input(tokens_sold, tokenidx, min_violas, deadline);
}