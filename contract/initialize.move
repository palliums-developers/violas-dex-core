script {
use 0x1::Exchange;
fun main(account: signer, rewarder: address) {
    Exchange::initialize(&account, rewarder);
}
}
