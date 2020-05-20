script {
use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;
fun main<SoldToken, BoughtToken>(tokens_sold: u64, min_tokens_bought: u64, min_violas_bought: u64, deadline: u64) {
    Exchange::token_to_token_swap_input<SoldToken, BoughtToken>(tokens_sold, min_tokens_bought, min_violas_bought, deadline);
}
}