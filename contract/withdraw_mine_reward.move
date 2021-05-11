script {
use 0x1::Exchange;

fun main(account: signer) {
    Exchange::withdraw_mine_reward(&account);
}
}
