use 0x0::Transaction;
use 0xeac261c89adafb5ab577bca15c0c187d::Exchange;

fun main() {
    Exchange::add_liquidity(1, 0, 20*10000000000000, 5*10000000000000, 1596784979);
    let liq_amt = Exchange::balance(1, Transaction::sender());
    Transaction::assert(liq_amt == 5*10000000000000, 405);
}