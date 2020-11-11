script {
use 0x1::Exchange;

fun main<Coin1, Coin2>(account: &signer) {
    Exchange::withdraw_mine_reward<Coin1, Coin2>(account);
}
}