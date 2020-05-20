script {
use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;
fun main<Token>(violas_sold: u64, min_tokens: u64, deadline: u64) {
    Exchange::violas_to_token_swap_input<Token>(violas_sold, min_tokens, deadline);
}
}