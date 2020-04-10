addr=$1

dependences=$(ls modules| sed "s:^:`pwd`/modules/: ")

./move-build -f exbase.move -s $addr -d $dependences


./move-build -f exchange.move -s $addr -d $dependences \
            exbase.move

./move-build -f initialize.move -s $addr \
            -o output/initialize -d $dependences \
            exbase.move \
            exchange.move

./move-build -f publish.move -s $addr \
            -o output/publish -d $dependences \
            exbase.move \
            exchange.move

./move-build -f add_liquidity.move -s $addr \
            -o output/add_liquidity -d $dependences \
            exbase.move \
            exchange.move

./move-build -f transfer.move -s $addr \
            -o output/transfer -d $dependences \
            exbase.move \
            exchange.move
    
./move-build -f remove_liquidity.move -s $addr \
            -o output/remove_liquidity -d $dependences \
            exbase.move \
            exchange.move

./move-build -f violas_to_token_swap.move -s $addr \
            -o output/violas_to_token_swap -d $dependences \
            exbase.move \
            exchange.move

./move-build -f token_to_violas_swap.move -s $addr \
            -o output/token_to_violas_swap -d $dependences \
            exbase.move \
            exchange.move

./move-build -f token_to_token_swap.move -s $addr \
            -o output/token_to_token_swap -d $dependences \
            exbase.move \
            exchange.move