script {
use 0x1::Exchange;
fun main(account: &signer, rewarder: address) {
    Exchange::change_rewarder(account, rewarder);
}
}