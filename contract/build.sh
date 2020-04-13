addr=$1

sed -i "s/0x7257c2417e4d1038e1817c8f283ace2e/$addr/g" *.move

dependences=$(ls modules| sed "s:^:`pwd`/modules/: ")

./move-build -f token.move -s $addr -d $dependences

./move-build -f exbase.move -s $addr -d $dependences \
            token.move


./move-build -f exchange.move -s $addr -d $dependences \
			token.move \
            exbase.move

./move-build -f initialize.move -s $addr \
            -o output/initialize -d $dependences \
			token.move \
            exbase.move \
            exchange.move

./move-build -f publish.move -s $addr \
            -o output/publish -d $dependences \
			token.move \
            exbase.move \
            exchange.move

./move-build -f add_liquidity.move -s $addr \
            -o output/add_liquidity -d $dependences \
			token.move \
            exbase.move \
            exchange.move

./move-build -f transfer.move -s $addr \
            -o output/transfer -d $dependences \
			token.move \
            exbase.move \
            exchange.move
    
./move-build -f remove_liquidity.move -s $addr \
            -o output/remove_liquidity -d $dependences \
			token.move \
            exbase.move \
            exchange.move

./move-build -f violas_to_token_swap.move -s $addr \
            -o output/violas_to_token_swap -d $dependences \
			token.move \
            exbase.move \
            exchange.move

./move-build -f token_to_violas_swap.move -s $addr \
            -o output/token_to_violas_swap -d $dependences \
			token.move \
            exbase.move \
            exchange.move

./move-build -f token_to_token_swap.move -s $addr \
            -o output/token_to_token_swap -d $dependences \
			token.move \
            exbase.move \
            exchange.move

sed -i "s/$addr/0x7257c2417e4d1038e1817c8f283ace2e/g" *.move