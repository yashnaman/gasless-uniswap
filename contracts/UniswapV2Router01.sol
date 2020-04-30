pragma solidity =0.5.16;

import "./interfaces/IUniswapV2Router01.sol";
import "./UniswapV2Library.sol";
import "./interfaces/IWETH.sol";
import "./ForwarderReceiverBase.sol";


contract UniswapV2Router01 is
    IUniswapV2Router01,
    UniswapV2Library,
    ForwarderReceiverBase
{
    bytes4 private constant SELECTOR_TRANSFER = bytes4(
        keccak256(bytes("transfer(address,uint256)"))
    );
    bytes4 private constant SELECTOR_TRANSFER_FROM = bytes4(
        keccak256(bytes("transferFrom(address,address,uint256)"))
    );

    IWETH public WETH;

    // **** TRANSFER HELPERS ****
    function _safeTransfer(address token, address to, uint256 value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR_TRANSFER, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "UniswapV2Router: TRANSFER_FAILED"
        );
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR_TRANSFER_FROM, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "UniswapV2Router: TRANSFER_FROM_FAILED"
        );
    }

    function _safeTransferETH(address to, uint256 value) private {
        (bool success, ) = to.call.value(value)(new bytes(0));
        require(success, "UniswapV2Router: ETH_TRANSFER_FAILED");
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "UniswapV2Router: EXPIRED");
        _;
    }

    constructor(address _WETH, address _factory, address _forwarder)
        public
        ForwarderReceiverBase(_forwarder)
    {
        factory = IUniswapV2Factory(_factory);
        WETH = IWETH(_WETH);
    }

    function() external payable {
        assert(_getTxSigner() == address(WETH)); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) private returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (factory.getPair(tokenA, tokenB) == address(0)) {
            factory.createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = getReserves(tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );
        address pair = pairFor(tokenA, tokenB);
        _safeTransferFrom(tokenA, _getTxSigner(), pair, amountA);
        _safeTransferFrom(tokenB, _getTxSigner(), pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        (amountToken, amountETH) = _addLiquidity(
            token,
            address(WETH),
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = pairFor(token, address(WETH));
        _safeTransferFrom(token, _getTxSigner(), pair, amountToken);
        WETH.deposit.value(amountETH)();
        assert(WETH.transfer(pair, amountETH));
        liquidity = IUniswapV2Pair(pair).mint(to);
        if (msg.value > amountETH)
            _safeTransferETH(_getTxSigner(), msg.value - amountETH); // refund dust eth, if any
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = pairFor(tokenA, tokenB);
        IUniswapV2Pair(pair).transferFrom(_getTxSigner(), pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IUniswapV2Pair(pair).burn(to);
        (address token0, ) = sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(
            amountA >= amountAMin,
            "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
        );
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            address(WETH),
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        _safeTransfer(token, to, amountToken);
        WETH.withdraw(amountETH);
        _safeTransferETH(to, amountETH);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = pairFor(tokenA, tokenB);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IUniswapV2Pair(pair).permit(
            _getTxSigner(),
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountA, amountB) = removeLiquidity(
            tokenA,
            tokenB,
            liquidity,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH) {
        address pair = pairFor(token, address(WETH));
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IUniswapV2Pair(pair).permit(
            _getTxSigner(),
            address(this),
            value,
            deadline,
            v,
            r,
            s
        );
        (amountToken, amountETH) = removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint256[] memory amounts, address[] memory path, address _to)
        private
    {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? pairFor(output, path[i + 2])
                : _to;
            IUniswapV2Pair(pairFor(input, output)).swap(
                amount0Out,
                amount1Out,
                to,
                new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsOut(amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        _safeTransferFrom(
            path[0],
            _getTxSigner(),
            pairFor(path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        amounts = getAmountsIn(amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        _safeTransferFrom(
            path[0],
            _getTxSigner(),
            pairFor(path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == address(WETH), "UniswapV2Router: INVALID_PATH");
        amounts = getAmountsOut(msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        WETH.deposit.value(amounts[0])();
        assert(WETH.transfer(pairFor(path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(
            path[path.length - 1] == address(WETH),
            "UniswapV2Router: INVALID_PATH"
        );
        amounts = getAmountsIn(amountOut, path);
        require(
            amounts[0] <= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        _safeTransferFrom(
            path[0],
            _getTxSigner(),
            pairFor(path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        WETH.withdraw(amounts[amounts.length - 1]);
        _safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256[] memory amounts) {
        require(
            path[path.length - 1] == address(WETH),
            "UniswapV2Router: INVALID_PATH"
        );
        amounts = getAmountsOut(amountIn, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        _safeTransferFrom(
            path[0],
            _getTxSigner(),
            pairFor(path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, address(this));
        WETH.withdraw(amounts[amounts.length - 1]);
        _safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == address(WETH), "UniswapV2Router: INVALID_PATH");
        amounts = getAmountsIn(amountOut, path);
        require(
            amounts[0] <= msg.value,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        WETH.deposit.value(amounts[0])();
        assert(WETH.transfer(pairFor(path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        if (msg.value > amounts[0])
            _safeTransferETH(_getTxSigner(), msg.value - amounts[0]); // refund dust eth, if any
    }
}
