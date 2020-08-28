script {
use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;
fun main<Coin1, Coin2>(account: &signer, amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64) {
    Exchange::add_liquidity<Coin1, Coin2>(account, amounta_desired, amountb_desired, amounta_min, amountb_min);
}
}