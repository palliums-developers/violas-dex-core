address 0x7257c2417e4d1038e1817c8f283ace2e {
module ExDep {
    use 0x1::Libra::{Self, Libra};
    use 0x1::LibraAccount;
    use 0x1::Transaction;

    // A resource that holds the coins stored in this account
    resource struct Balance<Token> {
        coin: Libra<Token>,
    }

    resource struct WithdrawCapability {
        cap: LibraAccount::WithdrawCapability,
    }
    
    struct MintEvent {
        coina: vector<u8>,
        deposit_amounta: u64,
        coinb: vector<u8>,
        deposit_amountb: u64,
        mint_amount: u64,
    }

    struct BurnEvent {
        coina: vector<u8>,
        withdraw_amounta: u64,
        coinb: vector<u8>,
        withdraw_amountb: u64,
        burn_amount: u64,
    }

    struct SwapEvent {
        input_name: vector<u8>,
        input_amount: u64,
        output_name: vector<u8>,
        output_amount: u64,
    }

    fun singleton_addr(): address {
        0x7257c2417e4d1038e1817c8f283ace2e
    }

    public fun extract_withdraw_capability(sender: &signer): WithdrawCapability {
        assert(Transaction::sender() == singleton_addr(), 4000);
        WithdrawCapability {
            cap: LibraAccount::extract_withdraw_capability(sender),
        }
    }

    // Add a balance of `Token` type to the sending account.
    public fun add_currency<Token>(account: &signer) {
        assert(Transaction::sender() == singleton_addr(), 4010);
        move_to(account, Balance<Token>{ coin: Libra::zero<Token>() })
    }

    public fun deposit<Token>(account: &signer, cap: &WithdrawCapability, to_deposit: u64, metadata: vector<u8>) acquires Balance {
        let sender_cap = LibraAccount::extract_withdraw_capability(account);
        let to_deposit_coin = LibraAccount::withdraw_from<Token>(&sender_cap, to_deposit);
        LibraAccount::restore_withdraw_capability(sender_cap);
        LibraAccount::deposit_with_metadata<Token>(account, singleton_addr(), to_deposit_coin, metadata, x"");
        to_deposit_coin = LibraAccount::withdraw_from<Token>(&cap.cap, to_deposit);
        let balance = borrow_global_mut<Balance<Token>>(singleton_addr());
        Libra::deposit<Token>(&mut balance.coin, to_deposit_coin);
    }

    public fun withdraw<Token>(account: &signer, cap: &WithdrawCapability, amount: u64, metadata: vector<u8>) acquires Balance{
        let balance = borrow_global_mut<Balance<Token>>(singleton_addr());
        assert(balance_for(balance) >= amount, 4020);
        let coin = Libra::withdraw<Token>(&mut balance.coin, amount);
        LibraAccount::deposit<Token>(account, singleton_addr(), coin);
        LibraAccount::pay_from_with_metadata<Token>(&cap.cap, Transaction::sender(), amount, metadata, x"");
    }

    fun balance_for<Token>(balance: &Balance<Token>): u64 {
        Libra::value<Token>(&balance.coin)
    }

    // Return the current balance of the account at `addr`.
    public fun balance<Token>(): u64 acquires Balance {
        balance_for(borrow_global<Balance<Token>>(singleton_addr()))
    }

    public fun c_m_event(v1: vector<u8>, v2: u64, v3: vector<u8>, v4: u64, v5: u64): MintEvent {
        MintEvent {
            coina: v1,
            deposit_amounta: v2,
            coinb: v3,
            deposit_amountb: v4,
            mint_amount: v5
        }
    }

    public fun c_b_event(v1: vector<u8>, v2: u64,v3: vector<u8>, v4: u64, v5: u64): BurnEvent {
        BurnEvent {
            coina: v1,
            withdraw_amounta: v2,
            coinb: v3,
            withdraw_amountb: v4,
            burn_amount: v5
        }
    }


    public fun c_s_event(v1: vector<u8>, v2: u64, v3: vector<u8>, v4: u64): SwapEvent {
        SwapEvent {
            input_name: v1,
            input_amount: v2,
            output_name: v3,
            output_amount: v4,
        }
    }

    fun min(x: u128, y: u128): u64 {
        if(x < y) {
            (x as u64)
        }
        else {
            (y as u64)
        }
    }

    fun sqrt(a: u64, b: u64): u64 {
        let y: u128 =  (a as u128) * (b as u128);
        let z: u128 = 1;
        if (y > 3) {
            z = y;
            let x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        };
        (z as u64)
    }

    public fun get_mint_liquidity(amounta_desired: u64, amountb_desired: u64, amounta_min: u64, amountb_min: u64, reservea: u64, reserveb: u64, total_supply: u64): (u64, u64, u64) {
        let (amounta, amountb) = if(reservea == 0 && reserveb == 0){
            (amounta_desired, amountb_desired)
        }
        else {
            let amountb_optimal = quote(amounta_desired, reservea, reserveb);
            if(amountb_optimal <= amountb_desired){
                assert(amountb_optimal >= amountb_min, 4030);
                (amounta_desired, amountb_optimal)
            }
            else {
                let amounta_optimal = quote(amountb_desired, reserveb, reservea);
                assert(amounta_optimal <= amounta_desired && amounta_optimal >= amounta_min, 4031);
                (amounta_optimal, amountb_desired)
            }
        };
        let big_amounta = (amounta as u128);
        let big_amountb = (amountb as u128);
        let big_total_supply = (total_supply as u128);
        let big_reservea = (reservea as u128);
        let big_reserveb = (reserveb as u128);
        let liquidity = if(total_supply == 0){
            sqrt(amounta, amountb)
        }
        else{
            min(big_amounta * big_total_supply / big_reservea, big_amountb * big_total_supply / big_reserveb)
        };
        assert(liquidity > 0, 4032);
        (liquidity, amounta, amountb)
    }

    fun quote(amounta: u64, reservea: u64, reserveb: u64): u64 {
        assert(amounta > 0 && reservea > 0 && reserveb > 0, 4040);
        let amountb: u64 = (((amounta as u128) * (reserveb as u128) / (reservea as u128)) as u64);
        amountb
    }

    public fun get_amount_out(amount_in: u64, reserve_in: u64, reserve_out: u64): u64 {
        assert(amount_in > 0 && reserve_in > 0 && reserve_out > 0, 4050);
        let amount_in_with_fee = (amount_in as u128) * 997;
        let numerator = amount_in_with_fee * (reserve_out as u128);
        let denominator = (reserve_in as u128) * 1000 + amount_in_with_fee;
        ((numerator / denominator) as u64)
    }
}
}