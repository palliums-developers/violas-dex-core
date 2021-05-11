script {
use 0x1::Exchange;

fun main<CoinType:store>(account: signer) {
    Exchange::add_currency<CoinType>(&account);
}
}
