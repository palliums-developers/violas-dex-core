script {
use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;
fun main<Coin1, Coin2>(account: &signer, amount_in: u64, amount_out_min: u64, path: vector<u8>) {
    Exchange::swap<Coin1, Coin2>(account, amount_in, amount_out_min, path);
}
}