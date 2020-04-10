address 0x7257c2417e4d1038e1817c8f283ace2e:

module ViolasToken {
    use 0x0::LibraAccount;
    use 0x0::Transaction;
    use 0x0::Vector;
    use 0x0::LCS;
    // use 0x0::LibraTransactionTimeout;
    // use 0x0::LibraCoin;
    // use 0x0::Hash;

    resource struct Supervisor {
    }

    resource struct T {
	index: u64,
	value: u64,
    }

    resource struct Tokens {
	ts: vector<T>
    }

    resource struct Order {
	t: T,
	peer_token_idx: u64,
	peer_token_amount: u64,
    }
    
    resource struct UserInfo {
	violas_events: LibraAccount::EventHandle<ViolasEvent>,
	data: vector<u8>,
	orders: vector<Order>,
	order_freeslots: vector<u64>,
    }

    resource struct TokenInfo {
	owner: address,
	total_supply: u64,
	data: vector<u8>,
	bulletin_first: vector<u8>,
	bulletins: vector<vector<u8>>,
    }

    resource struct TokenInfoStore {
	tokens: vector<TokenInfo>,
    }
    
    struct ViolasEvent {
	etype: u64,
	paras: vector<u8>,
	data:  vector<u8>,
    }

    fun contract_address() : address {
	0x7257c2417e4d1038e1817c8f283ace2e
    }
    
    fun require_published() {
	Transaction::assert(exists<Tokens>(Transaction::sender()), 101);
    }

    fun require_supervisor() {
	Transaction::assert(exists<Supervisor>(Transaction::sender()), 102);
    }
    
    fun require_owner(tokenidx: u64) acquires TokenInfoStore {
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let len = Vector::length(&tokeninfos.tokens);
	Transaction::assert(tokenidx < len , 103);
	let token = Vector::borrow(&tokeninfos.tokens, tokenidx);
	Transaction::assert(token.owner == Transaction::sender(), 104);
    }

    fun extend_user_tokens(payee: address) acquires TokenInfoStore, Tokens {
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let tokencnt = Vector::length(&tokeninfos.tokens);
	let tokens = borrow_global_mut<Tokens>(payee);
	let usercnt = Vector::length(&tokens.ts);
	loop {
	    if(usercnt >= tokencnt) break;
	    Vector::push_back(&mut tokens.ts, T{ index: usercnt, value: 0});
	    usercnt = usercnt + 1;
	}
    }

    public fun join(t1: T, t2: T) : T {
	let T { index: i1, value: v1 } = t1;
	let T { index: i2, value: v2 } = t2;
	Transaction::assert(i1 == i2, 202);
	T { index: i1, value: v1+v2 }
    }

    public fun join2(t1: &mut T, t2: T) {
	let T { index: i2, value: v2 } = t2;
	Transaction::assert(t1.index == i2, 202);
	t1.value = t1.value + v2;
    }
    
    public fun split(t: &mut T, amount: u64) : T {
	Transaction::assert(t.value >= amount, 203);
	t.value = t.value - amount;
	T { index: t.index, value: amount }
    }
    
    public fun deposit(payee: address, to_deposit: T) acquires TokenInfoStore,Tokens {
	extend_user_tokens(payee);
	let T { index, value } = to_deposit;
	let tokens = borrow_global_mut<Tokens>(payee);
	let t = Vector::borrow_mut(&mut tokens.ts, index);
	t.value = t.value + value; 
    }
    
    public fun withdraw(tokenidx: u64, amount: u64) : T acquires Tokens {
	let tokens = borrow_global_mut<Tokens>(Transaction::sender());
	let t = Vector::borrow_mut(&mut tokens.ts, tokenidx);
	Transaction::assert(t.value >= amount, 105);
	t.value = t.value - amount;
	T { index: tokenidx, value: amount }
    }
    
    fun pay_from_sender(tokenidx: u64, payee: address, amount: u64) acquires TokenInfoStore,Tokens {
    	let t = withdraw(tokenidx, amount);
    	deposit(payee, t);
    }
    
    fun emit_events(etype: u64, paras: vector<u8>, data: vector<u8>) acquires UserInfo {
	let info = borrow_global_mut<UserInfo>(Transaction::sender());
	LibraAccount::emit_event<ViolasEvent>(&mut info.violas_events, ViolasEvent{ etype: etype, paras: paras, data: data});
    }

    public fun zero(tokenidx: u64) : T {
	T { index: tokenidx, value: 0 }
    }

    public fun value(coin_ref: &T): u64 {
    	coin_ref.value
    }
    
    public fun balance(tokenidx: u64) : u64 acquires Tokens {
	let tokens = borrow_global<Tokens>(Transaction::sender());
	if(tokenidx < Vector::length(&tokens.ts)) {
	    let t = Vector::borrow(& tokens.ts, tokenidx);
	    t.value
	} else { 0 }
    }

    public fun token_count() : u64 acquires TokenInfoStore {
	let tokeninfos = borrow_global<TokenInfoStore>(contract_address());
	Vector::length(&tokeninfos.tokens)
    }

    public fun total_supply(tokenidx: u64) : u64 acquires TokenInfoStore {
	let tokeninfos = borrow_global<TokenInfoStore>(contract_address());
	let token = Vector::borrow(& tokeninfos.tokens, tokenidx);
	token.total_supply
    }
    
    public fun publish(userdata: vector<u8>) acquires UserInfo {
	let sender = Transaction::sender();
	Transaction::assert(!exists<Tokens>(sender), 106);
	move_to_sender<Tokens>(Tokens{ ts: Vector::empty() });

	move_to_sender<UserInfo>(UserInfo{
	    violas_events: LibraAccount::new_event_handle<ViolasEvent>(),
	    data: *&userdata,
	    orders: Vector::empty(),
	    order_freeslots: Vector::empty(),
	});

	if(sender == contract_address()) {
	    move_to_sender<Supervisor>(Supervisor{});
	    move_to_sender<TokenInfoStore>(TokenInfoStore{ tokens: Vector::empty() });
	};
	
	emit_events(0, userdata, Vector::empty());
    }

    public fun create_token(owner: address, tokendata: vector<u8>) : u64 acquires TokenInfoStore, UserInfo {
	require_published();
	require_supervisor();
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let len = Vector::length(&tokeninfos.tokens);
	Vector::push_back(&mut tokeninfos.tokens, TokenInfo { owner: owner, total_supply: 0, data: *&tokendata, bulletin_first: Vector::empty(), bulletins: Vector::empty() });
	
	let v = LCS::to_bytes(&owner);
	Vector::append(&mut v, tokendata);
	emit_events(1, v, LCS::to_bytes(&len));
	len
    }

    public fun mint(tokenidx: u64, payee: address, amount: u64, data: vector<u8>) acquires TokenInfoStore, Tokens, UserInfo {
	require_published();
	require_owner(tokenidx);
	let t = T{ index: tokenidx, value: amount };
	deposit(payee, t);

	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	token.total_supply = token.total_supply + amount;

	let v = LCS::to_bytes(&tokenidx);
	Vector::append(&mut v, LCS::to_bytes(&payee));
	Vector::append(&mut v, LCS::to_bytes(&amount));
	Vector::append(&mut v, data);
	emit_events(2, v, Vector::empty());
    }
    
    public fun transfer(tokenidx: u64, payee: address, amount: u64, data: vector<u8>) acquires TokenInfoStore, Tokens,  UserInfo {
	require_published();
	pay_from_sender(tokenidx, payee, amount);
	
	let v = LCS::to_bytes(&tokenidx);
	Vector::append(&mut v, LCS::to_bytes(&payee));
	Vector::append(&mut v, LCS::to_bytes(&amount));
	Vector::append(&mut v, data);
	emit_events(3, v, Vector::empty());
    }

    // public fun make_order(idxa: u64, amounta: u64, idxb: u64, amountb: u64, data: vector<u8>) : u64 acquires Tokens, UserInfo {
    // 	require_published();
    // 	Transaction::assert(amounta > 0, 201);

    // 	let t = withdraw(idxa, amounta);
    // 	let info = borrow_global_mut<UserInfo>(Transaction::sender());
    // 	let len = Vector::length(&info.orders);
    // 	let idx = len;

    // 	Vector::push_back(&mut info.orders, Order { t: t, peer_token_idx: idxb, peer_token_amount: amountb});	    
	
    // 	if(!Vector::is_empty(&info.order_freeslots)) {
    // 	    idx = Vector::pop_back(&mut info.order_freeslots);
    // 	    let order = Vector::swap_remove(&mut info.orders, idx);
    // 	    let Order { t: T { index:_, value:_ }, peer_token_idx:_, peer_token_amount:_ } = order;
    // 	};
	
    // 	let v = LCS::to_bytes(&idxa);
    // 	Vector::append(&mut v, LCS::to_bytes(&amounta));
    // 	Vector::append(&mut v, LCS::to_bytes(&idxb));
    // 	Vector::append(&mut v, LCS::to_bytes(&amountb));
    // 	Vector::append(&mut v, data);
    // 	emit_events(4, v, LCS::to_bytes(&idx));

    // 	idx
    // }

    // public fun cancel_order(orderidx: u64, idxa: u64, amounta: u64, idxb: u64, amountb: u64, data: vector<u8>) acquires TokenInfoStore,Tokens, UserInfo {
    // 	require_published();
    // 	let info = borrow_global_mut<UserInfo>(Transaction::sender());
	
    // 	Vector::push_back(&mut info.orders, Order { t: T{ index: 0, value: 0}, peer_token_idx: 0, peer_token_amount: 0});	    
    // 	Vector::push_back(&mut info.order_freeslots, orderidx);
    // 	let order = Vector::swap_remove(&mut info.orders, orderidx);
	
    // 	Transaction::assert(order.t.index == idxa, 107);
    // 	Transaction::assert(order.t.value == amounta, 108);
    // 	Transaction::assert(order.peer_token_idx == idxb, 109);
    // 	Transaction::assert(order.peer_token_amount == amountb, 110);
	
    // 	let Order { t: t, peer_token_idx:_, peer_token_amount:_ } = order;
    // 	deposit(Transaction::sender(), t);
	
    // 	let v = LCS::to_bytes(&idxa);
    // 	Vector::append(&mut v, LCS::to_bytes(&amounta));
    // 	Vector::append(&mut v, LCS::to_bytes(&idxb));
    // 	Vector::append(&mut v, LCS::to_bytes(&amountb));
    // 	Vector::append(&mut v, data);
    // 	emit_events(5, v, Vector::empty());
    // }
    
    // public fun take_order(maker: address, orderidx: u64, idxa: u64, amounta: u64, idxb: u64, amountb: u64, data: vector<u8>) acquires TokenInfoStore, Tokens, UserInfo {
    // 	require_published();
    // 	let info = borrow_global_mut<UserInfo>(maker);
    // 	let len = Vector::length(&info.orders);
    // 	Vector::push_back(&mut info.orders, Order { t: T {index: idxa, value: 0}, peer_token_idx: idxb, peer_token_amount: amountb });

    // 	let order = Vector::swap_remove(&mut info.orders, orderidx);
	
    // 	Transaction::assert(order.t.index == idxa, 111);
    // 	Transaction::assert(order.t.value == amounta, 112);
    // 	Transaction::assert(order.peer_token_idx == idxb, 113);
    // 	Transaction::assert(order.peer_token_amount == amountb, 114);

    // 	pay_from_sender(idxb, maker, amountb);
    // 	let Order { t: t, peer_token_idx:_, peer_token_amount:_ } = order;
    // 	deposit(Transaction::sender(), t );

	
    // 	if(len == orderidx+1) {
    // 	    let o = Vector::pop_back(&mut info.orders);
    // 	    let Order { t: T { index:_, value:_ }, peer_token_idx:_, peer_token_amount:_ } = o;
    // 	} else {
    // 	    Vector::push_back(&mut info.order_freeslots, orderidx);
    // 	};

    // 	let v = LCS::to_bytes(&maker);
    // 	Vector::append(&mut v, LCS::to_bytes(&orderidx));
    // 	Vector::append(&mut v, LCS::to_bytes(&idxa));
    // 	Vector::append(&mut v, LCS::to_bytes(&amounta));
    // 	Vector::append(&mut v, LCS::to_bytes(&idxb));
    // 	Vector::append(&mut v, LCS::to_bytes(&amountb));
    // 	Vector::append(&mut v, data);
    // 	emit_events(6, v, Vector::empty());
    // }
    
    public fun move_owner(tokenidx: u64, new_owner: address, data: vector<u8>) acquires TokenInfoStore, UserInfo {
	require_published();
	require_owner(tokenidx);
	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
	token.owner = new_owner;

	let v = LCS::to_bytes(&tokenidx);
	Vector::append(&mut v, LCS::to_bytes(&new_owner));
	Vector::append(&mut v, data);
	emit_events(7, v, Vector::empty());
    }

    // public fun update_first_bulletin(tokenidx: u64, data: vector<u8>) acquires TokenInfoStore, UserInfo {
    // 	require_published();
    // 	require_owner(tokenidx);
    // 	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
    // 	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
    // 	token.bulletin_first = *&data;
	
    // 	let v = LCS::to_bytes(&tokenidx);
    // 	Vector::append(&mut v, data);
    // 	emit_events(8, v, Vector::empty());
    // }

    // public fun append_bulletin(tokenidx: u64, data: vector<u8>) acquires TokenInfoStore, UserInfo {
    // 	require_published();
    // 	require_owner(tokenidx);
    // 	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
    // 	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
    // 	Vector::push_back(&mut token.bulletins, *&data);

    // 	let v = LCS::to_bytes(&tokenidx);
    // 	Vector::append(&mut v, data);
    // 	emit_events(9, v, Vector::empty());
    // }

    // public fun destroy_owner(tokenidx: u64, data: vector<u8>) acquires TokenInfoStore, UserInfo{
    // 	require_published();
    // 	require_owner(tokenidx);
    // 	let tokeninfos = borrow_global_mut<TokenInfoStore>(contract_address());
    // 	let token = Vector::borrow_mut(&mut tokeninfos.tokens, tokenidx);
    // 	token.owner = 0x0;

    // 	let v = LCS::to_bytes(&tokenidx);
    // 	Vector::append(&mut v, data);
    // 	emit_events(10, v, Vector::empty());
    // }
    
    // public fun destroy_coin(tokenidx: u64, amount: u64, data: vector<u8>) acquires TokenInfoStore, Tokens, UserInfo{
    // 	require_published();
    // 	require_owner(tokenidx);
    // 	T { index: _, value: _ } = withdraw(tokenidx, amount);
	
    // 	let v = LCS::to_bytes(&tokenidx);
    // 	Vector::append(&mut v, LCS::to_bytes(&amount));
    // 	Vector::append(&mut v, data);
    // 	emit_events(11, v, Vector::empty());
    // }

    // public fun record(data: vector<u8>) acquires UserInfo {
    // 	require_published();
    // 	emit_events(12, data, Vector::empty());
    // }
}