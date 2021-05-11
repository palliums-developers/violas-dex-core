script {
use 0x1::Exchange;
fun main(account: signer, id: u64, new_alloc_point: u64) {
    Exchange::set_pool_alloc_point(&account, id, new_alloc_point);
}
}
