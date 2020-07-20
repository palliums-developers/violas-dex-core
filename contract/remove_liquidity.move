script {
use 0x1::Exchange;
fun main<Coin1, Coin2>(account: &signer, liquidity: u64, amounta_min: u64, amountb_min: u64) {
    Exchange::remove_liquidity<Coin1, Coin2>(account, liquidity, amounta_min, amountb_min);
}
}