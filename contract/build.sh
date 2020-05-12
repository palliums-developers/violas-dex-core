addr=$1

sed -i "s/0x7257c2417e4d1038e1817c8f283ace2e/$addr/g" *.move

dependences=$(ls modules| sed "s:^:`pwd`/modules/: ")

./move-build -f token.move -s $addr -d $dependences

mv output/transaction_0_module_ViolasToken.mv output/token.mv

./move-build -f exbase.move -s $addr -d $dependences \
            token.move

mv output/transaction_0_module_ExBase.mv output/exbase.mv

./move-build -f exchange.move -s $addr -d $dependences \
			token.move \
            exbase.move

mv output/transaction_0_module_Exchange.mv output/exchange.mv

./move-build -f initialize.move -s $addr -d $dependences \
			token.move \
            exbase.move \
            exchange.move

mv output/transaction_0_script.mv output/initialize.mv

./move-build -f publish.move -s $addr -d $dependences \
			token.move \
            exbase.move \
            exchange.move

mv output/transaction_0_script.mv output/publish.mv

./move-build -f add_liquidity.move -s $addr -d $dependences \
			token.move \
            exbase.move \
            exchange.move

mv output/transaction_0_script.mv output/add_liquidity.mv

./move-build -f transfer.move -s $addr -d $dependences \
			token.move \
            exbase.move \
            exchange.move

mv output/transaction_0_script.mv output/transfer.mv

./move-build -f remove_liquidity.move -s $addr -d $dependences \
			token.move \
            exbase.move \
            exchange.move

mv output/transaction_0_script.mv output/remove_liquidity.mv

./move-build -f violas_to_token_swap.move -s $addr -d $dependences \
			token.move \
            exbase.move \
            exchange.move

mv output/transaction_0_script.mv output/violas_to_token_swap.mv

./move-build -f token_to_violas_swap.move -s $addr -d $dependences \
			token.move \
            exbase.move \
            exchange.move

mv output/transaction_0_script.mv output/token_to_violas_swap.mv

./move-build -f token_to_token_swap.move -s $addr -d $dependences \
			token.move \
            exbase.move \
            exchange.move

mv output/transaction_0_script.mv output/token_to_token_swap.mv


sed -i "s/$addr/0x7257c2417e4d1038e1817c8f283ace2e/g" *.move