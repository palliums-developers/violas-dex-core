script {
use 0x7257c2417e4d1038e1817c8f283ace2e::Exchange;
use 0x1::LibraAccount;
use 0x1::Signer;

fun main<CoinType>(account: &signer) {
    Exchange::add_currency<CoinType>(account);
    if(!LibraAccount::accepts_currency<CoinType>(Signer::address_of(account))){
        LibraAccount::add_currency<CoinType>(account);
    };
}
}