script {
use 0x1::ExDep;

fun main<Coin1, Coin2>(account: &signer, init_balance: u64, start_time: u64, end_time: u64) {
    ExDep::set_next_rewardpool<Coin1, Coin2>(account, init_balance, start_time, end_time);
}
}