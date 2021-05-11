script {
use 0x1::Exchange;

fun main<Coin1:store, Coin2:store>(account: signer, payee: address, amount_in: u64, amount_out_min: u64, path: vector<u8>, data: vector<u8>) {
    Exchange::swap<Coin1, Coin2>(&account, payee, amount_in, amount_out_min, path, data);
}
}
