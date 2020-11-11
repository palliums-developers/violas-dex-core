script {
use 0x1::ExDep;

fun main<Coin1, Coin2>(account: &signer) {
    ExDep::add_mine_pool<Coin1, Coin2>(account);
}
}