script {
use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;
fun main<Token>(tokens_sold: u64, min_violas: u64, deadline: u64) {
    Exchange::token_to_violas_swap_input<Token>(tokens_sold, min_violas, deadline);
}
}