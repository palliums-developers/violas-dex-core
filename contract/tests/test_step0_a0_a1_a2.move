use 0xeac261c89adafb5ab577bca15c0c187d::ViolasToken;
use 0xeac261c89adafb5ab577bca15c0c187d::Exchange;
use 0x0::Vector;

fun main() {
    ViolasToken::publish(Vector::empty());
    Exchange::publish();
}