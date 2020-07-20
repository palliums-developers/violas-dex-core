script {
use 0x1::Exchange;
use 0x1::LibraAccount;
use 0x1::Signer;

fun main<CoinType>(account: &signer) {
    Exchange::add_currency<CoinType>(account);
    if(!LibraAccount::accepts_currency<CoinType>(Signer::address_of(account))){
        LibraAccount::add_currency<CoinType>(account);
    };
}
}