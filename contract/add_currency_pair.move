script {
use 0x1::Exchange;
use 0x1::ExDep;

fun main<Coin1, Coin2>(account: &signer) {
    Exchange::add_currency<Coin1>(account);
    Exchange::add_currency<Coin2>(account);
    ExDep::add_mine_pool<Coin1, Coin2>(account);
}
}