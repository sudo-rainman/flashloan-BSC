interface IBiswapCallee {
    function BiswapCall(address sender, uint amount0, uint amount1, bytes calldata data) external;
}