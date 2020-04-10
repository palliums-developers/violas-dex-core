use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;

fun main(token_sold_idx: u64, tokens_sold: u64, token_bought_idx: u64, min_tokens_bought: u64, min_violas_bought: u64, deadline: u64) {
    Exchange::token_to_token_swap_input(tokens_sold, token_sold_idx, min_tokens_bought, token_bought_idx, min_violas_bought, deadline);
}