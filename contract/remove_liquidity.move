script {
use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;
fun main<Coin1, Coin2>(account: &signer, liquidity: u64, amounta_min: u64, amountb_min: u64) {
    Exchange::remove_liquidity<Coin1, Coin2>(account, liquidity, amounta_min, amountb_min);
}
}