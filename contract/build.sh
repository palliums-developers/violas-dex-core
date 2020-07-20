#!/bin/bash -e


addr=0x1

dependences=$(ls modules| sed "s:^:`pwd`/modules/: ")

./move-build exdep.move -s $addr -d $dependences

mv ./move_build_output/modules/0_ExDep.mv ./move_build_output/modules/exdep.mv

./move-build exchange.move -s $addr -d $dependences exdep.move

mv ./move_build_output/modules/0_Exchange.mv ./move_build_output/modules/exchange.mv

./move-build initialize.move -s $addr -d $dependences exdep.move exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/initialize.mv

./move-build add_currency.move -s $addr -d $dependences exdep.move exchange.move

mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/add_currency.mv

./move-build add_liquidity.move -s $addr -d $dependences exdep.move exchange.move
          
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/add_liquidity.mv

./move-build remove_liquidity.move -s $addr -d $dependences exdep.move exchange.move
           
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/remove_liquidity.mv

./move-build swap.move -s $addr -d $dependences exdep.move exchange.move
         
mv ./move_build_output/scripts/main.mv ./move_build_output/scripts/swap.mv
