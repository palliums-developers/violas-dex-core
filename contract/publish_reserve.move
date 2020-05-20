script {
use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;
fun main<Token>() {
    Exchange::publish_reserve<Token>();
}

}