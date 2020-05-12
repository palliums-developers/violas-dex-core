use 0xeac261c89adafb5ab577bca15c0c187d::ViolasToken;
use 0xeac261c89adafb5ab577bca15c0c187d::Exchange;
use 0x0::Vector;
use 0x0::Transaction;

fun main() {
    let idx = ViolasToken::create_token(0xeac261c89adafb5ab577bca15c0c187d, Vector::empty());
    Transaction::assert(idx == 0, 1);
    idx = ViolasToken::create_token(0xeac261c89adafb5ab577bca15c0c187d, Vector::empty());
    Transaction::assert(idx == 1, 1);
    Exchange::initialize();
    ViolasToken::mint(0, 0xeac261c89adafb5ab577bca15c0c187d, 1000000000000000, Vector::empty());
    let b = ViolasToken::balance(0);
    Transaction::assert(b == 1000000000000000, 400);
    ViolasToken::mint(1, 0xeac261c89adafb5ab577bca15c0c187d, 1000000000000000, Vector::empty());
    b = ViolasToken::balance(1);
    Transaction::assert(b == 1000000000000000, 401);
    ViolasToken::mint(0, 0x3988f2fef277ece79ccb4f3cfa935ab4, 15 * 10000000000000, Vector::empty());
}