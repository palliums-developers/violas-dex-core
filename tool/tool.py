
import math

reserves = [{"ida": 4, "amoaunta": 10*10**18, "idb": 6, "amoauntb": 20*10**18}, \
            {"ida": 1, "amoaunta": 10*10**18, "idb": 3, "amoauntb": 20*10**18}, \
            {"ida": 3, "amoaunta": 10*10**18, "idb": 6, "amoauntb": 40*10**18},\
            {"ida": 0, "amoaunta": 5*10**18, "idb": 4, "amoauntb": 10*10**18},\
            {"ida": 0, "amoaunta": 5*10**18, "idb": 1, "amoauntb": 10*10**18}]

def getPairs():
    pairs = [(r['ida'], r['idb']) for r in reserves]
    return pairs

def getCurrencys():
    return ['Coin1', 'Coin2', 'VLSUSD', 'VLSEUR', 'VLSGBP', 'VLSJPY', 'VLSSGD']

def getReserve(CoinA, CoinB):
    (id1, id2) = (CoinA, CoinB)
    sw_flag = False
    if id1 > id2:
        (id1, id2) =  (id2, id1)
        sw_flag = True
    for r in reserves:
        if r['ida'] == id1 and r['idb'] ==id2:
            if sw_flag:
                return (r['amoauntb'], r['amoaunta'])
            else:
                return (r['amoaunta'], r['amoauntb'])
    return (0, 0)

def quote(amountA, reserveA, reserveB):
    assert amountA > 0 and reserveA > 0 and reserveB > 0
    amountB = amountA * reserveB // reserveA
    return amountB

def addLiquidity(amountADesired, amountBDesired, amountAMin, amountBMin, reserveA, reserveB, total_liquidity_supply):
    (amounta, amountb) = (amountADesired, amountBDesired)
    if reserveA > 0 or reserveB > 0:
        amountbOptimal = quote(amountADesired, reserveA, reserveB);
        if amountbOptimal <= amountBDesired:
            assert amountbOptimal >= amountBMin
            (amounta, amountb) = (amountADesired, amountbOptimal)
        else:
            amountaOptimal = quote(amountBDesired, reserveB, reserveA);
            assert amountaOptimal <= amountADesired and amountaOptimal >= amountAMin
            (amounta, amountb) = (amountaOptimal, amountBDesired)
    new_liquidity = int(math.sqrt(amounta * amountb)) if total_liquidity_supply == 0 else \
        int(min(amounta * total_liquidity_supply / reserveA, amountb * total_liquidity_supply / reserveB))
    assert new_liquidity > 0
    return (new_liquidity, amounta, amountb)

def removeLiquidity(liquidity, amounta_min, amountb_min, reservea, reserveb, total_liquidity_supply):
    amounta = liquidity * reservea // total_liquidity_supply
    amountb = liquidity * reserveb // total_liquidity_supply
    assert amounta >= amounta_min and amountb >= amountb_min
    return (amounta, amountb)

    

def getOutputAmountWithoutFee(amountIn, reserveIn, reserveOut):
    assert amountIn > 0 and reserveIn > 0 and reserveOut
    amountOut = amountIn * reserveOut // ( reserveIn + amountIn);
    return amountOut

def getOutputAmountsWithoutFee(amountIn, path):
    assert amountIn > 0 and len(path) >= 2
    amounts = []
    amounts.append(amountIn)
    for i in range(len(path) - 1):
        (reserveIn, reserveOut) = getReserve(path[i], path[i + 1])
        assert reserveIn > 0 and reserveOut > 0
        amountOut = getOutputAmountWithoutFee(amounts[i], reserveIn, reserveOut)
        amounts.append(amountOut)
    return amounts


def getOutputAmount(amountIn, reserveIn, reserveOut):
    assert amountIn > 0 and reserveIn > 0 and reserveOut
    amountInWithFee = amountIn * 997;
    numerator = amountInWithFee * reserveOut;
    denominator = reserveIn * 1000 + amountInWithFee;
    amountOut = numerator // denominator;
    return amountOut

def getInputAmount(amountOut, reserveIn, reserveOut):
    assert amountOut > 0 and reserveIn > 0 and reserveOut
    numerator = reserveIn * amountOut * 1000;
    denominator = (reserveOut - amountOut) * 997;
    amountIn = numerator // denominator + 1;
    return amountIn

def getOutputAmounts(amountIn, path):
    assert amountIn > 0 and len(path) >= 2
    amounts = []
    amounts.append(amountIn)
    for i in range(len(path) - 1):
        (reserveIn, reserveOut) = getReserve(path[i], path[i + 1])
        assert reserveIn > 0 and reserveOut > 0
        amountOut = getOutputAmount(amounts[i], reserveIn, reserveOut)
        amounts.append(amountOut)
    return amounts

def getInputAmounts(amountOut, path):
    assert amountOut > 0 and len(path) >= 2
    amounts = [None] * len(path)
    amounts[len(path) - 1] = amountOut
    for i in range(len(path)-1, 0, -1):
        (reserveIn, reserveOut) = getReserve(path[i - 1], path[i])
        assert reserveIn > 0 and reserveOut > 0
        amounts[i - 1] = getInputAmount(amounts[i], reserveIn, reserveOut)
    return amounts

def bestTradeExactIn(pairs, idIn, idOut, amountIn, originalAmountIn, path = [], bestTrades = None):
    assert len(pairs) > 0
    assert originalAmountIn == amountIn or len(path) > 0
    if len(path) == 0:
        path.append(idIn)
    if bestTrades is None:
        bestTrades = []
    for i in range(0, len(pairs)):
        pair = pairs[i]
        (reserveIn, reserveOut) = getReserve(pair[0], pair[1])
        if pair[0] != idIn and pair[1] != idIn:
            continue
        if reserveIn == 0 or reserveOut == 0:
            continue
        amountOut = getOutputAmount(amountIn, reserveIn, reserveOut)
        newIdIn = pair[1] if idIn == pair[0] else pair[0]
        if idOut == pair[0] or idOut == pair[1]:
            path.append(idOut)
            bestTrades.append((path, amountOut))
        elif len(pairs) > 1:
            pairsExcludingThisPair = pairs[:]
            del(pairsExcludingThisPair[i])
            newPath = path + [newIdIn]
            bestTradeExactIn(pairsExcludingThisPair, newIdIn, idOut, amountOut, originalAmountIn, newPath, bestTrades)
        
    return sorted(bestTrades, key=lambda k: k[1], reverse=True)


def bestTradeExactOut(pairs, idIn, idOut, amountOut, originalAmountOut, path = [], bestTrades = None):
    assert len(pairs) > 0
    assert originalAmountOut == amountOut or len(path) > 0
    if len(path) == 0:
        path.append(idOut)
    if bestTrades is None:
        bestTrades = []
    for i in range(0, len(pairs)):
        pair = pairs[i]
        (reserveIn, reserveOut) = getReserve(pair[0], pair[1])
        if pair[0] != idOut and pair[1] != idOut:
            continue
        if reserveIn == 0 or reserveOut == 0:
            continue
        amountIn = getInputAmount(amountOut, reserveIn, reserveOut)
        newIdOut = pair[1] if idOut == pair[0] else pair[0]
        if idIn == pair[0] or idIn == pair[1]:
            path.insert(0, idIn)
            bestTrades.append((path, amountIn))
        elif len(pairs) > 1:
            pairsExcludingThisPair = pairs[:]
            del(pairsExcludingThisPair[i])
            newPath = [newIdOut] + path
            bestTradeExactOut(pairsExcludingThisPair, idIn, newIdOut, amountIn, originalAmountOut, newPath, bestTrades)
        
    return sorted(bestTrades, key=lambda k: k[1], reverse=False)


if __name__ == "__main__":
    # print(addLiquidity(0, 1, 1*10**30, 2*10**30, 0, 0, 0, 0, 0))
    # print(addLiquidity(0, 1, 1*10**29, 2*10**29, 0, 0, 1*10**30, 2*10**30, 1414213562373094995304885780480))
    # pairs = getPairs()
    # trades = bestTradeExactIn(pairs, 0, 6, 1*10**18, 1*10**18)
    # trades = bestTradeExactIn(pairs, 0, 6, 1*10**18, 1*10**18)
    # print(trades)
    # print("xxxxx")
    # print(getOutputAmounts(1*10**18, trades[0][0]))
    # print(getOutputAmountsWithoutFee(1*10**18, trades[0][0]))
    # print(getOutputAmounts(1*10**18, trades[1][0]))
    # trades = bestTradeExactOut(pairs, 0, 6, 2843678215834080602, 2843678215834080602)
    # print(trades)
    print(addLiquidity(2, 200, 0, 0, 0, 0, 0))
