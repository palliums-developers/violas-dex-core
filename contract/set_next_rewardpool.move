script {
use 0x1::Exchange;
use 0x1::DiemTimestamp;

fun main(account: signer, init_balance: u64) {
    let start_time = DiemTimestamp::now_seconds();
    let end_time = start_time + 86400; // 24hours
    Exchange::set_next_rewards(&account, init_balance, start_time, end_time);
}
}
